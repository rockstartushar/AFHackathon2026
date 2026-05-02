# Onco Global — Health Cloud Hackathon Data Seeding Plan

**Purpose:** Complete, consistent data plan with exact API field names, realistic Indian demo values, and creation order for loading via Data Import Wizard, Data Loader, anonymous Apex, or manual entry.

**Target org:** Onco Global (India-focused Health Cloud demo)  
**Date:** 29 Apr 2026  
**Timezone:** Asia/Kolkata (UTC+5.5)

---

## Dependency-Ordered Insertion Checklist

Insert in this exact order to satisfy foreign key constraints:

1. ✅ **Location** (5–6 cities)
2. ✅ **Account** (15+ Person Accounts — patients; unique `PersonMobilePhone`)
3. ✅ **Contact** (12–18 practitioners)
4. ✅ **HealthcareProvider** (one per practitioner)
5. ✅ **HealthcareFacility** (5–6 facilities, one per Location)
6. ✅ **OperatingHours** (5–6 calendars, one default OPD per major facility)
7. ✅ **TimeSlot** (weekday windows per OperatingHours)
8. ✅ **Link HealthcareFacility.OPD_Operating_Hours__c** → OperatingHours Ids (update facilities)
9. ✅ **HealthcarePractitionerFacility** (every provider linked to 1–2 facilities)
10. ✅ **HealthcareProviderSpecialty** (link providers to existing CareSpecialty catalog rows)
11. ✅ **Symptom_Specialty_Map__c** (10–14 Active rows)
12. ✅ **Patient_Insurance__c** (2–4 rows per subset of patients)
13. ✅ **Facility_Room_Rate__c** (2–3 room types per facility)
14. ✅ **ServiceAppointment** (3–8 future appointments)
15. ✅ **ClinicalEncounter** (matching ServiceAppointment rows)
16. ✅ **ClinicalEncounterProvider** (link providers to encounters)
17. ✅ **Counselling_Prerequisite__c** (8–12 rows tied to ServiceAppointments)
18. ✅ **Booking_Session__c** (5–8 returning patient sessions)

---

## Foreign Key Placeholder Resolution Map

After inserting each object, record the Salesforce-generated Ids and substitute placeholders:

| Placeholder | Object | Example Real Id |
|-------------|--------|-----------------|
| `LOCATION_MUMBAI_ID` | Location | `131xx000000001AAA` |
| `LOCATION_DELHI_ID` | Location | `131xx000000002AAA` |
| `LOCATION_JAIPUR_ID` | Location | `131xx000000003AAA` |
| `LOCATION_BENGALURU_ID` | Location | `131xx000000004AAA` |
| `LOCATION_HYDERABAD_ID` | Location | `131xx000000005AAA` |
| `LOCATION_CHENNAI_ID` | Location | `131xx000000006AAA` |
| `PATIENT_01_ID` | Account (Person) | `001xx000000001AAA` |
| `PATIENT_01_CONTACT_ID` | Contact (from `PersonContactId`) | `003xx000000001AAA` |
| ... | ... | ... |
| `CONTACT_DR_NAIR_ID` | Contact | `003xx000000020AAA` |
| `PROVIDER_DR_NAIR_ID` | HealthcareProvider | `0pBxx000000001AAA` |
| `FACILITY_MUMBAI_ID` | HealthcareFacility | `0csxx000000001AAA` |
| `HOURS_MUMBAI_OPD_ID` | OperatingHours | `0Hnxx000000001AAA` |
| `SPECIALTY_MED_ONC_ID` | CareSpecialty | `0t5xx000000001AAA` |
| `SA_FUTURE_01_ID` | ServiceAppointment | `08pxx000000001AAA` |
| `CE_FUTURE_01_ID` | ClinicalEncounter | `0Y0xx000000001AAA` |

---

## 1. Location (5–6 cities)

**Object:** `Location`  
**Purpose:** Geographic anchor for facilities; lat/long for "near me" searches

| Name | Latitude | Longitude | VisitorAddressId | Notes |
|------|----------|-----------|------------------|-------|
| Onco Global Mumbai — Andheri West | 19.1136 | 72.8697 | (Address: Andheri West, Mumbai, Maharashtra 400053, India) | Mumbai flagship |
| Onco Global Delhi NCR — Saket | 28.5244 | 77.2066 | (Address: Saket, New Delhi, Delhi 110017, India) | Delhi NCR primary |
| Onco Global Jaipur — Malviya Nagar | 26.8500 | 75.8000 | (Address: Malviya Nagar, Jaipur, Rajasthan 302017, India) | Rajasthan hub |
| Onco Global Bengaluru — Koramangala | 12.9352 | 77.6245 | (Address: Koramangala 4th Block, Bengaluru, Karnataka 560034, India) | South India tech corridor |
| Onco Global Hyderabad — Jubilee Hills | 17.4315 | 78.4108 | (Address: Jubilee Hills, Hyderabad, Telangana 500033, India) | Telangana center |
| Onco Global Chennai — Adyar (optional) | 13.0067 | 80.2575 | (Address: Adyar, Chennai, Tamil Nadu 600020, India) | Optional 6th location |

**CSV Template (Location):**
```csv
Name,Latitude,Longitude,StreetAddress__c,City__c,State__c,PostalCode__c,Country__c
Onco Global Mumbai — Andheri West,19.1136,72.8697,Andheri West,Mumbai,Maharashtra,400053,India
Onco Global Delhi NCR — Saket,28.5244,77.2066,Saket,New Delhi,Delhi,110017,India
Onco Global Jaipur — Malviya Nagar,26.8500,75.8000,Malviya Nagar,Jaipur,Rajasthan,302017,India
Onco Global Bengaluru — Koramangala,12.9352,77.6245,Koramangala 4th Block,Bengaluru,Karnataka,560034,India
Onco Global Hyderabad — Jubilee Hills,17.4315,78.4108,Jubilee Hills,Hyderabad,Telangana,500033,India
```

---

## 2. Account (Person Account — Patients, 15 rows minimum)

**Object:** `Account` (Person Account model)  
**Critical:** `IsPersonAccount = true`, `PersonMobilePhone` UNIQUE per patient (required for HC_Resolve_Patient_By_Phone / guest flows)

| Name (FirstName LastName) | PersonMobilePhone | PersonEmail | ShippingCity | IsPersonAccount | Notes |
|---------------------------|-------------------|-------------|--------------|-----------------|-------|
| Priya Sharma | 9876543210 | priya.demo@example.com | Jaipur | TRUE | Returning patient |
| Rajesh Kumar | 9876543211 | rajesh.demo@example.com | Mumbai | TRUE | New patient |
| Anjali Verma | 9876543212 | anjali.demo@example.com | Delhi | TRUE | Has insurance |
| Vikram Singh | 9876543213 | vikram.demo@example.com | Bengaluru | TRUE | Multiple insurances |
| Meera Patel | 9876543214 | meera.demo@example.com | Hyderabad | TRUE | Active booking session |
| Arjun Reddy | 9876543215 | arjun.demo@example.com | Chennai | TRUE | Recent appointment |
| Kavita Iyer | 9876543216 | kavita.demo@example.com | Mumbai | TRUE | Counselling prereqs |
| Suresh Nair | 9876543217 | suresh.demo@example.com | Jaipur | TRUE | Guest patient |
| Lakshmi Menon | 9876543218 | lakshmi.demo@example.com | Bengaluru | TRUE | Returning with session |
| Rohit Desai | 9876543219 | rohit.demo@example.com | Delhi | TRUE | New inquiry |
| Shalini Gupta | 9876543220 | shalini.demo@example.com | Hyderabad | TRUE | Has primary insurance |
| Anil Joshi | 9876543221 | anil.demo@example.com | Mumbai | TRUE | Future appointment |
| Deepa Rao | 9876543222 | deepa.demo@example.com | Jaipur | TRUE | Guest conversion |
| Karthik Bhat | 9876543223 | karthik.demo@example.com | Bengaluru | TRUE | Multiple appointments |
| Sunita Kapoor | 9876543224 | sunita.demo@example.com | Delhi | TRUE | Insurance pending |
| Ramesh Pillai | 9876543225 | ramesh.demo@example.com | Chennai | TRUE | Optional 16th patient |

**CSV Template (Account - Person Account):**
```csv
FirstName,LastName,PersonMobilePhone,PersonEmail,ShippingCity,IsPersonAccount
Priya,Sharma,9876543210,priya.demo@example.com,Jaipur,TRUE
Rajesh,Kumar,9876543211,rajesh.demo@example.com,Mumbai,TRUE
Anjali,Verma,9876543212,anjali.demo@example.com,Delhi,TRUE
Vikram,Singh,9876543213,vikram.demo@example.com,Bengaluru,TRUE
Meera,Patel,9876543214,meera.demo@example.com,Hyderabad,TRUE
Arjun,Reddy,9876543215,arjun.demo@example.com,Chennai,TRUE
Kavita,Iyer,9876543216,kavita.demo@example.com,Mumbai,TRUE
Suresh,Nair,9876543217,suresh.demo@example.com,Jaipur,TRUE
Lakshmi,Menon,9876543218,lakshmi.demo@example.com,Bengaluru,TRUE
Rohit,Desai,9876543219,rohit.demo@example.com,Delhi,TRUE
Shalini,Gupta,9876543220,shalini.demo@example.com,Hyderabad,TRUE
Anil,Joshi,9876543221,anil.demo@example.com,Mumbai,TRUE
Deepa,Rao,9876543222,deepa.demo@example.com,Jaipur,TRUE
Karthik,Bhat,9876543223,karthik.demo@example.com,Bengaluru,TRUE
Sunita,Kapoor,9876543224,sunita.demo@example.com,Delhi,TRUE
```

**After insert:** Record `PersonContactId` for each Account (needed for ServiceAppointment.ContactId)

---

## 3. Contact (Practitioners, 12–18 rows)

**Object:** `Contact`  
**Purpose:** Practitioner person behind HealthcareProvider

