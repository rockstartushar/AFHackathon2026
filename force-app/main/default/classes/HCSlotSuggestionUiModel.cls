/**
 * Payload shape for Custom Lightning Type + Enhanced Web Chat renderer (HC_SlotSuggestionInvocable).
 * Field `payload` mirrors `slotsJson` (facilityId, providerId, date, slotMinutes, facilityName, slots[]).
 */
global class HCSlotSuggestionUiModel {
    @InvocableVariable(
        label = 'Slot UI payload'
        description = 'JSON string consumed by hcSlotSuggestionRenderer (same contract as slotsJson).'
    )
    @AuraEnabled
    global String payload;
}
