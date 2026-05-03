/**
 * Thin @AuraEnabled facade for the internal Scheduling Console LWC.
 * Delegates only to existing HC_* Flows and invocables — no booking/directory logic duplicated here.
 * Does not change Agentforce GenAi actions or invocable contracts.
 */
public inherited sharing class HC_SchedulingConsoleController {
    @AuraEnabled
    public static Map<String, Object> resolvePatientByPhone(String phone, String messagingSessionId) {
        Map<String, Object> vars = new Map<String, Object>{
            'input_Phone' => phone == null ? '' : phone.trim(),
            'input_MessagingSessionId' => messagingSessionId
        };
        Flow.Interview fi = Flow.Interview.createInterview('HC_Resolve_Patient_By_Phone', vars);
        fi.start();
        Object callerHint = fi.getVariableValue('output_CallerPhoneHint');
        return new Map<String, Object>{
            'output_Status' => String.valueOf(fi.getVariableValue('output_Status')),
            'output_PatientAccountId' => fi.getVariableValue('output_PatientAccountId'),
            'output_CallerPhoneHint' => callerHint != null ? String.valueOf(callerHint) : ''
        };
    }

    @AuraEnabled
    public static Map<String, Object> createGuestPersonAccount(
        String patientFullName,
        String personMobilePhone,
        String personEmail,
        String messagingSessionId
    ) {
        Map<String, Object> vars = new Map<String, Object>{
            'patient_full_name' => patientFullName,
            'PersonMobilePhone' => personMobilePhone,
            'PersonEmail' => personEmail,
            'input_MessagingSessionId' => messagingSessionId
        };
        Flow.Interview fi = Flow.Interview.createInterview('HC_Create_Guest_Person_Account', vars);
        fi.start();
        return new Map<String, Object>{
            'output_Status' => String.valueOf(fi.getVariableValue('output_Status')),
            'output_PatientAccountId' => fi.getVariableValue('output_PatientAccountId'),
            'output_ErrorMessage' => fi.getVariableValue('output_ErrorMessage')
        };
    }

    @AuraEnabled
    public static void logAgentAction(
        String inputActionName,
        String inputStatus,
        String inputCorrelationId,
        String inputErrorMessage,
        String inputInputSummary
    ) {
        Map<String, Object> vars = new Map<String, Object>{
            'input_ActionName' => inputActionName,
            'input_Status' => inputStatus,
            'input_CorrelationId' => inputCorrelationId,
            'input_ErrorMessage' => inputErrorMessage,
            'input_InputSummary' => inputInputSummary
        };
        Flow.Interview fi = Flow.Interview.createInterview('HC_Log_Agent_Action', vars);
        fi.start();
    }

    @AuraEnabled
    public static Map<String, Object> getFacilities(String cityKeyword) {
        HCFacilityListInvocable.GetFacilitiesRequest req = new HCFacilityListInvocable.GetFacilitiesRequest();
        req.input_CityKeyword = cityKeyword;
        List<HCFacilityListInvocable.GetFacilitiesResult> res = HCFacilityListInvocable.getFacilities(
            new List<HCFacilityListInvocable.GetFacilitiesRequest>{ req }
        );
        return wrapFacilityResult(firstOrEmptyFacility(res));
    }

    private static Map<String, Object> wrapFacilityResult(HCFacilityListInvocable.GetFacilitiesResult r) {
        if (r == null || r.facilityListUi == null || String.isBlank(r.facilityListUi.payload)) {
            return new Map<String, Object>{
                'success' => false,
                'message' => 'No result',
                'summaryText' => '',
                'rows' => new List<Object>()
            };
        }
        Map<String, Object> pay = (Map<String, Object>) JSON.deserializeUntyped(r.facilityListUi.payload);
        Boolean ok = pay.containsKey('success') ? (Boolean) pay.get('success') : true;
        String msg = pay.containsKey('message') ? (String) pay.get('message') : '';
        String summary = pay.containsKey('summaryText') ? (String) pay.get('summaryText') : '';
        List<Object> rows = new List<Object>();
        if (pay.containsKey('rows')) {
            rows = (List<Object>) pay.get('rows');
        }
        return new Map<String, Object>{
            'success' => ok,
            'message' => msg,
            'summaryText' => summary,
            'rows' => rows
        };
    }

    private static HCFacilityListInvocable.GetFacilitiesResult firstOrEmptyFacility(List<HCFacilityListInvocable.GetFacilitiesResult> res) {
        return (res == null || res.isEmpty()) ? null : res[0];
    }

    @AuraEnabled
    public static Map<String, Object> findSpecialists(String cityKeyword, String specialtyName, Integer topN) {
        HC_DirectoryInvocable.FindSpecialistRequest req = new HC_DirectoryInvocable.FindSpecialistRequest();
        req.cityKeyword = cityKeyword;
        req.specialtyName = specialtyName;
        req.topN = topN;
        List<HC_DirectoryInvocable.FindSpecialistResult> res = HC_DirectoryInvocable.findSpecialists(
            new List<HC_DirectoryInvocable.FindSpecialistRequest>{ req }
        );
        if (res == null || res.isEmpty()) {
            return new Map<String, Object>{
                'success' => false,
                'message' => 'No result',
                'summaryText' => '',
                'rows' => new List<Object>()
            };
        }
        HC_DirectoryInvocable.FindSpecialistResult r = res[0];
        List<Object> rows = new List<Object>();
        if (r.directoryUi != null && String.isNotBlank(r.directoryUi.payload)) {
            Map<String, Object> pay = (Map<String, Object>) JSON.deserializeUntyped(r.directoryUi.payload);
            if (pay.containsKey('rows')) {
                rows = (List<Object>) pay.get('rows');
            }
        }
        return new Map<String, Object>{
            'success' => r.success == null ? true : r.success,
            'summaryText' => r.summaryText,
            'rows' => rows
        };
    }

    @AuraEnabled
    public static Map<String, Object> routeSymptomToSpecialty(String symptomText, String cityKeyword) {
        HC_SymptomRoutingInvocable.SymptomRoutingInput in0 = new HC_SymptomRoutingInvocable.SymptomRoutingInput();
        in0.symptomText = symptomText;
        in0.cityKeyword = cityKeyword;
        List<HC_SymptomRoutingInvocable.SymptomRoutingOutput> outs = HC_SymptomRoutingInvocable.routeSymptomToSpecialty(
            new List<HC_SymptomRoutingInvocable.SymptomRoutingInput>{ in0 }
        );
        if (outs == null || outs.isEmpty()) {
            return new Map<String, Object>();
        }
        HC_SymptomRoutingInvocable.SymptomRoutingOutput o = outs[0];
        return new Map<String, Object>{
            'recommendedSpecialty' => o.recommendedSpecialty,
            'routingSummary' => o.routingSummary,
            'disclaimer' => o.disclaimer,
            'matchFound' => o.matchFound,
            'cityKeyword' => o.cityKeyword
        };
    }

    @AuraEnabled
    public static Map<String, Object> getSuggestedSlots(
        String healthcareFacilityId,
        String healthcareProviderId,
        String targetDateIso,
        Integer slotDurationMinutes,
        Integer maxSlots,
        String correlationId
    ) {
        HC_SlotSuggestionInvocable.Request req = new HC_SlotSuggestionInvocable.Request();
        req.healthcareFacilityId = (Id) healthcareFacilityId;
        if (String.isNotBlank(healthcareProviderId)) {
            req.healthcareProviderId = (Id) healthcareProviderId;
        }
        req.targetDate = parseDateIso(targetDateIso);
        req.slotDurationMinutes = slotDurationMinutes;
        req.maxSlots = maxSlots;
        req.correlationId = correlationId;
        List<HC_SlotSuggestionInvocable.Result> res = HC_SlotSuggestionInvocable.run(new List<HC_SlotSuggestionInvocable.Request>{ req });
        if (res == null || res.isEmpty()) {
            return new Map<String, Object>{ 'success' => false, 'message' => 'No result', 'summaryText' => '', 'slotsJson' => null, 'slotsFound' => 0 };
        }
        HC_SlotSuggestionInvocable.Result r = res[0];
        return new Map<String, Object>{
            'success' => r.success,
            'message' => r.message,
            'summaryText' => r.summaryText,
            'slotsJson' => r.slotsJson,
            'slotsFound' => r.slotsFound
        };
    }

    @AuraEnabled
    public static Map<String, Object> runBookingAction(
        String operation,
        String patientAccountId,
        String healthcareFacilityId,
        String schedStartIso,
        String schedEndIso,
        String healthcareProviderId,
        String parentRecordId,
        String workTypeId,
        String correlationId,
        String subject,
        String serviceAppointmentId,
        String cancellationReason
    ) {
        HC_BookingActionsInvocable.Request req = new HC_BookingActionsInvocable.Request();
        req.operation = operation;
        if (String.isNotBlank(patientAccountId)) {
            req.patientAccountId = (Id) patientAccountId;
        }
        if (String.isNotBlank(healthcareFacilityId)) {
            req.healthcareFacilityId = (Id) healthcareFacilityId;
        }
        if (String.isNotBlank(healthcareProviderId)) {
            req.healthcareProviderId = (Id) healthcareProviderId;
        }
        if (String.isNotBlank(parentRecordId)) {
            req.parentRecordId = (Id) parentRecordId;
        }
        if (String.isNotBlank(workTypeId)) {
            req.workTypeId = (Id) workTypeId;
        }
        if (String.isNotBlank(serviceAppointmentId)) {
            req.serviceAppointmentId = (Id) serviceAppointmentId;
        }
        req.correlationId = correlationId;
        req.subject = subject;
        req.cancellationReason = cancellationReason;
        if (String.isNotBlank(schedStartIso)) {
            req.schedStartOrNewStart = parseDatetimeFlexible(schedStartIso);
        }
        if (String.isNotBlank(schedEndIso)) {
            req.schedEndOrNewEnd = parseDatetimeFlexible(schedEndIso);
        }
        List<HC_BookingActionsInvocable.Result> res = HC_BookingActionsInvocable.run(new List<HC_BookingActionsInvocable.Request>{ req });
        if (res == null || res.isEmpty()) {
            return new Map<String, Object>{ 'success' => false, 'message' => 'No result' };
        }
        HC_BookingActionsInvocable.Result r = res[0];
        return new Map<String, Object>{
            'success' => r.success,
            'message' => r.message,
            'serviceAppointmentId' => r.serviceAppointmentId,
            'clinicalEncounterId' => r.clinicalEncounterId,
            'clinicalEncounterProviderId' => r.clinicalEncounterProviderId
        };
    }

    @AuraEnabled
    public static Map<String, Object> runPatientDataAction(
        String operation,
        String patientAccountId,
        String serviceAppointmentId,
        String healthcareFacilityId,
        String roomTypeApi,
        String correlationId
    ) {
        HC_PatientDataActionsInvocable.Request req = new HC_PatientDataActionsInvocable.Request();
        req.operation = operation;
        if (String.isNotBlank(patientAccountId)) {
            req.patientAccountId = (Id) patientAccountId;
        }
        if (String.isNotBlank(serviceAppointmentId)) {
            req.serviceAppointmentId = (Id) serviceAppointmentId;
        }
        if (String.isNotBlank(healthcareFacilityId)) {
            req.healthcareFacilityId = (Id) healthcareFacilityId;
        }
        req.roomTypeApi = roomTypeApi;
        req.correlationId = correlationId;
        List<HC_PatientDataActionsInvocable.Result> res = HC_PatientDataActionsInvocable.run(
            new List<HC_PatientDataActionsInvocable.Request>{ req }
        );
        if (res == null || res.isEmpty()) {
            return new Map<String, Object>{ 'success' => false, 'message' => 'No result', 'summaryText' => '' };
        }
        HC_PatientDataActionsInvocable.Result r = res[0];
        return new Map<String, Object>{ 'success' => r.success, 'message' => r.message, 'summaryText' => r.summaryText };
    }

    @AuraEnabled
    public static Map<String, Object> createVisitReminderTask(String serviceAppointmentId, String correlationId) {
        HC_ReminderInvocable.ReminderRequest req = new HC_ReminderInvocable.ReminderRequest();
        req.serviceAppointmentId = (Id) serviceAppointmentId;
        req.correlationId = correlationId;
        List<HC_ReminderInvocable.ReminderResult> res = HC_ReminderInvocable.createReminderTask(
            new List<HC_ReminderInvocable.ReminderRequest>{ req }
        );
        if (res == null || res.isEmpty()) {
            return new Map<String, Object>{ 'success' => false, 'message' => 'No result' };
        }
        HC_ReminderInvocable.ReminderResult r = res[0];
        return new Map<String, Object>{ 'success' => r.success, 'message' => r.message, 'taskId' => r.taskId };
    }

    /**
     * Lists visits for reschedule/cancel UI: ClinicalEncounter rows for the patient, optionally narrowed by facility and
     * healthcare provider (via ClinicalEncounterProvider). Sorted by service appointment start time descending (latest first).
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> listPatientVisitsForConsole(
        String patientAccountId,
        String healthcareFacilityId,
        String healthcareProviderId
    ) {
        if (String.isBlank(patientAccountId)) {
            return new Map<String, Object>{
                'success' => false,
                'message' => 'Select a patient first.',
                'rows' => new List<Object>()
            };
        }
        return HCPatientVisitListInvocable.listVisitsMap(
            patientAccountId,
            healthcareFacilityId,
            healthcareProviderId
        );
    }

    private static Date parseDateIso(String targetDateIso) {
        if (String.isBlank(targetDateIso)) {
            throw new AuraHandledException('targetDate is required (YYYY-MM-DD).');
        }
        String s = targetDateIso.trim();
        if (s.length() >= 10) {
            s = s.substring(0, 10);
        }
        return Date.valueOf(s);
    }

    /**
     * Accepts ISO-8601 from LWC (e.g. 2026-04-29T14:30:00.000Z or local without Z).
     */
    private static Datetime parseDatetimeFlexible(String iso) {
        if (String.isBlank(iso)) {
            return null;
        }
        String s = iso.trim();
        Boolean endsZ = s.endsWithIgnoreCase('Z');
        if (endsZ) {
            s = s.substring(0, s.length() - 1);
        }
        s = s.replace('T', ' ');
        Integer dot = s.indexOf('.');
        if (dot > 0) {
            s = s.substring(0, dot);
        }
        if (s.length() > 19) {
            s = s.substring(0, 19);
        }
        if (endsZ) {
            return Datetime.valueOfGmt(s);
        }
        return Datetime.valueOf(s);
    }
}