| Name (FirstName LastName) | Phone | Email | Notes |
|---------------------------|-------|-------|-------|
| Dr. Sneha Nair | +91-22-55501234 | sneha.nair@oncoglobal.demo | Medical Oncology, Mumbai |
| Dr. Amit Deshmukh | +91-22-55501235 | amit.deshmukh@oncoglobal.demo | Radiation Oncology, Mumbai |
| Dr. Ravi Chandra | +91-11-55501236 | ravi.chandra@oncoglobal.demo | Surgical Oncology, Delhi |
| Dr. Priya Kapoor | +91-11-55501237 | priya.kapoor@oncoglobal.demo | Hematology, Delhi |
| Dr. Arun Mehta | +91-141-55501238 | arun.mehta@oncoglobal.demo | Medical Oncology, Jaipur |
| Dr. Sanjay Verma | +91-141-55501239 | sanjay.verma@oncoglobal.demo | Surgical Oncology, Jaipur |
| Dr. Kavita Reddy | +91-80-55501240 | kavita.reddy@oncoglobal.demo | Medical Oncology, Bengaluru |
| Dr. Suresh Kumar | +91-80-55501241 | suresh.kumar@oncoglobal.demo | Radiation Oncology, Bengaluru |
| Dr. Lakshmi Iyer | +91-40-55501242 | lakshmi.iyer@oncoglobal.demo | Hematology, Hyderabad |
| Dr. Rajesh Pillai | +91-40-55501243 | rajesh.pillai@oncoglobal.demo | Medical Oncology, Hyderabad |
| Dr. Anita Singh | +91-22-55501244 | anita.singh@oncoglobal.demo | Hematology, Mumbai |
| Dr. Vikram Joshi | +91-11-55501245 | vikram.joshi@oncoglobal.demo | Medical Oncology, Delhi |
| Dr. Meera Bhat | +91-141-55501246 | meera.bhat@oncoglobal.demo | Radiation Oncology, Jaipur |
| Dr. Deepak Rao | +91-80-55501247 | deepak.rao@oncoglobal.demo | Surgical Oncology, Bengaluru |
| Dr. Sunita Menon | +91-40-55501248 | sunita.menon@oncoglobal.demo | Surgical Oncology, Hyderabad |
| Dr. Karthik Nair (optional) | +91-44-55501249 | karthik.nair@oncoglobal.demo | Medical Oncology, Chennai |
| Dr. Ramesh Gupta (optional) | +91-44-55501250 | ramesh.gupta@oncoglobal.demo | Radiation Oncology, Chennai |
| Dr. Pooja Sharma (optional) | +91-22-55501251 | pooja.sharma@oncoglobal.demo | Surgical Oncology, Mumbai |

**CSV Template (Contact):**
```csv
FirstName,LastName,Phone,Email
Dr. Sneha,Nair,+91-22-55501234,sneha.nair@oncoglobal.demo
Dr. Amit,Deshmukh,+91-22-55501235,amit.deshmukh@oncoglobal.demo
Dr. Ravi,Chandra,+91-11-55501236,ravi.chandra@oncoglobal.demo
Dr. Priya,Kapoor,+91-11-55501237,priya.kapoor@oncoglobal.demo
Dr. Arun,Mehta,+91-141-55501238,arun.mehta@oncoglobal.demo
Dr. Sanjay,Verma,+91-141-55501239,sanjay.verma@oncoglobal.demo
Dr. Kavita,Reddy,+91-80-55501240,kavita.reddy@oncoglobal.demo
Dr. Suresh,Kumar,+91-80-55501241,suresh.kumar@oncoglobal.demo
Dr. Lakshmi,Iyer,+91-40-55501242,lakshmi.iyer@oncoglobal.demo
Dr. Rajesh,Pillai,+91-40-55501243,rajesh.pillai@oncoglobal.demo
Dr. Anita,Singh,+91-22-55501244,anita.singh@oncoglobal.demo
Dr. Vikram,Joshi,+91-11-55501245,vikram.joshi@oncoglobal.demo
Dr. Meera,Bhat,+91-141-55501246,meera.bhat@oncoglobal.demo
Dr. Deepak,Rao,+91-80-55501247,deepak.rao@oncoglobal.demo
Dr. Sunita,Menon,+91-40-55501248,sunita.menon@oncoglobal.demo
```

---

## 4. HealthcareProvider (one per practitioner)

**Object:** `HealthcareProvider`  
**Purpose:** Provider profile in Health Cloud

| Name | PractitionerId (Contact Id) | IsActive | Notes |
|------|----------------------------|----------|-------|
| Dr. Sneha Nair | CONTACT_DR_NAIR_ID | TRUE | Medical Oncology |
| Dr. Amit Deshmukh | CONTACT_DR_DESHMUKH_ID | TRUE | Radiation Oncology |
| Dr. Ravi Chandra | CONTACT_DR_CHANDRA_ID | TRUE | Surgical Oncology |
| Dr. Priya Kapoor | CONTACT_DR_KAPOOR_ID | TRUE | Hematology |
| Dr. Arun Mehta | CONTACT_DR_MEHTA_ID | TRUE | Medical Oncology |
| Dr. Sanjay Verma | CONTACT_DR_VERMA_ID | TRUE | Surgical Oncology |
| Dr. Kavita Reddy | CONTACT_DR_REDDY_ID | TRUE | Medical Oncology |
| Dr. Suresh Kumar | CONTACT_DR_KUMAR_ID | TRUE | Radiation Oncology |
| Dr. Lakshmi Iyer | CONTACT_DR_IYER_ID | TRUE | Hematology |
| Dr. Rajesh Pillai | CONTACT_DR_PILLAI_ID | TRUE | Medical Oncology |
| Dr. Anita Singh | CONTACT_DR_SINGH_ID | TRUE | Hematology |
| Dr. Vikram Joshi | CONTACT_DR_JOSHI_ID | TRUE | Medical Oncology |
| Dr. Meera Bhat | CONTACT_DR_BHAT_ID | TRUE | Radiation Oncology |
| Dr. Deepak Rao | CONTACT_DR_RAO_ID | TRUE | Surgical Oncology |
| Dr. Sunita Menon | CONTACT_DR_MENON_ID | TRUE | Surgical Oncology |

**CSV Template (HealthcareProvider):**
```csv
Name,PractitionerId,IsActive
Dr. Sneha Nair,CONTACT_DR_NAIR_ID,TRUE
Dr. Amit Deshmukh,CONTACT_DR_DESHMUKH_ID,TRUE
Dr. Ravi Chandra,CONTACT_DR_CHANDRA_ID,TRUE
Dr. Priya Kapoor,CONTACT_DR_KAPOOR_ID,TRUE
Dr. Arun Mehta,CONTACT_DR_MEHTA_ID,TRUE
Dr. Sanjay Verma,CONTACT_DR_VERMA_ID,TRUE
Dr. Kavita Reddy,CONTACT_DR_REDDY_ID,TRUE
Dr. Suresh Kumar,CONTACT_DR_KUMAR_ID,TRUE
Dr. Lakshmi Iyer,CONTACT_DR_IYER_ID,TRUE
Dr. Rajesh Pillai,CONTACT_DR_PILLAI_ID,TRUE
Dr. Anita Singh,CONTACT_DR_SINGH_ID,TRUE
Dr. Vikram Joshi,CONTACT_DR_JOSHI_ID,TRUE
Dr. Meera Bhat,CONTACT_DR_BHAT_ID,TRUE
Dr. Deepak Rao,CONTACT_DR_RAO_ID,TRUE
Dr. Sunita Menon,CONTACT_DR_MENON_ID,TRUE
```

---

## 5. HealthcareFacility (5–6 facilities, one per Location)

**Object:** `HealthcareFacility`  
**Purpose:** Hospital/clinic site; ties to Location for maps

| Name | LocationId | Max_Daily_Appointments__c | LicensedBedCount | OPD_Operating_Hours__c | Notes |
|------|-----------|---------------------------|------------------|------------------------|-------|
| Onco Global Mumbai | LOCATION_MUMBAI_ID | 50 | 150 | (link after OperatingHours insert) | Flagship |
| Onco Global Delhi NCR | LOCATION_DELHI_ID | 40 | 120 | (link after OperatingHours insert) | Primary NCR |
| Onco Global Jaipur | LOCATION_JAIPUR_ID | 30 | 80 | (link after OperatingHours insert) | Rajasthan hub |
| Onco Global Bengaluru | LOCATION_BENGALURU_ID | 45 | 130 | (link after OperatingHours insert) | Tech corridor |
| Onco Global Hyderabad | LOCATION_HYDERABAD_ID | 35 | 100 | (link after OperatingHours insert) | Telangana center |
| Onco Global Chennai (optional) | LOCATION_CHENNAI_ID | 25 | 70 | (link after OperatingHours insert) | Optional 6th |

**CSV Template (HealthcareFacility - initial insert):**
```csv
Name,LocationId,Max_Daily_Appointments__c,LicensedBedCount
Onco Global Mumbai,LOCATION_MUMBAI_ID,50,150
Onco Global Delhi NCR,LOCATION_DELHI_ID,40,120
Onco Global Jaipur,LOCATION_JAIPUR_ID,30,80
Onco Global Bengaluru,LOCATION_BENGALURU_ID,45,130
Onco Global Hyderabad,LOCATION_HYDERABAD_ID,35,100
```

**Note:** `OPD_Operating_Hours__c` will be populated in step 8 after OperatingHours are created.

---

## 6. OperatingHours (5–6 calendars, one default OPD per major facility)

**Object:** `OperatingHours`  
**Purpose:** Defines weekly hour patterns for slot suggestion

| Name | TimeZone | Notes |
|------|----------|-------|
| Mumbai OPD — Weekdays | Asia/Kolkata | Mon–Sat 09:00–18:00 |
| Delhi OPD — Weekdays | Asia/Kolkata | Mon–Sat 09:00–17:00 |
| Jaipur OPD — Weekdays | Asia/Kolkata | Mon–Sat 09:00–17:00 |
| Bengaluru OPD — Weekdays | Asia/Kolkata | Mon–Fri 09:00–18:00, Sat 09:00–13:00 |
| Hyderabad OPD — Weekdays | Asia/Kolkata | Mon–Sat 09:00–17:00 |

