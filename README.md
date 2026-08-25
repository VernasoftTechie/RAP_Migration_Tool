# ZRAP_MT — RAP Dependency Intelligence Platform

Phase 1: identify, collect, verify, version, and export every dependency
required for an ECC → RAP migration. Single source of truth across
migration cycles — see [`docs/01_solution_architecture.md`](docs/01_solution_architecture.md)
for the full constitution and Phase 1 architecture.

Design proceeds in the sequence mandated by the project constitution
(Solution Architecture → Business Object Model → Persistence → CDS →
Behavior → Service → UI → Detector Framework → Rule Engine → Delta Engine →
TR Generation → OpenText Integration) — implementation begins only after
architecture approval.

## Status

- [x] 01 — Solution Architecture (draft, pending approval)
- [x] 02 — RAP Business Object Model (draft, pending approval; OpenText resolved as stub adapter)
- [x] 03 — Persistence Model (draft, pending approval)
- [x] 04 — CDS Design (draft, pending approval)
- [x] 05 — Behavior Design (draft, pending approval)
- [x] 06 — Service Definition (draft, pending approval)
- [x] 07 — UI Navigation (draft, pending approval)
- [x] 08 — Detector Framework (draft, pending approval)
- [x] 09 — Rule Engine (draft, pending approval)
- [x] 10 — Delta Engine (draft, pending approval)
- [x] 11 — TR Generation Design (draft, pending approval)
- [x] 12 — OpenText Integration Design (draft, pending approval)

All 12 design docs are drafted. See `docs/12_opentext_integration_design.md`
for the consolidated list of 13 decisions — **all approved**, implementation
underway.

## Implementation status

Objects appear under [`src/`](src/) as they're built, in persistence →
CDS → behavior → service → classes order (same sequence as the design
docs). **None of this has been activated against a real SAP system** —
there's no backend available in this environment to compile-check DDIC
XML or ABAP syntax against. Treat every object as a best-effort draft to
verify on first activation, not a guarantee.

### Persistence layer — complete (25 objects)

- [x] Domains (8/8): `ZRAP_MT_APPTYPE`, `ZRAP_MT_OBJTYPE_KEY`,
      `ZRAP_MT_OBJTYPE`, `ZRAP_MT_CFGTYPE`, `ZRAP_MT_DOCTYPE`,
      `ZRAP_MT_SEVERITY`, `ZRAP_MT_BLKCLASS`, `ZRAP_MT_SCANSTAT`
- [x] Data elements (4/4, reused across tables): `ZRAP_MT_MIGRATIONID`,
      `ZRAP_MT_VERSIONNO`, `ZRAP_MT_UUID`, `ZRAP_MT_FINGERPRINT`.
      Simpler fields are typed inline (built-in type, no dedicated data
      element) rather than hand-crafting ~80 mostly-trivial data
      elements — a deliberate scope trim, not an oversight.
- [x] Check/config tables (4/4): `ZRAP_MT_OTYPE_T`, `ZRAP_MT_DETREG`,
      `ZRAP_MT_RULE`, `ZRAP_MT_DOCADPT`
- [x] Core tables (9/9): `ZRAP_MT_HDR`, `ZRAP_MT_VER`, `ZRAP_MT_OBJ`,
      `ZRAP_MT_SRC`, `ZRAP_MT_CFG`, `ZRAP_MT_OPT`, `ZRAP_MT_BLK`,
      `ZRAP_MT_DOC`, `ZRAP_MT_NOTE`
- [x] `.abapgit.xml` + `src/package.devc.xml` — needed for this repo to
      pull at all, same requirement as `RAP_Migration_Tool`'s earlier fix
- [ ] Number range object `ZRAP_MT` — **manual setup step, not
      abapGit-serialized** (see note below)

**Target package: `ZRAP_MIGR` (existing, not a new package).** Note that
`src/package.devc.xml` only carries descriptive text (`CTEXT`) — the
actual package a repo's objects land in is chosen when you link the repo
in abapGit (Repository → New Online / Clone in the SAP GUI/ADT abapGit
UI): point it at your existing `ZRAP_MIGR` package there, and every
object under `src/` is created inside it, no new package involved. This
is unrelated to object naming — `ZRAP_MT_*` objects living inside package
`ZRAP_MIGR` is completely normal; a package's name and its objects'
naming prefix don't need to match.

**Not yet done, next when you resume:** CDS interface + projection
views, behavior definitions, service definition/binding, detector
framework classes, rule/delta engines, TR generator, doc store stub.

### Design fixes caught while implementing

- **Circular value-table reference.** Doc 3 §2 described `ZRAP_MT_OBJTYPE`
  as a value-table-bound domain pointing at check table
  `ZRAP_MT_OBJTYPE_T` — but the check table's own key field can't be typed
  with a domain that references that same table (circular). Split into two
  domains: `ZRAP_MT_OBJTYPE_KEY` (bare CHAR4, no value check — used only
  for the check table's own key) and `ZRAP_MT_OBJTYPE` (CHAR4,
  `ENTITYTAB = ZRAP_MT_OTYPE_T` — used by every table that actually
  references an object type).
- **Check table name too long.** `ZRAP_MT_OBJTYPE_T` (17 chars) exceeded
  the 16-character limit for a domain's value table — a real activation
  error (`Select a shorter name`) hit on first pull. Renamed to
  `ZRAP_MT_OTYPE_T` (15 chars) everywhere: the table itself, the domain's
  `ENTITYTAB`, and Docs 3/11.
- **`PACKAGE` is an ABAP reserved word.** Real activation error on
  `ZRAP_MT_HDR` and `ZRAP_MT_OBJ`, both of which had a `PACKAGE` field.
  Renamed to `DEV_PACKAGE` in both tables (and the CDS source field in
  Doc 4); the CDS-exposed alias stays `Package` since that's a view
  column name, not a raw ABAP structure component, and isn't affected by
  the same restriction. Also renamed the equivalent field on the
  authorization object design (Doc 5 §6) to the standard `DEVCLASS`
  field rather than inventing a same-named one.
- **Data elements were missing max-length metadata.** The 4 custom data
  elements omitted `HEADLEN`/`SCRLEN1-3` (the fields SAP normally
  auto-fills on save), causing `Heading/Short/Medium/Long ... > maximum
  length 0` errors on activation — fixed by adding those fields directly
  to the `.dtel.xml` source so a future fresh pull doesn't need the same
  manual re-save to resolve it.

### Number range object — manual step

`ZRAP_MT` (Doc 3 §4) needs to be created via SNRO directly in the target
system — number range objects carry runtime interval state that doesn't
serialize meaningfully as static abapGit source. Setup: object `ZRAP_MT`,
one interval `01`, no year-dependency, number range `0000000001` to
`0000999999`, external number range not allowed (so `MigrationID`
generation can never collide with a manually-entered value).
