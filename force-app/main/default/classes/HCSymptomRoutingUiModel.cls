/**
 * Payload for symptom → specialty routing (HC_SymptomRoutingInvocable).
 * Field `payload` is JSON: recommendedSpecialty, routingSummary, disclaimer, matchFound — consumed by hcSymptomRoutingCard.
 */
global class HCSymptomRoutingUiModel {
    @InvocableVariable(
        label = 'Symptom routing UI payload'
        description = 'JSON string consumed by hcSymptomRoutingCard in Enhanced Web Chat.'
    )
    @AuraEnabled
    global String payload;
}
