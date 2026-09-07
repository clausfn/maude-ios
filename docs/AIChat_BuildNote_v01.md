# Maude Assistant (wellness-scope AI chat) — Build Note v01

_2026-06-09. Scope authority: 06_Regulatory/Maude_CounselMemo_AIChat_WellnessScope_v01_20260609.docx._

**Where inference runs.** Fully **on-device and deterministic**. The MVP ships a
rule-based descriptive responder (`LocalDataResponder`) that reports the user's own
summarised metrics (glucose avg/TIR, sleep, resting HR, steps). There is **no LLM
yet** — so model/version = *none (deterministic)*. A real on-device model (candidate:
**Mistral**, via MLX or llama.cpp) can later implement the `ChatResponder` protocol
**behind the same deterministic guard, unchanged**.

**The guard is the compliance core.** `ChatGuard` sits between any responder/model
and the UI (not a prompt instruction — models drift). Two layers: `inputIsOutOfScope`
refuses prediction/prognosis/diagnosis/symptom/triage/treatment **requests** before
generation; `sanitizeOutput` blocks/rewrites drifting **responses** (→ the single
static safety line), strips imperative advice, and silently strips sexual-function
meds. 10 acceptance tests (`MaudeTests/ChatGuardTests`) green, incl. all red-team
prompts → safety line.

**Cloud / "Enhanced" mode is NOT built.** Its consent toggle is present but disabled;
cloud is never the default.

**Where quality forced a decision.** Ship a real LLM now (richer language, but drift
risk + on-device model size/latency) vs the deterministic responder (compliant by
construction, narrower phrasing). MVP chose **deterministic** to guarantee the
non-MDSW boundary. Enabling an on-device LLM and/or the cloud "Enhanced" mode is the
**open decision** (flagged to DfG Works → `01 — Decisions Needed`).

**Privacy.** Chat history is **in-memory only** (never written to disk); one-tap
withdrawal purges it and resets all three consents. The rest of the app works fully
if the user declines. Persistent AI label shown on every chat screen (EU AI Act
Art. 50). Brand/chrome/nav unchanged; entry point is one row in the profile sheet
(placement is a UX decision — see below).

**Open decisions for sign-off**
1. AI model: (a) keep deterministic describer [default], (b) on-device LLM (Mistral),
   (c) cloud "Enhanced" mode (separate consent, EU data flow).
2. Entry-point placement: profile-sheet row (current) vs a more prominent surface
   (note: the tab bar is locked — promoting it is a nav decision).