**CSV Template (OperatingHours):**
```csv
Name,TimeZone
Mumbai OPD — Weekdays,Asia/Kolkata
Delhi OPD — Weekdays,Asia/Kolkata
Jaipur OPD — Weekdays,Asia/Kolkata
Bengaluru OPD — Weekdays,Asia/Kolkata
Hyderabad OPD — Weekdays,Asia/Kolkata
```

---

## 7. TimeSlot (weekday windows per OperatingHours)

**Object:** `TimeSlot`  
**Purpose:** Child of OperatingHours — one row per DayOfWeek + StartTime + EndTime

### Mumbai OPD — Weekdays (HOURS_MUMBAI_OPD_ID)

| OperatingHoursId | DayOfWeek | StartTime | EndTime | Notes |
|------------------|-----------|-----------|---------|-------|
| HOURS_MUMBAI_OPD_ID | Monday | 09:00:00.000 | 13:00:00.000 | Morning session |
| HOURS_MUMBAI_OPD_ID | Monday | 14:00:00.000 | 18:00:00.000 | Afternoon session |
| HOURS_MUMBAI_OPD_ID | Tuesday | 09:00:00.000 | 13:00:00.000 | Morning session |
| HOURS_MUMBAI_OPD_ID | Tuesday | 14:00:00.000 | 18:00:00.000 | Afternoon session |
| HOURS_MUMBAI_OPD_ID | Wednesday | 09:00:00.000 | 13:00:00.000 | Morning session |
| HOURS_MUMBAI_OPD_ID | Wednesday | 14:00:00.000 | 18:00:00.000 | Afternoon session |
| HOURS_MUMBAI_OPD_ID | Thursday | 09:00:00.000 | 13:00:00.000 | Morning session |
| HOURS_MUMBAI_OPD_ID | Thursday | 14:00:00.000 | 18:00:00.000 | Afternoon session |
| HOURS_MUMBAI_OPD_ID | Friday | 09:00:00.000 | 13:00:00.000 | Morning session |
| HOURS_MUMBAI_OPD_ID | Friday | 14:00:00.000 | 18:00:00.000 | Afternoon session |
| HOURS_MUMBAI_OPD_ID | Saturday | 09:00:00.000 | 13:00:00.000 | Saturday morning only |

### Delhi OPD — Weekdays (HOURS_DELHI_OPD_ID)

| OperatingHoursId | DayOfWeek | StartTime | EndTime | Notes |
|------------------|-----------|-----------|---------|-------|
| HOURS_DELHI_OPD_ID | Monday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_DELHI_OPD_ID | Tuesday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_DELHI_OPD_ID | Wednesday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_DELHI_OPD_ID | Thursday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_DELHI_OPD_ID | Friday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_DELHI_OPD_ID | Saturday | 09:00:00.000 | 13:00:00.000 | Saturday morning only |

### Jaipur OPD — Weekdays (HOURS_JAIPUR_OPD_ID)

| OperatingHoursId | DayOfWeek | StartTime | EndTime | Notes |
|------------------|-----------|-----------|---------|-------|
| HOURS_JAIPUR_OPD_ID | Monday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_JAIPUR_OPD_ID | Tuesday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_JAIPUR_OPD_ID | Wednesday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_JAIPUR_OPD_ID | Thursday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_JAIPUR_OPD_ID | Friday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_JAIPUR_OPD_ID | Saturday | 09:00:00.000 | 13:00:00.000 | Saturday morning only |

### Bengaluru OPD — Weekdays (HOURS_BENGALURU_OPD_ID)

| OperatingHoursId | DayOfWeek | StartTime | EndTime | Notes |
|------------------|-----------|-----------|---------|-------|
| HOURS_BENGALURU_OPD_ID | Monday | 09:00:00.000 | 18:00:00.000 | Full day |
| HOURS_BENGALURU_OPD_ID | Tuesday | 09:00:00.000 | 18:00:00.000 | Full day |
| HOURS_BENGALURU_OPD_ID | Wednesday | 09:00:00.000 | 18:00:00.000 | Full day |
| HOURS_BENGALURU_OPD_ID | Thursday | 09:00:00.000 | 18:00:00.000 | Full day |
| HOURS_BENGALURU_OPD_ID | Friday | 09:00:00.000 | 18:00:00.000 | Full day |
| HOURS_BENGALURU_OPD_ID | Saturday | 09:00:00.000 | 13:00:00.000 | Saturday half day |

### Hyderabad OPD — Weekdays (HOURS_HYDERABAD_OPD_ID)

| OperatingHoursId | DayOfWeek | StartTime | EndTime | Notes |
|------------------|-----------|-----------|---------|-------|
| HOURS_HYDERABAD_OPD_ID | Monday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_HYDERABAD_OPD_ID | Tuesday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_HYDERABAD_OPD_ID | Wednesday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_HYDERABAD_OPD_ID | Thursday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_HYDERABAD_OPD_ID | Friday | 09:00:00.000 | 17:00:00.000 | Continuous |
| HOURS_HYDERABAD_OPD_ID | Saturday | 09:00:00.000 | 13:00:00.000 | Saturday morning only |

**CSV Template (TimeSlot - Combined):**
```csv
OperatingHoursId,DayOfWeek,StartTime,EndTime
HOURS_MUMBAI_OPD_ID,Monday,09:00:00.000,13:00:00.000
HOURS_MUMBAI_OPD_ID,Monday,14:00:00.000,18:00:00.000
HOURS_MUMBAI_OPD_ID,Tuesday,09:00:00.000,13:00:00.000
HOURS_MUMBAI_OPD_ID,Tuesday,14:00:00.000,18:00:00.000
HOURS_MUMBAI_OPD_ID,Wednesday,09:00:00.000,13:00:00.000
HOURS_MUMBAI_OPD_ID,Wednesday,14:00:00.000,18:00:00.000
HOURS_MUMBAI_OPD_ID,Thursday,09:00:00.000,13:00:00.000
HOURS_MUMBAI_OPD_ID,Thursday,14:00:00.000,18:00:00.000
HOURS_MUMBAI_OPD_ID,Friday,09:00:00.000,13:00:00.000
HOURS_MUMBAI_OPD_ID,Friday,14:00:00.000,18:00:00.000
HOURS_MUMBAI_OPD_ID,Saturday,09:00:00.000,13:00:00.000
HOURS_DELHI_OPD_ID,Monday,09:00:00.000,17:00:00.000
HOURS_DELHI_OPD_ID,Tuesday,09:00:00.000,17:00:00.000
HOURS_DELHI_OPD_ID,Wednesday,09:00:00.000,17:00:00.000
HOURS_DELHI_OPD_ID,Thursday,09:00:00.000,17:00:00.000
HOURS_DELHI_OPD_ID,Friday,09:00:00.000,17:00:00.000
HOURS_DELHI_OPD_ID,Saturday,09:00:00.000,13:00:00.000
HOURS_JAIPUR_OPD_ID,Monday,09:00:00.000,17:00:00.000
HOURS_JAIPUR_OPD_ID,Tuesday,09:00:00.000,17:00:00.000
HOURS_JAIPUR_OPD_ID,Wednesday,09:00:00.000,17:00:00.000
HOURS_JAIPUR_OPD_ID,Thursday,09:00:00.000,17:00:00.000
HOURS_JAIPUR_OPD_ID,Friday,09:00:00.000,17:00:00.000
HOURS_JAIPUR_OPD_ID,Saturday,09:00:00.000,13:00:00.000
HOURS_BENGALURU_OPD_ID,Monday,09:00:00.000,18:00:00.000
HOURS_BENGALURU_OPD_ID,Tuesday,09:00:00.000,18:00:00.000
HOURS_BENGALURU_OPD_ID,Wednesday,09:00:00.000,18:00:00.000
HOURS_BENGALURU_OPD_ID,Thursday,09:00:00.000,18:00:00.000
HOURS_BENGALURU_OPD_ID,Friday,09:00:00.000,18:00:00.000
HOURS_BENGALURU_OPD_ID,Saturday,09:00:00.000,13:00:00.000
HOURS_HYDERABAD_OPD_ID,Monday,09:00:00.000,17:00:00.000
HOURS_HYDERABAD_OPD_ID,Tuesday,09:00:00.000,17:00:00.000
HOURS_HYDERABAD_OPD_ID,Wednesday,09:00:00.000,17:00:00.000
HOURS_HYDERABAD_OPD_ID,Thursday,09:00:00.000,17:00:00.000
HOURS_HYDERABAD_OPD_ID,Friday,09:00:00.000,17:00:00.000
HOURS_HYDERABAD_OPD_ID,Saturday,09:00:00.000,13:00:00.000
```

**Note:** Sunday is intentionally omitted (closed) to test different operating patterns.

---

## 8. Update HealthcareFacility.OPD_Operating_Hours__c

**Object:** `HealthcareFacility` (UPDATE operation)  
**Purpose:** Link each facility to its default OPD operating hours

| Facility Id | OPD_Operating_Hours__c |
|-------------|------------------------|
| FACILITY_MUMBAI_ID | HOURS_MUMBAI_OPD_ID |
| FACILITY_DELHI_ID | HOURS_DELHI_OPD_ID |
| FACILITY_JAIPUR_ID | HOURS_JAIPUR_OPD_ID |
| FACILITY_BENGALURU_ID | HOURS_BENGALURU_OPD_ID |
| FACILITY_HYDERABAD_ID | HOURS_HYDERABAD_OPD_ID |

---

## 9. HealthcarePractitionerFacility (provider-facility linkage)

**Object:** `HealthcarePractitionerFacility`  
**Purpose:** Every provider linked to 1–2 facilities (overlap for directory)

