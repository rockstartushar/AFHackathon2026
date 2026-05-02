# Agent Configuration Deployment Summary

## Completed Actions

### 1. Permission Set Configuration ✅
**File:** `force-app/main/default/permissionsets/Hackathon_Agent_Runtime_Access.permissionset-meta.xml`

Created comprehensive permission set for Einstein Service Agent runtime user with:
- **Flow Access:** HC_Create_Guest_Person_Account, HC_Resolve_Patient_By_Phone, HC_Log_Agent_Action, HC_Get_Facilities
- **Apex Classes:** HC_SymptomRoutingInvocable, HC_SlotSuggestionInvocable, HC_BookingActionsInvocable, HC_DirectoryInvocable, HC_PatientDataActionsInvocable, HC_ReminderInvocable, HCAuditHelper
- **Object Permissions:**
  - Account (Create, Read, Edit) - for guest Person Account creation
  - Contact (Create, Read, Edit)
  - ServiceAppointment (Create, Read, Edit) - for booking
  - HealthcareFacility (Read) - for facility lookup
  - HealthcareProvider (Read) - for provider lookup
  - Agent_Action_Log__c (Create, Read, Edit) - for audit logging
  - Patient_Insurance__c (Read)
  - Symptom_Specialty_Map__c (Read)
- **User Permissions:** RunFlow (ManageProfiles removed for least privilege)

### 2. Agent Actions Registered ✅
Created GenAiFunction metadata for:

1. **HC_Create_Guest_Person_Account** (Flow)
   - Creates new guest Person Accounts
   - Path: `force-app/main/default/genAiFunctions/HC_Create_Guest_Person_Account/`

2. **HC_Route_Symptom_To_Specialty** (Apex)
   - Routes symptoms to medical specialties
   - Path: `force-app/main/default/genAiFunctions/HC_Route_Symptom_To_Specialty/`

3. **HC_Slot_Suggestion** (Apex)
   - Suggests available appointment slots
   - Path: `force-app/main/default/genAiFunctions/HC_Slot_Suggestion/`

4. **HC_Coverage_Prep_Patient_Facing** (Prompt Template)
   - Generates patient-facing coverage information
   - Path: `force-app/main/default/genAiFunctions/HC_Coverage_Prep_Patient_Facing/`

### 3. Agent Topics Updated ✅

#### Scheduling_visits Topic
**Updated Functions:**
- HC_Booking_Actions
- HC_Create_Visit_Reminder_Task
- HC_Log_Agent_Action
- HC_Resolve_Patient_By_Phone
- ✨ **HC_Create_Guest_Person_Account** (NEW)
- ✨ **HC_Slot_Suggestion** (NEW)
- ✨ **HC_Get_Facilities** (NEW)

**Key Instructions Added:**
- Guest identification workflow (returning vs new patients)
- Slot suggestion before booking
- Multi-match phone number handling

#### Provider_Matching Topic
**Updated Functions:**
- HC_Find_Specialist
- ✨ **HC_Route_Symptom_To_Specialty** (NEW)
- HC_Get_Facilities
- HC_Log_Agent_Action
- HC_Patient_Data_Actions

**Key Instructions Added:**
- Symptom-based routing to specialties
- Navigation/education disclaimer (not diagnosis)

#### Coverage_prep Topic
**Updated Functions:**
- HC_Log_Agent_Action
- HC_Patient_Data_Actions
- ✨ **HC_Coverage_Prep_Patient_Facing** (NEW)

**Key Instructions Added:**
- Coverage prep workflow sequence
- Call HC_Patient_Data_Actions first, then pass summary to prompt template

### 4. GenAiPlannerBundle (Onco Global Patient Agent) ✅

**File:** `force-app/main/default/genAiPlannerBundles/Onco_Global_Patient_Agent/Onco_Global_Patient_Agent.genAiPlannerBundle`

The planner bundle in source now embeds the **same topic instructions and local actions** as the standalone `GenAiPlugin` assets:

| Topic | Added / aligned actions |
| ----- | ------------------------ |
| **Scheduling_visits** | `HC_Create_Guest_Person_Account`, `HC_Get_Facilities`, `HC_Slot_Suggestion` (plus existing resolve, booking, reminder, log) |
| **Provider_Matching** | `HC_Route_Symptom_To_Specialty` (plus existing find specialist, get facilities, patient data, log) |
| **Coverage_prep** | `HC_Coverage_Prep_Patient_Facing` (plus existing patient data, log) |

**Deploy:** `sf project deploy start --source-dir force-app/main/default/genAiPlannerBundles/Onco_Global_Patient_Agent` (validated against `captainhack2026`).

**After deploy:** In **Agent Builder**, set **output rendering** for **HC Slot Suggestion** and **HC Find Specialist** to the Custom Lightning types (`slotUi` / `directoryUi`) if you use Enhanced Chat renderers — see `docs/Agentforce-Enhanced-Chat-LWC-Plan.md`.

---

## Next Steps - REQUIRED ACTIONS

### Step 1: Deploy to Org
Deploy permission set, GenAiFunctions, GenAiPlugins, Lightning Type bundles, LWCs, and GenAiPlannerBundle as needed:

```bash
sf project deploy start -m "PermissionSet:Hackathon_Agent_Runtime_Access" -o <your-org-alias>
# Or deploy paths from repo root for incremental updates
```

