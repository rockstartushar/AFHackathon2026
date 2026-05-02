# Patient ↔ Agent conversation scripts

Demo and QA scripts for the **Patient Scheduling Agent** (Onco Global). They align with `Data-Model-Objects-And-Fields.md`, deployed GenAi actions, and **Enhanced Web Chat** structured outputs (see [`Agentforce-Enhanced-Chat-LWC-Plan.md`](./Agentforce-Enhanced-Chat-LWC-Plan.md) for Lightning types, Builder wiring, and deploy manifest `manifest/package-phase2-enhanced-chat.xml`).

**Conventions**

- **Patient** — end user (web or messaging).
- **Agent** — Agentforce reply (shorten in UI as needed).
- Placeholders: `[PatientName]`, `[FacilityName]`, `[DateTime]`, `[ConfirmationCode]` — replace at demo time.
- Clinical advice: agent stays **navigational + scheduling**; medical decisions go to a clinician.

### Structured outputs (Enhanced Web Chat)

After deploy, map each action’s **UI model** output in Agent Builder so cards render (not only plain `summaryText`):

| GenAi action | Invocable / Flow | Output field | Lightning type / LWC (high level) |
|--------------|------------------|--------------|-----------------------------------|
| **HC_Get_Facilities** | `HCFacilityListInvocable` | `facilityListUi` | Facility cards → `hcFacilityCardList` |
| **HC_Find_Specialist** | `HC_DirectoryInvocable` | `directoryUi` | Directory rows → `hcDirectoryResultsRenderer` |
| **HC_Slot_Suggestion** | `HC_SlotSuggestionInvocable` | `slotUi` | Slot list → `hcSlotSuggestionRenderer` |
| **HC_Booking_Actions** | `HC_BookingActionsInvocable` | `bookingUi` | BOOK / MODIFY / CANCEL outcome → `hcBookingConfirmationRenderer` |
| **HC_Coverage_Prep_UI** | `HCCoveragePrepUiInvocable` | `coveragePrepUi` | Prep accordion → `hcCoveragePrepAccordion` |
| **HC_Patient_Data_Actions** | `HC_PatientDataActionsInvocable` | `summaryText` (per operation) | Narrative summary; no separate card bundle in this repo |

Optional narrative coverage prep still uses **`HC_Coverage_Prep_Patient_Facing`** (prompt template). Use **`HC_Coverage_Prep_UI`** when you want the structured accordion alongside or instead of long prose.

### Demo / QA seed reference (hackathon org)

Use seeded data from `docs/Data-Seeding-Plan.md` and your CSV loads. Handy anchors for **repeatable** runs:

| Role | Example | Notes |
|------|---------|--------|
| Returning patient | **Rajesh Kumar**, mobile **`9876543211`** | Resolves via **`HC_Resolve_Patient_By_Phone`**; use for booking, insurance, booking-session flows. |
| Facilities | Metro + neighborhood sites (e.g. Delhi NCR, Mumbai, Bengaluru, Hyderabad, Chennai, Kolkata, **Jaipur**) | **`HC_Get_Facilities`** with `cityKeyword` / `stateKeyword` returns **`facilityListUi`**. |
| Specialists | Eight demo clinicians (e.g. Dr. Arjun Mehta, Dr. Priya Nair, Dr. Rajesh Pillai, …) | **`HC_Find_Specialist`** + **`directoryUi`**. |
| Symptom routing | `Symptom_Specialty_Map__c` + **`HC_Route_Symptom_To_Specialty`** → then directory | Education-only, not triage. |
| Counselling prerequisites | Linked to a **`ServiceAppointment`** (e.g. seeded counselling row) | **`HC_Patient_Data_Actions`** `operation=PREREQUISITES` + `serviceAppointmentId`; optional **`HC_Coverage_Prep_UI`** for the accordion. |
| Room rates | **`Facility_Room_Rate__c`** per facility | `operation=ROOM_RATES` + `healthcareFacilityId` (optional `roomTypeApi`). |
| Rebook context | **`Booking_Session__c`** | `operation=BOOKING_SESSION` with `patientAccountId` (+ payload fields per action schema). |

Adjust names and IDs to match **your** org after seeding.

### Verification & channels (MVP)

