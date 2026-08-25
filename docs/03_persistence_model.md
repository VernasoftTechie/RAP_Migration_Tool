# ZRAP_MT — Persistence Model

**Phase 1 — Doc 3/12.** Translates the Business Object Model (Doc 2) into
concrete DDIC objects: domains, data elements, tables. This is the last
purely-design doc before actual DDIC source starts getting written
(Doc 4 onward produces real `.tabl`/`.doma`/`.dtel` source alongside these
descriptions).

## 1. Domains

| Domain | Type | Values / Range | Used by |
|---|---|---|---|
| `ZRAP_MT_APPTYPE` | CHAR(5) | `PROG`, `MPOOL`, `TRAN`, `PACK`, `CLAS` | `ZRAP_MT_HDR-APPLICATION_TYPE` |
| `ZRAP_MT_OBJTYPE` | CHAR(4) | Value-help/check-table-driven (see §2) — `PROG`, `INCL`, `CLAS`, `INTF`, `FUGR`, `FUNC`, `BAPI`, `GUIS`, `MENU`, `DYNP`, `MSAG`, `SHLP`, `ENQU`, `TABL`, `STRU`, `VIEW`, `DOMA`, `DTEL`, `TTYP`, `SMFR`, `ADOB`, `SCRP`, `HRFO`, `BADI`, `EXIT`, `ENHS`, `ENHO`, `RFC`, `IDOC`, `SOAP`, `ODAT`, `CPI`, `FILE` | `ZRAP_MT_OBJ-OBJECT_TYPE` |
| `ZRAP_MT_CFGTYPE` | CHAR(5) | `SNRO`, `TVARVC`, `SPRO`, `SM30`, `AUTH` | `ZRAP_MT_CFG-CONFIG_TYPE` |
| `ZRAP_MT_DOCTYPE` | CHAR(15) | `FSD`, `TSD`, `UNIT_TEST`, `SIT`, `UAT`, `EXCEL_MAPPING`, `SOP`, `BUSINESS_NOTE` | `ZRAP_MT_DOC-DOC_TYPE` |
| `ZRAP_MT_SEVERITY` | CHAR(1) | `H`(High) `M`(Medium) `L`(Low) | `ZRAP_MT_OPT-SEVERITY` |
| `ZRAP_MT_BLKCLASS` | CHAR(10) | `BLOCKER`, `WARNING`, `REVIEW`, `CONFIG` (per §8's table) | `ZRAP_MT_BLK-CLASSIFICATION` |
| `ZRAP_MT_SCANSTAT` | CHAR(10) | `NEW`, `SCANNING`, `SCAN_OK`, `SCAN_FAILED` | `ZRAP_MT_HDR-SCAN_STATUS` |

### 2. `ZRAP_MT_OBJTYPE` as a check table, not a fixed domain value list

Per Doc 1 §6's extensibility requirement, this domain is **value-table
bound** to a small master table `ZRAP_MT_OBJTYPE_T` (ObjectType code +
description + category), not a hardcoded `SELECT ... 'PROG' OR 'INCL' OR
...` list. Adding a type the constitution didn't originally list (Doc 1
§19's future BRF+/Workflow/CPI detectors will discover new object types)
is then a customizing insert, not a domain change requiring transport
of a DDIC object.

## 2. Data Elements (representative — full list is 1:1 with fields, omitted for brevity)

| Data Element | Domain/Type | Field Label |
|---|---|---|
| `ZRAP_MT_MIGRATIONID` | CHAR(10) | Migration ID |
| `ZRAP_MT_VERSIONNO` | INT4 | Version |
| `ZRAP_MT_FINGERPRINT` | CHAR(64) | SHA-256 checksum, hex |
| `ZRAP_MT_UUID` | RAW(16) | (reused across all surrogate keys) |
| `ZRAP_MT_TRKORR` | `TRKORR` (reuse standard SAP data element) | TR Number |

## 3. Tables

All tables: `TABKLASS = 'TRANSP'`, delivery class `A`, no client-independent
tables (Rule: migration data is inherently client/landscape-specific — a
cross-client design would risk one client's scan data leaking into
another's Fiori app instance).

### `ZRAP_MT_HDR`

| Field | Key | Type | Notes |
|---|---|---|---|
| MANDT | X | CLNT | |
| MIGRATION_ID | X | `ZRAP_MT_MIGRATIONID` | from number range `ZRAP_MT` |
| APPLICATION_NAME | | CHAR(40) | |
| APPLICATION_TYPE | | `ZRAP_MT_APPTYPE` | |
| PACKAGE | | `DEVCLASS` (reuse) | |
| DESCRIPTION | | CHAR(100) | |
| CREATED_BY | | `SYUNAME` (reuse) | |
| CREATED_ON | | `SY-DATUM` type (`DATS`) | |
| CURRENT_VERSION_NO | | `ZRAP_MT_VERSIONNO` | denormalized pointer, §Doc2 §3 |
| LAST_SCAN_TIMESTAMP | | `TIMESTAMPL` | |
| SCAN_STATUS | | `ZRAP_MT_SCANSTAT` | |
| READINESS_* (×6) | | see Doc 2 §3 | denormalized current-version mirror |

### `ZRAP_MT_VER`

Key: MANDT, MIGRATION_ID, VERSION_NO. Fields: `SCAN_TIMESTAMP`,
`TR_NUMBER` (`ZRAP_MT_TRKORR`, initial), `IS_IMMUTABLE` (`ABAP_BOOL`),
`CREATED_BY`, `CREATED_ON`, plus the six authoritative readiness metrics.

### `ZRAP_MT_OBJ`

Key: MANDT, MIGRATION_ID, VERSION_NO, OBJECT_UUID. Fields: `OBJECT_NAME`
(CHAR40), `OBJECT_TYPE` (`ZRAP_MT_OBJTYPE`), `PACKAGE`, `LAST_CHANGED_BY`,
`LAST_CHANGED_ON` (source-system values, captured not derived),
`FINGERPRINT`, `DISCOVERED_BY_DETECTOR_ID`.
Secondary index: (MIGRATION_ID, VERSION_NO, OBJECT_TYPE) — Page 4's
"Repository Objects, ALV with filtering" (§14) will filter by type
constantly.

### `ZRAP_MT_SRC`

Key: MANDT, MIGRATION_ID, VERSION_NO, OBJECT_UUID (1:1 with `ZRAP_MT_OBJ`).
Field: `SOURCE_CODE` (`STRING`). No secondary indexes — always accessed by
full key from the Source Viewer page (§14 Page 5), never searched/filtered.

### `ZRAP_MT_CFG`

Key: MANDT, MIGRATION_ID, VERSION_NO, CONFIG_UUID. Fields: `CONFIG_TYPE`
(`ZRAP_MT_CFGTYPE`), `CONFIG_NAME`, `REFERENCED_OBJECT`, `DESCRIPTION`,
`DETAIL` (`STRING` — raw captured value/config dump).

### `ZRAP_MT_OPT` / `ZRAP_MT_BLK`

Same shape, two tables (kept separate rather than one table with a
discriminator — Optimization Findings and RAP Blockers have genuinely
different downstream consumers: §17 counts them into different readiness
metrics, and §14 gives Blockers its own dedicated page grouped by severity,
so separate tables avoid every Blocker query needing a `WHERE KIND =
'BLOCKER'` filter on a shared table).

Key: MANDT, MIGRATION_ID, VERSION_NO, FINDING_UUID (or BLOCKER_UUID).
Non-key FK: OBJECT_UUID. Fields: `CATEGORY`, `SEVERITY`
(`ZRAP_MT_SEVERITY` for Opt / `ZRAP_MT_BLKCLASS` for Blk), `PATTERN`,
`DESCRIPTION`, `RECOMMENDATION`, `SOURCE_LINE` (INT4, nullable).

### `ZRAP_MT_DOC`

Key: MANDT, MIGRATION_ID, VERSION_NO, DOC_UUID. Fields: `DOC_TYPE`
(`ZRAP_MT_DOCTYPE`), `OPENTEXT_ID` (CHAR60 — sized generously since a real
OpenText BO ID format is still unknown, per the still-open question),
`IS_STUBBED` (`ABAP_BOOL`), `FILE_NAME`, `UPLOADED_BY`, `TIMESTAMP`.

### `ZRAP_MT_NOTE`

Key: MANDT, MIGRATION_ID, VERSION_NO, NOTE_UUID. Fields: `NOTE_TEXT`
(`STRING`), `CREATED_BY`, `CREATED_ON`.

### `ZRAP_MT_DETREG` (global config, not composed under Header)

Key: MANDT, DETECTOR_ID (CHAR20). Fields: `CLASS_NAME` (`SEOCLSNAME`,
must implement `ZIF_RAP_MT_DETECTOR` — enforced at activation time by the
orchestrator, not by DDIC, since DDIC can't constrain "implements this
interface"), `DESCRIPTION`, `IS_ACTIVE` (`ABAP_BOOL`), `SEQUENCE` (INT4,
execution order — some detectors, e.g. DDIC, may need to run after PROG
detection identifies which tables to inspect).

### `ZRAP_MT_RULE` (global config)

Key: MANDT, RULE_ID (CHAR20). Fields: `PATTERN` (regex or literal,
`STRING`), `MATCH_TYPE` (`REGEX`/`LITERAL`), `CATEGORY`, `CLASSIFICATION`
(`ZRAP_MT_BLKCLASS`), `RECOMMENDATION` (`STRING`), `IS_ACTIVE`.

### `ZRAP_MT_OBJTYPE_T` (global config — the check table from §2)

Key: MANDT, OBJECT_TYPE (`ZRAP_MT_OBJTYPE`). Fields: `DESCRIPTION`,
`CATEGORY` (Repository/DDIC/Form/Enhancement/Integration — for §14's
grouped displays).

## 4. Number Range

Object `ZRAP_MT`, interval `01`, no-year, generating `MIGRATION_ID` as
`MT` + 6-digit zero-padded sequence (`MT000001`, `MT000002`, ...) —
matches the constitution's exact format. Generated once, at Header CREATE,
inside the behavior implementation's `create` handler (not client-side, so
it can't be spoofed or collide under concurrent creation).

## 5. What's *not* here on purpose

No table stores Optimization Findings or Blockers *in memory only* pending
a version save — Doc 1 §5's scan model writes `ZRAP_MT_OBJ` /
`ZRAP_MT_OPT` / `ZRAP_MT_BLK` rows directly during the background scan,
tagged to a **staging** version row (`VERSION_NO = 0`, reserved/reused
across scans, overwritten each `RunScan` — the one deliberate exception to
"insert-only," since staging-by-definition isn't yet a real version).
`SaveVersion` then **copies** staging rows into a new real `VERSION_NO`
(≥1, permanently insert-only from that point on) rather than just
"promoting" the staging version number, keeping the immutability guarantee
airtight for every version that ever appears in the UI's version history.

This staging-version mechanism wasn't explicit in the original constitution
and is a design decision worth your explicit sign-off, same as the earlier
flagged items.
