# ZRAP_MT — Detector Framework

**Phase 1 — Doc 8/12.**

## 1. Contract

```abap
INTERFACE zif_rap_mt_detector.
  TYPES: BEGIN OF ty_scan_context,
           migration_id     TYPE zrap_mt_migrationid,
           application_name TYPE char40,
           application_type TYPE zrap_mt_apptype,
           package          TYPE devclass,
         END OF ty_scan_context.

  METHODS detect
    IMPORTING is_context      TYPE ty_scan_context
    RETURNING VALUE(rt_finds) TYPE zrap_mt_t_obj_finding
    RAISING   zcx_rap_mt_detector_error.
ENDINTERFACE.
```

`zcx_rap_mt_detector_error` is caught by the orchestrator (§3), not left
to propagate — one failing detector must not abort the other nine (§4).

## 2. Detector Classes (Phase 1 set)

| Class | Discovers |
|---|---|
| `ZCL_RAP_MT_DET_PROG` | Reports, includes, module pools, classes, interfaces, function groups/modules, BAPIs, GUI status/menus, dynpros, message classes, search helps, lock objects — reuses the RAP migration extractor's `RS_GET_ALL_INCLUDES` + regex approach (the tool from `RAP_Migration_Tool` repo), extended with proper AST-level detection now that this is a persisted platform, not a one-off script |
| `ZCL_RAP_MT_DET_DDIC` | Tables, structures, views, domains, data elements, table types referenced by `ZCL_RAP_MT_DET_PROG`'s findings — runs *after* PROG in sequence (Doc 3 §3's `SEQUENCE` field on `ZRAP_MT_DETREG` exists specifically for this ordering dependency) |
| `ZCL_RAP_MT_DET_FORM` | SmartForms, Adobe Forms, SAPScript, HR Forms |
| `ZCL_RAP_MT_DET_CFG` | SNRO, TVARVC, SPRO tables, SM30 views, authorization objects → writes to `ZRAP_MT_CFG`, not `ZRAP_MT_OBJ` (different target table, same interface) |
| `ZCL_RAP_MT_DET_OPT` | The optimization patterns from §7 (SELECT in LOOP, nested LOOP, etc.) — classifies via the Rule Engine (Doc 9), doesn't hardcode severities itself |
| `ZCL_RAP_MT_DET_ENH` | BAdIs, user exits, customer exits, enhancement spots, implicit/explicit enhancements |
| `ZCL_RAP_MT_DET_INTG` | RFC, IDoc, SOAP, OData, CPI references, file interfaces |

`ZCL_RAP_MT_DELTA` is explicitly **not** in this table — confirmed again
here, it's a comparison service, not a detector, and never registered in
`ZRAP_MT_DETREG`.

## 3. Orchestrator

```abap
CLASS zcl_rap_mt_det_orchestrator DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS run
      IMPORTING is_context TYPE zif_rap_mt_detector=>ty_scan_context.
ENDCLASS.

CLASS zcl_rap_mt_det_orchestrator IMPLEMENTATION.
  METHOD run.
    SELECT * FROM zrap_mt_detreg WHERE is_active = @abap_true
      ORDER BY sequence
      INTO TABLE @DATA(lt_detectors).

    LOOP AT lt_detectors INTO DATA(ls_det).
      TRY.
          DATA(lo_detector) = CAST zif_rap_mt_detector(
            cl_abap_classdescr=>create_instance( ls_det-class_name ) ).
          DATA(lt_finds) = lo_detector->detect( is_context ).
          persist_findings( iv_migration_id = is_context-migration_id
                             it_finds        = lt_finds
                             iv_detector_id  = ls_det-detector_id ).
        CATCH zcx_rap_mt_detector_error INTO DATA(lx).
          log_detector_failure( iv_detector_id = ls_det-detector_id
                                 ix_error       = lx ).
          " continue to the next detector -- one failure doesn't abort the scan
      ENDTRY.
    ENDLOOP.

    finalize_scan( is_context-migration_id ).
  ENDMETHOD.
ENDCLASS.
```

`persist_findings` writes directly to the **staging version** (`VERSION_NO
= 0`, Doc 3 §5) as each detector completes — not held in memory until the
whole loop finishes, so a scan that fails partway (system restart, dialog
timeout on a very large application) doesn't lose the detectors that did
complete. `finalize_scan` flips `ScanStatus` to `SCAN_OK`/`SCAN_FAILED`.

## 4. Failure Isolation as a Real Requirement, Not Just Robustness

A single mis-written or third-party-contributed detector (§19's future
BRF+/CPI detectors will come from someone else's implementation, not the
original author) must not be able to take down scanning for every other
migration workspace. The `TRY`/`CATCH` around each detector call, plus
per-detector logging (a lightweight append to the standard application
log, `BAL_LOG_CREATE`/`BAL_LOG_MSG_ADD`, not a new custom table — this is
diagnostic data, not migration data, so it doesn't belong in the
`ZRAP_MT_*` persistence model) is the concrete mechanism for that
guarantee, not just a design intention.

No new open decisions — this doc operationalizes Doc 1 §6/§16 exactly.
