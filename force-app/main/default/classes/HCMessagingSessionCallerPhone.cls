/**
 * Resolves the caller's address from MessagingSession for WhatsApp-only auto identity.
 * Used by HC_Resolve_Patient_By_Phone Flow when input_Phone is blank and input_MessagingSessionId is set.
 * Web / Embedded chat: leave input_Phone populated so this path is skipped.
 */
public without sharing class HCMessagingSessionCallerPhone {
    public class Request {
        @InvocableVariable(
            required = true
            label = 'Messaging Session Id'
            description = 'Active MessagingSession Id (Agent context).'
        )
        public Id messagingSessionId;
    }

    public class Result {
        @InvocableVariable(
            label = 'Normalized phone'
            description = 'Same normalization as HC_Resolve_Patient_By_Phone Flow (strip space, dash, parens) for PersonMobilePhone lookup.'
        )
        public String normalizedPhone;
        @InvocableVariable(
            label = 'Caller phone hint'
            description = 'Short phrase for yes/no confirmation (e.g. last digits). Empty when channel phone could not be read.'
        )
        public String callerPhoneHint;
        @InvocableVariable(
            label = 'Used channel address'
            description = 'True when MessagingPlatformKey was read from a WhatsApp MessagingEndUser.'
        )
        public Boolean usedChannelAddress;
    }

    @InvocableMethod(
        label = 'HC Messaging Session Caller Phone'
        description = 'For WhatsApp sessions, returns MessagingEndUser MessagingPlatformKey normalized for patient lookup. Other channels return empty values.'
        category = 'Health Cloud'
    )
    public static List<Result> resolveCallerFromSession(List<Request> requests) {
        List<Result> out = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return out;
        }
        for (Request req : requests) {
            out.add(resolveOne(req));
        }
        return out;
    }

    private static Result resolveOne(Request req) {
        Result r = new Result();
        r.normalizedPhone = '';
        r.callerPhoneHint = '';
        r.usedChannelAddress = false;
        if (req == null || req.messagingSessionId == null) {
            return r;
        }
        List<MessagingSession> sessions = [
            SELECT Id, ChannelType, MessagingEndUserId
            FROM MessagingSession
            WHERE Id = :req.messagingSessionId
            LIMIT 1
        ];
        if (sessions.isEmpty()) {
            return r;
        }
        MessagingSession ms = sessions[0];
        if (ms.ChannelType != 'WhatsApp' || ms.MessagingEndUserId == null) {
            return r;
        }
        List<MessagingEndUser> endUsers = [
            SELECT Id, MessagingPlatformKey
            FROM MessagingEndUser
            WHERE Id = :ms.MessagingEndUserId
            LIMIT 1
        ];
        if (endUsers.isEmpty() || String.isBlank(endUsers[0].MessagingPlatformKey)) {
            return r;
        }
        String raw = endUsers[0].MessagingPlatformKey.trim();
        r.normalizedPhone = normalizeLikeResolveFlow(raw);
        r.callerPhoneHint = buildHint(raw);
        r.usedChannelAddress = String.isNotBlank(r.normalizedPhone);
        return r;
    }

    /**
     * Mirrors Flow formula Normalize_Phone_Formula on HC_Resolve_Patient_By_Phone.
     */
    private static String normalizeLikeResolveFlow(String input) {
        if (input == null) {
            return '';
        }
        String s = input;
        s = s.replace(' ', '');
        s = s.replace('-', '');
        s = s.replace('(', '');
        s = s.replace(')', '');
        return s.trim();
    }

    private static String buildHint(String raw) {
        if (String.isBlank(raw)) {
            return '';
        }
        String digits = raw.replaceAll('[^0-9]', '');
        if (digits.length() >= 4) {
            String tail = digits.substring(digits.length() - 4, digits.length());
            return 'the WhatsApp number ending in ' + tail;
        }
        return 'this WhatsApp number';
    }
}
