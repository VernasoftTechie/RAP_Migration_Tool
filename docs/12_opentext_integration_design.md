# ZRAP_MT — OpenText Integration Design

**Phase 1 — Doc 12/12.**

## 1. Interface (unchanged from Doc 1 §8 / Doc 2 §4)

```abap
INTERFACE zif_rap_mt_doc_store.
  METHODS upload
    IMPORTING iv_filename           TYPE string
              iv_doc_type           TYPE zrap_mt_doctype
              iv_content            TYPE xstring
    RETURNING VALUE(rs_result)      TYPE zrap_mt_s_doc_store_result
    RAISING   zcx_rap_mt_doc_store_error.

  METHODS download
    IMPORTING iv_opentext_id        TYPE zrap_mt_opentextid
    RETURNING VALUE(rv_content)     TYPE xstring
    RAISING   zcx_rap_mt_doc_store_error.
ENDINTERFACE.
```

`zrap_mt_s_doc_store_result` carries both `OpenTextID` and `IsStubbed` —
the adapter, not the caller, decides whether a given call was real or
stubbed, so `UploadDocument` (Doc 5) never needs adapter-specific
knowledge.

## 2. Phase 1 Implementation — Stub Only

```abap
CLASS zcl_rap_mt_doc_store_stub DEFINITION FOR TESTING
  " not actually FOR TESTING -- flagging this deliberately: see note below
  .
```

Correction — **not** `FOR TESTING`. `ZCL_RAP_MT_DOC_STORE_STUB` is a real,
shippable Phase 1 class (per your instruction to proceed with a dummy ID
now), just not a permanent one:

```abap
CLASS zcl_rap_mt_doc_store_stub DEFINITION.
  PUBLIC SECTION.
    INTERFACES zif_rap_mt_doc_store.
ENDCLASS.

CLASS zcl_rap_mt_doc_store_stub IMPLEMENTATION.
  METHOD zif_rap_mt_doc_store~upload.
    rs_result-opentext_id = |STUB-{ cl_system_uuid=>create_uuid_x16_static( ) }|.
    rs_result-is_stubbed  = abap_true.
  ENDMETHOD.

  METHOD zif_rap_mt_doc_store~download.
    RAISE EXCEPTION TYPE zcx_rap_mt_doc_store_error
      EXPORTING textid = zcx_rap_mt_doc_store_error=>stub_cannot_download.
  ENDMETHOD.
ENDCLASS.
```

`download` deliberately **fails loudly** rather than returning empty/fake
content — a stubbed upload producing a fake ID is a reasonable
placeholder; a stubbed *download* silently returning nothing could be
mistaken for "the document is empty" instead of "this was never really
stored." Uploads can be faked safely; retrieval failure needs to be
impossible to mistake for success.

## 3. Adapter Selection

Bound via a single customizing switch (a new one-row table
`ZRAP_MT_DOCADPT`, fields `ADAPTER_CLASS` + `IS_ACTIVE`) rather than a
hardcoded `CREATE OBJECT zcl_rap_mt_doc_store_stub` in
`UploadDocument` — the same registry pattern as detectors/rules (Docs
8/9), so switching to a real adapter later is a config change, not a
behavior-pool code change. This is a new table beyond Doc 3's original
list, consistent with the pattern already established there.

## 4. Real Adapter — Deferred, Interface Frozen Now

The concrete real implementation isn't built in Phase 1 (per your
instruction — "will fill it later"). What Phase 1 *does* lock in is the
interface shape, so that whichever mechanism turns out to be in place
(ArchiveLink/CMIS/CPI middleware — Doc 1 §8's open question) plugs in as
`ZCL_RAP_MT_DOC_STORE_ARCHIVELINK` / `_CMIS` / `_CPI` implementing the
same `ZIF_RAP_MT_DOC_STORE`, activated via the `ZRAP_MT_DOCADPT` switch,
with zero changes to `UploadDocument`, the CDS model, or the UI.

## 5. Migration Path for Already-Stubbed Documents

Worth deciding now rather than after documents have accumulated: when a
real adapter goes live, existing `ZRAP_MT_DOC` rows with
`IS_STUBBED = abap_true` are **not** automatically re-uploaded — Rule 2
("never overwrite previous migration records") applies here too. A
stubbed document row stays exactly as it is (a historical record that a
document existed and was referenced, even if never really archived);
real re-upload of that specific file, if wanted, would be a manual,
explicit action producing a *new* document row, not a silent rewrite of
the old one.

---

## Summary — All 12 Docs Complete

Every doc from Doc 1's methodology is now drafted. Outstanding items
needing your explicit sign-off, collected across all docs:

1. Managed/non-draft RAP BO decision (Doc 1 §3)
2. `ZRAP_MT_OPT`/`ZRAP_MT_BLK` tables (Doc 1 §4.1)
3. `ZRAP_MT_DETREG`/`ZRAP_MT_RULE` registry tables (Doc 1 §6/§7)
4. Background-job scan model (Doc 1 §5)
5. ~~OpenText mechanism~~ — resolved (stub, this doc)
6. Source-versioning storage tradeoff — full copy per version (Doc 3 §5)
7. Staging-version mechanism, `VERSION_NO = 0` (Doc 3 §5)
8. No root `delete` operation at all (Doc 5 §7.1)
9. Document/note attachment blocked once a version is immutable (Doc 5 §7.2)
10. "Resolved blockers" addition to the delta output (Doc 10 §2)
11. `IsTransportable` flag on the object-type check table (Doc 11 §2)
12. New `README` document type value (Doc 11 §2)
13. New `ZRAP_MT_DOCADPT` adapter-selection table (this doc, §3)

Nothing has been implemented in ABAP yet — per your own methodology
(§20), that starts once you've reviewed this list.