| Name | HealthcareProviderId | HealthcareFacilityId | IsActive | Notes |
|------|---------------------|---------------------|----------|-------|
| Sneha Nair @ Mumbai | PROVIDER_DR_NAIR_ID | FACILITY_MUMBAI_ID | TRUE | Primary |
| Sneha Nair @ Jaipur | PROVIDER_DR_NAIR_ID | FACILITY_JAIPUR_ID | TRUE | Secondary |
| Amit Deshmukh @ Mumbai | PROVIDER_DR_DESHMUKH_ID | FACILITY_MUMBAI_ID | TRUE | Primary |
| Ravi Chandra @ Delhi | PROVIDER_DR_CHANDRA_ID | FACILITY_DELHI_ID | TRUE | Primary |
| Ravi Chandra @ Jaipur | PROVIDER_DR_CHANDRA_ID | FACILITY_JAIPUR_ID | TRUE | Secondary |
| Priya Kapoor @ Delhi | PROVIDER_DR_KAPOOR_ID | FACILITY_DELHI_ID | TRUE | Primary |
| Arun Mehta @ Jaipur | PROVIDER_DR_MEHTA_ID | FACILITY_JAIPUR_ID | TRUE | Primary |
| Arun Mehta @ Delhi | PROVIDER_DR_MEHTA_ID | FACILITY_DELHI_ID | TRUE | Secondary |
| Sanjay Verma @ Jaipur | PROVIDER_DR_VERMA_ID | FACILITY_JAIPUR_ID | TRUE | Primary |
| Kavita Reddy @ Bengaluru | PROVIDER_DR_REDDY_ID | FACILITY_BENGALURU_ID | TRUE | Primary |
| Kavita Reddy @ Hyderabad | PROVIDER_DR_REDDY_ID | FACILITY_HYDERABAD_ID | TRUE | Secondary |
| Suresh Kumar @ Bengaluru | PROVIDER_DR_KUMAR_ID | FACILITY_BENGALURU_ID | TRUE | Primary |
| Lakshmi Iyer @ Hyderabad | PROVIDER_DR_IYER_ID | FACILITY_HYDERABAD_ID | TRUE | Primary |
| Rajesh Pillai @ Hyderabad | PROVIDER_DR_PILLAI_ID | FACILITY_HYDERABAD_ID | TRUE | Primary |
| Rajesh Pillai @ Mumbai | PROVIDER_DR_PILLAI_ID | FACILITY_MUMBAI_ID | TRUE | Secondary |
| Anita Singh @ Mumbai | PROVIDER_DR_SINGH_ID | FACILITY_MUMBAI_ID | TRUE | Primary |
| Vikram Joshi @ Delhi | PROVIDER_DR_JOSHI_ID | FACILITY_DELHI_ID | TRUE | Primary |
| Meera Bhat @ Jaipur | PROVIDER_DR_BHAT_ID | FACILITY_JAIPUR_ID | TRUE | Primary |
| Deepak Rao @ Bengaluru | PROVIDER_DR_RAO_ID | FACILITY_BENGALURU_ID | TRUE | Primary |
| Sunita Menon @ Hyderabad | PROVIDER_DR_MENON_ID | FACILITY_HYDERABAD_ID | TRUE | Primary |

**CSV Template (HealthcarePractitionerFacility):**
```csv
Name,HealthcareProviderId,HealthcareFacilityId,IsActive
Sneha Nair @ Mumbai,PROVIDER_DR_NAIR_ID,FACILITY_MUMBAI_ID,TRUE
Sneha Nair @ Jaipur,PROVIDER_DR_NAIR_ID,FACILITY_JAIPUR_ID,TRUE
Amit Deshmukh @ Mumbai,PROVIDER_DR_DESHMUKH_ID,FACILITY_MUMBAI_ID,TRUE
Ravi Chandra @ Delhi,PROVIDER_DR_CHANDRA_ID,FACILITY_DELHI_ID,TRUE
Ravi Chandra @ Jaipur,PROVIDER_DR_CHANDRA_ID,FACILITY_JAIPUR_ID,TRUE
Priya Kapoor @ Delhi,PROVIDER_DR_KAPOOR_ID,FACILITY_DELHI_ID,TRUE
Arun Mehta @ Jaipur,PROVIDER_DR_MEHTA_ID,FACILITY_JAIPUR_ID,TRUE
Arun Mehta @ Delhi,PROVIDER_DR_MEHTA_ID,FACILITY_DELHI_ID,TRUE
Sanjay Verma @ Jaipur,PROVIDER_DR_VERMA_ID,FACILITY_JAIPUR_ID,TRUE
Kavita Reddy @ Bengaluru,PROVIDER_DR_REDDY_ID,FACILITY_BENGALURU_ID,TRUE
Kavita Reddy @ Hyderabad,PROVIDER_DR_REDDY_ID,FACILITY_HYDERABAD_ID,TRUE
Suresh Kumar @ Bengaluru,PROVIDER_DR_KUMAR_ID,FACILITY_BENGALURU_ID,TRUE
Lakshmi Iyer @ Hyderabad,PROVIDER_DR_IYER_ID,FACILITY_HYDERABAD_ID,TRUE
Rajesh Pillai @ Hyderabad,PROVIDER_DR_PILLAI_ID,FACILITY_HYDERABAD_ID,TRUE
Rajesh Pillai @ Mumbai,PROVIDER_DR_PILLAI_ID,FACILITY_MUMBAI_ID,TRUE
Anita Singh @ Mumbai,PROVIDER_DR_SINGH_ID,FACILITY_MUMBAI_ID,TRUE
Vikram Joshi @ Delhi,PROVIDER_DR_JOSHI_ID,FACILITY_DELHI_ID,TRUE
Meera Bhat @ Jaipur,PROVIDER_DR_BHAT_ID,FACILITY_JAIPUR_ID,TRUE
Deepak Rao @ Bengaluru,PROVIDER_DR_RAO_ID,FACILITY_BENGALURU_ID,TRUE
Sunita Menon @ Hyderabad,PROVIDER_DR_MENON_ID,FACILITY_HYDERABAD_ID,TRUE
```

---

## 10. HealthcareProviderSpecialty (link providers to CareSpecialty catalog)

**Object:** `HealthcareProviderSpecialty`  
**Purpose:** Link providers to existing CareSpecialty catalog rows for directory filtering

**IMPORTANT:** Before inserting, query your org for existing CareSpecialty records:
```sql
SELECT Id, Name FROM CareSpecialty WHERE Name IN ('Medical Oncology', 'Radiation Oncology', 'Surgical Oncology', 'Hematology')
```

Record the Ids and use them in the SpecialtyId column below.

| Name | PractitionerId | SpecialtyId | IsPrimarySpecialty | IsActive | Notes |
|------|---------------|-------------|-------------------|----------|-------|
| Med Onc — Sneha Nair | CONTACT_DR_NAIR_ID | SPECIALTY_MED_ONC_ID | TRUE | TRUE | Medical Oncology |
| Rad Onc — Amit Deshmukh | CONTACT_DR_DESHMUKH_ID | SPECIALTY_RAD_ONC_ID | TRUE | TRUE | Radiation Oncology |
| Surg Onc — Ravi Chandra | CONTACT_DR_CHANDRA_ID | SPECIALTY_SURG_ONC_ID | TRUE | TRUE | Surgical Oncology |
| Hematology — Priya Kapoor | CONTACT_DR_KAPOOR_ID | SPECIALTY_HEMATOLOGY_ID | TRUE | TRUE | Hematology |
| Med Onc — Arun Mehta | CONTACT_DR_MEHTA_ID | SPECIALTY_MED_ONC_ID | TRUE | TRUE | Medical Oncology |
| Surg Onc — Sanjay Verma | CONTACT_DR_VERMA_ID | SPECIALTY_SURG_ONC_ID | TRUE | TRUE | Surgical Oncology |
| Med Onc — Kavita Reddy | CONTACT_DR_REDDY_ID | SPECIALTY_MED_ONC_ID | TRUE | TRUE | Medical Oncology |
| Rad Onc — Suresh Kumar | CONTACT_DR_KUMAR_ID | SPECIALTY_RAD_ONC_ID | TRUE | TRUE | Radiation Oncology |
| Hematology — Lakshmi Iyer | CONTACT_DR_IYER_ID | SPECIALTY_HEMATOLOGY_ID | TRUE | TRUE | Hematology |
| Med Onc — Rajesh Pillai | CONTACT_DR_PILLAI_ID | SPECIALTY_MED_ONC_ID | TRUE | TRUE | Medical Oncology |
| Hematology — Anita Singh | CONTACT_DR_SINGH_ID | SPECIALTY_HEMATOLOGY_ID | TRUE | TRUE | Hematology |
| Med Onc — Vikram Joshi | CONTACT_DR_JOSHI_ID | SPECIALTY_MED_ONC_ID | TRUE | TRUE | Medical Oncology |
| Rad Onc — Meera Bhat | CONTACT_DR_BHAT_ID | SPECIALTY_RAD_ONC_ID | TRUE | TRUE | Radiation Oncology |
| Surg Onc — Deepak Rao | CONTACT_DR_RAO_ID | SPECIALTY_SURG_ONC_ID | TRUE | TRUE | Surgical Oncology |
| Surg Onc — Sunita Menon | CONTACT_DR_MENON_ID | SPECIALTY_SURG_ONC_ID | TRUE | TRUE | Surgical Oncology |

