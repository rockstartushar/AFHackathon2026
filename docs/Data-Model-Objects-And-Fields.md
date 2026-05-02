# Data dictionary — objects & fields in use (Hackathon scope)

This dictionary lists standard and custom elements the hackathon uses. **Slot finding + booking** use a **small, explicit** model (see **§ Hackathon: slot finding & booking — canonical data model** below). Other topics (symptom map, insurance, prerequisites, files, Knowledge, reminders, audit) are **separate** features—objects in those areas are **not** part of the slot algorithm.

**Sprint freeze target (2026):** feature-complete build **29 Apr**; submission **3 May** — see `docs/Org-Build-Checklist.md`.

**On every object below**, Salesforce also provides system fields where applicable: `Id`, `OwnerId`, `CreatedDate`, `CreatedById`, `LastModifiedDate`, `LastModifiedById`. They are omitted from tables to reduce noise.

---

> **Changelog — 24 Apr 2026 (read this first)**  
> - Added **`Example (demo)`** column on key tables for seed/test data alignment.  
> - Documented **standard vs custom** rule of thumb and **official Salesforce references** for scheduling objects.  
> - Locked implementation plan: **Smart Navigator** = **`Symptom_Specialty_Map__c`** + planned **`HC_SymptomRoutingInvocable`** → existing **`HC_DirectoryInvocable`**; **slot suggestions** = **Approach A** (`OperatingHours`/`TimeSlot` + conflict subtract) + planned **`HC_SlotSuggestionInvocable`** → existing **`HC_BookingActionsInvocable` BOOK**; **LWC** = JSON from slot invocable (basic cards if advanced UI slips).  
> - Related updates: `docs/Org-Build-Checklist.md`, `docs/Dev-QA-Backlog.md`, `docs/HC-Automations.md`, `docs/Patient-Agent-Conversation-Scripts.md`, `docs/Agentforce-Subagents-Design.md` (cross-refs only).
> - **25 Apr 2026:** **`Symptom_Specialty_Map__c`** metadata (fields, layout, list view, tab) is **in `force-app/` and deployed**; **`HealthcareFacility.OPD_Operating_Hours__c`** added; **`OperatingHours`** / **`TimeSlot`** OLS + **`standard-OperatingHours`** tab on hackathon permission sets (**no** standalone **`standard-TimeSlot`** tab in this org — use Operating Hours → Time Slots). Apex **`HC_SymptomRoutingInvocable`** / **`HC_SlotSuggestionInvocable`** still **planned**.
> - **Slot model clarity:** Single **Approach A** (hours − conflicts + cap); removed FSL/territory/resource slot path from hackathon narrative. See **§ Hackathon: slot finding & booking — canonical data model**.

### Where to find **new / expanded** material (24 Apr 2026)

Skim these first if you only care about **Smart Navigator** + **slots**:

| Topic | Location in this doc |
| ----- | ---------------------- |
| **Strategy** | § **Data strategy — standard first, then custom** (table above ↑) |
| **Official docs links** | § **Official references** |
| **`OperatingHours` / `TimeSlot`** | § **OperatingHours**, § **TimeSlot**, § **HealthcareFacility** optional lookups |
| **`Symptom_Specialty_Map__c`** | § **`Symptom_Specialty_Map__c`** + metadata note |
| **Slot algorithm (Approach A only)** | **§ Hackathon: slot finding & booking** + **§ Slot suggestion algorithm** |
| **LWC JSON contract** | Same section — **`slotsJson`** payload |

Across most tables, the **`Example (demo)`** column was added or extended on **24 Apr** — use it for seed data alignment.

### Data strategy — standard first, then custom

