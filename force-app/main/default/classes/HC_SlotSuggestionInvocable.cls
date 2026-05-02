/**
 * Slot suggestion invocable (Approach A): OperatingHours + TimeSlot minus booked ServiceAppointment/ClinicalEncounter windows.
 * Outputs: slotsJson (for LWC) + summaryText (for agent chat).
 * See docs/Data-Model-Objects-And-Fields.md § Slot suggestion algorithm (Approach A).
 * 
 * LIMITATIONS vs production scheduling:
 * - Fixed slot length (no dynamic duration based on WorkType or appointment type)
 * - No Field Service Lightning APIs (AppointmentBookingService, FSL scheduling policies)
 * - No ServiceTerritory / ServiceResource graphs or resource availability
 * - No travel time, break time, or buffer between appointments
 * - Simple conflict detection (overlap check only, no partial booking prevention)
 * - Timezone handling relies on OperatingHours.TimeZone; assumes consistent timezone across facility
 * - No slot hold/reservation mechanism (slots are suggestions only until BOOK is called)
 * - Max_Daily_Appointments__c is a hard cap check, not gradual capacity scoring
 * - Does not account for equipment, room, or multi-resource constraints
 * 
 * For production use cases requiring advanced scheduling, refer to Salesforce Scheduler or FSL APIs.
 */