### Step 2: Assign Permission Set
Assign the **Hackathon Agent Runtime Access** permission set to the Einstein Service Agent user:

```bash
sf org assign permset -n Hackathon_Agent_Runtime_Access -o <your-org-alias>
```

Or manually in Setup:
1. Setup → Users → Permission Sets
2. Select "Hackathon Agent Runtime Access"
3. Click "Manage Assignments"
4. Add the Einstein Service Agent user

### Step 3: Verify in Agent Builder
Open Agent Builder and verify:

1. **Actions Tab** - Confirm these actions are available:
   - HC Create Guest Person Account
   - HC Resolve Patient By Phone
   - Route Symptom to Specialty
   - HC Slot Suggestion
   - Coverage Prep Patient Facing
   - (Plus existing: HC Booking Actions, HC Find Specialist, HC Patient Data Actions, etc.)

2. **Topics Tab** - Verify each topic has the correct actions attached:
   - Scheduling_visits: Should show 7 actions
   - Provider_Matching: Should show 5 actions
   - Coverage_prep: Should show 3 actions

### Step 4: Custom Lightning output (Enhanced Chat v2)
1. Open the **Service Agent** in **Agent Builder**.
2. For **HC Slot Suggestion** and **HC Find Specialist**, set **output rendering** to the custom types that map to **`slotUi`** and **`directoryUi`**.
3. See `docs/Agentforce-Enhanced-Chat-LWC-Plan.md`.

### Step 5: Retrieve agent metadata (optional, after any Builder edits)
If you change the agent in the UI, refresh source from the org:

```bash
sf project retrieve start -m "GenAiPlannerBundle,GenAiFunction,GenAiPlugin" -o <your-org-alias>
```

## Validation Checklist

- [ ] GenAiPlannerBundle (`Onco_Global_Patient_Agent`) deployed — embedded topics include new local actions
- [ ] Permission set deployed successfully
- [ ] Permission set assigned to Einstein Service Agent user
- [ ] All 4 new GenAiFunctions are visible in Agent Builder
- [ ] Scheduling_visits topic shows 7 actions
- [ ] Provider_Matching topic shows 5 actions and symptom routing instruction
- [ ] Coverage_prep topic shows 3 actions and prompt workflow instruction
- [ ] Agent can be activated without errors
- [ ] Test conversation: Guest account creation flow works
- [ ] Test conversation: Symptom routing to specialty works
- [ ] Test conversation: Coverage prep prompt returns formatted response

## Known Issues

⚠️ **XML Validation Warnings:** The genAiPlugin files contain `language xsi:nil="true"` attributes that trigger XML schema warnings. These are benign and from the org's metadata format. They do not affect deployment or functionality.

## Files Modified

```
force-app/main/default/
├── permissionsets/
│   └── Hackathon_Agent_Runtime_Access.permissionset-meta.xml (UPDATED)
├── genAiFunctions/
│   ├── HC_Create_Guest_Person_Account/
│   │   └── HC_Create_Guest_Person_Account.genAiFunction-meta.xml (NEW)
│   ├── HC_Route_Symptom_To_Specialty/
│   │   └── HC_Route_Symptom_To_Specialty.genAiFunction-meta.xml (NEW)
│   ├── HC_Slot_Suggestion/
│   │   └── HC_Slot_Suggestion.genAiFunction-meta.xml (NEW)
│   └── HC_Coverage_Prep_Patient_Facing/
│       └── HC_Coverage_Prep_Patient_Facing.genAiFunction-meta.xml (NEW)
├── genAiPlugins/
│   ├── Scheduling_visits.genAiPlugin-meta.xml (UPDATED)
│   ├── Provider_Matching.genAiPlugin-meta.xml (UPDATED)
│   └── Coverage_prep.genAiPlugin-meta.xml (UPDATED)
└── genAiPlannerBundles/
    └── Onco_Global_Patient_Agent/
        └── Onco_Global_Patient_Agent.genAiPlannerBundle (UPDATED — topics + local actions)
```

## Testing Scenarios

### Scenario 1: New Guest Patient Booking
1. User: "I'd like to book an appointment"
2. Agent asks: "Are you a returning patient?"
3. User: "No, I'm new"
4. Agent collects: Full name, mobile, email
5. Agent calls: HC_Create_Guest_Person_Account
6. Agent proceeds with booking using returned Account Id

### Scenario 2: Symptom-Based Provider Discovery
1. User: "I have chest pain and need to see a specialist"
2. Agent calls: HC_Route_Symptom_To_Specialty with symptom description
3. Agent receives recommended specialty name for directory search
4. Agent calls: HC_Find_Specialist with specialty and optional city
5. Agent presents list of matching providers

### Scenario 3: Coverage Prep Information
1. User: "What does my insurance cover?"
2. Agent calls: HC_Patient_Data_Actions (operation=INSURANCE)
3. Agent receives raw summary text
4. Agent calls: HC_Coverage_Prep_Patient_Facing prompt with RawSummaryFromTool
5. Agent presents formatted, conversational coverage information with disclaimers

---

**Configuration Date:** April 29, 2026  
**Project:** AFHackathon2026 - Onco Global Patient Agent  
**Agent:** Onco_Global_Patient_Agent (Health Cloud + Agentforce Service Agent)