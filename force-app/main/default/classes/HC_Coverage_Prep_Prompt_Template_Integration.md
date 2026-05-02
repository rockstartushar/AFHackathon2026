# HC Coverage Prep Patient-Facing Prompt Template Integration Guide

## Overview
This document explains how to expose the `HC_Coverage_Prep_Patient_Facing` Flex GenAI Prompt Template as an Agent action and integrate it with the Coverage_prep topic.

## Template Details

**File:** `force-app/main/default/genAiPromptTemplates/HC_Coverage_Prep_Patient_Facing.genAiPromptTemplate-meta.xml`

**Purpose:** Transform raw coverage/prerequisites/room rate data from `HC_PatientDataActionsInvocable` into empathetic, patient-friendly language.

**Template Type:** `einstein_gpt__flex`

**Input:**
- `RawSummaryFromTool` (required, multiline string): Plain text containing INSURANCE, PREREQUISITES, and/or ROOM_RATES sections

**Output:** Patient-friendly text with disclaimers

---

## Step 1: Create the GenAI Function for Prompt Response

Create a new GenAI Function metadata file to expose the prompt template as an agent action.

**File:** `force-app/main/default/genAiFunctions/HC_Format_Coverage_For_Patient/HC_Format_Coverage_For_Patient.genAiFunction-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<GenAiFunction xmlns="http://soap.sforce.com/2006/04/metadata">
    <active>true</active>
    <description>Formats raw coverage, prerequisites, and room rate information into patient-friendly language using the HC_Coverage_Prep_Patient_Facing prompt template.</description>
    <apiName>HC_Format_Coverage_For_Patient</apiName>
    <label>Format Coverage Information for Patient</label>
    <invocableAction>
        <invocableActionName>HC_Coverage_Prep_Patient_Facing</invocableActionName>
        <invocationTargetType>generatePromptResponse</invocableActionType>
    </invocableAction>
    <input>
        <apiName>RawSummaryFromTool</apiName>
        <description>The raw text output from HC_PatientDataActionsInvocable containing INSURANCE, PREREQUISITES, and/or ROOM_RATES sections</description>
        <label>Raw Summary From Tool</label>
        <required>true</required>
        <type>STRING</type>
    </input>
    <output>
        <apiName>FormattedPatientMessage</apiName>
        <description>Patient-friendly formatted text with disclaimers</description>
        <label>Formatted Patient Message</label>
        <type>STRING</type>
    </output>
    <category>CUSTOM</category>
    <visibility>GLOBAL</visibility>
</GenAiFunction>
```

---

## Step 2: Update Coverage_prep Topic to Call the Actions in Sequence

The `Coverage_prep` topic should orchestrate the following action sequence:

1. **First:** Call `HC_Patient_Data_Actions` (Apex action) to retrieve raw data
2. **Second:** Call `HC_Format_Coverage_For_Patient` (Prompt Response action) to format the data

### Coverage_prep Topic Configuration

Update your `Coverage_prep.genAiPlugin-meta.xml` or configure via UI:

**Existing Topic:** Coverage_prep

**Action Sequence:**

### Action 1: Get Raw Data (Apex)
- **Action Name:** `HC_Patient_Data_Actions`
- **Type:** `apex`
- **Description:** "Retrieves insurance coverage, visit prerequisites, and room rates for the patient"
- **Input Mapping:**
  - `patientId`: {merge from agent context or previous actions}
  - `actionType`: `GET_COVERAGE_PREP`
- **Output:** Captures `summary` field → store as `{rawCoverageData}`

### Action 2: Format for Patient (Prompt Response)
- **Action Name:** `HC_Format_Coverage_For_Patient`
- **Type:** `generatePromptResponse`
- **Description:** "Formats coverage information into patient-friendly language"
- **Input Mapping:**
  - `RawSummaryFromTool`: `{rawCoverageData}` (from Action 1 output)
- **Output:** Captures `FormattedPatientMessage` → display to patient

---

## Step 3: Agent Topic Instructions

Update the Coverage_prep topic instructions to guide the agent:

