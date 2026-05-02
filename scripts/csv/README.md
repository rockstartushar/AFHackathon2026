# CSV extracts for hackathon seed data

These files mirror values in `force-app/main/default/classes/SeedHackathonData.cls`.

## CareSpecialty (`CareSpecialty.csv`)

- **4 rows** — insert only names that do not already exist (avoid duplicates).
- **Fields:** `Name` only (standard object).
- Use **Data Loader** or **Insert** from a spreadsheet; assign the running user profile/permission set that can create `CareSpecialty` if insert fails.

## Symptom specialty map (`Symptom_Specialty_Map__c.csv`)

- **12 rows** — no lookups; safe to import after custom object is deployed.
- **`Recommended_Specialty__c`** must match **`CareSpecialty.Name`** text exactly (same four names as above).

## Everything else (locations, Person Accounts, facilities, hours, slots, providers, insurance, …)

Relationships depend on **Salesforce-generated Ids**. The repo’s **`SeedHackathonData`** Apex class loads the full graph in the correct order; use:

```apex
SeedHackathonData seed = new SeedHackathonData();
seed.seedAll();
```

instead of hand-building CSVs for those objects unless you add External IDs and a multi-step mapping process.

## Person Accounts — additional rows (`PersonAccount_additional_same_locations.csv`)

- **18 new Person Account rows** covering the same metro layout as your org: **Gurgaon, Delhi, Jaipur, Mumbai, Noida, Bengaluru, Chennai, Hyderabad, Kolkata** (aligned with `Onco Global * Pvt Ltd` facility cities).
- **`PersonMobilePhone`** values are in the **9876510011–9876510028** range so they do **not** clash with your existing demo phones (e.g. Rajesh `9876543210`, Sunita `9812345678`, Mohit `9898989898`, Kavita `9765432109`, Ayaan `9123456780`).
- **`RecordTypeId`** is set to **`012ak00000AebxeAAB`** from your export (Person Account). **Verify** in **Setup → Object Manager → Account → Record Types** before import; replace the column if your Person Account record type Id differs in another org.
- **Import:** Use Data Loader **Insert** (leave **`Id`** out). Standard Salesforce **Upsert** needs an **External ID** field on Account; this file does not include one. To upsert later, add a custom Text field (unique, external ID) and populate stable keys, then re-export.

### Account rows you may delete (optional cleanup)

| Keep / review | Why |
| --- | --- |
| **Delete if unused** | **Global Media**, **Acme**, **salesforce.com** — typical Salesforce sample B2B accounts, not part of Health Cloud hackathon flows. |
| **Delete if unused** | **Sample Account for Entitlements** — only if you are not testing entitlements. |
| **Optional** | Three duplicate **Hackathon Network / Hackathon Facility Org / Patil** triads (timestamps 1776404791291, 1776404868175, 1776404894595) — leftover automation triplets; safe to remove if you standardize on **Onco Global Healthcare Pvt Ltd**, the **Onco Global (city) Pvt Ltd** facility rows, and CSV/seed patients. |
| **Merge or pick one** | **Onco Global Gurgaon Pvt Ltd** vs **Onco Global Gurgaon Care Center** — both NCR; keep a single canonical facility org if `HealthcareFacility.AccountId` or reporting should not double-count. |
| **Keep** | **Onco Global Healthcare Pvt Ltd**, your **Onco Global (city) Pvt Ltd** facility accounts, and named demo patients (**Rajesh Kumar**, **Sunita Devi**, **Mohit Arora**, **Kavita Sharma**, **Ayaan Khan**) unless you replace them with this CSV set. |

Always check **related records** (files, encounters, flows) before deleting accounts.

## Facility Accounts — extra sites per city (`FacilityAccount_additional_same_city_sites.csv`)

