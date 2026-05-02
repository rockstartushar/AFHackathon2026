/**
 * Inserts Agent_Action_Log__c rows from Apex (booking + directory) without invoking the HC_Log_Agent_Action flow.
 */
public without sharing class HCAuditHelper {
    public static void log(
        String actionName,
        String status,
        String correlationId,
        String errorMessage,
        String inputSummary,
        Id relatedServiceAppointmentId,
        Id relatedClinicalEncounterId
    ) {
        if (String.isBlank(actionName)) {
            actionName = 'Unknown';
        }
        if (String.isBlank(status)) {
            status = 'Failed';
        }
        Id saLookup = null;
        if (relatedServiceAppointmentId != null
            && relatedServiceAppointmentId.getSObjectType() == ServiceAppointment.SObjectType) {
            saLookup = relatedServiceAppointmentId;
        }
        Id ceLookup = null;
        if (relatedClinicalEncounterId != null
            && relatedClinicalEncounterId.getSObjectType() == ClinicalEncounter.SObjectType) {
            ceLookup = relatedClinicalEncounterId;
        }
        Agent_Action_Log__c row = new Agent_Action_Log__c(
            Action_Name__c = actionName,
            Status__c = status,
            Correlation_Id__c = correlationId,
            Error_Message__c = errorMessage,
            Input_Summary__c = inputSummary,
            Related_Service_Appointment__c = saLookup,
            Related_Clinical_Encounter__c = ceLookup
        );
        insert row;
    }
}