**CSV Template (HealthcareProviderSpecialty):**
```csv
Name,PractitionerId,SpecialtyId,IsPrimarySpecialty,IsActive
Med Onc — Sneha Nair,CONTACT_DR_NAIR_ID,SPECIALTY_MED_ONC_ID,TRUE,TRUE
Rad Onc — Amit Deshmukh,CONTACT_DR_DESHMUKH_ID,SPECIALTY_RAD_ONC_ID,TRUE,TRUE
Surg Onc — Ravi Chandra,CONTACT_DR_CHANDRA_ID,SPECIALTY_SURG_ONC_ID,TRUE,TRUE
Hematology — Priya Kapoor,CONTACT_DR_KAPOOR_ID,SPECIALTY_HEMATOLOGY_ID,TRUE,TRUE
Med Onc — Arun Mehta,CONTACT_DR_MEHTA_ID,SPECIALTY_MED_ONC_ID,TRUE,TRUE
Surg Onc — Sanjay Verma,CONTACT_DR_VERMA_ID,SPECIALTY_SURG_ONC_ID,TRUE,TRUE
Med Onc — Kavita Reddy,CONTACT_DR_REDDY_ID,SPECIALTY_MED_ONC_ID,TRUE,TRUE
Rad Onc — Suresh Kumar,CONTACT_DR_KUMAR_ID,SPECIALTY_RAD_ONC_ID,TRUE,TRUE
Hematology — Lakshmi Iyer,CONTACT_DR_IYER_ID,SPECIALTY_HEMATOLOGY_ID,TRUE,TRUE
Med Onc — Rajesh Pillai,CONTACT_DR_PILLAI_ID,SPECIALTY_MED_ONC_ID,TRUE,TRUE
Hematology — Anita Singh,CONTACT_DR_SINGH_ID,SPECIALTY_HEMATOLOGY_ID,TRUE,TRUE
Med Onc — Vikram Joshi,CONTACT_DR_JOSHI_ID,SPECIALTY_MED_ONC_ID,TRUE,TRUE
Rad Onc — Meera Bhat,CONTACT_DR_BHAT_ID,SPECIALTY_RAD_ONC_ID,TRUE,TRUE
Surg Onc — Deepak Rao,CONTACT_DR_RAO_ID,SPECIALTY_SURG_ONC_ID,TRUE,TRUE
Surg Onc — Sunita Menon,CONTACT_DR_MENON_ID,SPECIALTY_SURG_ONC_ID,TRUE,TRUE
```

---

## 11. Symptom_Specialty_Map__c (10–14 Active rows)

**Object:** `Symptom_Specialty_Map__c`  
**Purpose:** Drive Smart Navigator — map symptom phrases to specialties

**CRITICAL:** `Recommended_Specialty__c` must match EXACTLY how specialties appear in your CareSpecialty catalog (case and spelling).

| Name | Keyword_Pattern__c | Match_Priority__c | Recommended_Specialty__c | Routing_Summary__c | Disclaimer__c | Active__c |
|------|-------------------|------------------|-------------------------|-------------------|---------------|-----------|
| Lump neck → Med Onc | lump neck | 10 | Medical Oncology | Many people discuss symptoms like persistent lumps or swelling in the neck area with our medical oncology team for evaluation. This is navigation guidance, not a diagnosis. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Fatigue persistent → Med Onc | persistent fatigue | 8 | Medical Oncology | Ongoing fatigue concerns are often reviewed by our medical oncology specialists. This helps you connect with the right team, but is not a diagnosis. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Breast lump → Med Onc | breast lump | 10 | Medical Oncology | Questions about breast lumps or changes are commonly discussed with our medical oncology specialists. This is informational guidance, not a diagnosis. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Cough persistent → Rad Onc | persistent cough | 7 | Radiation Oncology | Long-lasting cough concerns may be reviewed by radiation oncology or other specialists. This helps guide you, but is not medical advice. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Weight loss unexplained → Med Onc | unexplained weight loss | 9 | Medical Oncology | Unexplained weight loss is often discussed with medical oncology for thorough evaluation. This is guidance only, not a diagnosis. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Bleeding abnormal → Surg Onc | abnormal bleeding | 8 | Surgical Oncology | Abnormal bleeding concerns may be reviewed by surgical oncology specialists. This helps you find the right team, not a diagnosis. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Pain abdomen → Surg Onc | abdominal pain | 7 | Surgical Oncology | Persistent abdominal pain is often evaluated by surgical specialists. This is navigation guidance only. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Blood disorder → Hematology | blood disorder | 10 | Hematology | Blood-related concerns are typically reviewed by our hematology team. This helps connect you with appropriate specialists. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Anemia symptoms → Hematology | anemia | 8 | Hematology | Anemia and related symptoms are commonly discussed with hematology specialists for evaluation. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Skin changes → Surg Onc | skin changes | 6 | Surgical Oncology | Persistent or concerning skin changes may be evaluated by surgical oncology or dermatology. This is guidance, not diagnosis. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Lymph node swelling → Med Onc | lymph node swelling | 9 | Medical Oncology | Swollen lymph nodes are often evaluated by medical oncology specialists. This navigation help is not a diagnosis. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Bone pain → Med Onc | bone pain | 7 | Medical Oncology | Persistent bone pain concerns may be discussed with medical oncology. This is informational guidance only. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Night sweats → Hematology | night sweats | 6 | Hematology | Persistent night sweats may be reviewed by hematology or other specialists. This helps guide your inquiry. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |
| Difficulty swallowing → Rad Onc | difficulty swallowing | 8 | Radiation Oncology | Swallowing difficulties are often evaluated by radiation oncology or gastroenterology. This is guidance only. | This is not medical advice. For emergency symptoms, please call local emergency services immediately. | TRUE |

**CSV Template (Symptom_Specialty_Map__c):**
```csv
Name,Keyword_Pattern__c,Match_Priority__c,Recommended_Specialty__c,Routing_Summary__c,Disclaimer__c,Active__c
Lump neck → Med Onc,lump neck,10,Medical Oncology,Many people discuss symptoms like persistent lumps or swelling in the neck area with our medical oncology team for evaluation. This is navigation guidance not a diagnosis.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Fatigue persistent → Med Onc,persistent fatigue,8,Medical Oncology,Ongoing fatigue concerns are often reviewed by our medical oncology specialists. This helps you connect with the right team but is not a diagnosis.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Breast lump → Med Onc,breast lump,10,Medical Oncology,Questions about breast lumps or changes are commonly discussed with our medical oncology specialists. This is informational guidance not a diagnosis.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Cough persistent → Rad Onc,persistent cough,7,Radiation Oncology,Long-lasting cough concerns may be reviewed by radiation oncology or other specialists. This helps guide you but is not medical advice.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Weight loss unexplained → Med Onc,unexplained weight loss,9,Medical Oncology,Unexplained weight loss is often discussed with medical oncology for thorough evaluation. This is guidance only not a diagnosis.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Bleeding abnormal → Surg Onc,abnormal bleeding,8,Surgical Oncology,Abnormal bleeding concerns may be reviewed by surgical oncology specialists. This helps you find the right team not a diagnosis.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Pain abdomen → Surg Onc,abdominal pain,7,Surgical Oncology,Persistent abdominal pain is often evaluated by surgical specialists. This is navigation guidance only.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Blood disorder → Hematology,blood disorder,10,Hematology,Blood-related concerns are typically reviewed by our hematology team. This helps connect you with appropriate specialists.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Anemia symptoms → Hematology,anemia,8,Hematology,Anemia and related symptoms are commonly discussed with hematology specialists for evaluation.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Skin changes → Surg Onc,skin changes,6,Surgical Oncology,Persistent or concerning skin changes may be evaluated by surgical oncology or dermatology. This is guidance not diagnosis.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Lymph node swelling → Med Onc,lymph node swelling,9,Medical Oncology,Swollen lymph nodes are often evaluated by medical oncology specialists. This navigation help is not a diagnosis.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Bone pain → Med Onc,bone pain,7,Medical Oncology,Persistent bone pain concerns may be discussed with medical oncology. This is informational guidance only.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Night sweats → Hematology,night sweats,6,Hematology,Persistent night sweats may be reviewed by hematology or other specialists. This helps guide your inquiry.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
Difficulty swallowing → Rad Onc,difficulty swallowing,8,Radiation Oncology,Swallowing difficulties are often evaluated by radiation oncology or gastroenterology. This is guidance only.,This is not medical advice. For emergency symptoms please call local emergency services immediately.,TRUE
```

---

## 12. Patient_Insurance__c (2–4 rows per subset of patients)

**Object:** `Patient_Insurance__c`  
**Purpose:** Insurance/eligibility snapshots for coverage validation

Select 8–10 patients from your 15 patient accounts to have insurance records.

| Patient__c | Payer_Name__c | Member_Id__c | Plan_Name__c | Eligibility_Status__c | Valid_From__c | Valid_To__c | Last_Verified_Date__c | Is_Primary__c | Notes__c |
|-----------|--------------|-------------|-------------|----------------------|--------------|------------|---------------------|--------------|----------|
| PATIENT_PRIYA_ID | Star Health | SH-992810 | Gold Plus | Active | 2025-01-01 | 2026-12-31 | 2026-04-01 | TRUE | Room rent sub-limit: ₹5000/day |
| PATIENT_ANJALI_ID | ICICI Lombard | ICICI-78452 | Comprehensive Health | Active | 2024-06-01 | 2027-05-31 | 2026-03-15 | TRUE | Full oncology coverage |
| PATIENT_VIKRAM_ID | Max Bupa | MB-556729 | Health Recharge | Active | 2025-03-01 | 2026-02-28 | 2026-04-10 | TRUE | Pre-existing covered after 2 years |
| PATIENT_VIKRAM_ID | Niva Bupa | NB-334211 | Senior First | Active | 2024-01-01 | 2026-12-31 | 2026-02-28 | FALSE | Secondary coverage |
| PATIENT_MEERA_ID | HDFC ERGO | HDFC-889342 | Optima Secure | Active | 2023-07-01 | 2026-06-30 | 2026-03-20 | TRUE | Cancer care included |
| PATIENT_KAVITA_ID | Care Health | CH-445678 | Care Advantage | Pending | 2026-05-01 | 2027-04-30 | 2026-04-25 | TRUE | Verification in progress |
| PATIENT_SHALINI_ID | Religare Health | RH-223456 | Care | Active | 2024-10-01 | 2026-09-30 | 2026-03-05 | TRUE | Room: Private ward eligible |
| PATIENT_ANIL_ID | New India Assurance | NIA-667788 | Mediclaim | Active | 2023-04-01 | 2026-03-31 | 2025-12-15 | TRUE | Government scheme |
| PATIENT_KARTHIK_ID | Bajaj Allianz | BA-991234 | Health Guard | Active | 2025-02-01 | 2027-01-31 | 2026-04-05 | TRUE | Day care procedures covered |
| PATIENT_SUNITA_ID | United India | UI-554332 | Comprehensive | Pending | 2026-04-15 | 2027-04-14 | 2026-04-20 | TRUE | New policy under review |

