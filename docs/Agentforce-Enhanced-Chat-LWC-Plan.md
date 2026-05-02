# Enhanced Chat v2 — Custom Lightning Types & LWCs (Service Agent)

**Prereq:** Embedded Service deployment uses **Enhanced Chat v2** (done in your org).

This doc is the **single plan** for which **Lightning Type bundles**, **Apex UI models**, **LWCs**, and **agent actions** line up. Implementation is in `force-app/` as listed below.

---

## Custom chat shell (Web v2) — header LWC *(optional)*

This is **separate** from **agent output** renderers (`hcFacilityCardList`, `hcDirectoryResultsRenderer`, …). Salesforce lets you replace the **conversation window header** in **Setup → Embedded Service Deployments → [your deployment] → Custom UI Components → Web (v2)**.

| Item | Detail |
|------|--------|
| **Component** | `hcEnhancedChatHeader` — target **`lightningSnapin__MessagingHeader`** only ([Customize the Header](https://developer.salesforce.com/docs/service/messaging-web/guide/customize-header.html)). |
| **Behavior** | Branded title (default **Onco Global**), listens for **`UPDATE_HEADER_TEXT`** to sync title, **Minimize** and **Close** dispatch **`MINIMIZE_BUTTON_CLICK`** / **`CLOSE_CONTAINER`**. |
| **Configure** | Deploy the LWC → open the deployment → **Custom UI Components** → **Web (v2)** → **Header** → choose **HC Enhanced Web Chat Header** → **Save** → **Publish** the deployment. |
| **More events** | [Messaging Conversation Window Header Events](https://developer.salesforce.com/docs/service/messaging-web/guide/customize-header-events.html) (menu, back, end conversation, etc.). |

Other v2 slots (e.g. **Minimized**) use different targets such as **`lightningSnapin__Minimized`** — not included in this repo unless you add them.

---

## What we ship (phase 1)

| Lightning Type bundle (folder) | Apex model (`global`) | Channel folder | LWC renderer | Agent action (GenAi / Apex) |
| ------------------------------ | ---------------------- | -------------- | ------------ | --------------------------- |
| `lightningTypes/HCSlotSuggestionUi` | `HCSlotSuggestionUiModel` (`payload` = same JSON as `slotsJson` + `facilityName`) | `enhancedWebChat` | `hcSlotSuggestionRenderer` | **HC_Slot_Suggestion** → `HC_SlotSuggestionInvocable` |
| `lightningTypes/HCDirectoryUi` | `HCDirectoryUiModel` (`payload` = JSON `{ summaryText, rows[] }` with Ids) | `enhancedWebChat` | `hcDirectoryResultsRenderer` | **HC_Find_Specialist** → `HC_DirectoryInvocable` |

The **`HC_Get_Facilities`** **Flow** (`flows/HC_Get_Facilities.flow-meta.xml`) remains available for **Flow-only** callers (plain-text `output_FacilitySummary`). The **GenAi** action **HC_Get_Facilities** targets **`HCFacilityListInvocable`** (Apex) for **`summaryText` + `facilityListUi`**.

---

## Phase 2 (implemented)

| Lightning Type bundle | Apex model | LWC | Agent action |
| --------------------- | ---------- | --- | ------------ |
| `lightningTypes/HCFacilityListUi` | `HCFacilityListUiModel` | `hcFacilityCardList` | **HC_Get_Facilities** → `HCFacilityListInvocable` |
| `lightningTypes/HCBookingConfirmationUi` | `HCBookingConfirmationUiModel` | `hcBookingConfirmationRenderer` | **HC_Booking_Actions** → `HC_BookingActionsInvocable` (`bookingUi` on every path) |
| `lightningTypes/HCCoveragePrepUi` | `HCCoveragePrepUiModel` | `hcCoveragePrepAccordion` | **HC_Coverage_Prep_UI** → `HCCoveragePrepUiInvocable` |

Narrative **`HC_Coverage_Prep_Patient_Facing`** (prompt template) is unchanged—use **HC_Coverage_Prep_UI** when you want the accordion in chat alongside or instead of long prose.

---

## GenAiPlannerBundle

`Onco_Global_Patient_Agent.genAiPlannerBundle` in the repo embeds **Scheduling** (guest + facilities + slot + book), **Provider Matching** (symptom route + directory), and **Coverage prep** (prompt template). Deploy it so the **agent container** matches standalone `GenAiPlugin` assets; then configure **output rendering** below.

After adding phase 2 actions, **attach** the new GenAi functions (**HC_Coverage_Prep_UI**) to the appropriate topic/plugin in Agent Builder if they are not yet in the planner bundle.

---

## Wiring in Agent Builder (required after deploy)

Deploy registers types + LWCs + **invocable outputs**. Tell each action to **display** the custom Lightning type for the structured output variable:

1. **HC Slot Suggestion** → **slotUi** / **`HCSlotSuggestionUiModel`** (see phase 1).
2. **HC Find Specialist** → **directoryUi** / **`HCDirectoryUiModel`** (see phase 1).
3. **HC Get Facilities** → **facilityListUi** / **`HCFacilityListUiModel`** (bind `facilityListUi`, not only `summaryText`).
4. **HC Booking Actions** → **bookingUi** / **`HCBookingConfirmationUiModel`** (shows BOOK/MODIFY/CANCEL outcome card).
5. **HC Coverage Prep UI** → **coveragePrepUi** / **`HCCoveragePrepUiModel`** (structured checklist).

If the UI lists multiple outputs, choose the variable bound to the **`Ui`** field (`slotUi`, `directoryUi`, etc.), not only plain **`summaryText`**.

---

## LWC `sourceType` in `js-meta.xml` (optional)

Salesforce may reject a **single deploy** when `lightning__AgentforceOutput` declares `<sourceType name="c__..."/>` **before** the Lightning Type exists in the org. This repo ships LWCs **without** that tag so CI deploy succeeds; binding is via **LightningTypeBundle** `renderer.json` + Builder.

**Optional tighten:** after types exist in the org, add `<sourceType name="c__..."/>` for each **`UiModel`** you use and redeploy **LWCs only**.

---

## Troubleshooting (text only in Enhanced Chat v2)

1. **GenAi `output/schema.json` must list every invocable output**, including **`directoryUi`**, **`slotUi`**, **`facilityListUi`**, **`bookingUi`**, **`coveragePrepUi`**. If a field is missing from the schema, Agent Builder cannot bind **Output rendering** to your Lightning type and the runtime may only surface **`summaryText`**. This repo had **`directoryUi` omitted** on **HC_Find_Specialist** and **no input/output schemas** on **HC_Slot_Suggestion** — both are fixed in `genAiFunctions/`.
2. **`enhancedWebChat/renderer.json`**: the org may expect both top-level **`renderer`** and nested **`collection.renderer`** (same LWC). If your bundle only had `renderer`, deploy the updated files under `lightningTypes/*/enhancedWebChat/renderer.json`.
3. **Retrieve errors** (`Input LightningTypeBundle schema for action 'HC_Slot_Suggestion' could not be found`): usually fixed after **slot** input/output schemas deploy; if retrieve still fails, temporarily **remove and re-add** **HC Slot Suggestion** from the agent in Builder, or retrieve without **`GenAiPlannerBundle`** / **`HC_Slot_Suggestion`** using `manifest/package-retrieve-agent-enhanced-chat.xml` (see comments in that file).

---

## JSON contracts

### Slots (`HCSlotSuggestionUiModel.payload`)

Same structure as `slotsJson` today: `facilityId`, `providerId`, `date`, `slotMinutes`, `facilityName`, `slots[]` with `start`, `end`, `label`.

### Directory (`HCDirectoryUiModel.payload`)

```json
{
  "summaryText": "...",
  "rows": [
    {
      "providerId": "0cm...",
      "facilityId": "0kl...",
      "providerName": "...",
      "facilityName": "...",
      "line": "- Provider @ Facility"
    }
  ]
}
```

### Facilities (`HCFacilityListUiModel.payload`)

```json
{
  "summaryText": "...",
  "rows": [
    { "facilityId": "0kl...", "facilityName": "...", "line": "- Name (Id)" }
  ]
}
```

### Booking confirmation (`HCBookingConfirmationUiModel.payload`)

```json
{
  "operation": "BOOK|MODIFY|CANCEL|UNKNOWN",
  "success": true,
  "headline": "Visit booked",
  "message": "Booked",
  "serviceAppointmentId": "08p...",
  "clinicalEncounterId": "0kG...",
  "clinicalEncounterProviderId": "0kM...",
  "schedStart": "2026-05-15T04:30:00.000Z",
  "schedEnd": "2026-05-15T05:30:00.000Z",
  "facilityName": "Onco Global ...",
  "subject": "Outpatient visit"
}
```

`schedStart` / `schedEnd` / `facilityName` / `subject` may be null (e.g. CANCEL or errors).

### Coverage prep (`HCCoveragePrepUiModel.payload`)

```json
{
  "summaryText": "...",
  "sections": [
    { "title": "Bring with you", "items": ["..."] }
  ]
}
```

---

## Related automation changes

- `HC_SlotSuggestionInvocable`: sets **`slotUi`** when slots JSON is built; adds **`facilityName`** into JSON.
- `HC_DirectoryInvocable`: builds **`directoryUi`** for every response path.
- `HCFacilityListInvocable`: mirrors **`HC_Get_Facilities`** flow filters; sets **`facilityListUi`**.
- `HC_BookingActionsInvocable`: sets **`bookingUi`** for BOOK, MODIFY, CANCEL (success and failure).
- `HCCoveragePrepUiInvocable`: static non-PHI demo sections; sets **`coveragePrepUi`**.

---

*Last updated: phase 2 facility list, booking confirmation, and coverage prep UI.*
