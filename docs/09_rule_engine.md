# ZRAP_MT — Rule Engine

**Phase 1 — Doc 9/12.**

## 1. Data-Driven Classification

`ZRAP_MT_RULE` (Doc 3 §3) is the entire rule engine's state — no
classification logic is hardcoded in ABAP beyond "evaluate this pattern
against this finding." Seed data for Phase 1, matching §8's example table
exactly:

| RULE_ID | PATTERN | MATCH_TYPE | CATEGORY | CLASSIFICATION |
|---|---|---|---|---|
| `SMARTFORM` | (object type = SMFR) | LITERAL | Forms | BLOCKER |
| `SAPSCRIPT` | (object type = SCRP) | LITERAL | Forms | BLOCKER |
| `CALL_SCREEN` | `CALL SCREEN` | REGEX | Dynpro | BLOCKER |
| `DYNPRO` | (object type = DYNP) | LITERAL | Dynpro | BLOCKER |
| `NUMBER_GET_NEXT` | `NUMBER_GET_NEXT` | REGEX | Number Range | CONFIG |
| `AUTHORITY_CHECK` | `AUTHORITY-CHECK` | REGEX | Authorization | REVIEW |
| `REUSE_ALV` | `REUSE_ALV` | REGEX | Output | WARNING |

## 2. Evaluation

```abap
CLASS zcl_rap_mt_rule_engine DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS classify
      IMPORTING it_findings        TYPE zrap_mt_t_raw_finding
      RETURNING VALUE(rt_blockers) TYPE zrap_mt_t_blk_finding.
ENDCLASS.
```

Loaded once per scan (not once per finding — a scan can produce thousands
of findings, and re-querying `ZRAP_MT_RULE` per finding would be a real
performance mistake, not just an inefficiency), then evaluated in-memory
against every `ZCL_RAP_MT_DET_OPT` / detector finding. `MATCH_TYPE =
REGEX` uses `FIND REGEX`; `LITERAL` matches object type or exact function
module name.

## 3. Extensibility — the actual mechanism behind §8's "must plug in"

Adding `BRF+`, `Workflow`, `CPI`, `Fiori`, `CDS`, `Gateway` detection
(§8's explicit future list) means: (1) a new detector class discovering
the relevant objects, registered in `ZRAP_MT_DETREG`, and (2) new rows in
`ZRAP_MT_RULE` classifying what that detector finds. **Zero changes** to
`ZCL_RAP_MT_RULE_ENGINE` itself — this is the concrete proof that §8's
requirement is met, not an assertion of it.

## 4. Multiple Rules Matching One Finding

Not addressed in the original constitution — flagging as a small decision:
if a finding matches more than one active rule (e.g. a custom pattern
someone adds later overlaps with a seed rule), **highest severity wins**
(`BLOCKER` > `WARNING` > `REVIEW` > `CONFIG`), and all matching
`RULE_ID`s are still recorded (not just the winning one) so the UI can
show "also matched: ..." rather than silently hiding a secondary match.