| Layer | Use | Why |
| ----- | --- | --- |
| **Standard Health Cloud — scheduling (hackathon)** | **`OperatingHours`**, **`TimeSlot`**, **`ServiceAppointment`**, **`ClinicalEncounter`**, **`ClinicalEncounterProvider`**, **`HealthcareFacility`**, **`HealthcareProvider`**, **`HealthcarePractitionerFacility`**, **`HealthcareProviderSpecialty`** (+ specialty catalog per org) | Slot **Approach A** + **`HC_BookingActionsInvocable`**; see **§ Hackathon: slot finding & booking** above. |
| **Custom extensions on standard** | `HealthcareFacility.Max_Daily_Appointments__c`, **`HealthcareFacility.OPD_Operating_Hours__c`** (lookup `OperatingHours`) | Small surface area; hackathon permission sets grant **`OperatingHours`**/**`TimeSlot`** access. |
| **Custom objects** | `Patient_Insurance__c`, `Facility_Room_Rate__c`, `Counselling_Prerequisite__c`, `Booking_Session__c`, `Agent_Action_Log__c`, **`Symptom_Specialty_Map__c`** | No standard object covers payer snapshots, room-rate rows, counselling checklist, opaque rebook token, audit log, or **demo symptom→specialty routing**. |

**Org verification:** Use **Setup → Object Manager** or `sf sobject describe -s ObjectName` against your trial org. Health Cloud and Scheduler/FSL objects appear only when those features are enabled and licensed. *(Validated in project default org Apr 2026: **`OperatingHours`** and **`TimeSlot`** describe successfully via CLI.)*

---

## Hackathon: slot finding & booking — canonical data model

**What we must deliver:** Suggest **free** visit windows at a **facility** (optional **named doctor**), then **book** the patient’s choice with **`HC_BookingActionsInvocable`** `BOOK` (same start/end on **`ServiceAppointment`** + **`ClinicalEncounter`**).

| Phase | Objects / fields | Role |
| ----- | ------------------ | ---- |
| **Daily cap (already in Apex)** | `HealthcareFacility.Max_Daily_Appointments__c`; **`ClinicalEncounter`** (`FacilityId`, `StartDate`, `Status`) | Same-day **non-cancelled** encounter count per facility; **`HC_BookingActionsInvocable`** blocks **BOOK** when cap reached. |
| **Open hours (Approach A — only approach in scope)** | **`OperatingHours`**, **`TimeSlot`**; **`HealthcareFacility.OPD_Operating_Hours__c`** → calendar; optional **`HealthcarePractitionerFacility.OperatingHoursId`** (standard) for doctor-specific hours at a site | **`HC_SlotSuggestionInvocable`** *(planned)* reads weekly windows, splits into segments (e.g. 30 min), **subtracts overlaps** using existing **`ServiceAppointment`** / **`ClinicalEncounter`** rows for that **facility** (and **provider** when the invocable filters by doctor). |
| **Persist visit** | **`ServiceAppointment`** (`SchedStartTime`, `SchedEndTime`, `ContactId`, `ParentRecordId`, `Status`, `Subject`, optional `WorkTypeId`); **`ClinicalEncounter`** (`PatientId`, `FacilityId`, `StartDate`, `EndDate`, `ServiceAppointmentId`, `Status`); optional **`ClinicalEncounterProvider`** | **`HC_BookingActionsInvocable`** `BOOK` / `MODIFY` / `CANCEL` — contract in **`docs/BOOKING_PATTERN.md`**. |

**Directory (before slots, not in slot math):** **`HealthcareFacility`**, **`HealthcareProvider`**, **`HealthcarePractitionerFacility`**, **`HealthcareProviderSpecialty`**, and your org’s **specialty catalog** row (e.g. **`CareSpecialty`**) — used by **`HC_DirectoryInvocable`** so the patient picks site/doctor; **no** territory/resource graph.

**Explicitly out of hackathon scope — do not implement for slot discovery:** Field Service **`AppointmentBookingService.getSlots`**, **`FSL__Scheduling_Policy__c`**, scheduling graphs built on **`ServiceTerritory`**, **`ServiceTerritoryMember`**, or **`ServiceResource`**, or requiring **`ServiceTerritoryId`** / territory membership to propose slots. Those APIs/objects may exist in the org but are **not** part of this project’s design before **3 May**.

**Automation chain (target):** **`HC_SlotSuggestionInvocable`** *(planned)* → numbered options or **`slotsJson`** → existing **`HC_BookingActionsInvocable`** `BOOK`. No separate “slot hold” object.

### Official references (verify field names in your API version)

| Topic | Salesforce documentation |
| ----- | ------------------------ |
| **TimeSlot** object | [Object Reference — TimeSlot](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_timeslot.htm) |
| **OperatingHours** | [Object Reference — OperatingHours](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_operatinghours.htm) |
| **ServiceAppointment** | [Object Reference — ServiceAppointment](https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_serviceappointment.htm) |
| **Salesforce Scheduler / slots** (if you adopt native slot APIs later) | [Salesforce Scheduler Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.salesforce_scheduler_developer_guide.meta/salesforce_scheduler_developer_guide/) |
| **Health Cloud data model** | [Health Cloud Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.health_cloud_dev_guide.meta/health_cloud_dev_guide/) |

---

## Standard objects

### Account (patient — Person Account model)

Used to identify the patient for encounters, appointments, insurance rows, and file uploads.

**Guest capture (hackathon):** New patients who chat as guests are recorded as **`Person Account`** rows only. **Lead is not used** for this path. Planned automation: Flow **`HC_Create_Guest_Person_Account`** (see **`docs/HC-Automations.md`**) after **`HC_Resolve_Patient_By_Phone`** rules for deduplication.

| Field API name                       | Type (concept)     | Description                                                                 | Example (demo) |
| ------------------------------------ | ------------------ | --------------------------------------------------------------------------- | ---------------- |
| `Name`                               | Text               | Patient or account display name.                                            | `Priya Sharma` |
| `PersonContactId`                    | Lookup (Contact)   | Underlying contact when using Person Accounts; links person data.           | *(system Id)* |
| `PersonMobilePhone`                  | Phone              | Mobile for OTP-style verification, SMS, or matching returning patients.     | `9876543210` |
| `PersonEmail`                        | Email              | Email for confirmations and reminders.                                      | `priya.demo@example.com` |
| `Phone`                              | Phone              | Alternate phone if you do not use mobile field.                             | — |
| `ShippingAddress` / `BillingAddress` | Address (compound) | Optional: city/postal for coarse matching; avoid over-collecting for HIPAA. | City `Jaipur` |
| `IsPersonAccount`                    | Checkbox           | Indicates this account is a person (patient) vs business.                   | `true` |


---

### Contact (practitioner / person)

Used as the practitioner person behind `HealthcareProvider` and `ClinicalEncounterProvider`.


| Field API name | Type (concept)   | Description                                                               | Example (demo) |
| -------------- | ---------------- | ------------------------------------------------------------------------- | -------------- |
| `Name`         | Text             | Practitioner full name (display).                                         | `Dr. Sneha Nair` |
| `Phone`        | Phone            | Contact phone for directory or admin use (not for bulk patient exposure). | `+91-11-55501234` |
| `Email`        | Email            | Professional email when needed for notifications.                         | `sneha.nair@oncoglobal.demo` |
| `AccountId`    | Lookup (Account) | Optional employer or practice account link.                               | — |


---

### Location

Geographic anchor for facilities (latitude/longitude for “nearest hospital” on the Experience site).


| Field API name     | Type (concept)   | Description                                                   | Example (demo) |
| ------------------ | ---------------- | ------------------------------------------------------------- | -------------- |
| `Name`             | Text             | Location label (e.g. site name).                              | `Onco Global Jaipur — Malviya Nagar` |
| `Latitude`         | Number           | North/south coordinate for distance math.                     | `26.85` |
| `Longitude`        | Number           | East/west coordinate for distance math.                       | `75.80` |
| `VisitorAddressId` | Lookup (Address) | Structured address tied to the location (street, city, etc.). | Jaipur, India |


---

### HealthcareFacility

Hospital or clinic site in the network; ties to **Location** for maps and “near me.”


| Field API name               | Type (concept)    | Description                                                        | Example (demo) |
| ---------------------------- | ----------------- | ------------------------------------------------------------------ | -------------- |
| `Name`                       | Text              | Facility name shown to patients and agents.                        | `Onco Global Mumbai` |
| `LocationId`                 | Lookup (Location) | Links to **Location** for lat/long and address.                    | *(seed Location Id)* |
| `AccountId`                  | Lookup (Account)  | Optional organizational account for the facility.                  | Facility business Account |
| `LicensedBedCount`           | Number            | Optional: supports capacity / “rooms” storytelling where relevant. | `120` |
| `ParentHealthcareFacilityId` | Lookup (self)     | Optional: campus or health system hierarchy.                       | — |
| `FacilityTypeId`             | Lookup            | Optional: type of facility (clinic, hospital, etc.).               | Hospital |


---

### HealthcareProvider

Provider profile (doctor) in Health Cloud.


| Field API name   | Type (concept)   | Description                                  | Example (demo) |
| ---------------- | ---------------- | -------------------------------------------- | -------------- |
| `Name`           | Text             | Provider record name / label.                | `Dr. Sneha Nair` |
| `PractitionerId` | Lookup (Contact) | Person (Contact) who is this provider.       | *(Contact Id)* |
| `IsActive`       | Checkbox         | When false, exclude from search and booking. | `true` |
| `AccountId`      | Lookup (Account) | Optional practice or employer account.       | — |


---

### HealthcarePractitionerFacility

Joins a provider to a facility (who sees patients where).


| Field API name         | Type (concept)              | Description                                        | Example (demo) |
| ---------------------- | --------------------------- | -------------------------------------------------- | -------------- |
| `Name`                 | Text                        | Record title (often auto or composite).            | `Sneha Nair @ Jaipur` |
| `HealthcareProviderId` | Lookup (HealthcareProvider) | The provider.                                      | *(Provider Id)* |
| `HealthcareFacilityId` | Lookup (HealthcareFacility) | The facility where they practice.                  | Onco Global Jaipur |
| `IsActive`             | Checkbox                    | If false, do not offer this provider at this site. | `true` |


---

### HealthcareProviderSpecialty

Links a provider to a specialty from the catalog (search by specialty/department).


| Field API name       | Type (concept)     | Description                                              | Example (demo) |
| -------------------- | ------------------ | -------------------------------------------------------- | -------------- |
| `Name`               | Text               | Record label.                                            | `Med Onc — Sneha Nair` |
| `PractitionerId`     | Lookup             | Practitioner associated with this specialty row.         | *(Practitioner Id)* |
| `SpecialtyId`        | Lookup             | Care specialty catalog in your org (e.g. **`CareSpecialty`**). | Medical Oncology row Id |
| `IsPrimarySpecialty` | Checkbox           | Optional: prefer this row when listing “main” specialty. | `true` |
| `IsActive`           | Checkbox           | Exclude from search when false.                          | `true` |


---

### Specialty / care specialty catalog (directory only)

Specialty rows used with **`HealthcareProviderSpecialty`** so **`HC_DirectoryInvocable`** can match **`specialtyName`**. **Not** part of slot overlap math. API name varies by org (**`CareSpecialty`** is common; some orgs expose a related **`Specialty`** type—confirm with **`sf sobject describe`**).


| Field API name | Type (concept) | Description                                       | Example (demo) |
| -------------- | -------------- | ------------------------------------------------- | -------------- |
| `Name`         | Text           | Specialty name shown in search and agent answers. | `Medical Oncology` |

---

### OperatingHours

Defines **weekly hour patterns** used by Field Service, Scheduler, and related products. Contains child **`TimeSlot`** rows (per day of week + start/end **Time**).


| Field API name | Type (concept) | Description                                      | Example (demo) |
| -------------- | -------------- | ------------------------------------------------ | -------------- |
| `Name`         | Text           | Label (e.g. “Jaipur OPD — Dr Smith”).            | `Jaipur OPD — Weekdays` |
| `TimeZone`     | Picklist/Text  | IANA timezone for interpreting slots.            | `Asia/Kolkata` |

**Use in this project:** Define **weekly open windows** for **`HC_SlotSuggestionInvocable`** (read **`TimeSlot`**, subtract booked **`ClinicalEncounter`** / **`ServiceAppointment`** overlaps). **Not** used: FSL slot grading, territories, or **`AppointmentBookingService`** (see **§ Hackathon: slot finding & booking**).

---

### TimeSlot

Child of **`OperatingHours`**: one row per **DayOfWeek** + **StartTime** + **EndTime** (wall-clock window).


| Field API name     | Type     | Description                          | Example (demo) |
| ------------------ | -------- | ------------------------------------ | -------------- |
| `OperatingHoursId` | Lookup   | Parent calendar.                     | Jaipur OPD hours Id |
| `DayOfWeek`        | Picklist | Monday … Sunday.                     | `Monday` |
| `StartTime`        | Time     | Window open.                         | `09:00` |
| `EndTime`          | Time     | Window close.                        | `17:00` |

---

### ServiceAppointment

Scheduled appointment row; **hackathon booking** sets **`SchedStartTime`**, **`SchedEndTime`**, **`ContactId`** (patient **`PersonContactId`**), **`ParentRecordId`** (Person Account in repo Apex), **`Status`**, **`Subject`**, optional **`WorkTypeId`** — see **`HC_BookingActionsInvocable`** and **`docs/BOOKING_PATTERN.md`**. Use **`Sched*`** + **`Status`** for overlap checks with proposed slots. Other `ServiceAppointment` fields exist in the platform (territory, attendees, actuals) but are **not** part of our slot/booking design.


| Field API name       | Type (concept)     | Description                                                                    | Example (demo) |
| -------------------- | ------------------ | ------------------------------------------------------------------------------ | -------------- |
| `ParentRecordId`     | Polymorphic lookup | Repo pattern: Person Account Id (see booking Apex / org validation rules).   | Person Account Id |
| `AccountId`          | Lookup (Account)   | Patient account when populated.                                                | *(often blank if using `ContactId` only)* |
| `ContactId`          | Lookup (Contact)   | Patient contact on the appointment.                                            | Patient’s `PersonContactId` |
| `SchedStartTime`     | Date/Time          | Planned start (slot + modify).                                                 | `2026-05-02T10:00:00+05:30` |
| `SchedEndTime`       | Date/Time          | Planned end.                                                                   | `2026-05-02T10:30:00+05:30` |
| `Status`             | Picklist           | Lifecycle (scheduled, canceled, …).                                              | `Scheduled` |
| `StatusCategory`     | Picklist           | Optional; set if your org requires it on **BOOK**.                             | *(org-specific)* |
| `Phone`              | Phone              | Optional on SA.                                                                | `9876543210` |
| `Subject`            | Text               | Short description of the appointment.                                          | `Outpatient consult — Medical Oncology` |
| `CancellationReason` | Picklist           | Used on **CANCEL** when picklist required.                                       | — |
| `WorkTypeId`         | Lookup (`WorkType`) | **Optional** on **BOOK** — omit unless org ties length to work type.           | — |


---

### ClinicalEncounter

Clinical visit tied to patient and facility; canonical visit record next to **ServiceAppointment**.


| Field API name         | Type (concept)              | Description                                               | Example (demo) |
| ---------------------- | --------------------------- | --------------------------------------------------------- | -------------- |
| `PatientId`            | Lookup (Account)            | Patient receiving care (confirm target type in your org). | Priya Sharma Person Account |
| `FacilityId`           | Lookup (HealthcareFacility) | Where the encounter occurs.                               | Onco Global Jaipur |
| `StartDate`            | Date/Time                   | Encounter start.                                          | Same as SA start |
| `EndDate`              | Date/Time                   | Encounter end.                                            | Same as SA end |
| `Status`               | Picklist                    | Visit state (in progress, finished, canceled, etc.).      | `Scheduled` |
| `ServiceAppointmentId` | Lookup (ServiceAppointment) | Links visit to the scheduled appointment.                 | *(SA Id)* |


---

### ClinicalEncounterProvider

Attending provider on a specific encounter.


| Field API name        | Type (concept)             | Description                               |
| --------------------- | -------------------------- | ----------------------------------------- |
| `ClinicalEncounterId` | Lookup (ClinicalEncounter) | Parent encounter.                         |
| `PractitionerId`      | Lookup                     | Practitioner for this encounter row.      |
| `StartDate`           | Date/Time                  | Provider segment start (optional detail). |
| `EndDate`             | Date/Time                  | Provider segment end (optional detail).   |


---

### ContentDocument (file header)

One row per uploaded file; latest version is on **ContentVersion**.


| Field API name | Type (concept) | Description             |
| -------------- | -------------- | ----------------------- |
| `Title`        | Text           | File title shown in UI. |


---

### ContentVersion (file body + metadata)

Used for **patient uploads** (reports, ID, forms) when linked to Account.


| Field API name           | Type (concept) | Description                                                        |
| ------------------------ | -------------- | ------------------------------------------------------------------ |
| `Title`                  | Text           | Version title.                                                     |
| `PathOnClient`           | Text           | Original filename from upload.                                     |
| `FileExtension`          | Text           | File type (pdf, jpg, etc.).                                        |
| `FirstPublishLocationId` | Reference      | Where the file was first attached (e.g. patient Account Id).       |
| `VersionData`            | Blob (binary)  | Actual file content (not shown in UI lists; stored by Salesforce). |


---

### Knowledge__kav (Knowledge Article Version)

Published articles for agent and site (FAQs, prep docs, insurance basics).


| Field API name | Type (concept)        | Description                                   |
| -------------- | --------------------- | --------------------------------------------- |
| `Title`        | Text                  | Article headline.                             |
| `UrlName`      | Text                  | URL segment for the article.                  |
| `Summary`      | Text                  | Short blurb for search and previews.          |
| `ArticleBody`  | Rich text / long text | Main content (exact API depends on template). |


---

### CareProgram & CareProgramEnrollee (optional demo only)


| Object                | Description                                    |
| --------------------- | ---------------------------------------------- |
| `CareProgram`         | Program definition (e.g. oncology navigation). |
| `CareProgramEnrollee` | Links a patient to a program.                  |


Only add fields you actually display or automate; otherwise use program name + enrollee status minimally.

---

### Messaging / Voice (only if you turn them on)


| Object             | Description                                                          |
| ------------------ | -------------------------------------------------------------------- |
| `MessagingSession` | Web/WhatsApp conversation session tied to channels you enable.       |
| `VoiceCall`        | Voice call record if Service Cloud Voice is implemented (*advanced). |


---

## Custom fields on standard objects


| Object               | Field API name                  | Type                   | Description                                                                                             | Example (demo) |
| -------------------- | ------------------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------- | -------------- |
| `HealthcareFacility` | `Max_Daily_Appointments__c`    | Number                 | Daily cap: same-day **non-cancelled** **`ClinicalEncounter`** count at facility (**`HC_BookingActionsInvocable`**). | `40` |
| `HealthcareFacility` | `OPD_Operating_Hours__c`       | Lookup (OperatingHours) | Default OPD calendar for **Approach A** slot windows (**`HC_SlotSuggestionInvocable`**). | `Jaipur OPD — Weekdays` hours Id |

> **Per-provider hours:** use standard **`HealthcarePractitionerFacility.OperatingHoursId`** only (no extra custom lookup in this repo).

---

## Custom objects (full field set)

### Patient_Insurance__c

Separate insurance / eligibility view for the patient (your “valid list” story).


| Field API name          | Type             | Description                                                                       | Example (demo) |
| ----------------------- | ---------------- | --------------------------------------------------------------------------------- | -------------- |
| `Patient__c`            | Lookup (Account) | Patient who owns this coverage row.                                               | Priya Sharma |
| `Payer_Name__c`         | Text             | Insurance company or payer name.                                                  | `Star Health` |
| `Member_Id__c`          | Text             | Member or subscriber id (encrypt in production if required by policy).            | `SH-99281` |
| `Plan_Name__c`          | Text             | Commercial or plan label shown to the patient.                                    | `Gold Plus` |
| `Eligibility_Status__c` | Picklist         | Active, Pending, Not covered, Unknown — high-level status for UI.                 | `Active` |
| `Valid_From__c`         | Date             | Coverage start for this snapshot.                                                 | `2025-01-01` |
| `Valid_To__c`           | Date             | Coverage end for this snapshot.                                                   | `2026-12-31` |
| `Last_Verified_Date__c` | Date             | When eligibility was last checked.                                                | `2026-04-01` |
| `Is_Primary__c`         | Checkbox         | Marks the patient’s primary plan when multiple rows exist.                        | `true` |
| `Notes__c`              | Long Text Area   | Short internal or patient-facing note; avoid storing sensitive PHI unnecessarily. | Room rent sub-limit for demo |


---

### Counselling_Prerequisite__c

Optional checklist: what documents or steps are expected **before** counselling.


| Field API name           | Type                        | Description                                                                                      | Example (demo) |
| ------------------------ | --------------------------- | ------------------------------------------------------------------------------------------------ | -------------- |
| `Related_Appointment__c` | Lookup (ServiceAppointment) | Appointment this prerequisite belongs to (or switch to ClinicalEncounter if you model that way). | *(SA Id)* |
| `Document_Type__c`       | Picklist                    | ID, Insurance card, Consent, Lab report, Other.                                                  | `Lab report` |
| `Is_Required__c`         | Checkbox                    | If true, show as mandatory before counselling.                                                   | `true` |
| `Is_Satisfied__c`        | Checkbox                    | True when uploaded or verified.                                                                  | `false` → `true` after upload |
| `Linked_File_Id__c`      | Text(18)                    | Optional: **ContentDocument** Id of the uploaded proof (or use Files only without this field).   | `069xx...` |
| `Due_Before__c`          | Date/Time                   | Optional deadline before the session.                                                            | `2026-05-01T09:00:00Z` |


---

### Facility_Room_Rate__c

Room-type pricing for “cost of rooms” conversations.


| Field API name           | Type                        | Description                                         | Example (demo) |
| ------------------------ | --------------------------- | --------------------------------------------------- | -------------- |
| `Healthcare_Facility__c` | Lookup (HealthcareFacility) | Site this rate applies to.                          | Onco Global Mumbai |
| `Room_Type__c`           | Picklist                    | General, ICU, Private, Semi-private, etc.           | `Private` |
| `Daily_Rate__c`          | Currency                    | Typical daily charge for demos (not a legal quote). | `15000` INR |
| `Effective_From__c`      | Date                        | Rate valid from.                                    | `2026-01-01` |
| `Effective_To__c`        | Date                        | Rate valid until (blank = open-ended).              | — |


---

### Booking_Session__c

Lightweight helper so returning patients **rebook** without retyping everything (store links, not clinical narrative).


| Field API name                | Type                        | Description                                                                          | Example (demo) |
| ----------------------------- | --------------------------- | ------------------------------------------------------------------------------------ | -------------- |
| `Patient__c`                  | Lookup (Account)            | Returning patient.                                                                   | Priya Sharma |
| `Last_Service_Appointment__c` | Lookup (ServiceAppointment) | Most recent appointment for prefill.                                                 | *(last SA Id)* |
| `Last_Clinical_Encounter__c`  | Lookup (ClinicalEncounter)  | Optional parallel link to last visit.                                                | — |
| `Preferred_Facility__c`       | Lookup (HealthcareFacility) | Default facility for next booking.                                                   | Jaipur |
| `Context_Token__c`            | Text                        | Opaque token for anonymous web resume flows; **do not** put diagnoses or notes here. | `sess_a1b2c3` |


---

### Symptom_Specialty_Map__c

**Purpose:** Drive the **Smart Navigator** demo — map **free-text symptom phrases** (entered by the patient) to a **recommended specialty label** and **safe patient-facing copy**. This is **navigation / education only**, not diagnosis or triage.

**Important:** `HC_DirectoryInvocable` today filters by **city + specialty text** only; it does **not** read this object. Implementation is a **new** invocable (planned: **`HC_SymptomRoutingInvocable`**) that queries this table, then calls existing **`findSpecialists`** with the derived **`specialtyName`** (and optional city from conversation).


| Field API name              | Type             | Description                                                                 | Example (demo) |
| --------------------------- | ---------------- | --------------------------------------------------------------------------- | -------------- |
| `Name`                      | Text             | Admin label (e.g. “Neck lump + fatigue → Med Onc”).                         | `Neck lump + fatigue → Med Onc` |
| `Keyword_Pattern__c`       | Text             | Token or short phrase to match against user text (case-insensitive contains). | `lump`, `neck`, `fatigue` (separate rows or one combined row per team convention) |
| `Match_Priority__c`        | Number           | Higher wins when multiple rows match (tie-break).                           | `10` |
| `Recommended_Specialty__c`  | Text             | Must align with the **specialty name** your directory SOQL matches (e.g. related **`Specialty.Name`** on `HealthcareProviderSpecialty` where that object exists, or equivalent in your org — e.g. **`CareSpecialty`** catalog). | `Medical Oncology` |
| `Routing_Summary__c`       | Long Text Area   | One or two sentences the agent may say before directory lookup (non-clinical). | `Many people discuss ongoing symptoms like these with our medical oncology team; this is not a diagnosis.` |
| `Disclaimer__c`            | Long Text Area   | e.g. “This is not medical advice; emergency symptoms require local emergency services.” | `Not medical advice. For emergencies, call local emergency services.` |
| `Active__c`                | Checkbox         | Exclude from matching when false.                                           | `true` |

**Metadata status:** **`Symptom_Specialty_Map__c`** is **in the repo** (object, fields, layout, list view, tab) and was deployed to the hackathon org; **seed rows** are still **data** work (see **Seed** below).

**Seed:** Cover 8–12 rows for demo (lump/neck, fatigue, breast, cough, GI, etc.). Keep language conservative.

---

### Agent_Action_Log__c

Proves the agent ran actions for judges and support.


| Field API name                   | Type                        | Description                                             | Example (demo) |
| -------------------------------- | --------------------------- | ------------------------------------------------------- | -------------- |
| `Action_Name__c`                 | Text                        | Which flow or action ran (e.g. HC_Find_Specialist).     | `HC_SlotSuggestion` |
| `Status__c`                      | Picklist                    | Success, Failed.                                        | `Success` |
| `Correlation_Id__c`              | Text                        | Ties multiple log rows to one conversation or session.  | `conv_7f3a` |
| `Error_Message__c`               | Long Text Area              | Safe error summary for failures (no full PHI payloads). | — |
| `Input_Summary__c`               | Long Text Area              | Redacted or high-level inputs for audit demo.           | `facility=Jaipur; date=2026-05-02` |
| `Related_Service_Appointment__c` | Lookup (ServiceAppointment) | Optional link to affected appointment.                  | — |
| `Related_Clinical_Encounter__c`  | Lookup (ClinicalEncounter)  | Optional link to affected encounter.                    | — |


---

## Slot suggestion algorithm (Approach A — sole in-scope method)

**Today:** **`HC_BookingActionsInvocable`** **does not** compute free time; it **BOOK**s whatever **start/end** the caller passes (after cap check).

**Add:** **`HC_SlotSuggestionInvocable`** *(planned)* — same **data model** as **§ Hackathon: slot finding & booking**:

1. Resolve **open hours** from **`HealthcareFacility.OPD_Operating_Hours__c`** and child **`TimeSlot`** rows (or from **`HealthcarePractitionerFacility.OperatingHoursId`** when scoping to a doctor).
2. For the **target date**, build fixed-length segments (e.g. 30 minutes) inside those windows (timezone from **`OperatingHours.TimeZone`**).
3. **Subtract conflicts:** overlapping **`ClinicalEncounter`** (same **`FacilityId`**, not cancelled) and/or **`ServiceAppointment`** rows as needed for your overlap rule; when a **provider** is chosen, filter encounters that include that practitioner on **`ClinicalEncounterProvider`**.
4. Respect **`Max_Daily_Appointments__c`** when **suggesting** (do not list options that would exceed cap if one more **BOOK** would fail).
5. **Outputs:** **`summaryText`** (numbered lines for chat) and **`slotsJson`** (optional **LWC** on Experience — see below).

**Out of scope:** Field Service **`AppointmentBookingService`**, **`FSL__Scheduling_Policy__c`**, territory/resource slot engines — see **§ Hackathon: slot finding & booking** exclusions.

---

### LWC slot picker — data contract

- **Minimum:** Agent displays **three lines** from **`summaryText`** / JSON; patient replies “option 1”.
- **LWC:** Pass **structured JSON** from **`HC_SlotSuggestionInvocable`** (planned) — exact wiring depends on site; Messaging inside chat may **not** host arbitrary LWC inside the transcript: often **side-by-side** Experience page hosts the slot cards **or** use **quick replies** only.

**Example `slotsJson` payload (illustrative):**

```json
{
  "facilityId": "0XXXX…",
  "providerId": "0XXXX…",
  "date": "2026-05-02",
  "slotMinutes": 30,
  "slots": [
    { "start": "2026-05-02T10:00:00.000+0530", "end": "2026-05-02T10:30:00.000+0530", "label": "10:00 AM – 10:30 AM" },
    { "start": "2026-05-02T11:45:00.000+0530", "end": "2026-05-02T12:15:00.000+0530", "label": "11:45 AM – 12:15 PM" },
    { "start": "2026-05-02T16:00:00.000+0530", "end": "2026-05-02T16:30:00.000+0530", "label": "4:00 PM – 4:30 PM" }
  ]
}
```

The **BOOK** step still uses **`HC_BookingActionsInvocable`** with the **chosen** `start`/`end` datetimes.

---

## What is intentionally excluded

- **Slot / scheduling:** FSL **`AppointmentBookingService`**, **`SchedulingPolicy`**, **`ServiceTerritory`**, **`ServiceTerritoryMember`**, **`ServiceResource`**-based slot graphs (see **§ Hackathon: slot finding & booking**).
- **General:** Opportunity, unrelated custom objects, exhaustive clinical-detail fields on **`ClinicalEncounter`**, full catalog schemas for every standard object.

Add rows here only when you deliberately expand scope.

---

## Org verification checklist (objects this hackathon relies on)

Use **Setup → Object Manager** or **`sf sobject describe`**:

| Objects | Typical add-on |
| ------- | ---------------- |
| `HealthcareFacility`, `HealthcareProvider`, `HealthcarePractitionerFacility`, `HealthcareProviderSpecialty`, `ClinicalEncounter`, `ClinicalEncounterProvider`, `ServiceAppointment` | **Health Cloud** |
| `OperatingHours`, `TimeSlot` | Core / Scheduler (for **Approach A** hours) |
| Specialty catalog type behind `HealthcareProviderSpecialty` (e.g. `CareSpecialty`) | Health Cloud (org-specific API name) |

---

## Related docs

- `docs/BOOKING_PATTERN.md` — how `ServiceAppointment`, `ClinicalEncounter`, and `ClinicalEncounterProvider` are created and updated together for booking flows; **§ Slot discovery → BOOK** when implemented.
- `docs/Dev-QA-Backlog.md` — symptom + slot epics and test ideas.
- `docs/Org-Build-Checklist.md` — deploy order and freeze dates.
- `docs/images/Data-Model-ER.png` — ER-style diagram (objects, key fields, relationships) derived from this dictionary.

