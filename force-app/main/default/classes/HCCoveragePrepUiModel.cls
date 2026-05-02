/**
 * Payload for visit preparation accordion (HCCoveragePrepUiInvocable).
 * Field `payload` is JSON: { summaryText, sections: [{ title, items: [] }] }.
 */
global class HCCoveragePrepUiModel {
    @InvocableVariable(
        label = 'Coverage prep UI payload'
        description = 'JSON string consumed by hcCoveragePrepAccordion.'
    )
    @AuraEnabled
    global String payload;
}