**CSV Template (Patient_Insurance__c):**
```csv
Patient__c,Payer_Name__c,Member_Id__c,Plan_Name__c,Eligibility_Status__c,Valid_From__c,Valid_To__c,Last_Verified_Date__c,Is_Primary__c,Notes__c
PATIENT_PRIYA_ID,Star Health,SH-992810,Gold Plus,Active,2025-01-01,2026-12-31,2026-04-01,TRUE,Room rent sub-limit: ₹5000/day
PATIENT_ANJALI_ID,ICICI Lombard,ICICI-78452,Comprehensive Health,Active,2024-06-01,2027-05-31,2026-03-15,TRUE,Full oncology coverage
PATIENT_VIKRAM_ID,Max Bupa,MB-556729,Health Recharge,Active,2025-03-01,2026-02-28,2026-04-10,TRUE,Pre-existing covered after 2 years
PATIENT_VIKRAM_ID,Niva Bupa,NB-334211,Senior First,Active,2024-01-01,2026-12-31,2026-02-28,FALSE,Secondary coverage
PATIENT_MEERA_ID,HDFC ERGO,HDFC-889342,Optima Secure,Active,2023-07-01,2026-06-30,2026-03-20,TRUE,Cancer care included
PATIENT_KAVITA_ID,Care Health,CH-445678,Care Advantage,Pending,2026-05-01,2027-04-30,2026-04-25,TRUE,Verification in progress
PATIENT_SHALINI_ID,Religare Health,RH-223456,Care,Active,2024-10-01,2026-09-30,2026-03-05,TRUE,Room: Private ward eligible
PATIENT_ANIL_ID,New India Assurance,NIA-667788,Mediclaim,Active,2023-04-01,2026-03-31,2025-12-15,TRUE,Government scheme
PATIENT_KARTHIK_ID,Bajaj Allianz,BA-991234,Health Guard,Active,2025-02-01,2027-01-31,2026-04-05,TRUE,Day care procedures covered
PATIENT_SUNITA_ID,United India,UI-554332,Comprehensive,Pending,2026-04-15,2027-04-14,2026-04-20,TRUE,New policy under review
```

---

## 13. Facility_Room_Rate__c (2–3 room types per facility)

**Object:** `Facility_Room_Rate__c`  
**Purpose:** Room-type pricing for patient inquiries

| Healthcare_Facility__c | Room_Type__c | Daily_Rate__c (INR) | Effective_From__c | Effective_To__c | Notes |
|----------------------|-------------|-------------------|------------------|----------------|-------|
| FACILITY_MUMBAI_ID | General | 8000 | 2026-01-01 | | Standard ward |
| FACILITY_MUMBAI_ID | Private | 15000 | 2026-01-01 | | Single occupancy |
| FACILITY_MUMBAI_ID | ICU | 25000 | 2026-01-01 | | Critical care |
| FACILITY_DELHI_ID | General | 7000 | 2026-01-01 | | Standard ward |
| FACILITY_DELHI_ID | Private | 12000 | 2026-01-01 | | Single occupancy |
| FACILITY_DELHI_ID | ICU | 22000 | 2026-01-01 | | Critical care |
| FACILITY_JAIPUR_ID | General | 5000 | 2026-01-01 | | Standard ward |
| FACILITY_JAIPUR_ID | Private | 10000 | 2026-01-01 | | Single occupancy |
| FACILITY_JAIPUR_ID | ICU | 18000 | 2026-01-01 | | Critical care |
| FACILITY_BENGALURU_ID | General | 7500 | 2026-01-01 | | Standard ward |
| FACILITY_BENGALURU_ID | Private | 14000 | 2026-01-01 | | Single occupancy |
| FACILITY_BENGALURU_ID | ICU | 24000 | 2026-01-01 | | Critical care |
| FACILITY_HYDERABAD_ID | General | 6500 | 2026-01-01 | | Standard ward |
| FACILITY_HYDERABAD_ID | Private | 11000 | 2026-01-01 | | Single occupancy |
| FACILITY_HYDERABAD_ID | ICU | 20000 | 2026-01-01 | | Critical care |

**CSV Template (Facility_Room_Rate__c):**
```csv
Healthcare_Facility__c,Room_Type__c,Daily_Rate__c,Effective_From__c,Effective_To__c
FACILITY_MUMBAI_ID,General,8000,2026-01-01,
FACILITY_MUMBAI_ID,Private,15000,2026-01-01,
FACILITY_MUMBAI_ID,ICU,25000,2026-01-01,
FACILITY_DELHI_ID,General,7000,2026-01-01,
FACILITY_DELHI_ID,Private,12000,2026-01-01,
FACILITY_DELHI_ID,ICU,22000,2026-01-01,
FACILITY_JAIPUR_ID,General,5000,2026-01-01,
FACILITY_JAIPUR_ID,Private,10000,2026-01-01,
FACILITY_JAIPUR_ID,ICU,18000,2026-01-01,
FACILITY_BENGALURU_ID,General,7500,2026-01-01,
FACILITY_BENGALURU_ID,Private,14000,2026-01-01,
FACILITY_BENGALURU_ID,ICU,24000,2026-01-01,
FACILITY_HYDERABAD_ID,General,6500,2026-01-01,
FACILITY_HYDERABAD_ID,Private,11000,2026-01-01,
FACILITY_HYDERABAD_ID,ICU,20000,2026-01-01,
```

---

## 14. ServiceAppointment (3–8 future appointments)

**Object:** `ServiceAppointment`  
**Purpose:** Scheduled appointments for testing slot overlap and capacity

**IMPORTANT:** Use future dates (May 2026 and beyond). Include varied times to test slot suggestion overlaps.

| ParentRecordId | ContactId | SchedStartTime | SchedEndTime | Status | Subject | Notes |
|---------------|-----------|----------------|--------------|--------|---------|-------|
| PATIENT_ARJUN_ID | PATIENT_ARJUN_CONTACT_ID | 2026-05-05T10:00:00+05:30 | 2026-05-05T10:30:00+05:30 | Scheduled | Consultation — Medical Oncology | Future appointment |
| PATIENT_KARTHIK_ID | PATIENT_KARTHIK_CONTACT_ID | 2026-05-05T14:00:00+05:30 | 2026-05-05T14:30:00+05:30 | Scheduled | Follow-up — Radiation Oncology | Same day as above (stress test) |
| PATIENT_MEERA_ID | PATIENT_MEERA_CONTACT_ID | 2026-05-05T15:00:00+05:30 | 2026-05-05T15:30:00+05:30 | Scheduled | Review — Hematology | Same day (cap test) |
| PATIENT_ANIL_ID | PATIENT_ANIL_CONTACT_ID | 2026-05-08T11:00:00+05:30 | 2026-05-08T11:30:00+05:30 | Scheduled | Consultation — Medical Oncology | Different day |
| PATIENT_LAKSHMI_ID | PATIENT_LAKSHMI_CONTACT_ID | 2026-05-12T09:30:00+05:30 | 2026-05-12T10:00:00+05:30 | Scheduled | Pre-op consultation | Week ahead |
| PATIENT_DEEPA_ID | PATIENT_DEEPA_CONTACT_ID | 2026-05-15T16:00:00+05:30 | 2026-05-15T16:30:00+05:30 | Scheduled | Chemotherapy session | Later date |
| PATIENT_PRIYA_ID | PATIENT_PRIYA_CONTACT_ID | 2026-05-20T10:30:00+05:30 | 2026-05-20T11:00:00+05:30 | Scheduled | Follow-up — Medical Oncology | Returning patient |
| PATIENT_RAJESH_ID | PATIENT_RAJESH_CONTACT_ID | 2026-05-22T14:30:00+05:30 | 2026-05-22T15:00:00+05:30 | Scheduled | Initial consultation | New patient |

**CSV Template (ServiceAppointment):**
```csv
ParentRecordId,ContactId,SchedStartTime,SchedEndTime,Status,Subject
PATIENT_ARJUN_ID,PATIENT_ARJUN_CONTACT_ID,2026-05-05T10:00:00.000+0530,2026-05-05T10:30:00.000+0530,Scheduled,Consultation — Medical Oncology
PATIENT_KARTHIK_ID,PATIENT_KARTHIK_CONTACT_ID,2026-05-05T14:00:00.000+0530,2026-05-05T14:30:00.000+0530,Scheduled,Follow-up — Radiation Oncology
PATIENT_MEERA_ID,PATIENT_MEERA_CONTACT_ID,2026-05-05T15:00:00.000+0530,2026-05-05T15:30:00.000+0530,Scheduled,Review — Hematology
PATIENT_ANIL_ID,PATIENT_ANIL_CONTACT_ID,2026-05-08T11:00:00.000+0530,2026-05-08T11:30:00.000+0530,Scheduled,Consultation — Medical Oncology
PATIENT_LAKSHMI_ID,PATIENT_LAKSHMI_CONTACT_ID,2026-05-12T09:30:00.000+0530,2026-05-12T10:00:00.000+0530,Scheduled,Pre-op consultation
PATIENT_DEEPA_ID,PATIENT_DEEPA_CONTACT_ID,2026-05-15T16:00:00.000+0530,2026-05-15T16:30:00.000+0530,Scheduled,Chemotherapy session
PATIENT_PRIYA_ID,PATIENT_PRIYA_CONTACT_ID,2026-05-20T10:30:00.000+0530,2026-05-20T11:00:00.000+0530,Scheduled,Follow-up — Medical Oncology
PATIENT_RAJESH_ID,PATIENT_RAJESH_CONTACT_ID,2026-05-22T14:30:00.000+0530,2026-05-22T15:00:00.000+0530,Scheduled,Initial consultation
```

**Note:** After insert, record ServiceAppointment Ids for use in ClinicalEncounter.

---

## 15. ClinicalEncounter (matching ServiceAppointment rows)

**Object:** `ClinicalEncounter`  
**Purpose:** Clinical visit records linked to appointments