Identity rules below are the **default for now** (e.g. no SMS OTP). They may change later (OTP, Salesforce Identity, tighter channel policies).

**Guest identity — Person Account only (no Lead).** For scheduling and patient-specific data we anchor to a **`Person Account`** (patient). **Returning** guests verify by mobile (**`HC_Resolve_Patient_By_Phone`**). **New** guests answer a short capture (name, mobile, email); automation creates a **`Person Account`** via Flow **`HC_Create_Guest_Person_Account`** (dedupe: resolve by phone first—if a unique match exists, treat as returning and do not create a duplicate). We do **not** use **`Lead`** for this hackathon path.

| Channel | How we treat “verification” |
|--------|------------------------------|
| **Web (guest)** | Ask whether they **already have a profile with us** (plain language—not “registered,” which sounds like hospital check-in). **Returning:** collect mobile → **`HC_Resolve_Patient_By_Phone`**. **`UNIQUE_MATCH`:** continue with `patientAccountId`. **`NO_MATCH`:** offer **profile creation** (minimal fields) → **`HC_Create_Guest_Person_Account`** → then continue. **Multiple matches** for the same mobile: **do not** self-serve book or show other patients’ data—hand off or sign-in path. |
| **Web (logged in)** | The user is **signed in**; we use their **profile / Account** from the session directly for booking and related actions. |
| **WhatsApp** | We use the **number they are messaging from** and match it to the patient profile **when possible**; same uniqueness and safety rules as guest web if mapping is ambiguous. |

---

## 1. Opening & scope

**Patient:** Hi, I need help with an appointment at Onco Global.

**Agent:** Hello — I’m Onco Global’s digital assistant. I can help you find hospitals and specialists, book or change appointments, and answer general questions about visits and preparation. I can’t diagnose conditions or replace your care team. What would you like to do today?

**Patient:** What can you actually do?

**Agent:** I can: list our centers and locations (including interactive facility cards in web chat); find a doctor by specialty or department; book, reschedule, or cancel an appointment (with a confirmation card after the action); check general prep and documents; share non-binding room-rate information where we have it; and help with common scheduling questions. For emergencies, please use emergency services or your nearest ER.

---

## 2. Hospital locations & facilities

**Patient:** Where are your hospitals in India?

**Agent:** I can list Onco Global hospitals from our network. Do you have a preferred city or state, or should I show all major locations?

**Patient:** I’m in Delhi NCR.

**Agent:** Here are facilities we have in the Delhi NCR area — you should see location cards in chat when available [**`HC_Get_Facilities`** → **`facilityListUi`**]. Would you like directions or to pick one for an appointment?

**Patient:** Which one has medical oncology?

**Agent:** I’ll check which Delhi NCR sites have medical oncology coverage through our provider network. One moment — [**`HC_Find_Specialist`** with specialty + city → **`directoryUi`**]. Site A and Site B both list medical oncologists. Would you like to book at one of these?

---

## 3. Nearest site / geo (coarse)

**Patient:** I’m traveling to Mumbai next week. Which hospital is closest to Bandra?

**Agent:** I can suggest facilities in the Mumbai area using our registered addresses — [**`HC_Get_Facilities`**]. For “closest,” I use location data we have on file; share a landmark or postal code to narrow further. None of this replaces GPS navigation apps for door-to-door directions.

---

## 4. Specialty & oncology navigation (Knowledge + directory)

**Patient:** What does “surgical oncology” mean at your network?

**Agent:** In general terms, surgical oncology focuses on cancer treatment that may involve surgery, as part of a larger care plan. Exact services vary by hospital and doctor. I can show you surgical oncologists at a location you choose, or link you to our general preparation articles — but I won’t interpret your symptoms or tell you which treatment you need.

**Patient:** Okay — show me surgical oncologists in Bengaluru.

**Agent:** Here are specialists matching surgical oncology in Bengaluru [**`HC_Find_Specialist`** → **`directoryUi`**]. Would you like to book with one of them, or only see the hospital list first?

---

## 4a. New vs returning guest — profile before scheduling (**Person Account**)

**Patient:** I’ve never been to Onco Global — I want to book my first visit.

**Agent:** Welcome — I can set that up. To schedule securely I’ll either match you to an existing profile or create a simple one. Have we seen you at Onco Global before, or is this your first time with us?

