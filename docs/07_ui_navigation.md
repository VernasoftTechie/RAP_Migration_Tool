# ZRAP_MT — UI Navigation

**Phase 1 — Doc 7/12.**

## 1. App Structure

Two apps sharing one service (Doc 6):

- **`zrap_mt_workspace` (Fiori Elements)** — List Report + Object Page,
  covering Pages 1, 2, 4, 6, 7, 8, 9.
- **`zrap_mt_explorer` (freestyle SAPUI5)** — Pages 3 and 5, launched
  in-context from the Object Page (a custom section action, per Doc 1 §10),
  passing `MigrationID`/`VersionNo` as navigation parameters. Not a
  separate FLP tile a user launches independently — it only makes sense
  entered from a specific version.

## 2. Navigation Map

```
Page 1  List Report (MigrationWorkspace)
  │  row click
  ▼
Page 2  Object Page header facet — Overview
        cards: Object Count / DDIC Count / Config Count / Blockers /
               Optimization Health / Current Version
        header actions: Run scan · Save version
  │
  ├─ facet ▶ Page 4  Repository Objects (table section, ALV-style, filter bar
  │                   on ObjectType/Package — filter bar exists because a
  │                   scan of a large app returns thousands of rows, and an
  │                   unfiltered facet would be unusable, not decorative)
  │
  ├─ facet ▶ Page 6  Configurations (table section, filter bar on ConfigType)
  │
  ├─ facet ▶ Page 7  RAP Blockers (table section, grouped by Severity —
  │                   FE's "group by" table personalization, not a custom
  │                   grouping widget)
  │
  ├─ facet ▶ Page 8  Documents & Notes (two sub-sections on one facet:
  │                   Document upload table + Note timeline)
  │
  ├─ facet ▶ Page 9  Version History (table of _Version, each row's
  │                   "compare" action opens the Delta view — see §3)
  │
  ├─ action ▶ Page 3  Dependency Explorer (custom section action → freestyle
  │                    app, tree rooted at the application, drill into any
  │                    _Object row)
  │
  └─ row action (from Page 4) ▶ Page 5  Source Viewer (freestyle app,
                                  read-only, opened per-object)
```

## 3. Version History / Delta View (Page 9 detail)

Not a separate page in the navigation sense — a dialog/section launched
from a Page 9 row pair ("compare Vn against Vn-1", or any two versions
picked). Renders three lists (New / Removed / Modified) sourced from
`ZCL_RAP_MT_DELTA` (Doc 10), read-only — delta is a computed comparison,
never a persisted "diff" entity of its own, so there's nothing to expose
as a separate CDS view here.

## 4. Confirmation Dialogs

Only one true confirmation dialog in the app: `GenerateMigrationPackage`
(§13's exact mockup — object/config/document counts, version, Proceed).
Standard FE "unsaved changes" dialogs don't apply here since there's no
draft (Doc 2 §3) — every action is either instantly persisted or
explicitly confirmed, nothing sits in an ambiguous "did you mean to save
that" state.

## 5. Empty States

Per the CDS design-language voice rules: Page 1 empty state is "Start your
first migration workspace" with a create action, not "No data." Page 4/6/7
facets, when a version has zero objects/configs/blockers of that kind
(a scan genuinely found none — a valid, good outcome, not an error),
read "No blockers found in this version." — a status, not an apology.

No new open decisions — this doc is a direct application of Docs 1/2's
structure to concrete FE/freestyle app boundaries.
