/**
 * Returns non-PHI visit preparation sections for Enhanced Web Chat accordion.
 * Complements narrative HC_Coverage_Prep_Patient_Facing prompt with structured UI when needed.
 */
public without sharing class HCCoveragePrepUiInvocable {
    public class PrepRequest {
        @InvocableVariable(
            label = 'Correlation Id'
            description = 'Optional session / trace id for audit logging.'
        )
        public String correlationId;
    }

    public class PrepResult {
        @InvocableVariable(label = 'Success')
        public Boolean success;
        @InvocableVariable(label = 'Summary text')
        public String summaryText;
        @InvocableVariable(
            label = 'Coverage prep UI model'
            description = 'Structured checklist for hcCoveragePrepAccordion.'
        )
        public HCCoveragePrepUiModel coveragePrepUi;
    }

    @InvocableMethod(
        label = 'HC Coverage Prep UI'
        description = 'Returns Onco Global demo checklist sections (IDs, insurance, timing) for Enhanced Web Chat — not medical advice.'
        category = 'Health Cloud'
    )
    public static List<PrepResult> getStructuredPrep(List<PrepRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            return new List<PrepResult>();
        }
        PrepResult out = new PrepResult();
        out.success = true;
        out.summaryText = 'Quick checklist for your Onco Global visit (informational only — not medical advice).';

        List<Map<String, Object>> sections = new List<Map<String, Object>>();

        Map<String, Object> s1 = new Map<String, Object>();
        s1.put('title', 'Bring with you');
        s1.put(
            'items',
            new List<String>{
                'Government-issued photo ID',
                'Insurance card / payer details if applicable',
                'Prior imaging, pathology, or discharge summaries',
                'Current medication list'
            }
        );
        sections.add(s1);

        Map<String, Object> s2 = new Map<String, Object>();
        s2.put('title', 'Plan ahead');
        s2.put(
            'items',
            new List<String>{
                'Arrive 15 minutes before scheduled time unless instructed otherwise',
                'Follow fasting instructions only if your care team told you to fast',
                'Use local emergency services for emergencies — this chat is not for urgent care'
            }
        );
        sections.add(s2);

        Map<String, Object> s3 = new Map<String, Object>();
        s3.put('title', 'Costs & coverage');
        s3.put(
            'items',
            new List<String>{
                'Eligibility and charges are finalized at registration with billing and your payer',
                'Room-rate references in chat are non-binding planning hints only'
            }
        );
        sections.add(s3);

        Map<String, Object> wrap = new Map<String, Object>();
        wrap.put('summaryText', out.summaryText);
        wrap.put('sections', sections);

        out.coveragePrepUi = new HCCoveragePrepUiModel();
        out.coveragePrepUi.payload = JSON.serialize(wrap);

        return new List<PrepResult>{ out };
    }
}
