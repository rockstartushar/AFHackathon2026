# HC_SlotSuggestionInvocable — Limitations vs Production Scheduling

**Document purpose:** This document outlines the **known limitations** of the `HC_SlotSuggestionInvocable` Approach A implementation compared to production-grade scheduling systems. Use this as a reference when discussing scope with stakeholders or planning future enhancements.

**Related documentation:**
- `docs/Data-Model-Objects-And-Fields.md` § Slot suggestion algorithm (Approach A)
- `docs/BOOKING_PATTERN.md` § Slot discovery → BOOK

---

## Executive Summary

`HC_SlotSuggestionInvocable` implements **Approach A**: a simplified slot discovery engine that:
- ✅ Reads `OperatingHours` + `TimeSlot` to find weekly open windows
- ✅ Subtracts booked `ClinicalEncounter` rows (facility-wide or provider-specific)
- ✅ Respects `Max_Daily_Appointments__c` daily capacity cap
- ✅ Outputs `slotsJson` (for LWC) and `summaryText` (for agent chat)
- ✅ Aligns datetime handling with `HC_BookingActionsInvocable` inputs

However, it is **NOT** a production-grade scheduling engine. For enterprise healthcare scheduling with advanced requirements, use **Salesforce Scheduler**, **Field Service Lightning (FSL)**, or third-party scheduling platforms.

---

## Detailed Limitations

### 1. Fixed Slot Duration
**Limitation:** All slots have the same fixed length (default 30 minutes, configurable via `slotDurationMinutes` parameter).

**Production need:** Different appointment types require different durations:
- Initial consultation: 60 minutes
- Follow-up visit: 30 minutes
- Procedure: 90+ minutes

**Workaround for hackathon:** Pass different `slotDurationMinutes` values per appointment type, or post-process results to filter by required duration.

**Production solution:** Integrate with `WorkType` or custom appointment type metadata to dynamically determine slot length.

---

### 2. No Field Service Lightning (FSL) APIs
**Limitation:** Does not use:
- `AppointmentBookingService.getSlots` (native FSL slot API)
- `FSL__Scheduling_Policy__c` (work rules, skill matching, optimization)
- FSL slot grading or multi-criteria scoring

**Production need:** FSL provides advanced features like:
- Travel time calculations between appointments
- Technician/resource skill matching
- Optimization algorithms (minimize drive time, maximize utilization)
- Real-time dispatching and emergency slot insertion

**Workaround for hackathon:** Manually select providers and facilities; do not rely on automatic resource assignment.

**Production solution:** Enable FSL and use `AppointmentBookingService` or `Scheduling API` for full scheduling capabilities.

---

### 3. No Territory / Resource Graph
**Limitation:** Does not consider:
- `ServiceTerritory` boundaries
- `ServiceResource` availability or work hours
- `ServiceTerritoryMember` assignments

**Production need:** Healthcare organizations often manage:
- Multi-site provider networks (territories)
- Resource pools (nurses, equipment, rooms)
- Complex assignment rules (primary care vs specialist territories)

**Workaround for hackathon:** Scope to single facility + single provider (or facility-wide open slots only).

**Production solution:** Model territories and resources; use FSL territory-aware scheduling.

---

### 4. No Travel Time, Break Time, or Buffer
**Limitation:** Slots are generated back-to-back with no gaps for:
- Provider breaks (lunch, coffee breaks)
- Travel time between locations (mobile providers)
- Setup/cleanup time between appointments
- Administrative buffer (charting, follow-up calls)

**Production need:** Realistic schedules must account for:
- 15-minute buffer between appointments for cleaning/setup
- 30-minute lunch break for providers
- Travel time for home health or mobile clinic scenarios

**Workaround for hackathon:** Manually reduce operating hours in `TimeSlot` to reflect breaks, or post-process slot list to insert gaps.

**Production solution:** Use FSL `Scheduling Policy` with break rules, or custom logic to inject buffer slots.

---

### 5. Simple Conflict Detection (Overlap Check Only)
**Limitation:** Conflict detection is binary (overlaps = conflict, no overlap = available). Does not prevent:
- **Partial overlaps** (e.g., 30-minute slot starting at 10:15 when a 60-minute appointment runs 10:00–11:00)
- **Near-misses** (slot ends at 11:00, next appointment starts at 11:00 with no buffer)
- **Overbooking scenarios** (multiple providers, shared resources)

**Production need:** Advanced systems use:
- Fine-grained overlap rules (block 15 minutes before/after each appointment)
- Resource contention detection (two appointments need same exam room)
- "Soft" vs "hard" conflicts (warn but allow override for emergencies)

**Workaround for hackathon:** Ensure `slotDurationMinutes` matches actual appointment duration; avoid back-to-back booking edge cases.

**Production solution:** Implement buffer logic in slot generation, or use FSL resource-aware scheduling.

---

### 6. Timezone Handling Assumptions
**Limitation:** Relies on `OperatingHours.TimeZone` field; assumes:
- All facilities in the same timezone (or each facility has correct timezone)
- `TimeSlot.StartTime` / `EndTime` are in facility local time
- No daylight saving time edge case handling (e.g., missing hour on DST transition)

**Production need:** Multi-region healthcare networks require:
- Automatic timezone conversion for patients in different zones
- DST-aware scheduling (e.g., no appointments at 2:30 AM on spring-forward day)
- Display times in patient local timezone vs facility timezone

**Workaround for hackathon:** Test with facilities in `Asia/Kolkata` timezone only (no DST in India).

