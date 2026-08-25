# ZRAP_MT — Solution Architecture

**Phase 1: RAP Dependency Intelligence Platform**
Status: DRAFT — awaiting architecture approval before any ABAP is written (per Golden Constitution §20).

---

## 1. Scope Recap

Phase 1 builds a system of record for ECC→RAP migration dependencies: discover,
verify, persist, version, and export. Explicitly **out of scope**: RAP
conversion, CDS generation for the *target* app, Behavior Definition
generation, AI-driven conversion. This document only architects the Phase 1
platform itself.

## 2. Layered Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Fiori Elements UI (9 pages, §14)                            │
│  + one freestyle UI5 extension (Dependency Explorer tree)    │
├─────────────────────────────────────────────────────────────┤
│  Service Binding (OData V4, UI)                              │
├─────────────────────────────────────────────────────────────┤
│  Service Definition — ZRAP_MT_UI_SRVD                        │
├─────────────────────────────────────────────────────────────┤
│  CDS Projections (ZC_RAP_MT_*) + Behavior Projections         │
├─────────────────────────────────────────────────────────────┤
│  CDS Interface Views (ZI_RAP_MT_*) + Root Behavior Definition │
│  (custom actions: RunScan, SaveVersion, GenerateMigrationPkg) │
├──────────────────────────────┬──────────────────────────────┤
│  Persistence (ZRAP_MT_* tbls)│  Execution-time components:   │
│                               │   - Detector Framework (§16)  │
│                               │   - Rule Engine (§8)          │
│                               │   - Delta Engine (§9)         │
│                               │   - TR Generator (§13)        │
│                               │   - Document Store Adapter    │
│                               │     (OpenText, §10)           │
└──────────────────────────────┴──────────────────────────────┘
```

The right-hand column is **not** CDS/Behavior logic — it's plain ABAP OO,
invoked from RAP action implementations in the behavior pool. This keeps
"discover/analyze/compare" logic reusable, unit-testable in isolation from
the RAP runtime, and independently extensible (§6/§16/§19).

## 3. RAP Object Type — Managed, Non-Draft

**Decision: Managed RAP Business Object, non-draft, with custom actions.**

Rationale:
- The root (Migration Workspace) needs standard CREATE, and several
  non-CRUD operations (`RunScan`, `SaveVersion`, `GenerateMigrationPackage`)
  — a natural fit for managed BO custom actions rather than hand-rolled
  unmanaged SAVE logic.
- **Non-draft**, not draft: this isn't a document a user edits field-by-field
  and might abandon mid-edit. Every meaningful state change (a scan, a new
  version) is an atomic, immediately-persisted business event — closer to
  "record a business event" than "edit a document." Draft would add
  complexity (draft tables, draft merge) with no matching use case.
- Child entities matching **Rule 2/Rule 4** (never overwrite, never delete
  history) are **insert-only, read-only-after-creation** compositions —
  enforced by *not* generating standard UPDATE/DELETE operations on them at
  the behavior definition level, so history-tampering isn't just
  discouraged, it's structurally impossible through the API. Corrections
  happen by creating a new version, never by editing an old one.

## 4. Composition Hierarchy

Root: `ZRAP_MT_HDR` (Migration Workspace)

```
MigrationWorkspace (ZRAP_MT_HDR)
 ├─ _Version        (ZRAP_MT_VER)   1:n, insert-only
 ├─ _Object         (ZRAP_MT_OBJ)   1:n, insert-only, FK to Version
 ├─ _Source         (ZRAP_MT_SRC)   1:1 per Object, insert-only
 ├─ _Config         (ZRAP_MT_CFG)   1:n, insert-only, FK to Version
 ├─ _Document        (ZRAP_MT_DOC)   1:n, insert-only, FK to Version
 ├─ _Note            (ZRAP_MT_NOTE)  1:n, append-only, FK to Version
 ├─ _OptimizationFinding (ZRAP_MT_OPT) 1:n, FK to Version  ⚠ see §4.1
 └─ _Blocker             (ZRAP_MT_BLK) 1:n, FK to Version  ⚠ see §4.1