```
**Topic: Coverage_prep**

**When to Use:** Patient asks about insurance coverage, what they need to bring, room costs, or preparation for their visit.

**Instructions:**
1. Identify the patient using available context
2. Call HC_Patient_Data_Actions to retrieve coverage, prerequisites, and room rate information
3. Pass the raw output to HC_Format_Coverage_For_Patient to format it for the patient
4. Present the formatted response to the patient
5. Ask if they have any questions about the information provided

**Key Points:**
- Always format raw data before showing to patients
- The formatted output includes important disclaimers
- Encourage patients to contact billing with specific cost questions
```

---

## Example Conversation Flow

**Patient:** "What does my insurance cover and what do I need to bring?"

**Agent Internal Processing:**
1. Identifies patient: John Doe (ID: 003xxx)
2. Calls `HC_Patient_Data_Actions`:
   - Input: `patientId=003xxx`, `actionType=GET_COVERAGE_PREP`
   - Output: Raw text containing INSURANCE and PREREQUISITES sections
3. Calls `HC_Format_Coverage_For_Patient`:
   - Input: `RawSummaryFromTool={raw text from step 2}`
   - Output: Patient-friendly formatted message

**Agent Response:**
```
### Your Coverage & Visit Information

**Insurance Coverage**
Great news! Your Blue Cross plan covers your upcoming visit. You'll need to pay a $30 amount at your visit, and your plan covers 80% of the visit cost after that.

**What to Bring**
Please bring these items to your appointment:
- Your insurance card
- A valid photo ID
- List of current medications

---
**Please Note:**
- Room rates shown are estimates and may vary. Final charges will be confirmed at registration.
- Insurance coverage is subject to verification of eligibility at the time of registration.
- This information is not medical advice. Please discuss any questions with your healthcare provider.
- Contact our billing department at [contact info] for specific cost questions.

Do you have any questions about your coverage or what to bring?
```

---

## Deployment Checklist

- [ ] Deploy `HC_Coverage_Prep_Patient_Facing.genAiPromptTemplate-meta.xml`
- [ ] Deploy `HC_Format_Coverage_For_Patient.genAiFunction-meta.xml`
- [ ] Update Coverage_prep topic to include action sequence
- [ ] Test in Agent Builder preview mode
- [ ] Verify prompt template is using correct model (GPT-4 Omni)
- [ ] Verify disclaimers appear in all outputs
- [ ] Test with various input scenarios (empty sections, all sections, etc.)

---

## Important Notes

### No Changes to Apex Contract
The `HC_PatientDataActionsInvocable` class remains unchanged. It continues to return raw text in the `summary` field.

### Input Format Expected
The prompt template expects plain text with sections like:
```
INSURANCE
Carrier: Blue Cross
Coverage: 80% after copay
Copay: $30

PREREQUISITES
- Insurance card
- Photo ID
- Medication list

ROOM_RATES
Semi-private: $250/day
Private: $400/day
```

### Error Handling
If `RawSummaryFromTool` is empty or null, the template will return "No information available at this time" for all sections.

### Model Selection
Template uses `sfdc_ai__DefaultGPT4Omni` for high-quality patient communication. Adjust if your org uses a different default model.

---

## Testing Scenarios

1. **Full data:** All three sections present → Should format all sections beautifully
2. **Partial data:** Only INSURANCE present → Should format insurance, state "No information available" for others
3. **Empty input:** Null or empty string → Should handle gracefully with "No information available"
4. **Special characters:** Test with currency symbols, percentages → Should preserve in patient-friendly way

---

## Troubleshooting

**Issue:** Prompt template not found
- **Solution:** Ensure template is deployed and status is "Published"

**Issue:** Action not appearing in Agent Builder
- **Solution:** Check GenAI Function visibility is "GLOBAL" and active is "true"

**Issue:** Disclaimers missing in output
- **Solution:** Verify template content includes the disclaimer section

**Issue:** Output too verbose
- **Solution:** Adjust prompt template instructions to emphasize brevity

---

## Future Enhancements

- Add support for multiple languages
- Include facility contact information dynamically
- Add links to patient portal for detailed cost breakdown
- Support for cost estimate ranges based on procedure codes