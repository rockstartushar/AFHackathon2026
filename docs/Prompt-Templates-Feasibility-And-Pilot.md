# Prompt templates — feasibility and pilot (Onco Global Patient Agent)

This document records **feasibility**, the **first pilot** (one template), and how to **scale to a few more** if the pilot succeeds. It aligns with `docs/Org-Build-Checklist.md`, the frozen automation scope (HC Apex/Flow owns facts and bookings), and Salesforce’s model of **prompt templates as single-turn generative actions** (not replacements for routing or tools).

---

## Feasibility verdict

**Feasible and suitable for a bounded pilot**, provided the org has **Einstein / Agentforce / Prompt Builder** entitlements and generative features enabled (same prerequisite family as checklist row **0**).

| Criterion | Assessment |
| --------- | ---------- |
| **Platform support** | **Yes.** Agent actions can invoke Prompt Builder templates via `GenAiFunction` with `invocationTargetType` = **`generatePromptResponse`** and `invocationTarget` referencing the template (see [GenAiFunction](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_genaifunction.htm)). Templates are deployable as **`GenAiPromptTemplate`** under `genAiPromptTemplates/` (see [GenAiPromptTemplate](https://developer.salesforce.com/docs/atlas.en-us.api_meta.meta/api_meta/meta_genaiprompttemplate.htm)). |
| **Fit for Onco architecture** | **Yes**, if templates **only polish or structure text** already produced by **`HC_PatientDataActionsInvocable`** (and similar tools). Facts, eligibility, and booking remain **Apex/Flow** per checklist rows **12–17**. |
| **Repo alignment** | **`Coverage_prep`** topic already wires **`HC_Patient_Data_Actions`** and **`HC_Log_Agent_Action`** in `Onco_Global_Patient_Agent.genAiPlannerBundle`. Adding one generative action here does not change data model or invocable contracts. |
| **Risk controls** | Instructions in the template must state: use **only** supplied tool output; **no** clinical advice; **non-binding** financial/rate language; no invented plans or numbers. Optional: log via existing **`HC_Log_Agent_Action`** when testing. |

**Not suitable** for: phone verification, directory lookup, booking, or symptom→specialty routing — those stay deterministic per freeze and checklist.

---

## Pilot #1 (recommended): patient-facing prose after coverage/prep data

**Goal:** After **`HC_Patient_Data_Actions`** returns plain-text summaries (e.g. `INSURANCE`, `PREREQUISITES`, `ROOM_RATES`), a **Flex** prompt template rewrites the assistant reply into **consistent, empathetic, policy-safe language** without changing underlying facts.

**Why this pilot**

- Single topic (**Coverage & prep**), one established tool chain.
- Clear separation: **tool = truth**, **template = tone and clarity**.
- Easy to judge success (readability, disclaimers, no hallucinated benefits).

**Template design (conceptual)**

- **Type:** Flex (`einstein_gpt__flex` in metadata).
- **Inputs:** Prefer **one primary multiline string** input (e.g. “`RawSummaryFromTool`”) fed with the **exact** text returned by `HC_Patient_Data_Actions` for the chosen operation. Keep **Flex inputs ≤ 5** per product guidance.
- **Prompt body:** Instruct the model to produce a short patient-facing message that **only restates** the provided facts; include mandatory disclaimers (non-binding rates, not a coverage guarantee, not medical advice).
- **Model:** Start with your org’s default / general model; adjust if latency or quality requires it.
- **Status:** **Published** version only — agent actions will not reliably use a draft.

**Agent / topic instruction tweak (in Agent Builder)**

- After calling **`HC_Patient_Data_Actions`** and receiving output, call the **new prompt template action** with that output as input **when** a natural-language reply is needed.
- Do **not** use the template **instead of** the tool; order is **tool first**, **template second**.

---

## Implementation sequence (org first, then source)

Order matches checklist deploy discipline (**dependencies → action → topic/agent**):

1. **Verify prerequisites:** Einstein / Prompt Builder / Agentforce enabled; runtime user can invoke generative actions (permission sets on **Einstein Agent** / integration user).
2. **Create** the Flex template in **Prompt Builder**; test in builder; **publish** a version.
3. **Add an agent action** that invokes the template (Service Agent / Agent Builder UI: new action from prompt template, or metadata — see below).
4. **Attach the action** to the **Coverage & prep** topic only (pilot scope).
5. **Preview** in Agent Builder: insurance / prereq / room-rate questions with seeded data.
6. **Retrieve** into the repo: `GenAiPromptTemplate`, updated `GenAiPlannerBundle` (and `GenAiFunction` if defined as a standalone asset). Use manifest entries for `GenAiPromptTemplate` (and `GenAiFunction` if applicable).

Metadata references:

- [Get Started with Prompt Builder](https://developer.salesforce.com/docs/ai/agentforce/guide/get-started-prompt-builder.html) (including moving templates via Metadata API).
- [Agents metadata](https://developer.salesforce.com/docs/ai/agentforce/references/agents-metadata-tooling/agents-metadata.html) for your API version.

---

## Success criteria for pilot #1

Use these to decide whether to add **pilot #2+** (e.g. slot-list prose after **`HC_SlotSuggestionInvocable`**, escalation wording).

| Measure | Pass |
| ------- | ---- |
| **Factual fidelity** | No plan names, amounts, or dates that did not appear in tool output (spot-check 10 runs). |
| **Compliance tone** | Disclaimers present when rates/coverage mentioned; no guarantees. |
| **Latency** | Acceptable for demo path (subjective; note model choice). |
| **Credits / limits** | Team accepts incremental generative usage per conversation. |
| **Operational** | Published template + retrieve/deploy path documented for the team. |

---

## Follow-on templates (if pilot #1 passes)

| Priority | Topic | Tool output to pass in | Notes |
| -------- | ----- | ------------------------ | ----- |
| 2 | **Scheduling_visits** | JSON or text from **`HC_SlotSuggestionInvocable`** (when implemented) | Turn structured slots into readable options; still no invented times. |
| 3 | **Escalation** | Minimal context (e.g. reason string) | Consistent handoff script; pair with queue/Messaging (checklist row **31**). |

Each addition should be **one template + one topic**, then retrieve and commit metadata.

---

## Related documents

- `docs/Org-Build-Checklist.md` — build order, licensing note, Agentforce rows **20–22**.
- `docs/Data-Model-Objects-And-Fields.md` — objects behind patient data actions.

---

*Last updated: Apr 2026. Revisit when Salesforce updates Agent Builder UI or `GenAiPromptTemplate` schema for your target API version.*
