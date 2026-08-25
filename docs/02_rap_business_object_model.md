# ZRAP_MT — RAP Business Object Model

**Phase 1 — Doc 2/12.** Builds on `01_solution_architecture.md`. Carries
forward decisions 1–4 and 6 from that doc's open list as provisional
defaults (not yet explicitly confirmed) and resolves decision 5 (OpenText)
as a stub adapter, per your instruction.

## 1. Entity Overview

```
MigrationWorkspace (ZRAP_MT_HDR)            root, managed, non-draft
 ├─ _Version            (ZRAP_MT_VER)       1:n, insert-only
 │   ├─ _Object          (ZRAP_MT_OBJ)      1:n, insert-only
 │   │   └─ _Source       (ZRAP_MT_SRC)     1:1, insert-only
 │   ├─ _Config           (ZRAP_MT_CFG)     1:n, insert-only
 │   ├─ _OptimizationFinding (ZRAP_MT_OPT)  1:n, insert-only, FK → _Object
 │   ├─ _Blocker              (ZRAP_MT_BLK) 1:n, insert-only, FK → _Object
 │   ├─ _Document              (ZRAP_MT_DOC) 1:n, insert-only
 │   └─ _Note                   (ZRAP_MT_NOTE) 1:n, append-only
 └─ (global, not composed) ZRAP_MT_DETREG, ZRAP_MT_RULE — tool configuration
```

`_OptimizationFinding` and `_Blocker` associate to `_Object` (which object
triggered the finding) but are still owned/keyed under `_Version`, not
nested under `_Object`, so §14 Page 7 ("RAP Blockers, grouped by severity")
can query them directly without walking through every object.

## 2. Key Structure

| Entity | Key | Notes |
|---|---|---|
| `ZRAP_MT_HDR` | `MigrationID` (CHAR10) | Semantic key, e.g. `MT000001`. Never changes (Rule: "Migration ID never changes"). Generated from a number range object `ZRAP_MT` on CREATE — not user-entered, so it can't collide or be mistyped. |
| `ZRAP_MT_VER` | `MigrationID` + `VersionNo` (INT4) | Displayed as `V<n>`. Always increments, never reused, even if a version is later superseded. |
| `ZRAP_MT_OBJ` | `MigrationID` + `VersionNo` + `ObjectUUID` (RAW16) | UUID surrogate, not object name — the same object can legitimately reappear across versions, and a natural key would fight the insert-only model. |
| `ZRAP_MT_SRC` | same as parent `ZRAP_MT_OBJ` | 1:1 — only created for object types that carry source. |
| `ZRAP_MT_CFG` | `MigrationID` + `VersionNo` + `ConfigUUID` | |
| `ZRAP_MT_OPT` / `ZRAP_MT_BLK` | `MigrationID` + `VersionNo` + `FindingUUID` | plus non-key FK `ObjectUUID` |
| `ZRAP_MT_DOC` | `MigrationID` + `VersionNo` + `DocUUID` | |
| `ZRAP_MT_NOTE` | `MigrationID` + `VersionNo` + `NoteUUID` | |
| `ZRAP_MT_DETREG` | `DetectorID` (CHAR20) | global config, not under a Migration Workspace |
| `ZRAP_MT_RULE` | `RuleID` (CHAR20) | global config, not under a Migration Workspace |

## 3. Field Highlights (non-exhaustive — full DDIC in Doc 3)

**`ZRAP_MT_HDR`**: `ApplicationName`, `ApplicationType` (checked against a
domain `ZRAP_MT_APPTYPE`: `PROG`/`MPOOL`/`TRAN`/`PACK`/`CLAS`), `Package`,
`Description`, `CreatedBy`, `CreatedOn`, `CurrentVersionNo` (denormalized
pointer to the latest `_Version` for fast list-page rendering — the
authoritative row still lives in `ZRAP_MT_VER`), `LastScanTimestamp`, plus
a denormalized **current readiness summary** (six fields mirroring §17,
refreshed whenever a version is saved) so Page 1 doesn't need to join
into version history just to show a status.

**`ZRAP_MT_VER`**: `ScanTimestamp`, `TRNumber` (initial until §13 runs),
`IsImmutable` (flag; set irreversibly true once a TR is generated — the
single field that makes §12's "immutable after TR creation" enforceable
at the behavior-definition level, by blocking child inserts once true),
and the six §17 readiness metric fields as the authoritative
per-version record.

