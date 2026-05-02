/**
 * Payload for Custom Lightning Type + Enhanced Web Chat (HCFacilityListInvocable).
 * Field `payload` is JSON: { success, message, summaryText, rows: [{ facilityId, facilityName, line }] }.
 */
@JsonAccess(serializable='always' deserializable='always')
global class HCFacilityListUiModel {
    @InvocableVariable(
        label = 'Facility list UI payload'
        description = 'JSON string consumed by hcFacilityCardList.'
    )
    @AuraEnabled
    global String payload;
}
