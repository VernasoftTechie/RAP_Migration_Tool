# ZRAP_MT — Service Definition

**Phase 1 — Doc 6/12.**

## 1. Service Definition — `ZRAP_MT_UI_SRVD`

```abap
@EndUserText.label: 'RAP MT - Migration Intelligence UI'
define service ZRAP_MT_UI_SRVD {
  expose ZC_RAP_MT_HDR as MigrationWorkspace;
  expose ZC_RAP_MT_VER as Version;
  expose ZC_RAP_MT_OBJ as RepositoryObject;
  expose ZC_RAP_MT_SRC as SourceRepository;
  expose ZC_RAP_MT_CFG as Configuration;
  expose ZC_RAP_MT_OPT as OptimizationFinding;
  expose ZC_RAP_MT_BLK as Blocker;
  expose ZC_RAP_MT_DOC as Document;
  expose ZC_RAP_MT_NOTE as ArchitectNote;
}
```

One service definition, one binding (`ZRAP_MT_UI_SRVB`, OData V4, UI) —
not split per-page, since every page (Doc 1 §10) reads from the same
composition tree and RAP's single-service-per-BO model handles that
natively without needing separate services to keep pages "independent."

## 2. Service Binding

`ZRAP_MT_UI_SRVB`, binding type **ODATA V4 - UI**, one binding for all
nine Fiori pages (Doc 1 §10's freestyle-UI5 exceptions for pages 3 and 5
still consume this same OData service — a freestyle app is still just an
OData client, not a reason for a separate binding).

## 3. What's deliberately not exposed

`ZRAP_MT_DETREG` and `ZRAP_MT_RULE` (the detector/rule registry configs)
are **not** exposed through this service. They're maintained via a plain
SM30-style maintenance view (a separate, small, non-RAP object — a
Generated Table Maintenance dialog is a better fit than a Fiori app for a
handful of admins editing a technical config table), not surfaced to the
same audience using the migration intelligence UI. Keeping them out of
this service also means a bug in service exposure can't accidentally let
an ordinary user edit detector wiring meant only for tool admins.

No new decisions in this doc.