**Patient:** First time — I don’t have a record.

**Agent:** Thanks. I’ll collect a few details: your **full name**, **mobile number**, and **email** for confirmations. [Captures fields → **`HC_Create_Guest_Person_Account`** creates a **Person Account** only—no Lead.] Your profile is ready — we can continue with finding a slot.

**Patient:** Actually my mobile is the same as my spouse’s old file — will that clash?

**Agent:** If that number already matches **one** patient profile, we’ll use that record and won’t create a duplicate. If it matches more than one or none, I’ll explain the safe next step—sometimes that means our contact center helps merge or verify.

---

## 4b. Smart Navigator — symptom phrases (**education-only**)

Routing from common phrases to a **recommended specialty** uses **`Symptom_Specialty_Map__c`** + **`HC_SymptomRoutingInvocable`** (GenAi: **`HC_Route_Symptom_To_Specialty`**) — then **`HC_Find_Specialist`** with city + specialty. This is **not** triage or diagnosis.

**Patient:** I’ve had a lump in my neck for a few weeks — who should I see?

**Agent:** I’m sorry you’re dealing with that — I can’t examine you or say what it is. In our network, patients often **start with a consultation in medical oncology or ENT** depending on symptoms and local practice — I’ll use general routing guidance only. Which **city** are you looking at?

**Patient:** Jaipur.

**Agent:** Based on general navigation (**not** a diagnosis), medical oncology is a reasonable first scheduling step for many patients with that concern — here are oncologists in Jaipur: [**`HC_Route_Symptom_To_Specialty`** then **`HC_Find_Specialist`**]. Would you like to pick a doctor or see hospitals first?

**Patient:** Emergency — chest pain and sweating now.

**Agent:** That can be serious. Please **call emergency services or go to the nearest ER** now. I can’t assess emergencies in chat.

---

## 5. Doctor discovery — city + specialty

**Patient:** I need a medical oncologist in Hyderabad.

**Agent:** Here are medical oncologists practicing at our Hyderabad facilities [**`HC_Find_Specialist`** → **`directoryUi`**]. Who would you prefer, or should I pick the next available slot across these doctors?

**Patient:** Tell me more about the first doctor.

**Agent:** I can share what’s in our directory — name, hospital(s), and specialty focus. For detailed clinical fit, our scheduling team or the doctor’s office can help after you book a consultation.

---

## 6. Department browse (e.g. gynecology, pediatrics)

**Patient:** I don’t know the exact specialty — I need the women’s cancer department. Is that gynecology oncology?

**Agent:** Yes — many patients ask for “gynecology oncology” or GYN oncology. I’ll search our network for providers and departments mapped to that area [**`HC_Find_Specialist`** / catalog via **`HC_Patient_Data_Actions`** `SPECIALTIES` where useful]. Would you like doctors only, or hospitals that offer this service?

**Patient:** Doctors in Chennai.

**Agent:** Here are GYN oncology specialists linked to Chennai sites [**`HC_Find_Specialist`**]. Shall we start booking?

---

## 7. Book appointment — specific doctor

**Patient:** I want to book with Dr. Rao at your Chennai center next Tuesday afternoon.

**Agent:** I’ll check openings for that doctor and site for next Tuesday afternoon — [**`HC_Slot_Suggestion`** → **`slotUi`**]. I need your patient record — please confirm the mobile number we have on file, or your patient ID, so I can attach this booking safely.

**Patient:** My mobile is 98xxxxxx01.

**Agent:** Thank you. I found your profile as [PatientName]. Proposed slot: Tuesday, [DateTime], with Dr. Rao at [FacilityName]. Shall I confirm?

**Patient:** Yes, confirm.

**Agent:** Your appointment is confirmed [**`HC_Booking_Actions`** `BOOK` → **`bookingUi`** shows outcome]. Reference: [ConfirmationCode]. You’ll receive an SMS summary. A clinical visit record is created in our system for the care team. Anything else — prep instructions or directions?

---

## 8. Book appointment — department only (no named doctor)

**Patient:** I don’t care which doctor — I just need medical oncology in Gurgaon, any morning next week.