```

Every child that carries analysis or inventory data is scoped to a
**Version** (not just the header), so a Delta between V2 and V3 is a
straight set-comparison between two child collections — no separate
"snapshot" copy step needed. This directly supports §9's delta requirements
and §12's "snapshot becomes immutable after TR creation" (immutability =
simply no UPDATE/DELETE operation exists on a persisted Version's children).

### 4.1 Gap flagged against §15

Your Database Design (§15) lists 7 tables and doesn't include persistence
for **Optimization Findings** (§7) or **RAP Blockers** (§8), even though
§12 (Migration Snapshot) and §17 (Readiness Metrics: "Blocker Count",
"Optimization Health") both require them as first-class, independently
queryable data — not something to bury as extra columns on `ZRAP_MT_OBJ`.

**Proposed addition:** two tables, `ZRAP_MT_OPT` and `ZRAP_MT_BLK`, same
shape as the others (Migration ID, Version, Object ref, Category, Severity,
Description, Recommendation). Flagging rather than silently adding these —
per Golden Constitution Rule 1, this needs your explicit confirmation
before it goes into the Persistence Model doc.

## 5. Scan Execution Model

`RunScan` is a long-running operation (traversing an application's full
include list, DDIC dependents, enhancement spots, etc. can be thousands of
objects). Running it synchronously inside a RAP action risks OData
gateway/dialog work process timeouts.

**Proposed model:**
1. `RunScan` action sets Header status to `SCANNING`, and submits a
   background job (`ZCL_RAP_MT_DET_ORCHESTRATOR=>run` via `cl_bgmc` or
   classic `JOB_OPEN`/`JOB_SUBMIT`) rather than executing inline.
2. The orchestrator runs each registered detector (§16), writes results
   directly to the DB (not held only in memory — Rule "Nothing should be
   lost between migration cycles" / §5 "Everything must be stored"), then
   flips Header status to `SCAN_COMPLETE` (or `SCAN_FAILED` with an error
   note).
3. UI polls/refreshes; **no version is created automatically** — per §9,
   the scan produces a delta view, and "Save New Version" remains a
   distinct, explicit user action ("No approval workflow" — but still a
   deliberate click, not an automatic side effect of scanning).

This keeps "scan" (fast, idempotent, re-runnable, safe to abandon) cleanly
separate from "version" (the actual immutable record per Rule 2).

## 6. Detector Framework

Interface-based plugin architecture, per §16:

```
ZIF_RAP_MT_DETECTOR
  METHODS:
    detect
      IMPORTING is_scan_context TYPE zrap_mt_s_scan_context
      RETURNING VALUE(rt_findings) TYPE zrap_mt_t_findings.
```

Each detector (`ZCL_RAP_MT_DET_PROG`, `ZCL_RAP_MT_DET_DDIC`,
`ZCL_RAP_MT_DET_FORM`, `ZCL_RAP_MT_DET_CFG`, `ZCL_RAP_MT_DET_OPT`, plus
enhancement/integration detectors implied by §5's full list) implements
this interface independently — no shared base class carrying logic, only
the contract. `ZCL_RAP_MT_DELTA` is **not** a detector; it's a separate
service that diffs two persisted Versions' child collections (§9).

**Registry, not hardcoded list:** the orchestrator resolves the active
detector set from a customizing table (proposed: `ZRAP_MT_DETREG` —
another small gap against §15, flagging per Rule 1) rather than a
hardcoded `CREATE OBJECT` list, so §19's "must support without redesign"
future detectors (BRF+, Workflow, CPI...) are a config entry plus one new
class, never a core code change.

## 7. Rule Engine (RAP Blockers, §8)

Same plug-in philosophy, applied to *classification* rather than
*discovery*: a customizing table (proposed: `ZRAP_MT_RULE` — flagged gap)
holding Pattern → Category → Severity → Recommendation, loaded once per
scan and evaluated against each Optimization Finding / discovered object.
New blocker patterns are data (a customizing entry), not code — satisfying
§8's "must plug in without redesign" directly, with zero class changes
needed for a new pattern.

## 8. Document Store — OpenText Integration

Per Rule 5 and §10 (documents in OpenText, only metadata in SAP), this
needs an abstraction so Phase 1 isn't hard-wired to one specific OpenText
connectivity mechanism:

```
ZIF_RAP_MT_DOC_STORE
  METHODS:
    upload   IMPORTING iv_filename ... RETURNING VALUE(rv_opentext_id) ...
    download IMPORTING iv_opentext_id ... RETURNING VALUE(rv_content) ...