**Production solution:** Use Salesforce timezone utilities (`Timezone.getTimeZone()`, `format()` with explicit timezone) and handle DST transitions explicitly.

---

### 7. No Slot Hold / Reservation Mechanism
**Limitation:** Slots returned by `HC_SlotSuggestionInvocable` are **suggestions only**. No lock prevents:
- Two patients selecting the same slot simultaneously
- Slot becoming unavailable between suggestion and booking

**Production need:** Real-world booking systems use:
- Temporary slot holds (5-minute reservation while patient completes form)
- Optimistic locking (detect double-booking, retry with next available slot)
- Queue management (waitlist for popular times)

**Workaround for hackathon:** Accept that double-booking may occur in high-concurrency scenarios; rely on `HC_BookingActionsInvocable` daily cap check to reject excess bookings.

**Production solution:** Implement custom `Slot_Hold__c` object with expiration logic, or use FSL slot reservation APIs.

---

### 8. Hard Daily Cap (Not Gradual Capacity Scoring)
**Limitation:** `Max_Daily_Appointments__c` is binary:
- Below cap → all slots shown
- At cap → no slots shown (even if only 1 slot away from cap)

**Production need:** Gradual capacity scoring:
- Show "high demand" warning when 80% full
- Prioritize certain appointment types (urgent vs routine) when near capacity
- Dynamic capacity based on provider type (attending vs resident)

**Workaround for hackathon:** Set conservative daily caps; accept binary behavior.

**Production solution:** Implement weighted capacity scoring (e.g., routine = 1 point, urgent = 2 points, total cap = 100 points).

---

### 9. No Equipment, Room, or Multi-Resource Constraints
**Limitation:** Only checks facility + provider availability. Does not consider:
- Exam room availability (2 providers share 3 rooms)
- Equipment availability (MRI machine booked for maintenance)
- Support staff availability (nurse, anesthesiologist for procedures)

**Production need:** Complex appointments require:
- Multi-resource scheduling (provider + room + equipment + staff)
- Conflict detection across resource pools
- Priority rules (surgery blocks MRI, but imaging does not block clinic rooms)

**Workaround for hackathon:** Scope to simple outpatient visits (assume infinite rooms/equipment).

**Production solution:** Model resources as `ServiceResource` with dependencies; use FSL multi-resource scheduling.

---

### 10. No Dynamic Duration Based on Appointment Type
**Limitation:** Slot duration is fixed per invocation call. Does not:
- Read `WorkType.DurationType` or `EstimatedDuration`
- Adjust slot length based on appointment reason (new patient vs follow-up)
- Support variable-length appointments (30–60 minute range)

**Production need:** Appointment types have different durations:
- Telehealth: 15 minutes
- In-person new patient: 60 minutes
- Procedure: 90 minutes

**Workaround for hackathon:** Call `HC_SlotSuggestionInvocable` multiple times with different `slotDurationMinutes` if needed, or standardize to 30 minutes.

**Production solution:** Pass `appointmentTypeId` or `workTypeId` and query duration; filter slots accordingly.

---

### 11. No Partial Day or Split Shift Support
**Limitation:** `TimeSlot` rows define full windows (e.g., 9 AM – 5 PM). Does not:
- Handle split shifts (9–12, 2–5 with lunch break)
- Block out ad-hoc unavailability (provider in surgery 10–11 AM on specific date)

**Production need:** Providers have:
- Variable schedules (mornings only on Mondays, afternoons only on Fridays)
- One-off blocks (conference, training, surgery)

**Workaround for hackathon:** Create separate `OperatingHours` records for split shifts, or manually create `ClinicalEncounter` "block" rows to mark unavailability.

**Production solution:** Implement `Provider_Exception__c` custom object for ad-hoc blocks, or use FSL `ResourceAbsence`.

---

### 12. No Waitlist or Overbooking Logic
**Limitation:** When no slots are available, returns empty list. Does not:
- Offer waitlist registration
- Suggest alternative dates
- Allow intentional overbooking (common in primary care to account for no-shows)

**Production need:** Healthcare organizations often:
- Maintain waitlists for high-demand providers
- Overbook by 10% to compensate for no-shows
- Suggest "next available" across multiple facilities

**Workaround for hackathon:** Agent manually suggests alternative dates or facilities.

**Production solution:** Implement `Waitlist__c` object; add overbooking factor to capacity logic.

---

## When to Use This Implementation

✅ **Good fit for:**
- **Hackathon / proof-of-concept** demos with simple scheduling needs
- **Low-volume clinics** (< 50 appointments/day, single facility)
- **Basic outpatient scheduling** (no procedures, no multi-resource constraints)
- **Agentforce conversational booking** where agent guides patient through slot selection

❌ **Not suitable for:**
- **High-volume hospitals** with hundreds of daily appointments
- **Multi-site networks** requiring territory management
- **Procedure scheduling** with equipment/room/staff dependencies
- **Mobile health** scenarios with travel time calculations
- **Real-time dispatch** or emergency scheduling

---

## Migration Path to Production Scheduling

If your organization needs production-grade scheduling, consider these upgrade paths:

### Path 1: Salesforce Scheduler (Recommended for Health Cloud)
- Enable **Salesforce Scheduler** product
- Use `AppointmentBookingService.getSlots` API
- Model appointment types with `WorkType` and `SchedulingConstraint`
- Leverage native slot grading and multi-criteria scoring

### Path 2: Field