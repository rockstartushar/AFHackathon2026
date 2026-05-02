/**
 * Payload for booking / reschedule / cancel confirmation card (HC_BookingActionsInvocable).
 * Field `payload` is JSON: operation, success, headline, message, ids, schedStart/End labels, facilityName, subject.
 */
global class HCBookingConfirmationUiModel {
    @InvocableVariable(
        label = 'Booking confirmation UI payload'
        description = 'JSON string consumed by hcBookingConfirmationRenderer.'
    )
    @AuraEnabled
    global String payload;
}