- **16 rows** — same **Hospital / facility** record type (`012ak00000AvEuvAAF`), **Type** = `Hospital`, **two extra neighborhoods per metro** for: Gurgaon, Delhi, Jaipur, Mumbai, Bengaluru, Chennai, Hyderabad, Kolkata (distinct **BillingStreet** / PIN within each city).
- **`ParentId`** = **`001ak0000284x48AAA`** (**Onco Global Healthcare Pvt Ltd**). Clear **ParentId** if your org does not use account hierarchy or validation rejects it.
- **Phones** use …91 / …92 suffixes so they differ from your original single-site facility lines (01244567890, etc.).
- After insert, create matching **`HealthcareFacility`** rows (and **`Location`** if you use lat/long) per **`docs/Data-Seeding-Plan.md`** — facility **Accounts** alone do not drive **`HC_Get_Facilities`** until linked to **HealthcareFacility`.

## `Location` — extra sites + fix missing coordinates

**Do you need more or updates?** For **directory / “near me” / distance** behavior, each **physical site** should have a **`Location`** with **latitude** and **longitude**. You already have **one `Location` per main metro** (Gurgaon … Kolkata). If you add **multiple facility Accounts per city**, add **one `Location` row per site** with coordinates for that neighborhood.

| File | Purpose |
| --- | --- |
| **`Location_INSERT_neighborhood_sites.csv`** | **Insert** 16 rows — matches the extra facility Accounts in `FacilityAccount_additional_same_city_sites.csv` (neighborhood-level lat/long, `LocationType` = `Warehouse` to match your existing Onco `Location` rows, `TimeZone` = `Asia/Kolkata`). |
| **`Location_UPDATE_fix_existing.csv`** | **Update** by **Id** — sets **latitude/longitude** on **Onco Global Jaipur Care Center Location** (`131ak000000hXS9AAM`), which was missing coordinates. |

**Not a generic upsert:** Standard **`Location`** has no built-in **External ID** for Data Loader **Upsert**. Use **Insert** for the new file and **Update** for the fix file. If you add a custom **Text(80) External Id, Unique** (e.g. `Hackathon_Location_Key__c`) on `Location`, you can switch to a single upsert file later.

**If insert/update fails on `TimeZone`:** Your org’s `Location` object may not expose it; remove the **`TimeZone`** column and retry.

**“Read-only” fields:** The **compound** `Location` (geolocation) field in the UI is often **read-only** when `Latitude` / `Longitude` are set by the platform. **Data Loader** should still accept **`Latitude`** and **`Longitude`** on insert/update for `Location` if your profile has **FLS** edit. If the API blocks them, check **Field-Level Security** and **Validation Rules**.

**Optional cleanup (not required for go-live):** You can delete or repurpose **Location1**, **Test Location**, and the three **Hackathon Site …** `Location` rows if nothing references them (query `HealthcareFacility` and `Account` / `ServiceAppointment` pickers first).

## `HealthcareFacility` — neighborhood sites (`HealthcareFacility_INSERT_neighborhood_sites.csv`)

**Insert** 16 rows: each **`AccountId`** is one of your imported facility Accounts (**`001ak00002SinwjAAB` … `001ak00002SinwyAAB`**); each **`LocationId`** matches the neighborhood **`Location`** Ids **`131ak000000k5JFAAY`** through **`131ak000000k5JUAAY`**. **`OPD_Operating_Hours__c`** stays empty until you load **`OperatingHours`** / **`TimeSlot`** and **update** facilities (see `SeedHackathonData.updateFacilityOperatingHours()`).

If **`LicensedBedCount`** or **`Max_Daily_Appointments__c`** fail validation, drop those columns or lower the numbers.

**Next seeding steps after this insert:** **`OperatingHours`** → **`TimeSlot`** → **`HealthcareFacility` UPDATE** (set **`OPD_Operating_Hours__c`**) → **`HealthcarePractitionerFacility`** (needs **`HealthcareProviderId`** + **`HealthcareFacilityId`**) → optional **`Facility_Room_Rate__c`** with **`Healthcare_Facility__c`**.

## `OperatingHours` — India metros (`OperatingHours_INSERT_india_metros.csv`)

- **Insert** **8** calendars (**`Name`** + **`TimeZone`** = **`Asia/Kolkata`**), one per metro used in your hackathon (Gurgaon … Kolkata).
- You currently have only **`Test`** (`America/Los_Angeles`). **You do not have to delete it** before importing; slot logic should use an **`Asia/Kolkata`** calendar. You may delete **`Test`** later if unused.
- After insert, **export** **`Id`**, **`Name`** from **`OperatingHours`**, then build **`TimeSlot`** rows with the correct **`OperatingHoursId`** (Data Loader cannot resolve by name). Repo reference: `SeedHackathonData.seedTimeSlots()` for window patterns (Mumbai split sessions vs single window, etc.).
- **Link facilities:** Update **`HealthcareFacility.OPD_Operating_Hours__c`** to the **`OperatingHours`** Id for that metro (main + neighborhood sites in the same city usually share one **`OperatingHours`** row).

## `TimeSlot` — weekly windows (`TimeSlot_INSERT_india_pattern.csv`)

**Insert** **53** rows keyed to **your** `OperatingHours` Ids (`Gurgaon`=`0OHak000003ygVhGAI` … `Kolkata`=`0OHak000003ygVoGAI`). Matches **`SeedHackathonData.seedTimeSlots()`**:

| Metro | Pattern |
| --- | --- |
| **Mumbai** | Mon–Fri two bands (09:00–13:00, 14:00–18:00); Sat 09:00–13:00 |
| **Bengaluru** | Mon–Fri 09:00–18:00; Sat 09:00–13:00 |
| **Gurgaon, Delhi, Jaipur, Hyderabad, Chennai, Kolkata** | Mon–Fri 09:00–17:00; Sat 09:00–13:00 |

**Columns:** `OperatingHoursId`, `DayOfWeek`, `StartTime`, `EndTime`, `Type`=`Normal`. Times are **wall-clock** strings (`HH:MM:SS`) for use with **`OperatingHours.TimeZone` = `Asia/Kolkata`**.

If Data Loader rejects **`Type`** or time format, remove **`Type`** or adjust to your org’s picklist/API expectations.

The lone **`TimeSlot`** on **`Test`** (`0OHak000003ygSTGAY`) is unrelated to these calendars; delete it if you retire the **`Test`** `OperatingHours` record.

## `Contact` — practitioners vs patients (`Contact_UPDATE_link_practitioners_to_HQ.csv`)

| Action | Records | Why |
| --- | --- | --- |
| **Keep (no change)** | All **`IsPersonAccount = true`** `Contact` rows (Rajesh Kumar, seed patients, etc.) | These are **patient** person-contacts. Do **not** use them as **`HealthcareProvider.PractitionerId`**. |
| **Update** | **8** business contacts with **no** `AccountId`: Arjun Mehta, Neha Sharma, Rahul Verma, Priya Kapoor, Karan Sethi, Rakesh Iyer, Sneha Nair, Vivek Rao (`003ak00001FtTTFAA3` … `003ak00001FtTTMAA3`) | Set **`AccountId`** = **`001ak0000284x48AAA`** (**Onco Global Healthcare Pvt Ltd**) so they are network-employed clinicians before **`HealthcareProvider`** / directory seeding. Use **`Contact_UPDATE_link_practitioners_to_HQ.csv`** (Data Loader **Update**). |
| **Optional delete** | **3** test contacts: Ananya Kapoor … (`003ak00001FsEHrAAN`, `003ak00001FsgHGAAZ`, `003ak00001FsgfSAAR`) | Hackathon automation leftovers; remove **only if** nothing references them. Query dependents first: `SELECT Id FROM HealthcareProvider WHERE PractitionerId IN (...)`, etc. |
| **Create (optional)** | New **`Contact`** rows | Only if you need **more** doctors than the **8** above to cover **facilities / specialties**; same pattern: **`IsPersonAccount = false`**, **`AccountId`** = HQ, then **`HealthcareProvider`** + **`HealthcarePractitionerFacility`**. |

**Next after update:** Insert **`HealthcareProvider`** (one per practitioner `Contact`), then **`HealthcarePractitionerFacility`** + **`HealthcareProviderSpecialty`** (needs **`CareSpecialty`** Ids).

## `HealthcareProvider` — link HQ + trim tests (`HealthcareProvider_UPDATE_link_HQ.csv`)

| Situation | Action |
| --- | --- |
| **Keep — already correct** | **8** providers (**Dr. Arjun Mehta** … **Dr. Vivek Rao**, Ids **`0cmak000003E5PVAA0`** … **`0cmak000003E5PcAAK`**) with **`PractitionerId`** = your HQ **`Contact`** rows — **do not recreate**; **`PractitionerId`** must stay as-is. |
| **Update** | Set **`AccountId`** = **`001ak0000284x48AAA`** (**Onco Global Healthcare Pvt Ltd**) and confirm **`IsActive`** = **true** — **`HealthcareProvider_UPDATE_link_HQ.csv`** (Data Loader **Update**). Skip if **`AccountId`** is already HQ or your org leaves it blank. |
| **Optional delete** | **`Test Provider`** (`0cmak000003E1DpAAK`); **3× `Dr Ananya Kapoor …`** (`0cmak000003E2zVAAS`, `0cmak000003E35xAAC`, `0cmak000003E37ZAAS`) — automation leftovers with **no** real **`PractitionerId`** linkage. Delete only after checking **`HealthcarePractitionerFacility`**, **`HealthcareProviderSpecialty`**, **`ClinicalEncounterProvider`**. |
| **Create** | Only if you need **more than 8** doctors; each needs a **`Contact`** first, then **`HealthcareProvider`**. |

**Next:** **`HealthcarePractitionerFacility`** (provider ↔ **`HealthcareFacility`**) and **`HealthcareProviderSpecialty`** (**`CareSpecialty`** Ids).
