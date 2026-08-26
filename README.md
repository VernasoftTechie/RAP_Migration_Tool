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

### CDS layer — interface views complete (9/9)

- [x] `ZI_RAP_MT_HDR` (root), `ZI_RAP_MT_VER`, `ZI_RAP_MT_OBJ`,
      `ZI_RAP_MT_SRC`, `ZI_RAP_MT_CFG`, `ZI_RAP_MT_OPT`, `ZI_RAP_MT_BLK`,
      `ZI_RAP_MT_DOC`, `ZI_RAP_MT_NOTE`

**Resolved, after three failed guesses at the metadata format.** Root
cause: the correct top-level element in `.ddls.xml` is `<DDLS>`, not
`<DD25V>` — an invented structure name that never matched anything, which
is why changing the fields inside it (three different attempts) never
made a difference. Confirmed by getting one real, activated example
(`ZI_RAP_MT_HDR`, created by hand in ADT then pulled via abapGit Sync —
same technique that fixed the table format earlier). The real shape:

```xml
<DDLS>
  <DDLNAME>ZI_RAP_MT_HDR</DDLNAME>
  <DDLANGUAGE>E</DDLANGUAGE>
  <DDTEXT>Migration Header Interface View</DDTEXT>
  <SOURCE_TYPE>W</SOURCE_TYPE>
</DDLS>
```

There's also a **third required file** per CDS view, `<name>.ddls.baseinfo`
— a small JSON file (not XML) listing the view's source table(s):

```json
{ "BASEINFO": { "FROM": ["ZRAP_MT_HDR"] } }
```

I didn't know this file type existed; it's now created for all 9 views.

**Two more corrections from the real example:**
- `@AbapCatalog.sqlViewName`, `@AbapCatalog.compiler.compareFilter`, and
  `@AbapCatalog.preserveKey` are dropped from every view — not needed for
  `define view entity` syntax (that first annotation is for classic
  `define view`) and caused errors on this system. This also makes the
  16-character `sqlViewName` limit moot here — good to know, but the
  concern doesn't apply to this object type after all.
- **Every CDS field aliased `Package` is renamed to `Pack`** — per your
  observation, even the CDS-level alias (not just the underlying DB
  column, already `DEV_PACKAGE`) triggers a reserved-word conflict.
  Fixed in `ZI_RAP_MT_HDR` and `ZI_RAP_MT_OBJ`, the two views that expose
  this field, and in Doc 4.
- `ZI_RAP_MT_HDR`'s `_Version` composition (temporarily removed on your
  system since `ZI_RAP_MT_VER` didn't exist yet when you created `HDR`
  standalone for diagnosis) is restored — pushing all 9 together this
  time means the dependency exists.

Minor polish opportunity, not a blocker: `ZI_RAP_MT_OBJ`'s
`_ObjectTypeText` association points directly at table `ZRAP_MT_OTYPE_T`
rather than a small CDS view wrapping it. Works fine in classic
on-premise ABAP, just not "ABAP Cloud"-idiomatic — can revisit later if
this ever needs to run release-contract-clean.

**Fixed:** 8 of 9 views activated on the metadata fix above; the 9th,
`ZI_RAP_MT_OBJ`, failed with "The column OBJECTTYPE is unknown" (the
other 8 only failed as a downstream dependency of this one). Cause: its
association to the raw table `ZRAP_MT_OTYPE_T` used the CDS-style alias
`.ObjectType` in the `on` condition — but a plain DB table has no CDS
aliases, so the condition needs the real column name, `.OBJECT_TYPE`
(with the underscore). Without it, CDS folded the camelCase into a
literal (non-existent) column named `OBJECTTYPE`. Fixed in both the
source and Doc 4.

### CDS layer — projection views complete (9/9)

