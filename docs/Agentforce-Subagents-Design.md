# Agentforce subagents — Onco Global Patient Agent

This document maps **`docs/Patient-Agent-Conversation-Scripts.md`** to **subagents** (topics) in Agentforce Builder, lists **actions** per subagent, and gives **classification descriptions**, **scope**, and **instructions** you can paste when configuring each subagent one by one. **Apr 2026:** see **§4a new vs returning (Person Account)** and **§4b Smart Navigator**, plus slot wording in **§§7–9** of the scripts; data model + freeze scope in **`docs/Data-Model-Objects-And-Fields.md`** / **`docs/Org-Build-Checklist.md`**.

**Repo source of truth (metadata):** Topic membership, embedded instructions, and action links for the shipped agent are in **`force-app/main/default/genAiPlannerBundles/Onco_Global_Patient_Agent/Onco_Global_Patient_Agent.genAiPlannerBundle`** and the standalone **`genAiPlugins/*.genAiPlugin-meta.xml`** files. After deploy, Builder should mirror those topics; if your org was customized only in the UI, retrieve the bundle to refresh the repo or align manually using **§1.1** below.

It aligns with Salesforce guidance: **narrow scope per topic**, **ground answers with actions** instead of inventing CRM facts, and **short, positive instructions** (see [Agentforce actions — get started](https://developer.salesforce.com/docs/einstein/genai/guide/get-started-actions.html), [Agentforce overview](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-overview.html), and the [Service Agent workshop](https://developer.salesforce.com/agentforce-workshop/service-agents/1-create-a-service-agent)).

---

## Patient-first guardrails (real patients will use this agent)

Configure topics and actions so behavior is safe for **people seeking care**, not only for demos.

| Area | What to enforce |
|------|------------------|
| **Clinical boundaries** | Never diagnose, prescribe, interpret labs/imaging, or recommend treatments. Encourage **911 / emergency services** for urgent or life-threatening symptoms. Point nuanced clinical questions to their **care team**. Align with **`Patient-Agent-Conversation-Scripts.md`** §23. |
| **Privacy & dignity** | Do **not** read **Salesforce record Ids**, internal codes, or stack traces aloud. Keep **Show in conversation OFF** for Ids and use **Filter**/internal handling (§2.3a). Paraphrase tool output in **plain, calm language**. If verification fails, say you could not match their profile—**do not** ask for full DOB, SSN, or full MRNs in chat unless your org’s approved policy explicitly requires it (default scripts use mobile match only). |
| **Wrong-patient safety** | Never show another patient’s bookings, insurance, or prerequisites. On **NO_MATCH** or ambiguous phone: apologize briefly and offer **human scheduling** or sign-in—no guessing. |
| **Booking certainty** | Before calling **BOOK**, confirm **facility name** and **human-readable date/time** in the patient’s words. After success, confirm in **everyday language** (e.g. “You’re booked for Tuesday at 2:30 PM at [facility]”). Avoid presenting raw Id as the “confirmation number” unless your org supplies a separate **patient-facing reference** field. |
| **Errors & limits** | Map failures to supportive messages (“We weren’t able to finish that reservation—would you like to try another time or reach our scheduling line at …”). Do **not** expose governor limits, validation API names, or permission errors verbatim. |
| **Financial / coverage** | Insurance lists and room rates are **informational**; repeat that **coverage is confirmed at registration / with payer** (scripts §12–14). Never imply a guarantee of payment or bed availability. |
| **Tone** | Short sentences, neutral warmth, no blame. **Loading text** (§2.5) should sound helpful (“Checking our hospitals…”), not technical (“Invoking flow”). |
| **Audit (`HC_Log_Agent_Action`)** | **`input_InputSummary`** / **`input_ErrorMessage`** must stay **non-PHI**—high-level labels only—so logs remain safe if reviewed beside chat. |

Everything in **§2.3b** (Require / Collect / Show) is written so that **patients** hear summaries and confirmations, not infrastructure.

---

## 1. What you already have (template)

The **Patient and Member Services** template pre-created subagents. **Do not duplicate** these; **configure** them:

| Subagent (UI) | Role | Your job |
|---------------|------|----------|
| **Topic Selector** | Routes user utterances to the right subagent | Ensure **classification descriptions** on your custom subagents are distinct (see below). |
| **Escalation** | Human handoff, out-of-scope medical | Add **instruction** for contact center + “no medical advice” boundaries (scripts §23). |
| **Off Topic** | Non–Onco Global requests | Keep default; optional one line on what the agent *does* handle. |
| **Ambiguous Question** | Clarification | Keep default. |
| **Provider Matching** | Find providers / facilities | **Wire actions** and **instructions** for scripts §2–6, §18 (see §4.1). |

### 1.1 Topics and actions shipped in this repo (`GenAiPlannerBundle`)

The planner bundle **`Onco_Global_Patient_Agent`** wires five **topics** (plugins) plus one **global** Knowledge action. IDs in the file (`*_16jak…`, `*_179ak…`) are org-specific—your retrieve will differ; match by **`localDeveloperName`** / **`source`**.

| Topic (`masterLabel`) | Linked GenAi functions (API names) |
|-----------------------|--------------------------------------|
| **Scheduling & visits** | `HC_Resolve_Patient_By_Phone`, `HC_Create_Guest_Person_Account`, `HC_Get_Facilities`, `HC_Slot_Suggestion`, `HC_Booking_Actions`, `HC_Create_Visit_Reminder_Task`, `HC_Log_Agent_Action` |
| **Provider Matching** | `HC_Route_Symptom_To_Specialty`, `HC_Find_Specialist`, `HC_Get_Facilities`, `HC_Patient_Data_Actions`, `HC_Log_Agent_Action` |
| **Coverage & prep** | `HC_Patient_Data_Actions`, `HC_Coverage_Prep_Patient_Facing`, `HC_Log_Agent_Action` |
| **Visit information (FAQ)** | *(no HC functions—uses planner action below)* |
| **Escalation** | *(template escalation topic; no HC automations in bundle)* |

**Planner-level (not under a single topic):** **`AnswerQuestionsWithKnowledge`** (`streamKnowledgeSearch`) — required for **Visit information (FAQ)** per topic instructions.

**Surfaces / routing (bundle):** **`Verified_User`** rule expression, **`Messaging`** and **`CustomerWebClient`** planner surfaces with Omni-Channel outbound route **`HC_Chats_Routed_to_Agents_and_Queues`**.

**Implementation status (Apr 2026):** **`HC_Route_Symptom_To_Specialty`** (`HC_SymptomRoutingInvocable` + **`Symptom_Specialty_Map__c`**), **`HC_Slot_Suggestion`** (`HC_SlotSuggestionInvocable`), and guest onboarding **`HC_Create_Guest_Person_Account`** (Flow) are **in the bundle** and plugins. Symptom routing remains **navigation/education only**, not triage. **Enhanced Web Chat** can render **`slotUi`**, **`directoryUi`**, **`facilityListUi`**, **`bookingUi`**, **`coveragePrepUi`** when actions are bound in Builder—see **`docs/Agentforce-Enhanced-Chat-LWC-Plan.md`**.

**Note on `HC_Get_Facilities`:** The **`GenAiFunction`** metadata in this repo targets **Apex** **`HCFacilityListInvocable`** ( **`summaryText`** + **`facilityListUi`** for chat cards). The autolaunched **Flow** **`HC_Get_Facilities`** still exists for non-agent callers and outputs **`output_FacilitySummary`** only. If a retrieved planner bundle still references the Flow for the agent action, switch the action to the Apex invocable so Enhanced Chat receives **`facilityListUi`**.

---

## 2. Agent actions — create in Agentforce Builder (step-by-step)

**Flows and Apex in the project are not automatically “agent actions.”** You register them **once** in Builder as **agent actions**, then attach them under each **subagent** (topic). Official references: [Get started with Agentforce actions](https://developer.salesforce.com/docs/einstein/genai/guide/get-started-actions.html), [Apex `@InvocableMethod` and agents](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-invocablemethod.html), [Service Agent workshop — create custom actions](https://developer.salesforce.com/agentforce-workshop/service-agents/1-create-a-service-agent), [Trailhead: add a Flow as an agent action](https://trailhead.salesforce.com/content/learn/modules/agent-customization-with-flows/add-a-flow-as-an-agent-action).

### 2.1 Prerequisites (do this first)

| Requirement | Why |
|-------------|-----|
| Flows **`HC_*`** deployed and **Autolaunched** / invocable | Picker only lists runnable automations. |
| Apex classes with `@InvocableMethod` deployed | Same for Apex actions. |
| Agent **running user** has **`Onco_Global_Patient_Agent…_Permissions`** or **`Hackathon_Agent_Runtime_Access`** (and data access as needed) | Actions execute in that user’s context. |
| You are in **Agentforce Builder** with the agent open (draft or version) | Actions are created **in context of an agent/topic**, not only in Setup. |

### 2.2 Where to click (typical UI)

Labels vary slightly by release; search Help for **“Create New Action”** if yours differ.

1. **Setup** → **Agentforce Agents** (or **Agents** under Einstein) → open **Onco Global Patient Agent** → **Open in Builder**.
2. In the **Explorer** tree, select the **subagent** where you want the action to appear first (you can reuse the same underlying Flow/Apex on another subagent later).  
3. Open the subagent’s **Actions** area (e.g. **This topic’s actions**, **Topic actions**, or **Actions** tab on the subagent).
4. **New** → **Create New Action** (or **Add action**).

### 2.3 Wizard fields (every action)

| Step / field | What to choose |
|--------------|----------------|
| **Reference action type** | **`Flow`** for autolaunched Flows; **`Apex`** for invocable Apex (wording may be **Apex** / **Invocable Apex**). |
| **Reference action** | **Flow** API name (e.g. `HC_Log_Agent_Action`, `HC_Resolve_Patient_By_Phone`) or **Apex** class/method label (**HC Get Facilities** → `HCFacilityListInvocable`, **HC Find Specialist** → `HC_DirectoryInvocable`, etc.). |
| **Loading text** | Short patient-facing phrase while the tool runs (summary table **§2.5**). |
| **Agent action label / API name** | Defaults are usually fine; keep API names stable if you script or retrieve metadata later. |
| **Next** — inputs | For each input, set **Description** (paste from **§2.3b**), then set **Require** / **Collect from user** per **§2.3a**. |
| **Outputs** | For each output, set **Description** from **§2.3b**, then **Show in conversation** and any **Filter** / exclude options per **§2.3a** (human-readable text vs internal Ids). |
| **Instructions for this action** (optional) | One or two lines on **when** to run this action inside **this** subagent; subagent-level instructions still govern routing. |

Repeat **§2.2–2.3**, then configure **inputs/outputs** per **§2.3b** for **each** automation in **§2.5** until all required actions exist **under the right subagents** (same Flow can be added twice with different topic-scoped instructions if needed—prefer one action per subagent for clarity).

### 2.3a Input/output descriptions & Builder checkboxes

Salesforce Agent Builder labels vary by release; you configure these on the **second step** (and sometimes per-variable panels) after you pick Flow/Apex. Use this section as the source of truth for **what to type in “description”** fields and **which boxes to check**.

#### Meaning of the common toggles

| Toggle | Typical UI label | What it does | Practical rule |
|--------|------------------|--------------|----------------|
| **Required input** | *Require input*, *Required* | Runtime will not invoke the action until this variable has a value. | Turn **ON** for anything that would cause Flow/Apex to **fail or behave wrongly** if empty (`operation`, `input_Phone` for resolve, **BOOK** facility/time when booking). Turn **OFF** when the field is optional in metadata **and** safe to omit (`input_CityKeyword`, optional filters). |
| **Collect from user** | *Collect from user*, *Agent collects*, *User must provide* (if shown) | The agent should **ask the user in chat** for this value (not only guess). | Turn **ON** for things the **patient must state**: mobile for verify, city/specialty for search, agreed **date/time** for booking, **cancellation** intent. Turn **OFF** for values the model or **prior action outputs** should pass (e.g. `patientAccountId` from **HC_Resolve** without reading digits aloud). If your org has no separate toggle, use **Required** + subagent instructions: “ask for X before calling.” |
| **Show in conversation** (output) | *Show in conversation*, *Include in response* | The value is available to the model to **phrase the user-visible answer** (usually safe, human-readable text). | Turn **ON** for: **`summaryText`**, **`output_FacilitySummary`**, **`message`**, **`success`** (boolean), **`output_Status`** for match/no-match **explanations**. Turn **OFF** for raw **record Ids** you do not want repeated to the patient (see below). |
| **Filter from agent action** (output) | *Filter*, *Exclude from conversation*, *Use as filter only* | Depends on edition: often **exclude from natural-language reply** and/or feed **topic/action guards** (e.g. booking only if verified). | Turn **ON** / enable filter-style behavior for **`output_PatientAccountId`**, **`serviceAppointmentId`** if your UI echoes Ids—keep them **structured** for the next tool call instead of reading Ids aloud. Turn **OFF** for human-readable summaries so the patient hears the directory/list. Tip: pair **Escalation** topic with outputs that encode **failure** (`NO_MATCH`). |

If a checkbox **does not appear**, rely on **Required** + **Show in conversation** only and encode the rest in **subagent instructions**.

#### Quick rules

1. **Require ON** + **Collect ON** → Patient explicitly provides the value (mobile, preferred slot in words that you map to datetime).
2. **Require ON** + **Collect OFF** → Value comes from **prior tool or session** (e.g. `patientAccountId` after verify)—**never read the Id aloud** to the patient.
3. **Human-readable CRM text** → **Show in conversation ON** so the model can reply with **summaries patients understand** (doctor names, facility names, plain dates—not ISO strings if avoidable).
4. **Opaque Ids** → **Show OFF** for patient sessions so Salesforce Ids are not spoken or pasted into chat. **On** only for internal testing with staff.
5. **`message` / errors** → **Show in conversation ON** for booking/patient-data actions so the agent can say something **kind** when something fails—but add subagent instruction: **rephrase** any raw exception into a short patient-safe line.

**Default for production patient traffic:** treat **Ids and task Ids as internal**; **summaries and success/failure intent** as patient-facing.

---

### 2.3b Detailed inputs & outputs (HC automations)

Use the **InvocableVariable / Flow variable API names** shown in Builder (they match repo metadata). **Description** column is safe to paste into Builder’s variable description fields. For **Enhanced Web Chat** structured renderers, bind the **`*Ui`** model outputs in Builder per **`docs/Agentforce-Enhanced-Chat-LWC-Plan.md`** (not only `summaryText`).

#### Flow — `HC_Log_Agent_Action`

**Inputs**

| Variable | Description (for Builder) | Require | Collect from user |
|----------|---------------------------|---------|-------------------|
| `input_ActionName` | Short audit label, e.g. `HC_Find_Specialist`, `HC_Booking_BOOK`. | Yes | No — agent derives from prior step / instruction. |
| `input_Status` | `Success` or `Failed` per `Agent_Action_Log__c.Status__c`. | Yes | No |
| `input_CorrelationId` | Tie to session/conversation Id for demos. | No | No |
| `input_ErrorMessage` | High-level failure reason for ops—**no PHI, no stack traces** (patients may trigger logs indirectly). | No | No |
| `input_InputSummary` | Redacted, **non-PHI** label of what was attempted (e.g. “book Chennai facility”)—not free-text patient quotes. | No | No |

**Outputs**

| Variable | Description | Show in conversation | Filter / internal |
|----------|-------------|----------------------|-------------------|
| `output_LogRecordId` | Id of `Agent_Action_Log__c` row. | **Off** for patients (technical). **On** only for internal/debug demos. | Prefer **Filter**/internal so Id is not read aloud. |

---

#### Flow — `HC_Resolve_Patient_By_Phone`

**Inputs**

| Variable | Description | Require | Collect from user |
|----------|-------------|---------|-------------------|
| `input_Phone` | Exact match to Person Account `PersonMobilePhone` (format as user states; normalize in data). | **Yes** | **Yes** — patient must provide mobile for guest verify. |

**Outputs**

| Variable | Description | Show in conversation | Filter / internal |
|----------|-------------|----------------------|-------------------|
| `output_Status` | `UNIQUE_MATCH` or `NO_MATCH`. | **Yes** — agent explains whether profile was found. | Use **Filter** logic in topic if Builder supports gating booking on `UNIQUE_MATCH`. |
| `output_PatientAccountId` | Person Account Id when matched; empty if no match. | **Off** for patient (do not read Id). Pass internally to booking/patient-data actions. | Treat as structured context for next action. |

---

#### Flow — `HC_Create_Guest_Person_Account`

**Inputs**

| Variable | Description | Require | Collect from user |
|----------|-------------|---------|-------------------|
| `patient_full_name` | Full name for new **Person Account** (parsed to first/last in Flow). | **Yes** | **Yes** when user is **new** and creating a profile. |
| `PersonMobilePhone` | Mobile; normalized in Flow (same family as **HC_Resolve**). | **Yes** | **Yes** |
| `PersonEmail` | Email on Person Account. | **Yes** | **Yes** |

**Outputs**

| Variable | Description | Show in conversation | Filter / internal |
|----------|-------------|----------------------|-------------------|
| `output_Status` | e.g. **`CREATED_NEW`**, **`MATCHED_EXISTING`**, **`FAILED`**. | **Yes** — agent explains outcome. | — |
| `output_PatientAccountId` | Person Account Id on success / match. | **Off** for patient | Pass to booking / patient-data actions. |
| `output_ErrorMessage` | High-level error when **FAILED**. | **Yes** on failure | Rephrase gently for patient. |

---

#### Apex — **HC Get Facilities** (Agentforce; `HCFacilityListInvocable`)

The **`GenAiFunction`** **`HC_Get_Facilities`** in this repo invokes **Apex** **`HCFacilityListInvocable`** (label **HC Get Facilities**). Same filters as the Flow below; adds **`facilityListUi`** for Enhanced Web Chat.

**Inputs**

| Variable | Description | Require | Collect from user |
|----------|-------------|---------|-------------------|
| `input_CityKeyword` | Filters `HealthcareFacility.Name` CONTAINS keyword; blank = first 25 alpha by name. | No | Optional |

**Outputs**

| Variable | Description | Show in conversation | Filter / internal |
|----------|-------------|----------------------|-------------------|
| `success` | Query/path succeeded. | **Yes** | Off |
| `message` | Detail when `success` is false. | **Yes** on failure | Off |
| `summaryText` | Plain-text facility lines for the reply. | **Yes** | Off |
| `facilityListUi` | **`HCFacilityListUiModel`** for **`hcFacilityCardList`** (Enhanced Web Chat). | Bind as **custom Lightning type** in Builder—see LWC plan | Off |

---

#### Flow — `HC_Get_Facilities` *(non-agent callers only)*

Use when something other than Agentforce calls the Flow directly (same **`input_CityKeyword`** semantics).

**Outputs**

| Variable | Description | Show in conversation | Filter / internal |
|----------|-------------|----------------------|-------------------|
| `output_FacilitySummary` | Plain-text facility list. | **Yes** | Off |

---

#### Apex — **HC Route Symptom to Specialty** (`HC_SymptomRoutingInvocable`)

**Inputs**

| Variable | Description | Require | Collect from user |
|----------|-------------|---------|-------------------|
| `symptomText` | Free-text symptom or concern (navigation only—not triage). | **Yes** | **Yes** when user describes symptoms before directory lookup. |
| `cityKeyword` | Optional city for downstream **HC Find Specialist**. | No | Optional |

**Outputs**

| Variable | Description | Show in conversation | Filter / internal |
|----------|-------------|----------------------|-------------------|
| `recommendedSpecialty` | Specialty label for **`HC_Find_Specialist.specialtyName`**. | **Yes** | Off |
| `routingSummary` | Short patient-facing explanation. | **Yes** | Off |
| `disclaimer` | Non-diagnosis / emergency guidance. | **Yes** | Off |
| `matchFound` | Whether a row matched in **`Symptom_Specialty_Map__c`**. | **Yes** | Off |
| `cityKeyword` | Echo for chaining to directory. | Optional | Off |

---

#### Apex — **HC Slot Suggestion** (`HC_SlotSuggestionInvocable`)

Call **before** **`BOOK`** when the user has chosen **facility** (and optional provider) and **date**.

**Inputs** — see class metadata for full list (typically facility Id, optional provider Id, target date, correlation Id).

**Outputs**

| Variable | Description | Show in conversation | Filter / internal |
|----------|-------------|----------------------|-------------------|
| `success` / `message` | Outcome and errors. | **Yes** | Off |
| `summaryText` | Plain-language slot summary. | **Yes** | Off |
| `slotsJson` | Machine-readable slot list (also embedded in **`slotUi`**). | Often internal | Off |
| `slotsFound` | Count. | Optional | Off |
| `slotUi` | **`HCSlotSuggestionUiModel`** for **`hcSlotSuggestionRenderer`**. | Bind in Builder for Enhanced Web Chat | Off |

---

#### Apex — **HC Find Specialist** (`HC_DirectoryInvocable.findSpecialists`)

**Inputs**

| Variable | Description | Require | Collect from user |
|----------|-------------|---------|-------------------|
| `cityKeyword` | Matches facility name (LIKE). | No | Optional — collect when user specifies city/area. |
| `specialtyName` | Matches specialty name (LIKE). | No | Optional — collect when user names specialty/dept. |
| `topN` | Max rows (cap 25; Apex defaults if null). | No | No — agent can pass a fixed number (e.g. 10). |

At least **one** of city or specialty is usually needed for a useful result; enforce via **instructions**, not always via Required (otherwise blocks “list everyone” paths).

**Outputs**

| Variable | Description | Show in conversation | Filter / internal |
|----------|-------------|----------------------|-------------------|
| `summaryText` | Directory lines for the reply. | **Yes** | Off |
| `success` | Whether query succeeded (boolean). | **Yes** for transparency on errors | Off |
| `directoryUi` | **`HCDirectoryUiModel`** for **`hcDirectoryResultsRenderer`** (Enhanced Web Chat). | Bind in Builder | Off |

---

#### Apex — **HC Booking Actions** (`HC_BookingActionsInvocable.run`)

**Inputs** (always set **`operation`** first; others depend on op — see `HC-Automations.md`)

| Variable | Description | Require | Collect from user |
|----------|-------------|---------|-------------------|
| `operation` | `BOOK`, `MODIFY`, or `CANCEL`. | **Yes** | **Yes** in the sense of intent — user must agree to book/cancel/reschedule. |
| `patientAccountId` | Person Account Id (from resolve or session). | **Yes** for all ops | **No** — pass from **`HC_Resolve`** / session; never ask patient for Id. |
| `healthcareFacilityId` | Facility for **BOOK**. | Required for **BOOK** (mark in instructions + Required if you split actions per op). | **Yes** when user chooses site (or map from directory result). |
| `schedStartOrNewStart` / `schedEndOrNewEnd` | Visit window for **BOOK**/**MODIFY**. | Required for **BOOK**/**MODIFY** | **Yes** — confirm date/time in conversation. |
| `healthcareProviderId` | Optional doctor for **BOOK**. | No | Optional — if user picks a named doctor. |
| `parentRecordId` / `workTypeId` | Org-specific optional **BOOK** fields. | Per org | Rarely from user — often fixed/default. |
| `correlationId` | Tracing / audit correlation. | No | No |
| `subject` | SA subject line **BOOK**. | No | Optional |
| `serviceAppointmentStatus` / `serviceAppointmentStatusCategory` / `clinicalEncounterStatus` | Override API picklist values. | No | No |
| `serviceAppointmentId` | Existing SA for **MODIFY**/**CANCEL**. | **Yes** for MODIFY/CANCEL | Collect **indirectly** (“your Monday visit”) — map to Id via context or prior lookup if you add one; otherwise agent needs Id from thread. |
| `cancellationReason` | **CANCEL** reason if org uses it. | Optional | Optional — ask if policy requires. |

**Outputs**

| Variable | Description | Show in conversation | Filter / internal |
|----------|-------------|----------------------|-------------------|
| `success` | Whether DML path succeeded. | **Yes** | Off |
| `message` | Error or detail text. | **Yes** especially on failure | Off |
| `bookingUi` | **`HCBookingConfirmationUiModel`** for **`hcBookingConfirmationRenderer`** (BOOK/MODIFY/CANCEL card). | Bind in Builder for Enhanced Web Chat | Off |
| `serviceAppointmentId` | Created/updated SA Id. | **Off** for patient | Internal / confirmation codes only if you map to human reference |
| `clinicalEncounterId` / `clinicalEncounterProviderId` | Encounter rows. | **Off** | Internal |

---

#### Apex — **HC Patient Data Actions** (`HC_PatientDataActionsInvocable.run`)

**Inputs**

| Variable | Description | Require | Collect from user |
|----------|-------------|---------|-------------------|
| `operation` | `INSURANCE`, `PREREQUISITES`, `ROOM_RATES`, `SPECIALTIES`, `BOOKING_SESSION`. | **Yes** | **Yes** — intent must match question type. |
| `patientAccountId` | **INSURANCE**, **BOOKING_SESSION**. | When op requires it | **No** — from resolve/session. |
| `serviceAppointmentId` | **PREREQUISITES**. | When op = PREREQUISITES | Indirect — user refers to counselling appointment; may need lookup if only date given. |
| `healthcareFacilityId` | **ROOM_RATES**. | When op = ROOM_RATES | **Yes** — facility for rates (from list or name). |
| `roomTypeApi` | **ROOM_RATES** filter (`General`, `ICU`, `Private`, `Semi_Private`). | No | Optional — ask if user asks ICU vs ward. |
| `preferredFacilityId` / `lastServiceAppointmentId` / `lastClinicalEncounterId` / `contextToken` | **BOOKING_SESSION** context. | Optional | Mixed — token is not conversational PHI. |

**Outputs**

| Variable | Description | Show in conversation | Filter / internal |
|----------|-------------|----------------------|-------------------|
| `success` | Outcome flag. | **Yes** | Off |
| `summaryText` | Main user-facing answer for read ops. | **Yes** | Off |
| `message` | Error/detail. | **Yes** on failure | Off |

---

#### Apex — **HC Create Visit Reminder Task** (`HC_ReminderInvocable.createReminderTask`)

**Inputs**

| Variable | Description | Require | Collect from user |
|----------|-------------|---------|-------------------|
| `serviceAppointmentId` | SA to attach reminder **Task** to patient. | **Yes** | **No** — use Id from successful **BOOK** output in the same session. |
| `correlationId` | Optional audit correlation. | No | No |

**Outputs**

| Variable | Description | Show in conversation | Filter / internal |
|----------|-------------|----------------------|-------------------|
| `success` | Task created or not. | **Yes** | Off |
| `message` | Error or confirmation. | **Yes** | Off |
| `taskId` | Created Task Id. | **Off** for patient | Internal |

---

### 2.4 Finding actions when you add or edit a subagent

- After actions are created, they appear under that subagent’s **Actions** list with the **Agent action label** you set.
- To reuse on another subagent: add a **new** action reference to the same Flow/Apex from that subagent (or duplicate pattern from the workshop). There is **no separate global “action library”** list in all orgs—actions are usually scoped to the agent/topic where you created them; **search within Builder** for the action label if the UI offers search.

### 2.5 HC automations → agent action checklist

Use this table while stepping through **Create New Action** so names line up with **`docs/HC-Automations.md`** and **`genAiFunctions/`**. GenAi **developer names** are in the first column where applicable.

| # | Reference type | Select in “Reference action” | Suggested loading text | Enhanced Chat UI output *(bind in Builder)* |
|---|----------------|------------------------------|------------------------|-----------------------------------------------|
| 1 | **Flow** | `HC_Log_Agent_Action` | Recording this step… | — |
| 2 | **Flow** | `HC_Resolve_Patient_By_Phone` | Verifying your profile… | — |
| 3 | **Flow** | `HC_Create_Guest_Person_Account` | Creating your profile… | — |
| 4 | **Apex** | **`HCFacilityListInvocable`** — **HC Get Facilities** *(same label as GenAi `HC_Get_Facilities`)* | Looking up hospitals… | **`facilityListUi`** → **`HCFacilityListUiModel`** |
| 5 | **Apex** | **`HC_SlotSuggestionInvocable`** — **HC Slot Suggestion** | Finding available times… | **`slotUi`** → **`HCSlotSuggestionUiModel`** |
| 6 | **Apex** | **`HC_DirectoryInvocable`** — **HC Find Specialist** | Searching our network… | **`directoryUi`** → **`HCDirectoryUiModel`** |
| 7 | **Apex** | **`HC_SymptomRoutingInvocable`** — **HC Route Symptom to Specialty** | Mapping your request… | — |
| 8 | **Apex** | **`HC_BookingActionsInvocable`** — **HC Booking Actions** | Updating your appointment… | **`bookingUi`** → **`HCBookingConfirmationUiModel`** |
| 9 | **Apex** | **`HC_PatientDataActionsInvocable`** — **HC Patient Data Actions** | Checking your records… | — *(text `summaryText`)* |
| 10 | **Apex** | **`HC_ReminderInvocable`** — **HC Create Visit Reminder Task** | Setting a reminder… | — |
| 11 | **Prompt** | **HC Coverage Prep Patient Facing** (`generatePromptResponse`) | Preparing your summary… | — *(narrative)* |
| 12 | **Apex** *(optional)* | **`HCCoveragePrepUiInvocable`** — **HC Coverage Prep UI** | Preparing your checklist… | **`coveragePrepUi`** → **`HCCoveragePrepUiModel`** *(not in default planner bundle—add to **Coverage & prep** if you want the accordion)* |

**Tips**

- Per-variable **Require**, **Collect from user**, **Show in conversation**, **Filter**: follow **§2.3a** and **§2.3b**.
- **`operation`** on booking / patient-data Apex: mark **Required** so the model passes `BOOK` vs `INSURANCE` explicitly.
- **HC Patient Data Actions** appears on **both** Provider Matching ( **`SPECIALTIES`** ) and Coverage & prep (other ops)—same automation, different topic instructions.
- **HC Get Facilities** for the agent must be the **Apex** invocable above so **`facilityListUi`** is populated; the standalone Flow **`HC_Get_Facilities`** is for non-agent integrations only.
- If a Flow does not appear: confirm it is **Autolaunched**, **Active**, and API name matches exactly.

### 2.6 Map created actions → subagents (quick)

| Subagent | Actions (§2.5 rows) |
|----------|---------------------|
| **Provider Matching** | **HC Route Symptom to Specialty** (7), **HC Find Specialist** (6), **HC Get Facilities** (4), **HC Patient Data Actions** (9) — emphasize **`SPECIALTIES`** in instructions; optional **HC Log Agent Action** (1) |
| **Scheduling & visits** | **HC Resolve Patient By Phone** (2), **HC Create Guest Person Account** (3), **HC Get Facilities** (4), **HC Slot Suggestion** (5), **HC Booking Actions** (8), **HC Create Visit Reminder Task** (10), optional **HC Log Agent Action** (1) |
| **Coverage & prep** | **HC Patient Data Actions** (9), **HC Coverage Prep Patient Facing** (11), optional **HC Coverage Prep UI** (12), optional **HC Log Agent Action** (1) |
| **Visit information (FAQ)** | **Answer Questions with Knowledge** (planner-level standard action)—no HC rows |
| **Escalation** | Usually **no HC actions** — policy + Omni handoff only |

---

## 3. Subagents (template + repo topics)

These cover scripts §7–17 and §12–15 without overloading **Provider Matching**. The shipped **`GenAiPlannerBundle`** already includes **Scheduling & visits**, **Coverage & prep**, and **Visit information (FAQ)** as topics—use this section for script alignment and copy-paste text; do not create duplicate topics.

| # | Subagent API label | Covers scripts | Role |
|---|--------------------|----------------|------|
| A | **Scheduling & visits** | §7–11, §9, §17 (copy), §22 | Verification + writes (`ServiceAppointment` / encounters); higher risk — isolate tools. |
| B | **Coverage & prep** | §12–15 | Read-heavy patient data (`Insurance`, prerequisites, rates, booking session); optional **`BOOKING_SESSION`** writes. |
| C | **Visit information (FAQ)** | §16 | Knowledge / general prep; bundle wires **Answer Questions with Knowledge** at planner level. |

**Global (agent) level** (not a subagent): scripts **§1** (opening), **§19** (verify fail), **§23** (escalation — can also mirror in **Escalation**), **§24** (close). Put short **system / agent instructions** there.

---

## 4. Subagent specs (copy blocks)

For each subagent in Builder, fill:

- **Classification description** — Helps **Topic Selector** route correctly (who should own this utterance).
- **Scope** — One paragraph: what this subagent owns end-to-end.
- **Instructions** — Bullet behaviors: when to call which action, **`operation`** values for Apex, verification rules.

Actions reference **`docs/HC-Automations.md`**.

---

### 4.1 Provider Matching *(existing — configure)*

| Maps to scripts | §2–3 (locations/geo), §4–6 (discovery), §18 (no results), §20–21 (logging optional) |
|-----------------|----------------------------------------------------------------------------------------|

**Actions to attach**

| Action | Type | When to use |
|--------|------|-------------|
| **HC Route Symptom to Specialty** (`HC_SymptomRoutingInvocable`) | Apex | When the user **describes symptoms**—run **first**, then **HC Find Specialist** with returned specialty (+ city). Navigation only—not diagnosis. |
| `HC_Get_Facilities` | Apex **`HCFacilityListInvocable`** (GenAi label **HC Get Facilities**) | List hospitals / filter by city keyword in **facility name** (not GPS). Prefer Apex so **`facilityListUi`** can render in Enhanced Web Chat. |
| **HC Find Specialist** (`HC_DirectoryInvocable`) | Apex | City + specialty search; “who practices in Delhi”, “GYN oncology in Chennai”. Bind **`directoryUi`** for card UI. |
| **HC Patient Data Actions** | Apex | Only **`operation` = `SPECIALTIES`** — plain-text specialty catalog. |
| `HC_Log_Agent_Action` | Flow | Optional: after successful directory lookup for demos/judging (§20–21). |

Do **not** attach **`HC_BookingActions`**, **`HC_Slot_Suggestion`**, or **`HC_Resolve_Patient_By_Phone`** here (avoid accidental booking from “find a doctor” turns). **`HC_Get_Facilities`** on this topic is for discovery only.

**Classification description** *(paste)*

> User wants to see hospitals or clinics, cities we operate in, which sites offer a specialty, or wants to find doctors by specialty or department without scheduling yet. Includes “nearest” / area questions answered from facility names and directory data only.

**Scope** *(paste)*

> Help users explore Onco Global’s facility network and provider directory. Provide lists and plain-text summaries from CRM. Do not book or cancel appointments here. Do not give clinical advice or diagnosis.

**Instructions** *(paste)*

> - When the user **describes symptoms**, call **HC Route Symptom to Specialty** first, then **HC Find Specialist** with the recommended specialty and city—navigation/education only, not triage.
> - For facility lists or “hospitals in [region]”, call **HC_Get_Facilities** with optional city keyword; summarize results clearly.
> - For “find [specialty] in [city]” or department-style requests, call **HC Find Specialist** with city keyword, specialty name, and a sensible max rows (for example 10).
> - For questions about what specialties exist in the network, call **HC Patient Data Actions** with **operation** = **SPECIALTIES**.
> - If no rows match, say so honestly and offer nearest alternatives or escalation (scripts §18).
> - Prefer grounded tool output over guessing facility or doctor names.

---

### 4.2 Scheduling & visits *(topic in bundle)*

| Maps to scripts | §7–11 (book / modify / cancel), §9 (capacity narrative), §17 (arrival copy), §22 (short turns), §19 routes here after failed verify |
|-----------------|---------------------------------------------------------------------|

**Actions to attach**

| Action | Type | When to use |
|--------|------|-------------|
| `HC_Resolve_Patient_By_Phone` | Flow | Before any booking or patient-specific modify/cancel by phone (guest channel). |
| `HC_Create_Guest_Person_Account` | Flow | After guest confirms they are **new**: minimal fields → creates **`Person Account` only** (no Lead); dedupe via phone; returns **`patientAccountId`** / status (**`CREATED_NEW`**, **`MATCHED_EXISTING`**, **`FAILED`**). |
| `HC_Get_Facilities` | Apex **`HCFacilityListInvocable`** | Shortlist sites when the user has not chosen a facility yet (optional **`facilityListUi`** in Enhanced Web Chat). |
| **HC Slot Suggestion** (`HC_SlotSuggestionInvocable`) | Apex | After facility (+ optional provider) and **date** are known—**before** **`BOOK`**; bind **`slotUi`** for slot picker UI. |
| **HC Booking Actions** (`HC_BookingActionsInvocable`) | Apex | **`BOOK`**, **`MODIFY`**, **`CANCEL`** — see `BOOKING_PATTERN.md` / Apex descriptions; bind **`bookingUi`** for confirmation card. |
| **HC Create Visit Reminder Task** (`HC_ReminderInvocable`) | Apex | Optional after confirmed booking if you want a Task reminder MVP. |
| `HC_Log_Agent_Action` | Flow | Log success/failure for audit (§20–21). |

**Classification description** *(paste)*

> User wants to book, reschedule, or cancel an appointment, or asks about availability, wait times, or capacity; or is a **new** or **returning** guest providing identity (mobile or profile-creation details) for scheduling. **All** patients are **`Person Account`** records—**not Lead**.

**Scope** *(paste)*

> Handle verified scheduling and changes to visits using approved Salesforce actions only. Enforce verification rules before self-serve booking for guest web. Never invent appointment times—use agreed datetimes from the conversation and pass them into booking actions.

**Instructions** *(paste)*

> - **Verification (guest):** Ask whether they already have a profile with us (**returning** vs **new**). **Returning:** resolve with **HC_Resolve_Patient_By_Phone**. **`UNIQUE_MATCH`:** use **`patientAccountId`** for booking and patient-data actions. **`NO_MATCH`:** if they are **new**, collect minimal details (name, mobile, email) and call **`HC_Create_Guest_Person_Account`** to create a **`Person Account` only** (no Lead)—then use returned **`patientAccountId`** when status is **`CREATED_NEW`** or **`MATCHED_EXISTING`**. If **multiple** accounts match the same mobile, do **not** self-serve book or expose data—hand off (scripts §19).
> - **Facilities:** Use **HC_Get_Facilities** to shortlist hospitals when needed before slots.
> - **Slots:** Before **BOOK**, when the user has chosen facility and date, call **HC_Slot_Suggestion**; map chosen slot to **start/end** datetimes for booking.
> - **BOOK:** Use **HC Booking Actions** with **operation** = **BOOK** and **patientAccountId** from resolution, plus facility, start/end datetimes, optional provider. If booking fails (e.g. capacity), explain safely and offer alternatives (§21).
> - **MODIFY / CANCEL:** Use **operation** = **MODIFY** or **CANCEL** with **serviceAppointmentId** and **patientAccountId** as required by the action.
> - **Capacity (§9):** If asked how busy a day is, explain that daily limits may exist and offer to try booking a specific slot; do not fabricate exact remaining counts unless a tool returns them.
> - **Reminder Task:** Optionally call **HC Create Visit Reminder Task** after a successful **BOOK** with the new **ServiceAppointment** Id.
> - **Logging:** Call **HC Log Agent Action** on important failures or after successful booking if your demo requires a visible audit row.
> - Do not provide medical advice or interpret symptoms.

---

### 4.3 Coverage & prep *(new subagent)*

| Maps to scripts | §12 (insurance), §13 (prerequisites), §14 (room rates), §15 (rebook context) |
|-----------------|-------------------------------------------------------------------------------|

**Actions to attach**

| Action | Type | When to use |
|--------|------|-------------|
| **HC Patient Data Actions** | Apex | **`INSURANCE`**, **`PREREQUISITES`**, **`ROOM_RATES`**, **`BOOKING_SESSION`** (not SPECIALTIES — that stays in Provider Matching). |
| **HC Coverage Prep Patient Facing** | Prompt template | After **`HC_Patient_Data_Actions`** returns raw **`summaryText`**, pass it into this action as **`RawSummaryFromTool`** for patient-facing narrative (bundle instruction). |
| **HC Coverage Prep UI** (`HCCoveragePrepUiInvocable`) | Apex *(optional)* | Structured **`coveragePrepUi`** accordion for Enhanced Web Chat — **not** in default **`Coverage_prep`** plugin; add in Builder if you want UI alongside the prompt. |
| `HC_Log_Agent_Action` | Flow | Optional logging for demo. |

**Classification description** *(paste)*

> User asks about insurance on file, documents needed before counselling, approximate room rates, or returning / “book similar” using past visit context.

**Scope** *(paste)*

> Read summaries from CRM for coverage and prep; room rates are non-binding information only. Booking-session updates support returning patients—not clinical notes.

**Instructions** *(paste)*

> - **Insurance:** **HC Patient Data Actions**, **operation** = **INSURANCE**, pass **patientAccountId** after verification if needed.
> - **Prerequisites:** **operation** = **PREREQUISITES**, pass **serviceAppointmentId** for the counselling appointment.
> - **Room rates:** **operation** = **ROOM_RATES**, pass **healthcareFacilityId**; optional **roomTypeApi** for ICU vs Private etc. Always state rates are illustrative, not a quote (§14).
> - **Rebook context:** **operation** = **BOOKING_SESSION** for storing or recalling last facility / context token per patient; combine with directory/scheduling subagents for actual new bookings (§15).
> - **Context / resume tokens:** Use only **opaque, non-clinical** values your automation expects (e.g. a short session key). Do **not** ask patients to dictate diagnoses, detailed clinical notes, or sensitive identifiers into chat to fill “token” or memo-like fields.

**Implementers — not part of the agent prompt:** The runtime agent **does not read** repo Markdown or `Data-Model-Objects-And-Fields.md`. Those docs are for **your team** when defining fields (`Booking_Session__c.Context_Token__c`, etc.) and Apex so free-text slots are never meant for PHI. The bullet above is what you **paste into Builder** so the **model** behaves correctly toward patients.

---

### 4.4 Visit information (FAQ) *(topic in bundle)*

| Maps to scripts | §16 |
|-----------------|-----|

**Actions / data**

- The **`Onco_Global_Patient_Agent`** bundle links the planner action **Answer Questions with Knowledge** (standard **streamKnowledgeSearch**). Connect **Knowledge** or **Data Library** in the org; topic instructions require calling Knowledge **before** free-text answers. No HC Apex is required for static FAQs if articles are grounded.

**Classification description** *(paste)*

> User asks what to bring on a first visit, general preparation, or generic educational questions answerable from approved Knowledge articles.

**Scope** *(paste)*

> Answer only from connected Knowledge / approved content. If articles are missing, keep answers high-level and suggest speaking with the care team.

**Instructions** *(paste)*

> - Prefer retrieved article snippets over generic medical claims.
> - Do not diagnose or recommend treatments.

---

### 4.5 Escalation *(existing — extend instructions)*

| Maps to scripts | §23 |
|-----------------|-----|

**Classification description** *(paste / merge)*

> User asks for a human, contact center, billing-specific guarantees, or personalized medical advice; or describes emergency symptoms.

**Instructions** *(paste)*

> - For **emergency** symptoms: tell the user to use **emergency services now**—do not triage, wait, or offer home remedies.
> - For **scheduling** handoff: share only **approved** phone numbers and hours; keep hold times/unavailability honest.
> - Never interpret **labs, imaging, or pathology**—direct to their clinician.
> - If the user is **distressed**, keep responses brief, supportive, and safety-first (emergency escalation per policy).

---

## 5. Action inventory (single list)

Use this checklist so you do not miss a binding when attaching actions:

| # | GenAi / Builder label | Invocation |
|---|------------------------|------------|
| 1 | `HC_Log_Agent_Action` | Flow |
| 2 | `HC_Resolve_Patient_By_Phone` | Flow |
| 3 | `HC_Create_Guest_Person_Account` | Flow |
| 4 | **`HC_Get_Facilities`** *(agent)* | Apex **`HCFacilityListInvocable`** — Flow **`HC_Get_Facilities`** is non-agent only |
| 5 | **HC Slot Suggestion** | Apex `HC_SlotSuggestionInvocable` |
| 6 | **HC Route Symptom to Specialty** | Apex `HC_SymptomRoutingInvocable` |
| 7 | **HC Find Specialist** | Apex `HC_DirectoryInvocable` |
| 8 | **HC Booking Actions** | Apex `HC_BookingActionsInvocable` |
| 9 | **HC Patient Data Actions** | Apex `HC_PatientDataActionsInvocable` |
| 10 | **HC Create Visit Reminder Task** | Apex `HC_ReminderInvocable` |
| 11 | **HC Coverage Prep Patient Facing** | Prompt (`generatePromptResponse`) |
| 12 | **HC Coverage Prep UI** *(optional)* | Apex `HCCoveragePrepUiInvocable` |
| — | **Answer Questions with Knowledge** | Standard planner action (`streamKnowledgeSearch`) — FAQ topic |

**`HC_Patient Data Actions` — `operation` values:** `SPECIALTIES` (Provider Matching), `INSURANCE`, `PREREQUISITES`, `ROOM_RATES`, `BOOKING_SESSION` (Coverage & prep).

**`HC Booking Actions` — `operation` values:** `BOOK`, `MODIFY`, `CANCEL` (Scheduling & visits).

---

## 6. Global agent instructions (Agent Definition → System)

Keep instructions **short** but **explicit for patients**. Paste into **Agent → Settings → System** (wording may vary). Below is a **patient-production-ready** baseline; adjust contact numbers/hours only with approved org copy.

**Patient-safe example (recommended):**

> You support **Onco Global patients and families** with **scheduling and finding care**—hospital locations, specialists, booking and changing appointments, general visit preparation, insurance and document checklists we have on file, and **non-binding** room-rate information for planning.
>
> **You are not a clinician.** Do not diagnose, prescribe, interpret test results, or give personalized treatment advice. For **emergency** symptoms, tell them to use **local emergency services (e.g. 911 or the local emergency number)** immediately. For clinical questions, direct them to their **care team** or appropriate services.
>
> Use **only** the configured **actions** for facts about our network and this patient’s record. **Never invent** doctors, facilities, or appointments.
>
> **Identity:** For guests, only proceed with self-service booking or account-specific information after identity rules are met: **returning** patients match **one** **`Person Account`** via mobile; **new** patients provide minimal fields and **`HC_Create_Guest_Person_Account`** creates a **`Person Account`** only—**no Lead**. If you cannot match or create safely (e.g. **multiple** matches for one mobile), **do not** show anyone else’s information—offer **phone or in-person help** using approved contact details.
>
> **How you speak:** Use **clear, calm, plain language**. **Never read Salesforce record Ids** or internal codes to the user. Confirm bookings with **facility names and times people understand**.
>
> **Money & coverage:** Rates and insurance summaries are **informational**; coverage and charges are finalized with **registration and the payer**.

**Shorter variant (if character limits apply):**

> Scheduling and navigation only—not medical advice. Emergencies → emergency services. Use actions for CRM facts; verify guest identity before bookings; never expose other patients’ data or read record Ids aloud; insurance and rates are informational.

---


## 7. Verification reminder (scripts §13–21)

| Situation | Behavior |
|-----------|----------|
| Directory only | No phone verification required. |
| Booking / modify / cancel / insurance / patient-specific data | **Returning:** **HC_Resolve_Patient_By_Phone** → **`UNIQUE_MATCH`**. **New guest:** **HC_Create_Guest_Person_Account** → **Person Account** + **`patientAccountId`** when status allows. |
| Ambiguous / multi-match phone | Hand off or sign-in path (§19)—do not book. |

---

## 8. Related docs

| Doc | Use |
|-----|-----|
| `docs/Patient-Agent-Conversation-Scripts.md` | QA utterances |
| `docs/HC-Automations.md` | Action matrix & Flow/Apex names |
| `docs/Agentforce-Enhanced-Chat-LWC-Plan.md` | **`\*Ui`** output → Lightning type → LWC binding for Enhanced Web Chat |
| `docs/Agent-Configuration-Deployment-Summary.md` | Deploy surfaces and agent packaging notes |
| `force-app/.../genAiPlannerBundles/Onco_Global_Patient_Agent/*.genAiPlannerBundle` | Embedded topic instructions + action links |
| This doc §**2** | Create actions (§2.2–2.3), I/O checkboxes (§2.3a), per-automation I/O (§2.3b), summary checklist (§2.5) |
| This doc §**10** | **Agent Details / System / Welcome / Error** copy for Builder |
| `docs/BOOKING_PATTERN.md` | SA / encounter semantics |
| `docs/Data-Model-Objects-And-Fields.md` | **Implementers only** — field semantics when building/metadata; **not** loaded by the agent at runtime |

---

## 10. Copy-paste text — Agent Details, System, Welcome, Error *(UI fields)*

Use these in **Agent Definition → Agent Details**, **Settings → System**, and **Language Settings** as noted. Replace **`[SCHEDULING_PHONE]`** / **`[HOURS]`** with values your org approves for production.

**Character counts** are approximate (spaces included); shorten with the **Short** variants if a field rejects long text.

### Agent Details → Description *(replaces generic Patient & Member Services text)*

**Recommended (~520 characters)**

```text
Onco Global digital assistant for scheduling and navigation across our hospital network: find locations and specialists, book or change appointments, and get general visit preparation guidance. Can share informational insurance summaries, counselling document checklists, and non-binding room-rate references for planning—not medical diagnosis or treatment decisions. Coverage, eligibility, and charges are finalized at registration and with your payer or insurer. For emergencies, use local emergency services; this assistant does not provide clinical advice.
```

**Short (~245 characters)** — use if Description max length is tight:

```text
Onco Global scheduling assistant: find hospitals/specialists, book or change visits, general prep info; insurance/rates are informational only—not clinical advice. Emergencies: use emergency services.
```

---

### Settings → System → Agent-level instructions *(high-level only; tasks live in subagents)*

UI guidance: avoid task-specific procedure here—put detail in **subagent** instructions.

**Recommended (~650 characters)**

```text
You support Onco Global patients and families with scheduling and finding care: hospital locations, specialists, booking or changing appointments, and high-level visit preparation. You are not a clinician—do not diagnose, prescribe, or interpret labs or imaging. For emergency or life-threatening symptoms, tell the user to contact local emergency services immediately. Use only your configured actions for facts about our network and the patient’s record; never invent doctors, facilities, or appointments. Speak in clear, calm language; never read Salesforce record IDs or internal codes aloud. For guest web users, follow each topic’s rules for identity before self-serve booking or sensitive account information. Insurance and room-rate information is informational only.
```

**Compact (~380 characters)** — if the field is short:

```text
Scheduling and navigation only—not medical advice; emergencies → emergency services. Use configured actions for CRM facts; plain language; never read record IDs to users. Verify guests per topic rules before booking. Insurance/rates informational.
```

---

### Settings → System → Welcome message *(screenshot showed ~800 max; stay under limit)*

**Recommended (~690 characters)**

```text
Hello—I’m Onco Global’s digital assistant. I can help you find our hospitals and specialists in the cities we serve, book or reschedule appointments, and answer general questions about visits and preparation. I can also share high-level information about insurance we have on file and typical room-rate bands where available—all informational, not a quote or guarantee. I’m not able to diagnose conditions or give personal treatment advice. For emergencies or severe symptoms, please use your local emergency services or go to the nearest emergency department. What would you like help with today?
```

**Shorter (~360 characters)**

```text
Hello—I’m Onco Global’s assistant. I can help you find hospitals and specialists, manage appointments, and share general visit and prep information (insurance and rates are informational only). I’m not a clinician—for emergencies use emergency services. What would you like to do?
```

---

### Settings → System → Error message *(fill if currently empty — patients see failures)*

**Recommended**

```text
Something went wrong and we couldn’t finish that step. Please try again in a moment. If it keeps happening, contact our scheduling team at [SCHEDULING_PHONE] during [HOURS]. If you have a medical emergency, use your local emergency number or go to the nearest emergency department—don’t wait for this chat.
```

**Without phone placeholder (if you publish the number elsewhere only)**

```text
Something went wrong on our side—please try again shortly. For help with scheduling, use the contact number on our website or your appointment materials. For emergencies, call your local emergency services immediately.
```

---

### Language Settings *(optional notes)*

- **Default English** with **English (UK)** allowed is fine; keep **one** primary tone.
- Add more **Allowed languages** only when Knowledge, templates, and staff support are ready.

---

## 11. Official references (bookmark)

- [Agentforce Developer Guide — overview](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-overview.html)
- [Get started with Agentforce actions](https://developer.salesforce.com/docs/einstein/genai/guide/get-started-actions.html)
- [Apex `InvocableMethod` for Agentforce](https://developer.salesforce.com/docs/ai/agentforce/guide/agent-invocablemethod.html)
- [Exercise: Create a Service Agent](https://developer.salesforce.com/agentforce-workshop/service-agents/1-create-a-service-agent) (includes **Create New Action** for Flows)
- [Trailhead: add a Flow as an agent action](https://trailhead.salesforce.com/content/learn/modules/agent-customization-with-flows/add-a-flow-as-an-agent-action)

---

*Update this file when the **`Onco_Global_Patient_Agent`** planner bundle, **`genAiPlugins`**, or HC automations change.*

**Patient review:** Before go-live, walk through **`Patient-Agent-Conversation-Scripts.md`** with clinicians and/or compliance stakeholders; adjust tone, escalation, and what the agent may say about coverage and emergencies to match **your** org policy.