| PatientId | FacilityId | StartDate | EndDate | Status | ServiceAppointmentId | Notes |
|-----------|------------|-----------|---------|--------|---------------------|-------|
| PATIENT_ARJUN_ID | FACILITY_HYDERABAD_ID | 2026-05-05T10:00:00+05:30 | 2026-05-05T10:30:00+05:30 | Scheduled | SA_FUTURE_01_ID | Match SA row 1 |
| PATIENT_KARTHIK_ID | FACILITY_BENGALURU_ID | 2026-05-05T14:00:00+05:30 | 2026-05-05T14:30:00+05:30 | Scheduled | SA_FUTURE_02_ID | Match SA row 2 |
| PATIENT_MEERA_ID | FACILITY_HYDERABAD_ID | 2026-05-05T15:00:00+05:30 | 2026-05-05T15:30:00+05:30 | Scheduled | SA_FUTURE_03_ID | Match SA row 3 |
| PATIENT_ANIL_ID | FACILITY_MUMBAI_ID | 2026-05-08T11:00:00+05:30 | 2026-05-08T11:30:00+05:30 | Scheduled | SA_FUTURE_04_ID | Match SA row 4 |
| PATIENT_LAKSHMI_ID | FACILITY_BENGALURU_ID | 2026-05-12T09:30:00+05:30 | 2026-05-12T10:00:00+05:30 | Scheduled | SA_FUTURE_05_ID | Match SA row 5 |
| PATIENT_DEEPA_ID | FACILITY_JAIPUR_ID | 2026-05-15T16:00:00+05:30 | 2026-05-15T16:30:00+05:30 | Scheduled | SA_FUTURE_06_ID | Match SA row 6 |
| PATIENT_PRIYA_ID | FACILITY_JAIPUR_ID | 2026-05-20T10:30:00+05:30 | 2026-05-20T11:00:00+05:30 | Scheduled | SA_FUTURE_07_ID | Match SA row 7 |
| PATIENT_RAJESH_ID | FACILITY_MUMBAI_ID | 2026-05-22T14:30:00+05:30 | 2026-05-22T15:00:00+05:30 | Scheduled | SA_FUTURE_08_ID | Match SA row 8 |

**CSV Template (ClinicalEncounter):**
```csv
PatientId,FacilityId,StartDate,EndDate,Status,ServiceAppointmentId
PATIENT_ARJUN_ID,FACILITY_HYDERABAD_ID,2026-05-05T10:00:00.000+0530,2026-05-05T10:30:00.000+0530,Scheduled,SA_FUTURE_01_ID
PATIENT_KARTHIK_ID,FACILITY_BENGALURU_ID,2026-05-05T14:00:00.000+0530,2026-05-05T14:30:00.000+0530,Scheduled,SA_FUTURE_02_ID
PATIENT_MEERA_ID,FACILITY_HYDERABAD_ID,2026-05-05T15:00:00.000+0530,2026-05-05T15:30:00.000+0530,Scheduled,SA_FUTURE_03_ID
PATIENT_ANIL_ID,FACILITY_MUMBAI_ID,2026-05-08T11:00:00.000+0530,2026-05-08T11:30:00.000+0530,Scheduled,SA_FUTURE_04_ID
PATIENT_LAKSHMI_ID,FACILITY_BENGALURU_ID,2026-05-12T09:30:00.000+0530,2026-05-12T10:00:00.000+0530,Scheduled,SA_FUTURE_05_ID
PATIENT_DEEPA_ID,FACILITY_JAIPUR_ID,2026-05-15T16:00:00.000+0530,2026-05-15T16:30:00.000+0530,Scheduled,SA_FUTURE_06_ID
PATIENT_PRIYA_ID,FACILITY_JAIPUR_ID,2026-05-20T10:30:00.000+0530,2026-05-20T11:00:00.000+0530,Scheduled,SA_FUTURE_07_ID
PATIENT_RAJESH_ID,FACILITY_MUMBAI_ID,2026-05-22T14:30:00.000+0530,2026-05-22T15:00:00.000+0530,Scheduled,SA_FUTURE_08_ID
```

**Note:** Record ClinicalEncounter Ids for use in ClinicalEncounterProvider.

---

## 16. ClinicalEncounterProvider (link providers to encounters)

**Object:** `ClinicalEncounterProvider`  
**Purpose:** Attending provider on specific encounters

| ClinicalEncounterId | PractitionerId | StartDate | EndDate | Notes |
|--------------------|---------------|-----------|---------|-------|
| CE_FUTURE_01_ID | CONTACT_DR_PILLAI_ID | 2026-05-05T10:00:00+05:30 | 2026-05-05T10:30:00+05:30 | Rajesh Pillai @ Hyderabad |
| CE_FUTURE_02_ID | CONTACT_DR_KUMAR_ID | 2026-05-05T14:00:00+05:30 | 2026-05-05T14:30:00+05:30 | Suresh Kumar @ Bengaluru |
| CE_FUTURE_03_ID | CONTACT_DR_IYER_ID | 2026-05-05T15:00:00+05:30 | 2026-05-05T15:30:00+05:30 | Lakshmi Iyer @ Hyderabad |
| CE_FUTURE_04_ID | CONTACT_DR_NAIR_ID | 2026-05-08T11:00:00+05:30 | 2026-05-08T11:30:00+05:30 | Sneha Nair @ Mumbai |
| CE_FUTURE_05_ID | CONTACT_DR_RAO_ID | 2026-05-12T09:30:00+05:30 | 2026-05-12T10:00:00+05:30 | Deepak Rao @ Bengaluru |
| CE_FUTURE_06_ID | CONTACT_DR_MEHTA_ID | 2026-05-15T16:00:00+05:30 | 2026-05-15T16:30:00+05:30 | Arun Mehta @ Jaipur |
| CE_FUTURE_07_ID | CONTACT_DR_MEHTA_ID | 2026-05-20T10:30:00+05:30 | 2026-05-20T11:00:00+05:30 | Arun Mehta @ Jaipur |
| CE_FUTURE_08_ID | CONTACT_DR_NAIR_ID | 2026-05-22T14:30:00+05:30 | 2026-05-22T15:00:00+05:30 | Sneha Nair @ Mumbai |

**CSV Template (ClinicalEncounterProvider):**
```csv
ClinicalEncounterId,PractitionerId,StartDate,EndDate
CE_FUTURE_01_ID,CONTACT_DR_PILLAI_ID,2026-05-05T10:00:00.000+0530,2026-05-05T10:30:00.000+0530
CE_FUTURE_02_ID,CONTACT_DR_KUMAR_ID,2026-05-05T14:00:00.000+0530,2026-05-05T14:30:00.000+0530
CE_FUTURE_03_ID,CONTACT_DR_IYER_ID,2026-05-05T15:00:00.000+0530,2026-05-05T15:30:00.000+0530
CE_FUTURE_04_ID,CONTACT_DR_NAIR_ID,2026-05-08T11:00:00.000+0530,2026-05-08T11:30:00.000+0530
CE_FUTURE_05_ID,CONTACT_DR_RAO_ID,2026-05-12T09:30:00.000+0530,2026-05-12T10:00:00.000+0530
CE_FUTURE_06_ID,CONTACT_DR_MEHTA_ID,2026-05-15T16:00:00.000+0530,2026-05-15T16:30:00.000+0530
CE_FUTURE_07_ID,CONTACT_DR_MEHTA_ID,2026-05-20T10:30:00.000+0530,2026-05-20T11:00:00.000+0530
CE_FUTURE_08_ID,CONTACT_DR_NAIR_ID,2026-05-22T14:30:00.000+0530,2026-05-22T15:00:00.000+0530
```

---

## 17. Counselling_Prerequisite__c (8–12 rows tied to ServiceAppointments)

**Object:** `Counselling_Prerequisite__c`  
**Purpose:** Document/prerequisite checklist before appointments

| Related_Appointment__c | Document_Type__c | Is_Required__c | Is_Satisfied__c | Due_Before__c | Notes |
|----------------------|-----------------|---------------|----------------|--------------|-------|
| SA_FUTURE_01_ID | Lab report | TRUE | FALSE | 2026-05-04T17:00:00+05:30 | Blood work needed |
| SA_FUTURE_01_ID | Insurance card | TRUE | TRUE | 2026-05-04T17:00:00+05:30 | Uploaded |
| SA_FUTURE_03_ID | ID | TRUE | TRUE | 2026-05-04T17:00:00+05:30 | Verified |
| SA_FUTURE_03_ID | Consent | TRUE | FALSE | 2026-05-05T09:00:00+05:30 | Pending signature |
| SA_FUTURE_04_ID | Lab report | TRUE | TRUE | 2026-05-07T17:00:00+05:30 | Recent imaging |
| SA_FUTURE_05_ID | Insurance card | TRUE | TRUE | 2026-05-11T17:00:00+05:30 | On file |
| SA_FUTURE_05_ID | Consent | TRUE | FALSE | 2026-05-11T17:00:00+05:30 | Pre-op consent pending |
| SA_FUTURE_06_ID | Lab report | FALSE | FALSE | 2026-05-14T17:00:00+05:30 | Optional for this visit |
| SA_FUTURE_07_ID | Lab report | TRUE | TRUE | 2026-05-19T17:00:00+05:30 | Follow-up labs complete |
| SA_FUTURE_07_ID | Insurance card | TRUE | TRUE | 2026-05-19T17:00:00+05:30 | Active coverage |
| SA_FUTURE_08_ID | ID | TRUE | FALSE | 2026-05-21T17:00:00+05:30 | New patient - needs ID |
| SA_FUTURE_08_ID | Insurance card | TRUE | FALSE | 2026-05-21T17:00:00+05:30 | Verification pending |