- [x] `ZC_RAP_MT_HDR` (root) through `ZC_RAP_MT_NOTE`, each with `@UI`
      annotations wired to Doc 7's page layout: `@UI.lineItem` for List
      Report/table columns, `@UI.selectionField` for filter bars on the
      high-volume tables (Objects, Configs, Findings, Blockers, Documents
      — per Doc 7's explicit point that these need real filtering),
      `@UI.identification` for Object Page general-info sections,
      `@UI.dataPoint` for the six readiness metrics, `@UI.facet` wiring
      the composition/navigation structure.
- Same three-file pattern as the interface views (`.ddls.asddls` +
  `.ddls.xml` with `<DDLS>` + `.ddls.baseinfo` pointing `FROM` at the
  underlying interface view, e.g. `ZC_RAP_MT_HDR`'s baseinfo lists
  `ZI_RAP_MT_HDR`) — same format, now proven correct, so no new guessing
  here.
- **Navigation clarification, not in Doc 7 explicitly:** Doc 7 places
  Pages 4/6/7/8 (Objects/Config/Blockers/Documents) as facets reachable
  from the Migration Workspace Object Page, but structurally those are
  `_Version`'s children, not `_Header`'s (Doc 2's composition tree only
  has `HDR → Version → {Object, Config, ...}`). Resolved as: `ZC_RAP_MT_HDR`'s
  Object Page shows the Overview + a Version History facet (Page 9);
  drilling into a specific version's own Object Page (`ZC_RAP_MT_VER`)
  is where Pages 4/6/7/8's facets actually live. This is the structurally
  correct reading of the composition tree, not a deviation from it.
- `Pack`, not `Package`, used consistently — no reversions.

**Fixed:** `@Metadata.layer: #CORE` (present on all 9 projection views)
is invalid at that position — "Annotation 'METADATA.LAYER' used at wrong
position (wrong scope)" — which broke parsing on `ZC_RAP_MT_HDR` and
poisoned the *entire* combined activation queue, including the 9 already
-working interface views (their "error in dependencies" / "could not be
activated" messages were downstream noise from this one parse failure,
not new problems in those objects). Removed the annotation from all 9 —
it's a metadata-classification annotation, not functionally required.
The separate "No root entity is found in this BO structure" message is
almost certainly the same cascading symptom (RAP couldn't recognize
`ZC_RAP_MT_HDR` as root once it failed to parse) rather than an
independent issue — should clear once this re-pulls clean.

### Behavior layer — full composition tree (1 object, 9 entities)

- [x] `ZI_RAP_MT_HDR.bdef.asbdef` — **one behavior definition object
      covers the entire composition tree**, not one per entity as
      originally assumed. Corrected via the same "create by hand once,
      Sync" technique that fixed CDS: you created the root manually in
      ADT, activated it, and the real Sync revealed both the correct
      `.bdef.xml` format (genuinely different from a guess — real
      abapGit `LCL_OBJECT_BDEF` output includes ADT-style `LINKS`/`HREF`
      metadata, adopted as-is) and that ADT auto-scaffolds **every**
      entity in the tree into the same file when you create the root.
- **Refined the ADT default scaffold to match Doc 5's actual design**,
  rather than keeping the bare CRUD defaults: removed `update;`/`delete;`
  from every entity (ADT's scaffold gives blanket CRUD by default, which
  contradicts "insert-only, never delete") — every child now has only
  `create` via its parent association, plus pass-through associations
  for navigation. Root keeps `create` with `field(readonly)`/
  `field(mandatory)` per Doc 5. Lock/authorization delegation chains
  filled in explicitly for the leaf entities (`lock dependent by
  _Version`, etc.) where ADT's auto-detection had left `//no
  to-master-association found` placeholder comments.
- **Corrected implementation class name**: `ZBP_I_RAP_MT_HDR` (ADT's
  real generated name, with the `I_` infix), not `ZBP_RAP_MT_HDR` as
  Doc 5 first drafted. Doc 5 updated to match.
- **The implementation class body is still not included on purpose** —
  same reasoning as before: RAP behavior handler signatures are
  framework-generated per your system's RAP runtime patch level. No
  custom actions are declared yet either (`RunScan`/`SaveVersion`/
  `GenerateMigrationPackage`), so there's currently nothing requiring
  custom method bodies — adding those is the next step, at which point
  ADT will need to re-scaffold the class with the new action stubs.

**Not yet done, next when you resume:** the other 8 behavior definitions
(mostly insert-only children), the three custom root actions, service
definition/binding, detector framework classes, rule/delta engines, TR
generator, doc store stub.

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