```

**Open question — needs your input, not an assumption I should make per
Rule 1:** which OpenText integration does the target landscape already
have? Common options are SAP ArchiveLink (`OAWD`/content repository, likely
already configured if OpenText is the archive backend), a direct
OpenText CMIS/REST API, or an existing middleware (CPI) exposing document
upload as an OData/REST service. The interface above stays constant either
way, but the concrete adapter class and its config depend entirely on which
one is actually in place.

## 9. TR Generation

`GenerateMigrationPackage` is a RAP action requiring a confirmation
dialog client-side (§13) — the *server-side* action itself must still
independently refuse to run without an explicit confirmation flag passed
from the UI (never trust "the button was styled as a confirm step" as the
only gate). Implementation: `cl_adt_cts_mgmt` or the classic
`TR_INSERT_REQUEST_WITH_TASKS` action to create the Workbench TR, add
objects, then flip the Version to immutable (§12) and persist the TR number
back onto `ZRAP_MT_VER`.

## 10. Fiori UI — one exception to pure Fiori Elements

Pages 1, 2, 4, 6, 7, 8, 9 (§14) map cleanly to Fiori Elements (List Report,
Object Page, Analytical List Page). **Page 3, Dependency Explorer**, needs
a genuine tree hierarchy with drill-down — Fiori Elements has no native
tree control. Proposed: a freestyle SAPUI5 app (`sap.m.Tree` or
`sap.ui.table.TreeTable`) consuming the same OData service, embedded as a
custom section/page rather than forcing a tree into an ALP that doesn't
support it. **Page 5, Source Viewer**, likely also needs a lightweight
custom UI5 view (code editor control) rather than a standard FE Object
Page facet, since source code display isn't a typical business-object
field layout.

## 11. Non-Functional Notes

- **Volume**: a single legacy application can involve thousands of
  dependency objects; `ZRAP_MT_SRC` (full source per object) will be the
  largest table by far — plan for a `STRING`/`RAWSTRING`-backed field, not
  a fixed-length one, and consider whether every version needs a full
  source copy or whether unchanged objects (same fingerprint, §6) can
  reference the prior version's row instead of duplicating content. This
  is a real storage/design tradeoff to decide explicitly, not default
  silently — flagging for the Persistence Model doc.
- **Authorization**: needs its own object (proposed `ZRAP_MT_AUTH`) checked
  at minimum on `GenerateMigrationPackage` (TR creation is a
  higher-privilege action than read/scan) — detailed in the Behavior
  Design doc, not decided here.
- **Naming**: this document already follows §2 Rule 7 throughout; will
  carry through consistently in every subsequent design doc.

## 12. Decisions Needed Before Proceeding to Doc #2 (RAP Business Object Model)

1. Approve or revise the **Managed, non-draft** decision (§3).
2. Approve adding `ZRAP_MT_OPT` / `ZRAP_MT_BLK` tables (§4.1) — not in your
   original §15 list.
3. Approve adding `ZRAP_MT_DETREG` / `ZRAP_MT_RULE` config tables (§6/§7)
   for the pluggable registry — also not in your original §15 list.
4. Approve the **background-job scan model** (§5) over a synchronous
   in-request scan.
5. Which OpenText connectivity mechanism actually exists in the target
   landscape (§8) — needed before the Document Store adapter can be
   designed, not just the interface.
6. Confirm the **source-versioning storage tradeoff** (§11: full copy per
   version vs. reference-when-unchanged) — affects the Persistence Model
   doc directly.

Once these are settled, Doc #2 (RAP Business Object Model) proceeds from a
confirmed foundation instead of carrying assumptions forward.