**Agent:** I’ll find the next available medical oncology slots across Gurgaon facilities for mornings next week — [**`HC_Slot_Suggestion`** → **`slotUi`**]. Option 1: [Facility A], Dr. [X], [DateTime]. Option 2: [Facility B], Dr. [Y], [DateTime]. Which should I book?

**Patient:** Option 1.

**Agent:** To book Option 1 I need to verify you — mobile or patient ID please.

**Patient:** [Provides verification]

**Agent:** Booked [**`HC_Booking_Actions`** → **`bookingUi`**]. Reference: [ConfirmationCode].

---

## 9. Slots / capacity (“how busy are you?”)

**Patient:** Is Tuesday very full at the Mumbai hospital?

**Agent:** I can share high-level availability — proposed times from [**`HC_Slot_Suggestion`**] reflect clinic capacity versus what’s already booked. Tuesday at [FacilityName] still has openings in several departments; exact counts change in real time. Would you like me to hold a specific time?

---

## 10. Modify appointment (reschedule)

**Patient:** I need to move my Thursday appointment to Friday same time.

**Agent:** I can help reschedule. Please confirm your mobile or patient ID, and if you know the appointment reference or hospital name, that speeds things up.

**Patient:** 98xxxxxx01, it was at Delhi.

**Agent:** I found a Thursday visit at [FacilityName]. Available Friday slots near the same time: [**`HC_Slot_Suggestion`**]. Pick one?

**Patient:** Friday 11:30.

**Agent:** Updated [**`HC_Booking_Actions`** `MODIFY` → **`bookingUi`**]. New time: Friday [DateTime] at [FacilityName]. Reference updated: [ConfirmationCode]. You should get a confirmation message shortly.

---

## 11. Cancel appointment

**Patient:** Cancel my appointment next Monday — I’m traveling.

**Agent:** I’m sorry you can’t make it. I’ll locate Monday’s booking — please verify mobile or patient ID.

**Patient:** [Verifies]

**Agent:** I see Monday [DateTime] with [Doctor] at [Facility]. Should I cancel this appointment?

**Patient:** Yes, cancel it.

**Agent:** It’s canceled [**`HC_Booking_Actions`** `CANCEL` → **`bookingUi`**]. If you’d like to rebook when you return, I can help find a new slot. Would you like that?

---

## 12. Insurance on file (read-only list)

**Patient:** Do you have my insurance details?

**Agent:** I can show what we have on file for your profile — payer name, plan label, and high-level status from our records [**`HC_Patient_Data_Actions`** `INSURANCE` + `patientAccountId`]. I don’t guarantee payment; final eligibility is determined at registration and with your payer.

**Patient:** What plans show up?

**Agent:** For [PatientName], we show: (1) [Payer] — [Plan] — status [Active/Pending/etc.]; (2) … If something looks wrong, you can upload an updated card or speak with registration at your visit.

---

## 13. Prerequisites before counselling (checklist)

**Patient:** I have a counselling session booked — what documents do I need?

**Agent:** For your upcoming counselling appointment, our checklist shows: [items from **`HC_Patient_Data_Actions`** `PREREQUISITES` + `serviceAppointmentId` — e.g. ID, insurance card, consent, lab report if required]. Items marked required must be completed before session. For a structured accordion in web chat, the agent can also call **`HC_Coverage_Prep_UI`**. Which item do you want to tackle first?

**Patient:** I uploaded my insurance card yesterday.

**Agent:** Thank you — I’ll reflect that against your appointment checklist when our system processes the file. If anything is still missing, I’ll list only the open items. You can also upload missing documents through your patient link or at the front desk.

---

## 14. Room rates (informational, non-binding)

**Patient:** How much is a private room per day at your Jaipur hospital?

**Agent:** For [FacilityName], our non-binding reference rates show: Private room — approximately [rate] per day for the current rate window [**`HC_Patient_Data_Actions`** `ROOM_RATES` + `healthcareFacilityId`]. Rates depend on acuity, insurance, and taxes — this is **not** a quote or guarantee. For a financial estimate, billing can help after admission planning.

**Patient:** What about ICU?

**Agent:** For ICU at the same site, the reference band is [rate] (`roomTypeApi` e.g. ICU). Again, this is illustrative only for planning conversations.

---

## 15. Returning patient / rebook (Booking_Session context)