**CSV Template (Counselling_Prerequisite__c):**
```csv
Related_Appointment__c,Document_Type__c,Is_Required__c,Is_Satisfied__c,Due_Before__c
SA_FUTURE_01_ID,Lab report,TRUE,FALSE,2026-05-04T17:00:00.000+0530
SA_FUTURE_01_ID,Insurance card,TRUE,TRUE,2026-05-04T17:00:00.000+0530
SA_FUTURE_03_ID,ID,TRUE,TRUE,2026-05-04T17:00:00.000+0530
SA_FUTURE_03_ID,Consent,TRUE,FALSE,2026-05-05T09:00:00.000+0530
SA_FUTURE_04_ID,Lab report,TRUE,TRUE,2026-05-07T17:00:00.000+0530
SA_FUTURE_05_ID,Insurance card,TRUE,TRUE,2026-05-11T17:00:00.000+0530
SA_FUTURE_05_ID,Consent,TRUE,FALSE,2026-05-11T17:00:00.000+0530
SA_FUTURE_06_ID,Lab report,FALSE,FALSE,2026-05-14T17:00:00.000+0530
SA_FUTURE_07_ID,Lab report,TRUE,TRUE,2026-05-19T17:00:00.000+0530
SA_FUTURE_07_ID,Insurance card,TRUE,TRUE,2026-05-19T17:00:00.000+0530
SA_FUTURE_08_ID,ID,TRUE,FALSE,2026-05-21T17:00:00.000+0530
SA_FUTURE_08_ID,Insurance card,TRUE,FALSE,2026-05-21T17:00:00.000+0530
```

---

## 18. Booking_Session__c (5–8 returning patient sessions)

**Object:** `Booking_Session__c`  
**Purpose:** Opaque rebook tokens for returning patients

| Patient__c | Last_Service_Appointment__c | Last_Clinical_Encounter__c | Preferred_Facility__c | Context_Token__c | Notes |
|-----------|---------------------------|--------------------------|---------------------|-----------------|-------|
| PATIENT_PRIYA_ID | SA_FUTURE_07_ID | CE_FUTURE_07_ID | FACILITY_JAIPUR_ID | sess_a1b2c3d4e5 | Returning patient |
| PATIENT_MEERA_ID | SA_FUTURE_03_ID | CE_FUTURE_03_ID | FACILITY_HYDERABAD_ID | sess_f6g7h8i9j0 | Active session |
| PATIENT_LAKSHMI_ID | SA_FUTURE_05_ID | CE_FUTURE_05_ID | FACILITY_BENGALURU_ID | sess_k1l2m3n4o5 | Returning with session |
| PATIENT_ARJUN_ID | SA_FUTURE_01_ID | CE_FUTURE_01_ID | FACILITY_HYDERABAD_ID | sess_p6q7r8s9t0 | Recent appointment context |
| PATIENT_KARTHIK_ID | SA_FUTURE_02_ID | CE_FUTURE_02_ID | FACILITY_BENGALURU_ID | sess_u1v2w3x4y5 | Multiple appointments history |
| PATIENT_ANIL_ID | SA_FUTURE_04_ID | CE_FUTURE_04_ID | FACILITY_MUMBAI_ID | sess_z6a7b8c9d0 | Prefers Mumbai facility |
| PATIENT_DEEPA_ID | SA_FUTURE_06_ID | CE_FUTURE_06_ID | FACILITY_JAIPUR_ID | sess_e1f2g3h4i5 | Guest conversion session |
| PATIENT_RAJESH_ID | SA_FUTURE_08_ID | CE_FUTURE_08_ID | FACILITY_MUMBAI_ID | sess_j6k7l8m9n0 | New patient with session |

**CSV Template (Booking_Session__c):**
```csv
Patient__c,Last_Service_Appointment__c,Last_Clinical_Encounter__c,Preferred_Facility__c,Context_Token__c
PATIENT_PRIYA_ID,SA_FUTURE_07_ID,CE_FUTURE_07_ID,FACILITY_JAIPUR_ID,sess_a1b2c3d4e5
PATIENT_MEERA_ID,SA_FUTURE_03_ID,CE_FUTURE_03_ID,FACILITY_HYDERABAD_ID,sess_f6g7h8i9j0
PATIENT_LAKSHMI_ID,SA_FUTURE_05_ID,CE_FUTURE_05_ID,FACILITY_BENGALURU_ID,sess_k1l2m3n4o5
PATIENT_ARJUN_ID,SA_FUTURE_01_ID,CE_FUTURE_01_ID,FACILITY_HYDERABAD_ID,sess_p6q7r8s9t0
PATIENT_KARTHIK_ID,SA_FUTURE_02_ID,CE_FUTURE_02_ID,FACILITY_BENGALURU_ID,sess_u1v2w3x4y5
PATIENT_ANIL_ID,SA_FUTURE_04_ID,CE_FUTURE_04_ID,FACILITY_MUMBAI_ID,sess_z6a7b8c9d0
PATIENT_DEEPA_ID,SA_FUTURE_06_ID,CE_FUTURE_06_ID,FACILITY_JAIPUR_ID,sess_e1f2g3h4i5
PATIENT_RAJESH_ID,SA_FUTURE_08_ID,CE_FUTURE_08_ID,FACILITY_MUMBAI_ID,sess_j6k7l8m9n0
```

---

## Sanity Checklist

Before going live with this data, verify:

### ✅ Unique Constraints
- [ ] All `PersonMobilePhone` values are unique across 15+ patient accounts (no duplicates)
- [ ] Each patient account has a corresponding `PersonContactId` recorded
- [ ] All email addresses are unique or intentionally shared

### ✅ Foreign Key Integrity
- [ ] Every `HealthcareFacility.LocationId` points to a valid Location
- [ ] Every `HealthcareFacility.OPD_Operating_Hours__c` points to a valid OperatingHours
- [ ] Every `TimeSlot.OperatingHoursId` points to its parent OperatingHours
- [ ] Every `HealthcareProvider.PractitionerId` points to a valid Contact
- [ ] Every `HealthcarePractitionerFacility` links valid Provider → Facility
- [ ] Every `HealthcareProviderSpecialty` links valid Practitioner → CareSpecialty catalog
- [ ] Every `ServiceAppointment.ContactId` uses patient's `PersonContactId`
- [ ] Every `ClinicalEncounter.ServiceAppointmentId` matches a ServiceAppointment
- [ ] Every `ClinicalEncounterProvider` links valid Encounter → Practitioner

### ✅ Specialty Name Consistency
- [ ] Query org for actual CareSpecialty names: `SELECT Id, Name FROM CareSpecialty`
- [ ] `Symptom_Specialty_Map__c.Recommended_Specialty__c` values EXACTLY match catalog (case-sensitive)
- [ ] All providers have at least one HealthcareProviderSpecialty row
- [ ] Specialty names in symptom map: Medical Oncology, Radiation Oncology, Surgical Oncology, Hematology

### ✅ Operating Hours Coverage
- [ ] Each major facility (Mumbai, Delhi, Jaipur, Bengaluru, Hyderabad) has one OperatingHours
- [ ] Each OperatingHours has TimeSlot rows for Mon–Sat (Sunday intentionally omitted for testing)
- [ ] TimeZone set to `Asia/Kolkata` on all OperatingHours
- [ ] At least one facility has split sessions (Mumbai: morning 09:00–13:00, afternoon 14:00–18:00)
- [ ] At least one facility has continuous hours (Delhi, Jaipur, Hyderabad: 09:00–17:00)
- [ ] Different Saturday patterns exist for testing (most close at 13:00, Bengaluru different)

### ✅ Appointment Stress Testing
- [ ] At least 3 ServiceAppointments on same day (2026-05-05) at different facilities for overlap testing
- [ ] Appointments span multiple weeks (May 5, 8, 12, 15, 20, 22) for date range tests
- [ ] Each ClinicalEncounter exactly matches its ServiceAppointment (same start/end, facility)
- [ ] Mix of morning, afternoon, and late afternoon appointments
- [ ] All appointment dates/times fall within facility operating hours

### ✅ Patient Insurance Coverage
- [ ] 8–10 patients (out of 15) have at least one insurance record
- [ ] At least one patient (Vikram) has multiple insurances (primary + secondary)
- [ ] Mix of Active and Pending statuses
- [ ] Valid_From__c < Valid_To__c for all active policies
- [ ] Is_Primary__c = true for at least one insurance per patient with multiple

### ✅ Directory Overlap
- [ ] Multiple providers work at 2+ facilities (e.g., Dr. Sneha Nair @ Mumbai + Jaipur)
- [ ] Every facility has at least 3–4 providers
- [ ] Provider distribution covers all four specialties at each major city
- [ ] HealthcarePractitionerFacility.IsActive = TRUE for all rows

### ✅ Data Volume Targets
- [ ] 15+ Person Accounts (patients) ✓
- [ ] 5–6 Locations ✓
- [ ] 5–6 HealthcareFacilities ✓
- [ ] 5–6 OperatingHours ✓
- [ ] 30+ TimeSlots (6 days × 5 facilities, some with split sessions) ✓
- [ ] 12–18 Contacts (practitioners) ✓
- [ ] 12–18 HealthcareProviders ✓
- [ ] 20+ HealthcarePractitionerFacility (overlap) ✓
- [ ] 15+ HealthcareProviderSpecialty ✓
- [ ] 10–14 Symptom_Specialty_Map__c rows ✓
- [ ] 10+ Patient_Insurance__c rows ✓
- [ ] 15+ Facility_Room_Rate__c rows (3 types × 5 facilities) ✓
- [ ] 3–8 ServiceAppointments ✓
- [ ] 3–8 ClinicalEncounters (matching) ✓
- [ ] 8+ ClinicalEncounterProviders ✓
- [ ] 8–12 Counselling_Prerequisite__c rows ✓
- [ ] 5–8 Booking_Session__c rows ✓

### ✅ Max Daily Appointments Testing
- [ ] At least one facility with low cap (Jaipur: 30) for easy stress testing
- [ ] At least one facility with high cap (Mumbai: 50) for volume demos
- [ ] Multiple appointments on 2026-05-05 to test cap calculation (3 on that day)
- [ ] Facilities: Hyderabad (35), Bengaluru (45) provide mid-range test cases

### ✅ Realistic Demo Data
- [ ] All Indian city names, lat/long coordinates plausible
- [ ] Phone numbers follow +91-XX-XXXXXXXX format for practitioners