**`ZRAP_MT_OBJ`**: `ObjectName`, `ObjectType` (checked against
`ZRAP_MT_OBJTYPE`, a value-help/check-table domain — not a fixed CDS enum
— so §5's "supported object" list can grow via a customizing entry, same
extensibility pattern as the detector registry), `Package`,
`LastChangedBy`/`LastChangedOn` (from the *source* system, not this tool),
`Fingerprint` (SHA-256 hex string, §6), `DiscoveredByDetectorID` (FK to
`ZRAP_MT_DETREG`, for traceability of which detector found it).

**`ZRAP_MT_SRC`**: `SourceCode` (`STRING`, not a fixed-length type — a
single include can exceed most fixed limits). **Provisional default**
carried from Doc 1 §11: full source copy stored on every version, even for
an unchanged object. Fingerprint match is still computed and *stored*, so
a later optimization (store by reference when the fingerprint is unchanged
from the prior version) is a storage-layer change behind the same
interface — not a model change. Flagging again since this wasn't
explicitly confirmed.

**`ZRAP_MT_DOC`**: `DocType` (domain: `FSD`/`TSD`/`UNIT_TEST`/`SIT`/`UAT`/
`EXCEL_MAPPING`/`SOP`/`BUSINESS_NOTE`), `OpenTextID`, `FileName`,
`UploadedBy`, `Timestamp`, and a new field **`IsStubbed`** (boolean) — set
true whenever `OpenTextID` was produced by the stub adapter rather than a
real OpenText call, so stubbed records are queryable/visually flagged in
the UI, never silently indistinguishable from real integration data.

## 4. Actions (root-bound unless noted)

| Action | Effect |
|---|---|
| `RunScan` | Validates the application reference (see §5 below), sets `SCANNING` status, submits the background job from Doc 1 §5. Re-runnable; does **not** create a version. |
| `SaveVersion` | Takes the current scan's staged findings, writes a new immutable-once-TR'd `_Version` with all children, recomputes and stores readiness metrics. The only action that actually advances `CurrentVersionNo`. |
| `GenerateMigrationPackage` (bound to a specific `_Version`) | Requires an explicit `confirmed` parameter from the UI confirmation dialog (§13) — checked server-side, never trusted from UI state alone. Rejects if `IsImmutable` is already true. Creates the Workbench TR, writes `TRNumber`, sets `IsImmutable = true`. |
| `UploadDocument` (on `_Document`) | Calls `ZIF_RAP_MT_DOC_STORE~upload`. Phase 1 default implementation: `ZCL_RAP_MT_DOC_STORE_STUB`, which performs no real upload and returns a placeholder ID in an unambiguous, clearly-fake format (e.g. `STUB-<GUID>`), with `IsStubbed = abap_true`. Swapping in a real adapter later is a class-binding change, not a model change. |
| `AddNote` (on `_Note`) | Simple create; no update/delete operation generated — corrections are new notes, not edits (Rule 4 applied to notes as well as objects). |

## 5. Key Validation — Golden Rule 1 as an actual check, not just prose

`RunScan` (and `ZRAP_MT_HDR` creation) validates the application reference
against the live repository before anything is persisted as "verified":
program/class/transaction/package existence checked via standard
lookups (`RS_PROGRAM_CHECK`-equivalent / `SEOCOMPOTX`/`TADIR` reads,
detailed in Doc 5 — Behavior Design). If the reference can't be verified,
the action raises a business error rather than allowing an unverified
Migration Workspace to be created — this is Rule 1 ("never assume any SAP
repository object") implemented as an executable check, not just a
constitution clause.

## 6. Still Open (unchanged from Doc 1 §12, minus #5)

1. Managed/non-draft decision — provisionally proceeding.
2. `ZRAP_MT_OPT`/`ZRAP_MT_BLK` tables — provisionally proceeding.
3. `ZRAP_MT_DETREG`/`ZRAP_MT_RULE` registry tables — provisionally proceeding.
4. Background-job scan model — provisionally proceeding.
5. ~~OpenText mechanism~~ — **resolved**: stub adapter for Phase 1, real
   adapter deferred until the target mechanism is known.
6. Source-versioning storage tradeoff — provisionally: full copy per
   version (simplest, matches immutability model cleanly).

Say the word if any of 1/2/3/4/6 should change — otherwise Doc 3
(Persistence Model — the actual DDIC table/domain/data-element
definitions) proceeds from these as final.
