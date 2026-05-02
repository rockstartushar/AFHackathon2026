/**
 * Single invocable: operation = INSURANCE | PREREQUISITES | ROOM_RATES | SPECIALTIES | BOOKING_SESSION
 */
public without sharing class HC_PatientDataActionsInvocable {
    public class Request {
        @InvocableVariable(
            required=true
            label='Operation'
            description='INSURANCE = Patient_Insurance__c lines for patientAccountId. PREREQUISITES = Counselling_Prerequisite__c for serviceAppointmentId. ROOM_RATES = Facility_Room_Rate__c for healthcareFacilityId (optional roomTypeApi: General, ICU, Private, Semi_Private). SPECIALTIES = catalog text of active specialties. BOOKING_SESSION = upsert Booking_Session__c for returning-patient context. Uppercase.'
        )
        public String operation;
        @InvocableVariable(
            label='Patient Account Id'
            description='Required for INSURANCE and BOOKING_SESSION; Person Account Id.'
        )
        public Id patientAccountId;
        @InvocableVariable(
            label='Service Appointment Id'
            description='Required for PREREQUISITES — counselling checklist rows linked to this ServiceAppointment.'
        )
        public Id serviceAppointmentId;
        @InvocableVariable(
            label='Healthcare Facility Id'
            description='Required for ROOM_RATES — reference rates for this HealthcareFacility.'
        )
        public Id healthcareFacilityId;
        @InvocableVariable(
            label='Room Type API'
            description='ROOM_RATES only: filter by Facility_Room_Rate__c.Room_Type__c API value.'
        )
        public String roomTypeApi;
        @InvocableVariable(
            label='Preferred Facility Id'
            description='BOOKING_SESSION: default facility for rebook flows.'
        )
        public Id preferredFacilityId;
        @InvocableVariable(
            label='Last Service Appointment Id'
            description='BOOKING_SESSION: link to last ServiceAppointment for context.'
        )
        public Id lastServiceAppointmentId;
        @InvocableVariable(
            label='Last Clinical Encounter Id'
            description='BOOKING_SESSION: optional link to last ClinicalEncounter.'
        )
        public Id lastClinicalEncounterId;
        @InvocableVariable(
            label='Context Token'
            description='BOOKING_SESSION: opaque resume token for anonymous web flows; never put PHI in text fields.'
        )
        public String contextToken;
        @InvocableVariable(
            label='Correlation Id'
            description='Optional tracing id aligned with Agent_Action_Log__c.Correlation_Id__c.'
        )
        public String correlationId;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String summaryText;
        @InvocableVariable public String message;
    }

    @InvocableMethod(
        label='HC Patient Data Actions'
        description='Read-only summaries and booking-session helpers: INSURANCE (plans on file), PREREQUISITES (documents before counselling), ROOM_RATES (non-binding daily rates), SPECIALTIES (catalog), BOOKING_SESSION (save rebook context). Does not schedule appointments — use HC Booking Actions for BOOK/MODIFY/CANCEL.'
        category='Health Cloud'
    )
    public static List<Result> run(List<Request> requests) {
        List<Result> out = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return out;
        }
        Request req = requests[0];
        String op = req.operation == null ? '' : req.operation.trim().toUpperCase();
        if (op == 'INSURANCE') {
            out.add(insurance(req));
        } else if (op == 'PREREQUISITES') {
            out.add(prerequisites(req));
        } else if (op == 'ROOM_RATES') {
            out.add(roomRates(req));
        } else if (op == 'SPECIALTIES') {
            out.add(specialties(req));
        } else if (op == 'BOOKING_SESSION') {
            out.add(bookingSession(req));
        } else {
            Result r = new Result();
            r.success = false;
            r.message = 'Unknown operation. Use INSURANCE, PREREQUISITES, ROOM_RATES, SPECIALTIES, or BOOKING_SESSION.';
            out.add(r);
        }
        return out;
    }

    private static Result insurance(Request req) {
        Result r = new Result();
        r.success = true;
        try {
            if (req.patientAccountId == null) {
                throw new IllegalArgumentException('patientAccountId is required.');
            }
            List<Patient_Insurance__c> rows = [
                SELECT
                    Payer_Name__c,
                    Plan_Name__c,
                    Member_Id__c,
                    Eligibility_Status__c,
                    Valid_From__c,
                    Valid_To__c,
                    Is_Primary__c
                FROM Patient_Insurance__c
                WHERE Patient__c = :req.patientAccountId
                ORDER BY Is_Primary__c DESC, Valid_From__c DESC
                LIMIT 50
            ];
            if (rows.isEmpty()) {
                r.summaryText = 'No insurance rows on file.';
            } else {
                List<String> lines = new List<String>();
                for (Patient_Insurance__c row : rows) {
                    lines.add(
                        '- ' +
                            nz(row.Payer_Name__c) +
                            ' / ' +
                            nz(row.Plan_Name__c) +
                            ' | status=' +
                            nz(row.Eligibility_Status__c) +
                            ' | primary=' +
                            row.Is_Primary__c
                    );
                }
                r.summaryText = String.join(lines, '\n');
            }
        } catch (Exception e) {
            r.success = false;
            r.message = e.getMessage();
        }
        return r;
    }

    private static Result prerequisites(Request req) {
        Result r = new Result();
        r.success = true;
        try {
            if (req.serviceAppointmentId == null) {
                throw new IllegalArgumentException('serviceAppointmentId is required.');
            }
            List<Counselling_Prerequisite__c> rows = [
                SELECT Document_Type__c, Is_Required__c, Is_Satisfied__c, Due_Before__c
                FROM Counselling_Prerequisite__c
                WHERE Related_Appointment__c = :req.serviceAppointmentId
                ORDER BY Due_Before__c NULLS LAST
                LIMIT 50
            ];
            if (rows.isEmpty()) {
                r.summaryText = 'No prerequisite rows for this appointment.';
            } else {
                List<String> lines = new List<String>();
                for (Counselling_Prerequisite__c row : rows) {
                    lines.add(
                        '- ' +
                            row.Document_Type__c +
                            ' | required=' +
                            row.Is_Required__c +
                            ' | satisfied=' +
                            row.Is_Satisfied__c
                    );
                }
                r.summaryText = String.join(lines, '\n');
            }
        } catch (Exception e) {
            r.success = false;
            r.message = e.getMessage();
        }
        return r;
    }

    private static Result roomRates(Request req) {
        Result r = new Result();
        r.success = true;
        try {
            if (req.healthcareFacilityId == null) {
                throw new IllegalArgumentException('healthcareFacilityId is required.');
            }
            List<Facility_Room_Rate__c> rows;
            if (String.isNotBlank(req.roomTypeApi)) {
                String rt = req.roomTypeApi.trim();
                rows = [
                    SELECT Room_Type__c, Daily_Rate__c, Effective_From__c, Effective_To__c
                    FROM Facility_Room_Rate__c
                    WHERE Healthcare_Facility__c = :req.healthcareFacilityId AND Room_Type__c = :rt
                    ORDER BY Effective_From__c DESC
                    LIMIT 50
                ];
            } else {
                rows = [
                    SELECT Room_Type__c, Daily_Rate__c, Effective_From__c, Effective_To__c
                    FROM Facility_Room_Rate__c
                    WHERE Healthcare_Facility__c = :req.healthcareFacilityId
                    ORDER BY Effective_From__c DESC
                    LIMIT 50
                ];
            }
            if (rows.isEmpty()) {
                r.summaryText = 'No room rates on file for this facility.';
            } else {
                List<String> lines = new List<String>();
                for (Facility_Room_Rate__c row : rows) {
                    lines.add(
                        '- ' +
                            row.Room_Type__c +
                            ': ' +
                            row.Daily_Rate__c +
                            ' (' +
                            row.Effective_From__c +
                            ' → ' +
                            (row.Effective_To__c == null ? 'open' : String.valueOf(row.Effective_To__c)) +
                            ')'
                    );
                }
                r.summaryText = String.join(lines, '\n');
            }
        } catch (Exception e) {
            r.success = false;
            r.message = e.getMessage();
        }
        return r;
    }

    private static Result specialties(Request req) {
        Result r = new Result();
        r.success = true;
        try {
            List<CareSpecialty> rows = [SELECT Name FROM CareSpecialty ORDER BY Name LIMIT 200];
            if (rows.isEmpty()) {
                r.summaryText = 'No CareSpecialty catalog rows.';
            } else {
                List<String> lines = new List<String>();
                for (CareSpecialty cs : rows) {
                    lines.add('- ' + cs.Name);
                }
                r.summaryText = String.join(lines, '\n');
            }
        } catch (Exception e) {
            r.success = false;
            r.message = e.getMessage();
        }
        return r;
    }

    private static Result bookingSession(Request req) {
        Result r = new Result();
        r.success = true;
        try {
            if (req.patientAccountId == null) {
                throw new IllegalArgumentException('patientAccountId is required.');
            }
            Booking_Session__c row = new Booking_Session__c();
            row.Patient__c = req.patientAccountId;
            row.Preferred_Facility__c = req.preferredFacilityId;
            row.Last_Service_Appointment__c = req.lastServiceAppointmentId;
            row.Last_Clinical_Encounter__c = req.lastClinicalEncounterId;
            if (String.isNotBlank(req.contextToken)) {
                row.Context_Token__c = req.contextToken.left(255);
                upsert row Context_Token__c;
            } else {
                insert row;
            }
            r.summaryText = 'Booking session Id=' + row.Id;
        } catch (Exception e) {
            r.success = false;
            r.message = e.getMessage();
        }
        return r;
    }

    private static String nz(String s) {
        return String.isBlank(s) ? '' : s;
    }
}