**Patient:** I was there last month — book something similar in Kolkata.

**Agent:** Welcome back. I can use your last visit preferences where we have them [**`HC_Patient_Data_Actions`** `BOOKING_SESSION` upserts / reads context tied to `patientAccountId`]. Your last booking was [summary]. Should I search the same specialty in Kolkata for the next two weeks?

**Patient:** Yes, same specialty.

**Agent:** Here are next available options in Kolkata: [**`HC_Slot_Suggestion`**]. Which works?

---

## 16. Knowledge / FAQ (no database write)

**Patient:** What should I bring on the first visit?

**Agent:** Generally: a government-issued ID, insurance information, a list of current medications, and any prior reports you have. Your exact checklist can vary by appointment type — I can pull our patient FAQ article: [short summary from `Knowledge__kav`]. Want me to add prep to your calendar description in the confirmation SMS?

---

## 17. Check-in / arrival (informational)

**Patient:** When should I arrive?

**Agent:** Many sites ask you to arrive 15–20 minutes before your scheduled time for registration. Your confirmation shows [DateTime] — plan to be a little early. For check-in status updates, the front desk or kiosk will confirm when you’re checked in [`CheckedInTime` where used].

---

## 18. No results / graceful empty state

**Patient:** Do you have any surgical oncologists in Shillong?

**Agent:** I don’t see a surgical oncologist at our Onco Global locations in Shillong in the directory I queried. I can: show the nearest cities where we do have coverage, or help you leave a message for our contact center. Which do you prefer?

---

## 19. Verification failure / safety

**Patient:** Book an appointment for mobile 99xxxxxx99.

**Agent:** I couldn’t match that number to a patient profile in our system yet. You can: double-check the number; if you’re **new to Onco Global**, I can help create a **basic patient profile** (name, mobile, email) — **Person Account only** — then continue booking; or say **“contact center”** and I’ll share how to reach the team during business hours.

**Patient:** I’m new — let’s create the profile.

**Agent:** [Collects name, mobile, email → **`HC_Create_Guest_Person_Account`.] Your profile is set up. Let’s pick your appointment …

If **`HC_Resolve_Patient_By_Phone`** finds **more than one** patient for the same mobile, **do not** book or expose details—hand off per policy (unchanged).

---

## 20. Agent action logging (judge-visible behavior)

**Patient:** Find a radiation oncologist in Mumbai.

**Agent:** [After tool run] Here are radiation oncologists in Mumbai: [list].

*(Internal / demo narration: **`HC_Log_Agent_Action`** records the step; optional correlation with session / `Agent_Action_Log__c` if configured in your org.)*

---

## 21. Failure after tool / partial error

**Patient:** Book me any slot tomorrow at Gurgaon medical oncology.

**Agent:** I wasn’t able to complete the booking — [safe reason: e.g. no open slots / validation]. Nothing was confirmed. I can try another day or facility, or escalate you to scheduling. What would you like?

*(Demo: failed booking still returns **`bookingUi`** with failure styling when the invocable sets error fields — verify in Builder.)*

---

## 22. WhatsApp-style (short turns) — optional channel

**Patient:** Slots Gurgaon oncology tomorrow?

**Agent:** Few slots left tomorrow AM at [Facility A]; PM tighter. Want a specific time?

**Patient:** 10am any doc.

**Agent:** Need quick verify — reply with last 4 digits of registered mobile.

**Patient:** xx01

**Agent:** Booked 10:00 [Facility A], Dr. [X]. Ref [ConfirmationCode].

---

## 23. Escalation & boundaries

**Patient:** My tumor marker doubled — what should I do?

**Agent:** I’m not able to interpret lab results or give medical advice. Please message your care team through your portal or call your oncologist’s office directly. If you have sudden severe symptoms, use emergency services.

**Patient:** Connect me to a human for scheduling only.

**Agent:** For scheduling with a live agent, you can reach our contact center at [published number] during [hours]. I can also stay with you to find a self-service slot if you prefer.

---

## 24. Closing

**Patient:** That’s all, thanks.

**Agent:** You’re welcome. Your confirmations are on the way. Good luck with your visit — if anything changes, you can return here to reschedule or cancel. Take care.

---

## 25. Suggested demo run-through (~15 minutes, Enhanced Web Chat)

