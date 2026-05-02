# Dev & QA backlog (simple)

**Org checked:** Salesforce CLI default alias `afhack2026` (EPIC OrgFarm), **2026-04-11**  
**Repo:** `AFHackathon2026` (`force-app/main/default`)

---

## Snapshot — what exists vs what to build

**Refresh Apr 2026:** Align with **`docs/Data-Model-Objects-And-Fields.md`** (changelog). Repo now includes **`GenAiPlannerBundle`** / **`GenAiPlugin`** / **`GenAiFunction`**, **`Network`**, **`EmbeddedServiceConfig`**, HC flows + booking Apex — see **`docs/Org-Build-Checklist.md`**.

| Area | In project (metadata) | In org (data / runtime) | You create |
|------|------------------------|-------------------------|------------|
| **Objects** `HealthcareFacility`, `HealthcareProvider`, `HealthcarePractitionerFacility`, `HealthcareProviderSpecialty` | Yes — under `objects/` | Seed as needed | **Seed data** + optional loader script |
| **Standard scheduling** `OperatingHours`, `TimeSlot` | Object metadata available | Hours + slots rows for demo | Seed **Approach A** calendars (see data dictionary) |
| **Objects** `ClinicalEncounter`, `ClinicalEncounterProvider` | Yes | Created by **`HC_BookingActionsInvocable`** when booking | Regression tests |
| **Object** `ServiceAppointment` | In repo | Same | Same |
| **Object** `CareProgram` | Not fully modeled in `objects/` folder | Optional | Optional demo programs + enrollees |
| **Flows** | HC flows + unrelated sample flows (`SDO_*`, etc.) | Deploy + verify | Keep HC_*; ignore samples for hackathon |
| **Agentforce / GenAi** | **`Onco_Global_Patient_Agent`** planner bundle, plugins, functions | Agent runtime user + permission sets | Topics + wire **new** actions when Apex lands (**§2.6**, **§2.7**) |
| **Knowledge** | `Knowledge__kav` in repo | **Published** articles still needed | Articles matching seed names |
| **Experience Cloud** | `networks/`, experience bundles | Published site (team org) | Guest profile + Omni queue QA |
| **Booking doc** | `docs/BOOKING_PATTERN.md` | — | Keep §7 in sync |
| **Action logging** | `Agent_Action_Log__c` + **`HC_Log_Agent_Action`** | — | Extend logging for new tools |
| **Smart Navigator + slots** | **`Symptom_Specialty_Map__c`** in `force-app/` (object + tab + PS); Apex **planned** | Seed map rows + **OperatingHours**/**TimeSlot** + link **`OPD_Operating_Hours__c`** | **`HC_SymptomRoutingInvocable`**, **`HC_SlotSuggestionInvocable`** (**§2.6**, **§2.7**) |

**Suggested new flow API names** (autolaunched, invocable where needed):

| Flow API name | Purpose |
|---------------|---------|
| `HC_Get_Facilities` | Return facility list (SOQL) |
| `HC_Get_Specialties` | Return specialty list |
| `HC_Find_Specialist` | City + specialty (+ optional department) → top N text |
| `HC_Book_Appointment` | SA + encounter + encounter provider |
| `HC_Modify_Appointment` | Reschedule |
| `HC_Cancel_Appointment` | Cancel |
| `HC_Reminder_Before_Visit` | Scheduled path / time-based reminder (MVP email) |

---

## Epic 1 — Data & booking rules

### 1.1 Seed hospitals & providers

**Dev**

- Add **seed data**: ≥10 `HealthcareFacility`, ≥25 `HealthcareProvider`, links in `HealthcarePractitionerFacility`, specialties in `HealthcareProviderSpecialty`, practitioner `Contact` as required by your org.
- Add **loader**: e.g. `scripts/apex/seed_Healthcare_Network.apex` or CSV + import order doc.
- Use **External Id** (or stable Name) so re-run does not duplicate.

**QA**

- Run loader; check counts with SOQL (same objects as above).
- **TC1.1a** After seed: facility count ≥10, provider count ≥25, at least one provider on 2+ facilities.
- **TC1.1b** Search-style SOQL for one city + specialty returns ≥1 row.

---

### 1.2 Single booking pattern (document)

**Dev**

- Write **`docs/BOOKING_PATTERN.md`**: Book = `ServiceAppointment` → `ClinicalEncounter` (Patient, FacilityId, StartDate, EndDate, Status) → `ClinicalEncounterProvider` (PractitionerId = doctor). Cancel = status rules + optional SA cancel. **(Doc added in repo — keep §7 org values in sync.)**
- Add a small **field table** (which SA fields map to encounter).

**QA**

- **TC1.2a** Doc is linked from README or team wiki.
- **TC1.2b** Implementer can follow doc without asking slack (peer check).

---

## Epic 2 — Agent & flows

### 2.1 Specialties & locations (no phone call)

**Dev**

- Agent **topics** + instructions (names in Setup — not in repo yet).
- **Knowledge** articles aligned with seeded facility/specialty names.
- Optional: flows **`HC_Get_Facilities`**, **`HC_Get_Specialties`**.

**QA**

- **TC2.1a** Ask agent for locations → matches seeded cities/facilities.
- **TC2.1b** Ask for specialties → matches seeded data.
- **TC2.1c** No other patients’ PII in answers.

---

### 2.2 Specialist by city + specialty

**Dev**

- Build **`HC_Find_Specialist`**: inputs e.g. `city`, `specialtyName` or Id, `topN` (default 5); query `HealthcarePractitionerFacility` + provider + facility + specialty; output one **plain-text** summary for the agent.
- Register as **agent action** if using Agentforce actions.

**QA**

- **TC2.2a** Known seeded pair returns ≤N rows with readable lines.
- **TC2.2b** Nonsense city → friendly “no results”, no error.

---

### 2.3 Browse by department (e.g. gynecology)

**Dev**

- Extend **`HC_Find_Specialist`** with input `departmentOrSpecialtyFilter` **or** second entry on same flow (document which).
- Seed **department** values if you use a picklist; else filter via `HealthcareProviderSpecialty` / `SpecialtyId` relation.

**QA**

- **TC2.3a** Filter by department returns only matching providers.
- **TC2.3b** City + department still works.

---

### 2.4 Book / modify / cancel (no agent)

**Dev**

- **`HC_Book_Appointment`**, **`HC_Modify_Appointment`**, **`HC_Cancel_Appointment`** following `BOOKING_PATTERN.md`.
- Inputs: patient Id **or** verified phone, facility, optional doctor, slot (start/end).
- Validation subflow or same flow: patient exists, slot in future, doctor at facility (if provided).

**QA**

- **TC2.4a** Book → 1 SA + 1 encounter + 1 encounter provider (when doctor set).
- **TC2.4b** Bad phone / past slot → clear fault message, no half-created records (per your doc).
- **TC2.4c** Modify updates times; Cancel sets statuses per doc.

---

### 2.5 Judge sees actions

**Dev**

- **`Agent_Action_Log__c`** (or platform event): ActionName, CorrelationId, Status, ErrorMessage, CreatedDate; optional JSON input summary.
- Subflow called from agent-exposed flows to insert log.
- One-page **demo script** with before/after record Ids.

**QA**

- **TC2.5a** Successful action creates log row.
- **TC2.5b** Failed validation creates log row with error.
- **TC2.5c** Demo script matches org records.

---

### 2.6 Smart Navigator (symptom → specialty) — **in scope Apr 2026**

**Dev**

- Custom object **`Symptom_Specialty_Map__c`** + seed rows (see `docs/Data-Model-Objects-And-Fields.md`).
- New Apex **`HC_SymptomRoutingInvocable`**: input patient text → match active map rows → output **`recommendedSpecialtyName`**, **`routingSummary`**, **`disclaimer`** → then call existing **`HC_DirectoryInvocable.findSpecialists`** with city + specialty (agent composes city from conversation).
- **Agent topic** instructions: never diagnose; emergency keywords → escalation (see scripts).

**QA**

- **TC2.6a** Sample phrase (“lump in neck”, “tired”) returns **Medical Oncology** (or seeded mapping), then directory returns ≥1 provider when city seeded.
- **TC2.6b** Gibberish / no match → safe fallback, no fabricated doctors.

---

### 2.7 Slot suggestions + optional LWC — **in scope Apr 2026**

**Dev**

- **`OperatingHours`** + **`TimeSlot`** (and optional custom **`OPD_Operating_Hours__c`** on **`HealthcareFacility`**) for clinic windows.
- New Apex **`HC_SlotSuggestionInvocable`**: **Approach A** — subtract booked **`ServiceAppointment`** / **`ClinicalEncounter`** from generated windows; output **`summaryText`** + **`slotsJson`** for agent / LWC.
- **Basic UX:** numbered slot list in chat; **advanced:** Experience **LWC** reads same JSON (side-by-side or parent page — see data dictionary).
- Wire agent: after user picks slot → **`HC_BookingActionsInvocable`** **`BOOK`** with chosen start/end.

**QA**

- **TC2.7a** For a date with no bookings, returns ≥1 proposed slot inside **`TimeSlot`** hours.
- **TC2.7b** After booking a slot, re-query same day → that window excluded or daily cap enforced.
- **TC2.7c** Past times never offered.

---

## Epic 3 — Web

### 3.1 Browser + agent

**Dev**

- Create **Experience Cloud** site (Network) — name e.g. `Patient Help` (final name in Setup).
- Add **Einstein Agent** component **or** **Messaging for Web** on a page.
- Fix **package manifest** for `ExperienceBundle` / `DigitalExperienceBundle`; document retrieve/deploy command in README.
- Guest profile: access to agent + invocable flows used on web.

**QA**

- **TC3.1a** Site URL loads.
- **TC3.1b** Chat opens; one question gets a valid reply.
- **TC3.1c** Deploy from repo works with documented steps.

---

## Epic 4 — Reminders

### 4.1 Before visit

**Dev**

- **Scheduled path** on `ServiceAppointment` or `ClinicalEncounter` → run **`HC_Reminder_Before_Visit`** (or inline send email).
- **Email template**: time, facility name, patient-safe text.
- Seed one appointment **inside demo window** for judges.

**QA**

- **TC4.1a** Path runs for test record (debug or short timer in sandbox).
- **TC4.1b** Email received with correct time/facility.

---

## Epic 5 — Stretch

### 5.1 WhatsApp

**Dev**

- Connect **WhatsApp** channel; bind to same invocable flows as 2.2–2.4.

**QA**

- **TC5.1a** Same happy path as TC2.2a + TC2.4a on WhatsApp.

### 5.2 Data Cloud

**Dev**

- Ingest SA/encounters; segment **high reschedule**; optional flag for “confirm harder” in agent.

**QA**

- **TC5.2a** Segment count matches rule; **TC5.2b** test member gets stricter copy (if built).

---

## Quick dev order

1. `BOOKING_PATTERN.md` + seed + loader (**directory + Person Accounts**)  
2. **`Symptom_Specialty_Map__c`** + **`HC_SymptomRoutingInvocable`** + agent topic (**§2.6**)  
3. **`OperatingHours`** / **`TimeSlot`** + **`HC_SlotSuggestionInvocable`** + BOOK handoff (**§2.7**)  
4. `HC_Find_Specialist` / **`HC_DirectoryInvocable`** → extend department if time  
5. Book / modify / cancel (**already** `HC_BookingActionsInvocable`) — regression  
6. Agent + Knowledge + actions (+ **new** invocable wrappers in Builder)  
7. `Agent_Action_Log__c` + demo script  
8. Experience site + embed + optional **LWC** slot UI  
9. Reminder path  
10. Stretch (WhatsApp, Data Cloud)

---

## Apr 2026 sprint (freeze **29 Apr**, submit **3 May**)

| Window | Focus |
| ------ | ----- |
| **24–26 Apr** | **`Symptom_Specialty_Map__c`** seed + **`HC_SymptomRoutingInvocable`**; **`OperatingHours`**/**`TimeSlot`** + **`HC_SlotSuggestionInvocable`** MVP |
| **27–28 Apr** | Agent topics/actions for new invocables; optional **LWC** if time; end-to-end script |
| **29 Apr** | Feature freeze + regression |
| **30 Apr – 2 May** | Polish, demo recording, submission pack only |

---

## How to re-check the org later

```text
sf data query -o afhack2026 -q "SELECT COUNT(Id) cnt FROM HealthcareFacility"
sf data query -o afhack2026 -q "SELECT COUNT(Id) cnt FROM HealthcareProvider"
sf org list metadata -o afhack2026 -m Flow --json
```

Use a different alias if your team’s shared org is not `afhack2026`.
