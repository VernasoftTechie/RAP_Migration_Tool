# ZRAP_MT — CDS Design

**Phase 1 — Doc 4/12.** First doc that produces near-final CDS source
sketches (not yet paste-ready — annotations get finalized once UI
navigation, Doc 7, is designed). Interface views first, then projections.

## 1. Naming

| Layer | Pattern | Example |
|---|---|---|
| Interface view | `ZI_RAP_MT_<entity>` | `ZI_RAP_MT_HDR` |
| Projection view | `ZC_RAP_MT_<entity>` | `ZC_RAP_MT_HDR` |
| Consumption/analytical (if any) | `ZC_RAP_MT_<entity>_A` | n/a in Phase 1 — no analytical query needed, §14 has no KPI-tile page like the earlier HR PoC had |

Matches Golden Constitution Rule 7 exactly (`ZI_RAP_MT_*` / `ZC_RAP_MT_*`).

## 2. Interface View Sketches

### `ZI_RAP_MT_HDR` (root)

```abap
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'RAP MT - Migration Workspace'
define root view entity ZI_RAP_MT_HDR
  as select from zrap_mt_hdr
  composition [0..*] of ZI_RAP_MT_VER as _Version
{
  key migration_id           as MigrationID,
      application_name       as ApplicationName,
      application_type       as ApplicationType,
      dev_package             as Pack,
      description             as Description,
      created_by              as CreatedBy,
      created_on              as CreatedOn,
      current_version_no      as CurrentVersionNo,
      last_scan_timestamp     as LastScanTimestamp,
      scan_status              as ScanStatus,
      readiness_repo_pct       as ReadinessRepositoryPct,
      readiness_ddic_pct       as ReadinessDdicPct,
      readiness_cfg_pct        as ReadinessConfigPct,
      readiness_doc_pct        as ReadinessDocumentationPct,
      readiness_opt_health     as ReadinessOptimizationHealth,
      readiness_blocker_count  as ReadinessBlockerCount,

      _Version
}
```

No `@AbapCatalog.sqlViewName` — not needed for `define view entity` syntax
(that annotation is for classic `define view`); real-system activation
confirmed it's unnecessary here. Field aliased `Pack`, not `Package` —
even as a CDS field alias (not just the underlying DB column), `Package`
triggers an error on this system, confirmed by real activation.

### `ZI_RAP_MT_VER`

```abap
define view entity ZI_RAP_MT_VER
  as select from zrap_mt_ver
  association to parent ZI_RAP_MT_HDR as _Header on $projection.MigrationID = _Header.MigrationID
{
  key migration_id      as MigrationID,
  key version_no        as VersionNo,
      scan_timestamp     as ScanTimestamp,
      tr_number          as TRNumber,
      is_immutable       as IsImmutable,
      created_by         as CreatedBy,
      created_on         as CreatedOn,
      readiness_repo_pct as ReadinessRepositoryPct,
      "  ... remaining five metrics, same pattern as Header

      _Header,
      _Object     : redirected to composition child ZI_RAP_MT_OBJ,
      _Config     : redirected to composition child ZI_RAP_MT_CFG,
      _Finding    : redirected to composition child ZI_RAP_MT_OPT,
      _Blocker    : redirected to composition child ZI_RAP_MT_BLK,
      _Document   : redirected to composition child ZI_RAP_MT_DOC,
      _Note       : redirected to composition child ZI_RAP_MT_NOTE
}
```

### `ZI_RAP_MT_OBJ`

```abap
define view entity ZI_RAP_MT_OBJ
  as select from zrap_mt_obj
  association to parent ZI_RAP_MT_VER as _Version on $projection.MigrationID = _Version.MigrationID
                                                   and $projection.VersionNo  = _Version.VersionNo
  association [0..1] to ZI_RAP_MT_SRC as _Source   on $projection.MigrationID = _Source.MigrationID
                                                   and $projection.VersionNo  = _Source.VersionNo
                                                   and $projection.ObjectUUID = _Source.ObjectUUID
  association [0..1] to ZRAP_MT_OTYPE_T as _ObjectTypeText on $projection.ObjectType = _ObjectTypeText.ObjectType
{
  key migration_id            as MigrationID,
  key version_no              as VersionNo,
  key object_uuid             as ObjectUUID,
      object_name              as ObjectName,
      object_type               as ObjectType,
      dev_package                as Pack,
      last_changed_by            as LastChangedBy,
      last_changed_on            as LastChangedOn,
      fingerprint                as Fingerprint,
      discovered_by_detector_id  as DiscoveredByDetectorID,

      _Version,
      _Source,
      _ObjectTypeText
}
```

### `ZI_RAP_MT_SRC`, `ZI_RAP_MT_CFG`, `ZI_RAP_MT_OPT`, `ZI_RAP_MT_BLK`, `ZI_RAP_MT_DOC`, `ZI_RAP_MT_NOTE`

Same pattern (parent association to `_Version`, `ZI_RAP_MT_OPT`/`ZI_RAP_MT_BLK`
additionally associate `to ZI_RAP_MT_OBJ as _Object` via `ObjectUUID` for
the "which object triggered this" link) — omitted here to avoid ~250 lines
of repetitive boilerplate; will be written in full at implementation time
directly as source files, not re-derived from scratch, so nothing here is
wasted effort.

## 3. Projection View Notes

Projections (`ZC_RAP_MT_*`) mirror the interface views field-for-field for
Phase 1 — no field renaming or hiding needed yet, since there's exactly one
UI consumer (the Fiori app itself, not a public API surface others might
also consume differently). `@UI` annotations for List Report / Object Page
layout live here and are finalized in Doc 7, not guessed now — adding them
prematurely risks having to redo them once the actual page layout is
nailed down, and a "TODO: revisit in Doc 7" annotation left in real source
is worse than not having the file yet.

## 4. Deliberately deferred to Doc 4 follow-up (not a new doc — same doc, later revision)

- `@ObjectModel.semanticKey` annotations — depend on Behavior Design (Doc 5)
  confirming whether `MigrationID` alone is semantically sufficient for the
  root (yes) vs. whether versions need a semantic key beyond their technical
  key (no — versions are pure history, no "current" flag needed since
  `ZRAP_MT_HDR.CURRENT_VERSION_NO` already answers that).
- Full field lists for the six views sketched only by pattern above.

## 5. Decision Carried Forward

No new open decisions in this doc — it's a direct translation of Doc 2/3,
not introducing new judgment calls. If Docs 1–3's provisional defaults
change, this doc's field lists change mechanically with them, not
structurally.