Use a **returning** seed patient (e.g. **Rajesh Kumar**, **`9876543211`**) so resolve + booking + patient-data actions succeed without creating a new account.

| Step | Say (patient side) | Expect (tools + UI) |
|------|--------------------|---------------------|
| 1 | “Where are your centers in Jaipur?” | **`HC_Get_Facilities`** — facility **cards** (`facilityListUi`). |
| 2 | “Show me medical oncologists in Jaipur.” | **`HC_Find_Specialist`** — directory **rows** (`directoryUi`). |
| 3 | “I had a neck lump for weeks — who should I see?” (then city Jaipur) | **`HC_Route_Symptom_To_Specialty`** → **`HC_Find_Specialist`**. |
| 4 | “Book the next available slot with [chosen doctor].” | Resolve phone → **`HC_Resolve_Patient_By_Phone`**; **`HC_Slot_Suggestion`**; confirm → **`HC_Booking_Actions`** — **confirmation card** (`bookingUi`). |
| 5 | “What insurance is on file?” | **`HC_Patient_Data_Actions`** `INSURANCE` (after `patientAccountId`). |
| 6 | “What do I need before my counselling session?” | **`PREREQUISITES`** (+ optional **`HC_Coverage_Prep_UI`** for accordion). |
| 7 | “Private room rate per day at [facility].” | **`ROOM_RATES`** with facility Id. |
| 8 | (Optional) “Move my appointment to Friday afternoon.” | **`HC_Slot_Suggestion`** + **`HC_Booking_Actions`** `MODIFY` — **`bookingUi`**. |

---

## Script → feature matrix (quick QA)

| # | Scenario | Primary GenAi / automation | Structured UI (when wired) |
|---|----------|----------------------------|----------------------------|
| 1 | Opening & scope | Instructions only | — |
| 2–3 | Locations & geo | **`HC_Get_Facilities`** | `facilityListUi` |
| 4 | Specialty education | Knowledge + **`HC_Find_Specialist`** | `directoryUi` |
| 4a | New vs returning guest | **`HC_Resolve_Patient_By_Phone`**, **`HC_Create_Guest_Person_Account`** | — |
| 4b | Smart Navigator (education-only) | **`HC_Route_Symptom_To_Specialty`**, **`HC_Find_Specialist`** | `directoryUi` |
| 5–6 | Doctor / department discovery | **`HC_Find_Specialist`**, optional **`HC_Patient_Data_Actions`** `SPECIALTIES` | `directoryUi` |
| 7–9 | Book (named / dept / capacity) | **`HC_Slot_Suggestion`**, **`HC_Booking_Actions`** | `slotUi`, `bookingUi` |
| 10–11 | Modify / cancel | **`HC_Slot_Suggestion`**, **`HC_Booking_Actions`** | `slotUi`, `bookingUi` |
| 12 | Insurance | **`HC_Patient_Data_Actions`** `INSURANCE` | summary text |
| 13 | Prerequisites / coverage prep | **`HC_Patient_Data_Actions`** `PREREQUISITES`; optional **`HC_Coverage_Prep_UI`** | `coveragePrepUi` |
| 14 | Room rates | **`HC_Patient_Data_Actions`** `ROOM_RATES` | summary text |
| 15 | Rebook | **`HC_Patient_Data_Actions`** `BOOKING_SESSION`, **`HC_Slot_Suggestion`** | `slotUi` |
| 16 | FAQ | `Knowledge__kav` | — |
| 17 | Check-in copy | `ServiceAppointment` (times) | — |
| 18–19 | Empty / verify fail / new guest | **`HC_Resolve_Patient_By_Phone`**, **`HC_Create_Guest_Person_Account`** | — |
| 20–21 | Logging / failures | **`HC_Log_Agent_Action`**; booking faults still populate **`bookingUi`** where implemented | `bookingUi` |
| 22 | WhatsApp tone | Same actions, shorter copy | platform-dependent |
| 23 | Escalation | Policy / handoff | — |
| 24 | Close | — | — |
| 25 | End-to-end demo | §25 table | All mapped types |

---

*Extend scripts when you add Care programs (`CareProgram`, `CareProgramEnrollee`) or Messaging (`MessagingSession`).*
