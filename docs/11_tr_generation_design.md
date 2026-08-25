# ZRAP_MT — TR Generation Design

**Phase 1 — Doc 11/12.**

## 1. `ZCL_RAP_MT_TR_GENERATOR`

Invoked only from `GenerateMigrationPackage` (Doc 5 §3), only after the
server-side confirmation and immutability checks have already passed —
this class assumes it's safe to act, it doesn't re-validate (that
responsibility stays in the behavior implementation, not duplicated here).

```abap
CLASS zcl_rap_mt_tr_generator DEFINITION.
  PUBLIC SECTION.
    METHODS generate
      IMPORTING iv_migration_id  TYPE zrap_mt_migrationid
                iv_version_no    TYPE zrap_mt_versionno
      RETURNING VALUE(rv_trkorr) TYPE trkorr
      RAISING   zcx_rap_mt_tr_error.
ENDCLASS.
```

## 2. Steps (matching §13 exactly)

1. **Create Workbench TR** — `TR_INSERT_REQUEST_WITH_TASKS`, description
   auto-populated as `ZRAP_MT: <MigrationID> V<VersionNo> - <ApplicationName>`
   so a Basis admin scanning the TR list can immediately identify what a
   given TR is for without opening it.
2. **Add Repository Objects** — every `ZRAP_MT_OBJ` row of this version
   whose `ObjectType` corresponds to an actual transportable repository
   object gets added via `TR_OBJECT_INSERT`. **Not** DDIC/config/document
   rows that merely *reference* something already transported elsewhere —
   only objects this scan is meant to package for migration. This
   distinction (transportable vs. reference-only) needs a flag on
   `ZRAP_MT_OTYPE_T` (Doc 3 §2's check table) — a new field,
   `IsTransportable`, flagged here as a small addition to that table.
3. **Freeze Snapshot** — set `ZRAP_MT_VER-IS_IMMUTABLE = abap_true` (the
   behavior-definition-level enforcement from Doc 5 §1 takes over from
   here on).
4. **Generate README Metadata** — per §18, written as a `ZRAP_MT_DOC` row
   (`DocType` needs a new value, `README` — flagging as an addition to
   the `ZRAP_MT_DOCTYPE` domain, Doc 3 §1), content generated from the
   version's own data (object count, blocker count, etc.), stored via the
   Document Store Adapter like any other document — **including going
   through the stub in Phase 1**, so even the generated README gets an
   `IsStubbed` marker until real OpenText wiring lands.
5. **Generate JSON Artifacts** — the five files from §18
   (`dependency_tree.json`, `object_inventory.json`, `blockers.json`,
   `configuration_manifest.json`, `optimization_report.json`), each
   serialized directly from the version's persisted child tables via
   `/ui2/cl_json`, stored the same way as the README.
6. **Save TR Number** — write back onto `ZRAP_MT_VER-TR_NUMBER`.

## 3. Explicit Non-Goal

Per §13's "Do not push Git" — this class's output ends at the TR and the
export artifacts sitting in the Document Store. No git operations, no
GitHub API calls, anywhere in this class. §19 lists "GitHub Branch
Creation" as future-only for a reason; building it now, even as an
unused stub method, would violate the instruction more than it would
future-proof anything.

## 4. Failure Handling

If step 2 (adding objects) fails partway — e.g. an object was deleted from
the source system between scan and package generation — the already-created
TR is **not** silently left half-populated and marked complete. The whole
operation is wrapped so a failure past step 1 triggers `TR_INSERT_REQUEST`
of a "delete" or leaves the TR explicitly flagged
`INCOMPLETE`/orphaned-and-reported rather than partially transported and
indistinguishable from a clean success — surfaced back to the user as a
failed action with a specific error, not a generic "something went wrong."

Two new decisions flagged: the `IsTransportable` field addition (§2 point
2) and the new `README` doc type value (§2 point 4) — both mechanical
consequences of implementing §13/§18 faithfully, but still additions
beyond what Docs 3/3 originally enumerated.
