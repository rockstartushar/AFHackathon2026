/**
 * Payload shape for Custom Lightning Type + Enhanced Web Chat renderer (HC_DirectoryInvocable).
 * Field `payload` is JSON: { summaryText, rows: [{ providerId, facilityId, providerName, facilityName, line }] }.
 */
global class HCDirectoryUiModel {
    @InvocableVariable(
        label = 'Directory UI payload'
        description = 'JSON string consumed by hcDirectoryResultsRenderer.'
    )
    @AuraEnabled
    global String payload;
}
