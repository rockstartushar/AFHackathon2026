# HC automations (flows + Apex)

Autolaunched components for the Patient Scheduling Agent and Experience site. See **`docs/BOOKING_PATTERN.md`** for the booking data model.

**Note:** This org’s metadata compile rules allow **one `@InvocableMethod` per Apex class**, so multi-step behavior is split into **operation** parameters (`HC_BookingActionsInvocable`, `HC_PatientDataActionsInvocable`) or separate classes (`HC_DirectoryInvocable`, `HC_ReminderInvocable`).

---

## Flows (autolaunched)

| API name | Purpose |
|----------|---------|
| **`HC_Log_Agent_Action`** | Inserts **`Agent_Action_Log__c`**: `input_ActionName`, `input_Status` (`Success` / `Failed`), `input_CorrelationId`, `input_ErrorMessage`, `input_InputSummary` → `output_LogRecordId`. |
| **`HC_Resolve_Patient_By_Phone`** | `input_Phone` is **normalized** (strip spaces, dashes, parentheses) then matched to **`PersonMobilePhone`**. Outputs `output_PatientAccountId`, `output_Status` (`UNIQUE_MATCH` / `NO_MATCH`). Duplicate phones: first row wins. |
| **`HC_Get_Facilities`** | `input_CityKeyword` blank → facilities sorted by **Name**; else **`Name` CONTAINS** keyword. Output `output_FacilitySummary`. No row cap in this Flow version—keep seed data small. |

**Planned — guest registration (**Person Account** only, no Lead):**

| API name | Purpose |
|----------|---------|
| **`HC_Create_Guest_Person_Account`** | Minimal inputs (`patient_full_name`, **`PersonMobilePhone`**, **`PersonEmail`**). Normalizes phone (same stripping as **`HC_Resolve_Patient_By_Phone`**). Lookups existing **`Person Account`** by **`PersonMobilePhone`**; **`MATCHED_EXISTING`** returns Id; else loads **`RecordType`** (`Account`, **`IsPersonType`** = true), creates **`Person Account`** with **`RecordTypeId`**, **`CREATED_NEW`** + Id; **`FAILED`** + **`output_ErrorMessage`** on fault or missing Person RT. |

When implementing **`Org-Build-Checklist`** row **12a**, extend **`Hackathon_Agent_Runtime_Access`** (or the integration profile) so the Einstein Agent user can **create**/`insert` patient **`Person Account`** rows used by this Flow.

---

## Apex (invocable)

| API name | Method | Purpose |
|----------|--------|---------|
| **`HC_DirectoryInvocable`** | `findSpecialists` | `cityKeyword`, `specialtyName`, `topN` (≤25) → `summaryText`, `success`. |
| **`HC_BookingActionsInvocable`** | `run` | **`operation`**: `BOOK` \| `MODIFY` \| `CANCEL`. Creates/updates **`ServiceAppointment`** + **`ClinicalEncounter`** (+ optional **`ClinicalEncounterProvider`**). **BOOK** uses **`ContactId`** = patient’s **`PersonContactId`** (not `AccountId`—not writeable in target org). Logs via **`HCAuditHelper`**. |
| **`HC_PatientDataActionsInvocable`** | `run` | **`operation`**: `INSURANCE` \| `PREREQUISITES` \| `ROOM_RATES` \| `SPECIALTIES` \| `BOOKING_SESSION`. Plain-text summaries or upsert **`Booking_Session__c`** (upsert when `contextToken` set; else insert). |
| **`HC_ReminderInvocable`** | `createReminderTask` | Creates a **`Task`** on the patient account from **`ServiceAppointment.ContactId`** (Person Contact). |
| **`HCAuditHelper`** | `log` (static, not invocable) | Used by booking Apex; you can still call **`HC_Log_Agent_Action`** flow from the agent separately. |

**Planned (Apr 2026 — see `docs/Data-Model-Objects-And-Fields.md` § *Hackathon: slot finding & booking* + changelog):**

