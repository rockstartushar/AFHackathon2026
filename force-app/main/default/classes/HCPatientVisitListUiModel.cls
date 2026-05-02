/**
 * Payload for listing a patient's upcoming visits (modify/cancel flow).
 * Field `payload` is JSON: { success, message, summaryText, rows: [{ serviceAppointmentId, facilityName, schedStartIso, schedEndIso, subject, status, clinicianName }] }.
 */
@JsonAccess(serializable='always' deserializable='always')
global class HCPatientVisitListUiModel {
    @InvocableVariable(
        label = 'Patient visits UI payload'
        description = 'JSON string with rows of visits for the agent and Enhanced Chat.'
    )
    @AuraEnabled
    global String payload;
}
