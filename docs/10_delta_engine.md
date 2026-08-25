# ZRAP_MT — Delta Engine

**Phase 1 — Doc 10/12.**

## 1. `ZCL_RAP_MT_DELTA`

```abap
CLASS zcl_rap_mt_delta DEFINITION.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_delta,
             new_objects      TYPE zrap_mt_t_obj,
             removed_objects  TYPE zrap_mt_t_obj,
             modified_objects TYPE zrap_mt_t_obj_pair,
             new_configs      TYPE zrap_mt_t_cfg,
             removed_configs  TYPE zrap_mt_t_cfg,
             new_blockers     TYPE zrap_mt_t_blk,
             resolved_blockers TYPE zrap_mt_t_blk,
           END OF ty_delta.

    CLASS-METHODS compare
      IMPORTING iv_migration_id    TYPE zrap_mt_migrationid
                iv_from_version    TYPE zrap_mt_versionno
                iv_to_version      TYPE zrap_mt_versionno
      RETURNING VALUE(rs_delta)    TYPE ty_delta.
ENDCLASS.
```

## 2. Comparison Logic

- **New / removed objects**: set difference on `ZRAP_MT_OBJ` between the
  two versions, keyed by `ObjectName` + `ObjectType` (not `ObjectUUID` —
  UUIDs are per-scan-instance by design, Doc 2 §2, so comparing by UUID
  would call every object "new" every time; the natural key for
  *comparison purposes only* is name+type, while the UUID remains the
  storage key).
- **Modified objects**: same name+type present in both, but
  `Fingerprint` differs (Doc 1 §6's exact purpose for the fingerprint).
- **Configs**: same pattern, keyed by `ConfigType` + `ConfigName`.
- **Blockers**: new = present in `to` but not `from` (by Pattern +
  ObjectName); resolved = present in `from` but not `to` — surfacing
  "resolved" is as important as "new" for a migration team tracking
  progress across scan cycles, and the original constitution's §9 list
  ("detect new blockers") didn't explicitly mention resolved ones, so
  flagging this as an addition, not an assumption buried silently.

## 3. When Delta Runs

Two call sites, not one:
1. **`RunScan` → staging vs. `CurrentVersionNo`**: powers the live "here's
   what changed since your last saved version" view shown before the user
   decides to `SaveVersion` (§9's actual requirement — "user chooses save
   new version" implies they need to see the delta *first* to decide).
2. **Page 9 (Version History)**: on-demand comparison between any two
   already-saved versions, per Doc 7 §3.

Same method, same class, two different callers — no duplicated comparison
logic between "pre-save preview" and "post-save history."

## 4. Performance Note

For a large application, this is an all-in-memory `SORT` + `LOOP AT ...
BINARY SEARCH` comparison across potentially thousands of rows per
side — not a big-O concern at that scale, but worth stating the approach
explicitly rather than leaving it to be discovered as a database-heavy
implementation later. No DB joins across versions; both versions' data is
read once each into internal tables, then compared entirely in ABAP.

No new open decisions beyond the "resolved blockers" addition noted above.
