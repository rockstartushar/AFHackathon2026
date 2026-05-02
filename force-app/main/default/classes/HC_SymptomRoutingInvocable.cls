/**
 * HC_SymptomRoutingInvocable
 * 
 * Smart Navigator component: maps patient-entered symptom text to recommended specialty
 * and provides safe patient-facing disclaimer. Queries Symptom_Specialty_Map__c for pattern
 * matching. This is navigation/education only - not diagnosis or triage.
 * 
 * Usage: Called by Agentforce agent to route symptom descriptions to appropriate specialty
 * before directory lookup (HC_DirectoryInvocable).
 */
public without sharing class HC_SymptomRoutingInvocable {
    
    /**
     * Input wrapper for invocable method
     */
    public class SymptomRoutingInput {
        @InvocableVariable(
            label='Symptom Text'
            description='Free-text symptom description entered by patient (required)'
            required=true
        )
        public String symptomText;
        
        @InvocableVariable(
            label='City Keyword'
            description='Optional city name for directory filtering (e.g., Jaipur, Mumbai)'
            required=false
        )
        public String cityKeyword;
    }
    
    /**
     * Output wrapper for invocable method
     */
    public class SymptomRoutingOutput {
        @InvocableVariable(
            label='Recommended Specialty'
            description='Specialty label matched from symptom pattern (e.g., Medical Oncology)'
        )
        public String recommendedSpecialty;
        
        @InvocableVariable(
            label='Routing Summary'
            description='Patient-facing explanation of the specialty recommendation (non-clinical)'
        )
        public String routingSummary;
        
        @InvocableVariable(
            label='Disclaimer'
            description='Safe disclaimer text for patient (not medical advice, emergency guidance)'
        )
        public String disclaimer;
        
        @InvocableVariable(
            label='Match Found'
            description='True if a specialty match was found, false otherwise'
        )
        public Boolean matchFound;
        
        @InvocableVariable(
            label='City Keyword'
            description='Echo of input city for downstream directory lookup'
        )
        public String cityKeyword;

        @InvocableVariable(
            label='Symptom routing UI'
            description='Single Enhanced Web Chat card payload (JSON); use hcSymptomRoutingCard renderer.'
        )
        public HCSymptomRoutingUiModel symptomRoutingUi;
    }
    
    /**
     * Route symptom text to recommended specialty
     * 
     * @param inputs List of SymptomRoutingInput (bulk-safe pattern)
     * @return List of SymptomRoutingOutput with specialty and disclaimer
     */
    @InvocableMethod(
        label='Route Symptom to Specialty'
        description='Maps patient symptom text to recommended specialty for Smart Navigator. Returns specialty label and safe patient-facing disclaimer. Not medical advice.'
        category='Healthcare'
    )
    public static List<SymptomRoutingOutput> routeSymptomToSpecialty(List<SymptomRoutingInput> inputs) {
        List<SymptomRoutingOutput> outputs = new List<SymptomRoutingOutput>();
        
        if (inputs == null || inputs.isEmpty()) {
            return outputs;
        }
        
        // Process each input (bulk-safe pattern, though typically single in agent context)
        for (SymptomRoutingInput input : inputs) {
            SymptomRoutingOutput output = processSymptomRouting(input);
            outputs.add(output);
        }
        
        return outputs;
    }
    
    /**
     * Core routing logic for a single symptom input
     * 
     * @param input Single SymptomRoutingInput
     * @return SymptomRoutingOutput with matched specialty or default response
     */
    private static SymptomRoutingOutput processSymptomRouting(SymptomRoutingInput input) {
        SymptomRoutingOutput output = new SymptomRoutingOutput();
        output.cityKeyword = input.cityKeyword;
        output.matchFound = false;
        
        // Validate input
        if (String.isBlank(input.symptomText)) {
            output.recommendedSpecialty = '';
            output.routingSummary = 'Please provide symptom details to help find the right specialist.';
            output.disclaimer = getDefaultDisclaimer();
            attachSymptomUi(output);
            return output;
        }
        
        // Normalize symptom text for matching (lowercase for case-insensitive comparison)
        String normalizedSymptom = input.symptomText.toLowerCase().trim();
        
        // Query active symptom mappings ordered by priority (highest first)
        List<Symptom_Specialty_Map__c> mappings = [
            SELECT Id, Name, Keyword_Pattern__c, Match_Priority__c,
                   Recommended_Specialty__c, Routing_Summary__c, Disclaimer__c
            FROM Symptom_Specialty_Map__c
            WHERE Active__c = true
            ORDER BY Match_Priority__c DESC NULLS LAST, Name ASC
            LIMIT 200
        ];
        
        // Find best match based on keyword patterns
        Symptom_Specialty_Map__c bestMatch = null;
        Integer bestMatchScore = 0;
        
        for (Symptom_Specialty_Map__c mapping : mappings) {
            if (String.isBlank(mapping.Keyword_Pattern__c)) {
                continue;
            }
            
            // Split pattern into individual keywords for matching
            List<String> keywords = mapping.Keyword_Pattern__c.toLowerCase().split('[,;\\s]+');
            Integer matchScore = 0;
            
            // Count how many keywords match in the symptom text
            for (String keyword : keywords) {
                keyword = keyword.trim();
                if (String.isNotBlank(keyword) && normalizedSymptom.contains(keyword)) {
                    matchScore++;
                }
            }
            
            // Select mapping with highest match score (keywords matched)
            // Priority field breaks ties
            if (matchScore > bestMatchScore) {
                bestMatchScore = matchScore;
                bestMatch = mapping;
            } else if (matchScore == bestMatchScore && bestMatch != null) {
                // Use priority as tie-breaker
                Decimal currentPriority = mapping.Match_Priority__c != null ? mapping.Match_Priority__c : 0;
                Decimal bestPriority = bestMatch.Match_Priority__c != null ? bestMatch.Match_Priority__c : 0;
                if (currentPriority > bestPriority) {
                    bestMatch = mapping;
                }
            }
        }
        
        // Populate output based on match result
        if (bestMatch != null && bestMatchScore > 0) {
            output.matchFound = true;
            output.recommendedSpecialty = String.isNotBlank(bestMatch.Recommended_Specialty__c) 
                ? bestMatch.Recommended_Specialty__c.trim() 
                : '';
            output.routingSummary = String.isNotBlank(bestMatch.Routing_Summary__c)
                ? bestMatch.Routing_Summary__c.trim()
                : getDefaultRoutingSummary(output.recommendedSpecialty);
            output.disclaimer = String.isNotBlank(bestMatch.Disclaimer__c)
                ? bestMatch.Disclaimer__c.trim()
                : getDefaultDisclaimer();
        } else {
            // No match found - return default guidance
            output.matchFound = false;
            output.recommendedSpecialty = '';
            output.routingSummary = 'We can help you find a specialist. Please share more details about your symptoms or the type of specialist you need.';
            output.disclaimer = getDefaultDisclaimer();
        }

        attachSymptomUi(output);
        return output;
    }

    private static void attachSymptomUi(SymptomRoutingOutput o) {
        Map<String, Object> wrap = new Map<String, Object>();
        wrap.put('recommendedSpecialty', o.recommendedSpecialty);
        wrap.put('routingSummary', o.routingSummary);
        wrap.put('disclaimer', o.disclaimer);
        wrap.put('matchFound', o.matchFound);
        HCSymptomRoutingUiModel ui = new HCSymptomRoutingUiModel();
        ui.payload = JSON.serialize(wrap);
        o.symptomRoutingUi = ui;
    }
    
    /**
     * Default routing summary when none provided in mapping
     * 
     * @param specialty Specialty name
     * @return Default summary text
     */
    private static String getDefaultRoutingSummary(String specialty) {
        if (String.isNotBlank(specialty)) {
            return 'Based on your description, you may want to consult with our ' + specialty + ' team.';
        }
        return 'We can help you find the right specialist for your needs.';
    }
    
    /**
     * Default disclaimer for all routing responses
     * 
     * @return Standard disclaimer text
     */
    private static String getDefaultDisclaimer() {
        return 'This is not medical advice or diagnosis. For medical emergencies, please contact your local emergency services immediately.';
    }
}