| API name | Method | Purpose |
|----------|--------|---------|
| **`HC_SymptomRoutingInvocable`** | TBD | Read **`Symptom_Specialty_Map__c`** from patient text → specialty + safe copy → pair with **`HC_DirectoryInvocable`**. |
| **`HC_SlotSuggestionInvocable`** | TBD | **`OperatingHours`**/**`TimeSlot`** minus booked visits → **`slotsJson`** + **`summaryText`** for agent/LWC → then **`HC_BookingActionsInvocable`** **`BOOK`**. |

### `HC_BookingActionsInvocable.run` — inputs by operation

**BOOK:** `operation=BOOK`, `patientAccountId`, `healthcareFacilityId`, `schedStartOrNewStart`, `schedEndOrNewEnd`, optional `healthcareProviderId`, `parentRecordId`, `workTypeId`, `subject`, `serviceAppointmentStatus` (default `Scheduled`), `clinicalEncounterStatus` (default `Scheduled`), `correlationId`.

**MODIFY:** `operation=MODIFY`, `serviceAppointmentId`, `patientAccountId`, `schedStartOrNewStart`, `schedEndOrNewEnd`, `correlationId`. Verifies SA **`ContactId`** matches patient’s **`PersonContactId`**.

**CANCEL:** `operation=CANCEL`, `serviceAppointmentId`, `patientAccountId`, optional `cancellationReason`, `correlationId`. Sets SA status to **`Canceled`** (and CE to canceled—adjust API values in class constants if your org differs).

Default picklist values are in **`HC_BookingActionsInvocable`** constants; align with **`BOOKING_PATTERN.md` §7**.

### `HC_PatientDataActionsInvocable.run` — inputs by operation

| operation | Required inputs |
|-----------|-----------------|
| `INSURANCE` | `patientAccountId` |
| `PREREQUISITES` | `serviceAppointmentId` |
| `ROOM_RATES` | `healthcareFacilityId`; optional `roomTypeApi` (`General`, `ICU`, `Private`, `Semi_Private`) |
| `SPECIALTIES` | none |
| `BOOKING_SESSION` | `patientAccountId`; optional `preferredFacilityId`, `lastServiceAppointmentId`, `lastClinicalEncounterId`, `contextToken` |

---

## Permission sets

| API name | Use |
|----------|-----|
| **`Hackathon_Agent_Runtime_Access`** | Einstein Agent user: **flows** above + **Apex** `HCAuditHelper`, `HC_DirectoryInvocable`, `HC_BookingActionsInvocable`, `HC_PatientDataActionsInvocable`, `HC_ReminderInvocable`; **OLS** for Account, Contact, CareSpecialty, Healthcare network objects, **`Agent_Action_Log__c`**, **`ServiceAppointment`**, **`ClinicalEncounter`**, **`ClinicalEncounterProvider`**, **`Patient_Insurance__c`**, **`Counselling_Prerequisite__c`**, **`Facility_Room_Rate__c`**, **`Booking_Session__c`**, **`Task`**. |
| **`Hackathon_Data_Model_Access`** | Broader hackathon CRUD. Assign **with** agent runtime set for full demos. |

---

## Agentforce — registering actions (best practice)

Salesforce recommends **narrow, intention-revealing actions** and **rich `description` text** on `@InvocableMethod` / `@InvocableVariable` so the reasoning engine can choose the right tool (see [Agentforce actions — get started](https://developer.salesforce.com/docs/einstein/genai/guide/get-started-actions.html)). This repo encodes those descriptions on the Apex classes above.

**Register in Agent Builder (typical path)**

1. Deploy updated Apex so labels/descriptions appear on invocable actions.
2. In **Agentforce / Agent Builder**, add **actions** for each runtime entry point:

| Kind | Developer name | Role |
|------|------------------|------|
| Flow | `HC_Log_Agent_Action` | Audit row (`Agent_Action_Log__c`). |
| Flow | `HC_Resolve_Patient_By_Phone` | Guest/mobile verification → Person Account or NO_MATCH. |
| Flow | `HC_Create_Guest_Person_Account` *(planned)* | **New** guest: create **`Person Account`** only (dedupe by mobile); returns **`patientAccountId`**. |
| Flow | `HC_Get_Facilities` | Facility list / city filter text. |
| Apex | `HC_DirectoryInvocable` — **HC Find Specialist** | Doctor + facility discovery. |
| Apex | `HC_BookingActionsInvocable` — **HC Booking Actions** | `operation`: BOOK \| MODIFY \| CANCEL. |
| Apex | `HC_PatientDataActionsInvocable` — **HC Patient Data Actions** | `operation`: INSURANCE \| PREREQUISITES \| ROOM_RATES \| SPECIALTIES \| BOOKING_SESSION. |
| Apex | `HC_ReminderInvocable` — **HC Create Visit Reminder Task** | Task reminder MVP. |

3. Attach actions to **topics** with short instructions (verification rules, when to call BOOK vs directory, etc.); map intents to `docs/Patient-Agent-Conversation-Scripts.md`.
4. Call **`HC_Log_Agent_Action`** after important tool outcomes if you want consistent judge-visible logging (or rely on `HCAuditHelper` inside Apex where already implemented).

**Metadata API note (`GenAiFunction`)**

Some orgs expose **`GenAiFunction`** for source-tracked action wrappers; others do not (Setup will still list Flow/Apex actions). If your org supports it, create **one** action in the UI, then run `sf project retrieve start -m GenAiFunction` and align folder names with the retrieved shape—Salesforce has adjusted on-disk layout over time. Do not hand-author XML unless it matches a retrieve from **your** target org.

---

## Still optional / follow-up

| Item | Notes |
|------|--------|
| **Record-triggered** reminder 24h before `SchedStartTime` | Use Flow Builder scheduled path on **`ServiceAppointment`** calling **`HC_ReminderInvocable`** or send email when org-wide email exists. |
| **Email template** + org-wide address | For email-based reminders (backlog Epic 4). |
| **Tune SA/CE status API values** | Per org (`BOOKING_PATTERN.md` §7). |

---

## Related docs

- `docs/BOOKING_PATTERN.md`
- `docs/Org-Build-Checklist.md`
- `docs/Dev-QA-Backlog.md`
- `docs/Agentforce-Subagents-Design.md` — subagents (topics), actions, and paste-ready instructions vs `Patient-Agent-Conversation-Scripts.md`
