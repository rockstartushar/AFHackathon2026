/**
 * Handoff summary for Messaging Session workspace (Omni routing).
 *
 * Manual setup (optional — improves consistency): Prompt Builder Flex template
 * HC_Messaging_Session_Handoff_Summary with Text input HC_Transcript (Input:HC_Transcript in Apex).
 * If the template is missing, this class falls back to Einstein Models API (same-org) for a short handoff brief.
 *
 * Transcript source: Enhanced / In-App & Web often do NOT populate SOQL ConversationEntry.Message.
 * This class loads text via Connect REST: /connect/conversation/{ConversationIdentifier}/entries
 * (see MessagingSession → Conversation.ConversationIdentifier), then falls back to SOQL.
 *
 * without sharing: service agents need rows that strict sharing can hide. FLS is not enforced on
 * the fallback SOQL path; Connect uses the current user’s session.
 */
public without sharing class HC_MessagingSessionSummaryController {
    public static final String PROMPT_TEMPLATE_DEV_NAME = 'HC_Messaging_Session_Handoff_Summary';
    public static final String PROMPT_INPUT_TRANSCRIPT = 'Input:HC_Transcript';

    private static final Integer MAX_ENTRIES = 150;
    private static final Integer MAX_TRANSCRIPT_CHARS = 24000;
    /** Room for system instructions when calling Models API */
    private static final Integer MODELS_API_TRANSCRIPT_CAP = 18000;
    private static final String MODELS_API_DEFAULT_MODEL = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';
    private static final String CONNECT_API_VERSION = 'v62.0';

    public class SummaryResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String summaryText;
        /** prompt | models_api | fallback | error */
        @AuraEnabled public String mode;
        @AuraEnabled public String message;
    }

    @AuraEnabled
    public static SummaryResult getHandoffSummary(Id messagingSessionId) {
        SummaryResult out = new SummaryResult();
        out.success = false;
        out.mode = 'error';
        out.summaryText = '';
        out.message = '';

        if (messagingSessionId == null) {
            out.message = 'Missing Messaging Session Id.';
            return out;
        }

        List<MessagingSession> sessions = [
            SELECT Id, ConversationId, Status, AcceptTime, EndUserLanguage, Origin, Conversation.ConversationIdentifier
            FROM MessagingSession
            WHERE Id = :messagingSessionId
            LIMIT 1
        ];

        if (sessions.isEmpty()) {
            out.message = 'Messaging Session not found or not accessible.';
            return out;
        }

        MessagingSession ms = sessions[0];
        if (ms.ConversationId == null) {
            out.success = true;
            out.mode = 'fallback';
            out.summaryText = sessionHeader(ms) + '\nNo Conversation linked yet — nothing to summarize.';
            return out;
        }

        String connectNote = '';
        String transcript = '';

        String uuid = ms.Conversation != null ? ms.Conversation.ConversationIdentifier : null;
        if (String.isNotBlank(uuid)) {
            ConnectFetchResult cfr = fetchTranscriptViaConnect(uuid);
            transcript = cfr.transcript;
            connectNote = cfr.diagnostic;
        }

        if (String.isBlank(transcript)) {
            transcript = buildTranscriptFromSoql(ms.ConversationId);
        }

        if (String.isBlank(transcript)) {
            out.success = true;
            out.mode = 'fallback';
            out.summaryText =
                sessionHeader(ms) +
                '\nNo transcript text yet. For Enhanced / Web Chat, ensure Connect conversation entries return data (check Remote Site for your org domain if callouts fail).' +
                (String.isNotBlank(connectNote) ? '\n(' + connectNote + ')' : '') +
                '\nYou can also enable transcript access per Salesforce Messaging documentation.';
            return out;
        }

        String transcriptForAi = truncate(transcript, MAX_TRANSCRIPT_CHARS);
        String promptTemplateError = null;

        try {
            ConnectApi.EinsteinPromptTemplateGenerationsInput inp = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            inp.isPreview = false;
            inp.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            inp.additionalConfig.applicationName = 'PromptTemplateGenerationsInvocable';

            ConnectApi.WrappedValue wv = new ConnectApi.WrappedValue();
            wv.value = transcriptForAi;

            inp.inputParams = new Map<String, ConnectApi.WrappedValue>{ PROMPT_INPUT_TRANSCRIPT => wv };

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation resp = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                PROMPT_TEMPLATE_DEV_NAME,
                inp
            );

            if (resp != null && resp.generations != null && !resp.generations.isEmpty()) {
                String text = resp.generations[0].text;
                if (String.isNotBlank(text)) {
                    out.success = true;
                    out.mode = 'prompt';
                    out.summaryText = text;
                    return out;
                }
            }
        } catch (Exception e) {
            promptTemplateError = e.getMessage();
        }

        ModelsSummarizeResult msr = summarizeWithModelsApi(transcriptForAi);
        if (String.isNotBlank(msr.generatedText)) {
            out.success = true;
            out.mode = 'models_api';
            out.summaryText = msr.generatedText;
            if (String.isNotBlank(promptTemplateError)) {
                out.message =
                    'Flex prompt template unavailable (' +
                    promptTemplateError +
                    '). Summary generated via Einstein Models API instead.';
            }
            return out;
        }

        out.success = true;
        out.mode = 'fallback';
        List<String> parts = new List<String>();
        parts.add(sessionHeader(ms));
        parts.add('');
        if (String.isNotBlank(promptTemplateError)) {
            parts.add('Flex prompt error: ' + promptTemplateError);
        }
        if (String.isNotBlank(msr.errorMessage)) {
            parts.add('Models API: ' + msr.errorMessage);
        }
        parts.add('');
        parts.add('--- Short transcript excerpt (full AI summary unavailable) ---');
        parts.add('');
        parts.add(truncate(transcript, 6000));
        out.summaryText = String.join(parts, '\n');
        out.message =
            'Could not generate an AI summary. Enable Einstein Generative AI / Models API, or create Flex template ' +
            PROMPT_TEMPLATE_DEV_NAME +
            '.';
        return out;
    }

    private class ModelsSummarizeResult {
        String generatedText;
        String errorMessage;
    }

    /**
     * Fallback when Prompt Builder template is missing or empty: same-org Einstein Models API text generation.
     */
    private static ModelsSummarizeResult summarizeWithModelsApi(String transcript) {
        ModelsSummarizeResult r = new ModelsSummarizeResult();
        if (String.isBlank(transcript)) {
            r.errorMessage = 'Empty transcript.';
            return r;
        }

        String slice = truncate(transcript, MODELS_API_TRANSCRIPT_CAP);
        String prompt =
            'You summarize customer messaging transcripts for a human agent taking over the chat.\n' +
            'Reply with at most 120 words. Use at most 6 short bullets (one line each). Cover only:\n' +
            '- Why they contacted us\n' +
            '- Facts they gave (no invented clinical detail)\n' +
            '- What the bot already did\n' +
            '- One concrete next step for the agent\n' +
            'Do not diagnose or recommend treatment. Do not repeat long quotes.\n\n' +
            'Transcript:\n' +
            slice;

        try {
            aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
            request.modelName = MODELS_API_DEFAULT_MODEL;
            aiplatform.ModelsAPI_GenerationRequest body = new aiplatform.ModelsAPI_GenerationRequest();
            body.prompt = prompt;
            request.body = body;

            aiplatform.ModelsAPI api = new aiplatform.ModelsAPI();
            aiplatform.ModelsAPI.createGenerations_Response response = api.createGenerations(request);

            if (response != null && response.Code200 != null && response.Code200.generation != null) {
                String text = response.Code200.generation.generatedText;
                if (String.isNotBlank(text)) {
                    r.generatedText = text.trim();
                    return r;
                }
            }
            r.errorMessage = 'Models API returned no text.';
        } catch (aiplatform.ModelsAPI.createGenerations_ResponseException e) {
            r.errorMessage = e.getMessage();
        } catch (Exception e) {
            r.errorMessage = e.getMessage();
        }
        return r;
    }

    private class ConnectFetchResult {
        String transcript;
        String diagnostic;
    }

    private static ConnectFetchResult fetchTranscriptViaConnect(String conversationIdentifier) {
        ConnectFetchResult r = new ConnectFetchResult();
        String sid = readApiSessionIdFromVf();
        if (String.isBlank(sid)) {
            r.diagnostic = 'Could not obtain API session for Connect callout.';
            return r;
        }
        try {
            String base = Url.getOrgDomainUrl().toExternalForm().replaceAll('/$', '');
            String path =
                '/services/data/' +
                CONNECT_API_VERSION +
                '/connect/conversation/' +
                EncodingUtil.urlEncode(conversationIdentifier, 'UTF-8') +
                '/entries?queryDirection=FromStart&recordLimit=500';
            HttpRequest req = new HttpRequest();
            req.setEndpoint(base + path);
            req.setMethod('GET');
            req.setTimeout(120000);
            req.setHeader('Authorization', 'Bearer ' + sid);
            req.setHeader('Content-Type', 'application/json');

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() == 200) {
                r.transcript = parseConnectEntriesJson(res.getBody());
                if (String.isBlank(r.transcript)) {
                    r.diagnostic = 'Connect returned 200 but no parseable message lines.';
                }
            } else {
                r.diagnostic =
                    'Connect entries HTTP ' +
                    res.getStatusCode() +
                    '. Add Remote Site for your org URL if blocked; check API access. Body: ' +
                    res.getBody().left(300);
            }
        } catch (Exception e) {
            r.diagnostic = 'Connect callout failed: ' + e.getMessage();
        }
        return r;
    }

    /** VF session id works for same-org REST; UserInfo.getSessionId() often fails for API. */
    private static String readApiSessionIdFromVf() {
        try {
            String raw = Page.HC_ApiSessionId.getContent().toString();
            return raw != null ? raw.trim() : null;
        } catch (Exception e) {
            return null;
        }
    }

    private static String parseConnectEntriesJson(String body) {
        if (String.isBlank(body)) {
            return '';
        }
        try {
            Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(body);
            List<Object> entries = (List<Object>) root.get('conversationEntries');
            if (entries == null) {
                return '';
            }
            List<String> lines = new List<String>();
            for (Object o : entries) {
                Map<String, Object> row = (Map<String, Object>) o;
                String msg = (String) row.get('messageText');
                Object senderObj = row.get('sender');
                String role = '';
                String subj = '';
                if (senderObj instanceof Map<String, Object>) {
                    Map<String, Object> sender = (Map<String, Object>) senderObj;
                    role = sender.get('role') != null ? String.valueOf(sender.get('role')) : '';
                    subj = sender.get('subject') != null ? String.valueOf(sender.get('subject')) : '';
                }
                Object tsObj = row.get('serverReceivedTimestamp');
                lines.add(
                    '[' +
                    (tsObj != null ? String.valueOf(tsObj) : '?') +
                    '] ' +
                    role +
                    (String.isNotBlank(subj) ? ' ' + subj : '') +
                    ': ' +
                    (msg != null ? msg : '')
                );
            }
            return String.join(lines, '\n');
        } catch (Exception e) {
            return '';
        }
    }

    private static String buildTranscriptFromSoql(Id conversationId) {
        try {
            List<ConversationEntry> rows = [
                SELECT CreatedDate, ActorType, ActorName, Message
                FROM ConversationEntry
                WHERE ConversationId = :conversationId
                ORDER BY CreatedDate ASC
                LIMIT :MAX_ENTRIES
            ];
            List<String> lines = new List<String>();
            for (ConversationEntry row : rows) {
                String who = row.ActorName != null ? row.ActorName : '';
                String role = row.ActorType != null ? String.valueOf(row.ActorType) : '';
                String body = row.Message != null ? row.Message : '';
                lines.add(
                    '[' +
                    String.valueOf(row.CreatedDate) +
                    '] ' +
                    role +
                    (String.isNotBlank(who) ? ' ' + who : '') +
                    ': ' +
                    body
                );
            }
            return String.join(lines, '\n');
        } catch (Exception e) {
            return '';
        }
    }

    private static String sessionHeader(MessagingSession s) {
        List<String> bits = new List<String>();
        bits.add('Session: ' + s.Id);
        if (s.Status != null) {
            bits.add('Status: ' + s.Status);
        }
        if (s.Origin != null) {
            bits.add('Origin: ' + s.Origin);
        }
        return String.join(bits, ' | ');
    }

    private static String truncate(String s, Integer maxLen) {
        if (s == null || maxLen == null || s.length() <= maxLen) {
            return s;
        }
        return s.substring(0, maxLen) + '\n… [truncated]';
    }
}