public without sharing class HC_SlotSuggestionInvocable {
    private static final Integer DEFAULT_SLOT_MINUTES = 30;
    private static final Integer DEFAULT_MAX_SLOTS = 10;
    private static final List<String> CANCELLED_ENCOUNTER_STATUSES = new List<String>{ 'Canceled', 'Cancelled' };
    private static final List<String> CANCELLED_SA_STATUSES = new List<String>{ 'Canceled', 'Cancelled' };

    public class Request {
        @InvocableVariable(
            required=true
            label='Healthcare Facility Id'
            description='HealthcareFacility Id to search slots for. Required.'
        )
        public Id healthcareFacilityId;

        @InvocableVariable(
            label='Healthcare Provider Id'
            description='Optional HealthcareProvider Id to filter by specific doctor availability.'
        )
        public Id healthcareProviderId;

        @InvocableVariable(
            required=true
            label='Target Date'
            description='Date to find slots for (YYYY-MM-DD or Date type). Required.'
        )
        public Date targetDate;

        @InvocableVariable(
            label='Slot Duration Minutes'
            description='Length of each slot in minutes. Default: 30.'
        )
        public Integer slotDurationMinutes;

        @InvocableVariable(
            label='Max Slots to Return'
            description='Maximum number of available slots to return. Default: 10.'
        )
        public Integer maxSlots;

        @InvocableVariable(
            label='Correlation Id'
            description='Session or conversation id for Agent_Action_Log tracing; optional but recommended.'
        )
        public String correlationId;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
        @InvocableVariable public String summaryText;
        @InvocableVariable public String slotsJson;
        @InvocableVariable public Integer slotsFound;
        @InvocableVariable(
            label = 'Slot UI model'
            description = 'Custom Lightning Type payload for Enhanced Web Chat (hcSlotSuggestionRenderer).'
        )
        public HCSlotSuggestionUiModel slotUi;
    }

    public class SlotWindow {
        public Datetime startTime;
        public Datetime endTime;
        public String label;

        public SlotWindow(Datetime startDt, Datetime endDt, String lbl) {
            this.startTime = startDt;
            this.endTime = endDt;
            this.label = lbl;
        }
    }

    @InvocableMethod(
        label='HC Slot Suggestion'
        description='Suggests available appointment slots for a facility (and optional provider) on a target date using OperatingHours/TimeSlot minus booked appointments. Returns slotsJson for LWC and summaryText for agent. Approach A implementation - see docs/Data-Model-Objects-And-Fields.md for limitations vs production scheduling.'
        category='Health Cloud'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return out;
        }
        Request req = requests[0];
        out.add(findSlots(req));
        return out;
    }

    private static Result findSlots(Request req) {
        Result res = new Result();
        res.success = false;
        res.slotsFound = 0;

        try {
            // Validate inputs
            if (req.healthcareFacilityId == null) {
                throw new IllegalArgumentException('healthcareFacilityId is required.');
            }
            if (req.targetDate == null) {
                throw new IllegalArgumentException('targetDate is required.');
            }
            if (req.targetDate < Date.today()) {
                throw new IllegalArgumentException('Target date must be today or in the future.');
            }

            Integer slotMinutes = req.slotDurationMinutes != null && req.slotDurationMinutes > 0
                ? req.slotDurationMinutes
                : DEFAULT_SLOT_MINUTES;
            Integer maxSlots = req.maxSlots != null && req.maxSlots > 0 ? req.maxSlots : DEFAULT_MAX_SLOTS;

            // Get facility and check daily cap
            HealthcareFacility facility = queryFacility(req.healthcareFacilityId);
            if (facility.Max_Daily_Appointments__c != null) {
                Integer dailyCount = countDailyEncounters(req.healthcareFacilityId, req.targetDate);
                if (dailyCount >= facility.Max_Daily_Appointments__c.intValue()) {
                    res.message = 'Facility has reached its daily appointment limit.';
                    res.summaryText = 'No slots available - daily capacity reached.';
                    HCAuditHelper.log(
                        'HC_SlotSuggestion',
                        'Failed',
                        req.correlationId,
                        res.message,
                        summarizeRequest(req),
                        null,
                        null
                    );
                    return res;
                }
            }

            // Get operating hours
            Id operatingHoursId = resolveOperatingHours(facility, req.healthcareProviderId);
            if (operatingHoursId == null) {
                throw new IllegalArgumentException('No operating hours configured for facility or provider.');
            }

            OperatingHours opHours = queryOperatingHours(operatingHoursId);
            List<TimeSlot> timeSlots = queryTimeSlots(
                operatingHoursId,
                req.targetDate,
                opHours.TimeZone
            );

            if (timeSlots.isEmpty()) {
                res.message = 'No operating hours defined for the selected day.';
                res.summaryText = 'No slots available for the selected date.';
                HCAuditHelper.log(
                    'HC_SlotSuggestion',
                    'Success',
                    req.correlationId,
                    null,
                    summarizeRequest(req),
                    null,
                    null
                );
                return res;
            }

            // Get booked appointments (conflicts)
            List<BookedWindow> conflicts = queryConflicts(
                req.healthcareFacilityId,
                req.healthcareProviderId,
                req.targetDate,
                opHours.TimeZone
            );

            // Generate candidate slots from TimeSlot windows
            List<SlotWindow> candidateSlots = generateCandidateSlots(
                timeSlots,
                req.targetDate,
                opHours.TimeZone,
                slotMinutes
            );

            // Filter out conflicts
            List<SlotWindow> availableSlots = filterConflicts(candidateSlots, conflicts, maxSlots);

            // Build outputs
            res.slotsFound = availableSlots.size();
            res.summaryText = buildSummaryText(availableSlots, facility.Name);
            res.slotsJson = buildSlotsJson(
                availableSlots,
                req.healthcareFacilityId,
                req.healthcareProviderId,
                req.targetDate,
                slotMinutes,
                facility.Name
            );
            res.slotUi = new HCSlotSuggestionUiModel();
            res.slotUi.payload = res.slotsJson;
            res.success = true;
            res.message = 'Found ' + res.slotsFound + ' available slot(s).';

            HCAuditHelper.log(
                'HC_SlotSuggestion',
                'Success',
                req.correlationId,
                null,
                summarizeRequest(req) + '; found=' + res.slotsFound,
                null,
                null
            );
        } catch (Exception e) {
            res.message = e.getMessage();
            res.summaryText = 'Unable to retrieve slots: ' + e.getMessage();
            HCAuditHelper.log(
                'HC_SlotSuggestion',
                'Failed',
                req.correlationId,
                e.getMessage(),
                summarizeRequest(req),
                null,
                null
            );
        }
        return res;
    }

    private static HealthcareFacility queryFacility(Id facilityId) {
        return [
            SELECT Id, Name, Max_Daily_Appointments__c, OPD_Operating_Hours__c
            FROM HealthcareFacility
            WHERE Id = :facilityId
            LIMIT 1
        ];
    }

    private static Integer countDailyEncounters(Id facilityId, Date targetDate) {
        Datetime sod = Datetime.newInstanceGmt(targetDate, Time.newInstance(0, 0, 0, 0));
        Datetime eod = sod.addDays(1);
        return [
            SELECT COUNT()
            FROM ClinicalEncounter
            WHERE
                FacilityId = :facilityId
                AND StartDate >= :sod
                AND StartDate < :eod
                AND (Status NOT IN :CANCELLED_ENCOUNTER_STATUSES OR Status = NULL)
        ];
    }

    private static Id resolveOperatingHours(HealthcareFacility facility, Id providerId) {
        // Provider-specific hours take precedence
        if (providerId != null) {
            List<HealthcarePractitionerFacility> hpfs = [
                SELECT OperatingHoursId
                FROM HealthcarePractitionerFacility
                WHERE
                    HealthcareProviderId = :providerId
                    AND HealthcareFacilityId = :facility.Id
                    AND IsActive = TRUE
                    AND OperatingHoursId != NULL
                LIMIT 1
            ];
            if (!hpfs.isEmpty() && hpfs[0].OperatingHoursId != null) {
                return hpfs[0].OperatingHoursId;
            }
        }
        // Fall back to facility default
        return facility.OPD_Operating_Hours__c;
    }

    private static OperatingHours queryOperatingHours(Id opHoursId) {
        return [SELECT Id, Name, TimeZone FROM OperatingHours WHERE Id = :opHoursId LIMIT 1];
    }

    private static List<TimeSlot> queryTimeSlots(Id opHoursId, Date targetDate, String timezoneSid) {
        String dayOfWeek = getDayOfWeekForFacility(targetDate, timezoneSid);
        return [
            SELECT Id, DayOfWeek, StartTime, EndTime
            FROM TimeSlot
            WHERE OperatingHoursId = :opHoursId AND DayOfWeek = :dayOfWeek
            ORDER BY StartTime
        ];
    }

    /**
     * Weekday label aligned with TimeSlot.DayOfWeek (typically English full day name).
     * Formats using OperatingHours.TimeZone so the weekday reflects the facility calendar.
     */
    private static String getDayOfWeekForFacility(Date targetDate, String timezoneSid) {
        if (targetDate == null) {
            return Datetime.now().format('EEEE');
        }
        String tz = String.isNotBlank(timezoneSid) ? timezoneSid : UserInfo.getTimeZone().getID();
        Datetime anchor = Datetime.newInstanceGmt(
            targetDate.year(),
            targetDate.month(),
            targetDate.day(),
            12,
            0,
            0
        );
        return anchor.format('EEEE', tz);
    }

    /**
     * Busy windows for overlap removal: all non-cancelled ClinicalEncounters at this facility on the target day.
     * Always facility-wide (not restricted to ClinicalEncounterProvider when a clinician is chosen).
     * Reason: BOOK often creates ClinicalEncounter without ClinicalEncounterProvider when no doctor is passed;
     * the old provider-only branch then missed those visits, so booked slots reappeared in provider-scoped searches.
     * Trade-off: with a named clinician, times blocked include any visit at the site, not only that doctor’s column
     * (acceptable for single-resource hackathon flows; refine per org if you model true multi-provider concurrency).
     */
    private static List<BookedWindow> queryConflicts(
        Id facilityId,
        Id providerId,
        Date targetDate,
        String timezone
    ) {
        Datetime sod = Datetime.newInstanceGmt(targetDate, Time.newInstance(0, 0, 0, 0));
        Datetime eod = sod.addDays(1);

        List<BookedWindow> conflicts = new List<BookedWindow>();

        List<ClinicalEncounter> encounters = [
            SELECT Id, StartDate, EndDate
            FROM ClinicalEncounter
            WHERE
                FacilityId = :facilityId
                AND StartDate >= :sod
                AND StartDate < :eod
                AND (Status NOT IN :CANCELLED_ENCOUNTER_STATUSES OR Status = NULL)
        ];
        for (ClinicalEncounter ce : encounters) {
            conflicts.add(new BookedWindow(ce.StartDate, ce.EndDate));
        }

        return conflicts;
    }

    private static List<SlotWindow> generateCandidateSlots(
        List<TimeSlot> timeSlots,
        Date targetDate,
        String timezone,
        Integer slotMinutes
    ) {
        List<SlotWindow> candidates = new List<SlotWindow>();

        for (TimeSlot ts : timeSlots) {
            Datetime windowStart = combineDateAndTime(targetDate, ts.StartTime, timezone);
            Datetime windowEnd = combineDateAndTime(targetDate, ts.EndTime, timezone);

            Datetime slotStart = windowStart;
            while (slotStart.addMinutes(slotMinutes) <= windowEnd) {
                Datetime slotEnd = slotStart.addMinutes(slotMinutes);
                String label = formatSlotLabel(slotStart, slotEnd, timezone);
                candidates.add(new SlotWindow(slotStart, slotEnd, label));
                slotStart = slotEnd;
            }
        }

        return candidates;
    }

    private static Datetime combineDateAndTime(Date d, Time t, String timezone) {
        // Create datetime in facility timezone
        Datetime dt = Datetime.newInstance(d, t);
        // Note: Salesforce stores datetimes in GMT internally; TimeZone on OperatingHours
        // is used for display/interpretation. For simplicity, we trust the Time values
        // are already in the facility's local context.
        return dt;
    }

    private static String formatSlotLabel(Datetime startDt, Datetime endDt, String timezone) {
        // Format in 12-hour time for readability
        String startStr = startDt.format('h:mm a', timezone);
        String endStr = endDt.format('h:mm a', timezone);
        return startStr + ' – ' + endStr;
    }

    private static List<SlotWindow> filterConflicts(
        List<SlotWindow> candidates,
        List<BookedWindow> conflicts,
        Integer maxSlots
    ) {
        List<SlotWindow> available = new List<SlotWindow>();

        for (SlotWindow candidate : candidates) {
            if (available.size() >= maxSlots) {
                break;
            }
            Boolean hasConflict = false;
            for (BookedWindow conflict : conflicts) {
                if (overlaps(candidate.startTime, candidate.endTime, conflict.startTime, conflict.endTime)) {
                    hasConflict = true;
                    break;
                }
            }
            if (!hasConflict) {
                available.add(candidate);
            }
        }

        return available;
    }

    private static Boolean overlaps(Datetime start1, Datetime end1, Datetime start2, Datetime end2) {
        return start1 < end2 && start2 < end1;
    }

    private static String buildSummaryText(List<SlotWindow> slots, String facilityName) {
        if (slots.isEmpty()) {
            return 'No available slots found for ' + facilityName + '.';
        }

        List<String> lines = new List<String>();
        lines.add('Available slots at ' + facilityName + ':');
        Integer count = 1;
        for (SlotWindow slot : slots) {
            lines.add(count + '. ' + slot.label);
            count++;
        }
        return String.join(lines, '\n');
    }

    private static String buildSlotsJson(
        List<SlotWindow> slots,
        Id facilityId,
        Id providerId,
        Date targetDate,
        Integer slotMinutes,
        String facilityName
    ) {
        Map<String, Object> payload = new Map<String, Object>();
        payload.put('facilityId', facilityId);
        payload.put('providerId', providerId);
        payload.put('date', targetDate.format());
        payload.put('slotMinutes', slotMinutes);
        payload.put('facilityName', facilityName);

        List<Map<String, Object>> slotList = new List<Map<String, Object>>();
        for (SlotWindow slot : slots) {
            Map<String, Object> slotObj = new Map<String, Object>();
            slotObj.put('start', slot.startTime.format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ'));
            slotObj.put('end', slot.endTime.format('yyyy-MM-dd\'T\'HH:mm:ss.SSSZ'));
            slotObj.put('label', slot.label);
            slotList.add(slotObj);
        }
        payload.put('slots', slotList);

        return JSON.serialize(payload);
    }

    private static String summarizeRequest(Request req) {
        String summary = 'facility=' + req.healthcareFacilityId + ';date=' + req.targetDate;
        if (req.healthcareProviderId != null) {
            summary += ';provider=' + req.healthcareProviderId;
        }
        return summary;
    }

    private class BookedWindow {
        public Datetime startTime;
        public Datetime endTime;

        public BookedWindow(Datetime start, Datetime endTime) {
            this.startTime = start;
            this.endTime = endTime;
        }
    }
}