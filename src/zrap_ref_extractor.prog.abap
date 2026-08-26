*&---------------------------------------------------------------------*
*& Report ZRAP_REF_EXTRACTOR
*&---------------------------------------------------------------------*
*& Scans a classic report (main program + all its INCLUDEs) and pulls
*& out the categories of information you need as reference material
*& before redesigning it as a RAP business object:
*&
*&   - Selection screen fields (PARAMETERS / SELECT-OPTIONS)
*&   - Database tables/views read (SELECT ... FROM / JOIN)
*&   - Z/Y custom tables among those (cross-checked against DD02L)
*&   - AUTHORITY-CHECK objects
*&   - Write operations (UPDATE/MODIFY/INSERT/DELETE, BAPI calls)
*&   - ALV / list-output building blocks in use
*&   - Every other FUNCTION MODULE called (for a general call inventory)
*&
*& This is a line-based regex scan, not a real ABAP parser — multi-line
*& statements, dynamic table names (SELECT ... FROM (lv_tabname)), and
*& macros can be missed or mis-flagged. Treat the output as a starting
*& checklist to verify against the source, not a certified inventory.
*&
*& Results are shown on screen (ALV) and can be exported to a
*& tab-delimited .xls file that opens directly in Excel.
*&---------------------------------------------------------------------*
REPORT zrap_ref_extractor.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
PARAMETERS: p_prog TYPE trdir-name OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
PARAMETERS: p_dload AS CHECKBOX DEFAULT abap_true,
            p_path  TYPE string LOWER CASE
                     DEFAULT 'C:\temp\rap_ref_extract.xls'.
SELECTION-SCREEN END OF BLOCK b2.

TYPES: BEGIN OF ty_ref,
         category TYPE string,
         include  TYPE programm,
         line     TYPE i,
         detail   TYPE string,
       END OF ty_ref.

DATA: gt_refs      TYPE STANDARD TABLE OF ty_ref,
      gt_includes  TYPE STANDARD TABLE OF programm,
      gt_tablelist TYPE STANDARD TABLE OF string.

*&---------------------------------------------------------------------*
*& Category constants — keeps the ALV/export grouping consistent
*&---------------------------------------------------------------------*
CONSTANTS:
  BEGIN OF gc_cat,
    selection    TYPE string VALUE 'Selection Screen',
    table_read   TYPE string VALUE 'Table/View Read',
    table_custom TYPE string VALUE 'Custom (Z/Y) Table Read',
    auth_check   TYPE string VALUE 'Authorization Check',
    write_op     TYPE string VALUE 'Write Operation',
    bapi_call    TYPE string VALUE 'BAPI Call',
    alv_output   TYPE string VALUE 'ALV/Output Building Block',
    func_call    TYPE string VALUE 'Function Module Call',
  END OF gc_cat.

START-OF-SELECTION.
  PERFORM collect_includes USING p_prog CHANGING gt_includes.
  PERFORM scan_includes USING gt_includes CHANGING gt_refs.
  PERFORM flag_custom_tables CHANGING gt_refs.
  PERFORM display_results USING gt_refs.

  IF p_dload = abap_true.
    PERFORM export_to_excel USING gt_refs p_path.
  ENDIF.

*&---------------------------------------------------------------------*
*&      Form  COLLECT_INCLUDES
*&---------------------------------------------------------------------*
FORM collect_includes USING iv_prog TYPE trdir-name
                       CHANGING ct_includes TYPE STANDARD TABLE OF programm.

  DATA: lt_includes TYPE STANDARD TABLE OF rsfdo_incl,
        ls_include  TYPE rsfdo_incl.

  CALL FUNCTION 'RS_GET_ALL_INCLUDES'
    EXPORTING
      program    = iv_prog
    TABLES
      includetab = lt_includes
    EXCEPTIONS
      OTHERS     = 1.

  APPEND iv_prog TO ct_includes.

  LOOP AT lt_includes INTO ls_include.
    APPEND ls_include TO ct_includes.
  ENDLOOP.

  SORT ct_includes.
  DELETE ADJACENT DUPLICATES FROM ct_includes.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  SCAN_INCLUDES
*&---------------------------------------------------------------------*
FORM scan_includes USING it_includes TYPE STANDARD TABLE OF programm
                    CHANGING ct_refs TYPE STANDARD TABLE OF ty_ref.

  DATA: lv_include TYPE programm,
        lt_source  TYPE STANDARD TABLE OF string,
        lv_line    TYPE string,
        lv_lineno  TYPE i.

  LOOP AT it_includes INTO lv_include.
    CLEAR lt_source.

    READ REPORT lv_include INTO lt_source.
    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    lv_lineno = 0.
    LOOP AT lt_source INTO lv_line.
      lv_lineno = lv_lineno + 1.
      PERFORM scan_one_line USING lv_include lv_lineno lv_line
                             CHANGING ct_refs.
    ENDLOOP.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  SCAN_ONE_LINE
*&---------------------------------------------------------------------*
FORM scan_one_line USING iv_include TYPE programm
                          iv_lineno  TYPE i
                          iv_line    TYPE string
                    CHANGING ct_refs TYPE STANDARD TABLE OF ty_ref.

  DATA: ls_ref   TYPE ty_ref,
        lv_name  TYPE string,
        lv_upper TYPE string.

  ls_ref-include = iv_include.
  ls_ref-line    = iv_lineno.

  lv_upper = iv_line.
  TRANSLATE lv_upper TO UPPER CASE.

  " --- Selection screen fields ---------------------------------------
  IF ( lv_upper CP '*PARAMETERS*' OR lv_upper CP '*PARAMETER *'
       OR lv_upper CP '*SELECT-OPTIONS*' OR lv_upper CP '*SELECT-OPTION *' )
     AND NOT lv_upper CS '"'.  " crude single-line-comment filter
    ls_ref-category = gc_cat-selection.
    ls_ref-detail   = iv_line.
    APPEND ls_ref TO ct_refs.
  ENDIF.

  " --- Authorization checks -------------------------------------------
  IF lv_upper CP '*AUTHORITY-CHECK*'.
    ls_ref-category = gc_cat-auth_check.
    ls_ref-detail   = iv_line.
    APPEND ls_ref TO ct_refs.
  ENDIF.

  " --- Tables/views read (SELECT ... FROM / JOIN) ---------------------
  FIND REGEX '(?i)\b(?:FROM|JOIN)\s+([A-Za-z_/][A-Za-z0-9_/]*)'
       IN iv_line SUBMATCHES lv_name.
  IF sy-subrc = 0 AND lv_name IS NOT INITIAL.
    ls_ref-category = gc_cat-table_read.
    ls_ref-detail   = |{ lv_name } (line: { iv_line })|.
    APPEND ls_ref TO ct_refs.
    APPEND lv_name TO gt_tablelist.
  ENDIF.

  " --- Write operations -------------------------------------------------
  IF lv_upper CP '*UPDATE *' OR lv_upper CP '*MODIFY *'
     OR lv_upper CP '*INSERT *' OR lv_upper CP '*DELETE *'.
    FIND REGEX '(?i)\b(?:UPDATE|MODIFY|INSERT|DELETE)\s+([A-Za-z_/][A-Za-z0-9_/]*)'
         IN iv_line SUBMATCHES lv_name.
    IF sy-subrc = 0 AND lv_name IS NOT INITIAL.
      ls_ref-category = gc_cat-write_op.
      ls_ref-detail   = |{ lv_name } (line: { iv_line })|.
      APPEND ls_ref TO ct_refs.
    ENDIF.
  ENDIF.

  " --- CALL FUNCTION (split into BAPI vs. ALV vs. general FM) -----------
  FIND REGEX '(?i)CALL FUNCTION\s+''([A-Za-z0-9_/]+)'''
       IN iv_line SUBMATCHES lv_name.
  IF sy-subrc = 0 AND lv_name IS NOT INITIAL.
    IF lv_name CP 'BAPI*'.
      ls_ref-category = gc_cat-bapi_call.
    ELSEIF lv_name CP '*ALV*'.
      ls_ref-category = gc_cat-alv_output.
    ELSE.
      ls_ref-category = gc_cat-func_call.
    ENDIF.
    ls_ref-detail = lv_name.
    APPEND ls_ref TO ct_refs.
  ENDIF.

  " --- Object-oriented ALV building blocks -------------------------------
  IF lv_upper CP '*CL_SALV_TABLE*' OR lv_upper CP '*CL_GUI_ALV_GRID*'.
    ls_ref-category = gc_cat-alv_output.
    ls_ref-detail   = iv_line.
    APPEND ls_ref TO ct_refs.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  FLAG_CUSTOM_TABLES
*&---------------------------------------------------------------------*
FORM flag_custom_tables CHANGING ct_refs TYPE STANDARD TABLE OF ty_ref.

  DATA: lt_unique TYPE STANDARD TABLE OF string,
        lv_table  TYPE string,
        lv_ddtab  TYPE dd02l-tabname,
        ls_dd02l  TYPE dd02l.

  lt_unique = gt_tablelist.
  SORT lt_unique.
  DELETE ADJACENT DUPLICATES FROM lt_unique.

  LOOP AT lt_unique INTO lv_table.
    IF lv_table(1) = 'Z' OR lv_table(1) = 'Y'
       OR lv_table(1) = 'z' OR lv_table(1) = 'y'.

      lv_ddtab = lv_table.
      SELECT SINGLE * FROM dd02l INTO ls_dd02l
        WHERE tabname = lv_ddtab
          AND as4local = 'A'.
      IF sy-subrc = 0.
        APPEND VALUE ty_ref(
          category = gc_cat-table_custom
          include  = space
          line     = 0
          detail   = |{ lv_table } ({ ls_dd02l-tabclass })| )
        TO ct_refs.
      ENDIF.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  DISPLAY_RESULTS
*&---------------------------------------------------------------------*
FORM display_results USING it_refs TYPE STANDARD TABLE OF ty_ref.

  DATA: lo_salv TYPE REF TO cl_salv_table,
        lo_cols TYPE REF TO cl_salv_columns_table.

  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_salv
        CHANGING  t_table      = it_refs ).

      lo_salv->get_functions( )->set_all( abap_true ).

      lo_cols = lo_salv->get_columns( ).
      lo_cols->set_optimize( abap_true ).

      lo_salv->display( ).
    CATCH cx_salv_msg.
      MESSAGE 'Could not build the ALV output.' TYPE 'I'.
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  EXPORT_TO_EXCEL
*&---------------------------------------------------------------------*
*&  Writes a tab-delimited file — opens directly in Excel, no OLE/xlsx
*&  library dependency, works the same on every GUI patch level.
*&---------------------------------------------------------------------*
FORM export_to_excel USING it_refs TYPE STANDARD TABLE OF ty_ref
                            iv_path TYPE string.

  DATA: lt_lines TYPE STANDARD TABLE OF string,
        ls_ref   TYPE ty_ref,
        lv_line  TYPE string.

  APPEND 'Category' && cl_abap_char_utilities=>horizontal_tab &&
         'Include'  && cl_abap_char_utilities=>horizontal_tab &&
         'Line'     && cl_abap_char_utilities=>horizontal_tab &&
         'Detail'   TO lt_lines.

  LOOP AT it_refs INTO ls_ref.
    lv_line = ls_ref-category && cl_abap_char_utilities=>horizontal_tab &&
              ls_ref-include  && cl_abap_char_utilities=>horizontal_tab &&
              ls_ref-line     && cl_abap_char_utilities=>horizontal_tab &&
              ls_ref-detail.
    APPEND lv_line TO lt_lines.
  ENDLOOP.

  cl_gui_frontend_services=>gui_download(
    EXPORTING
      filename                = iv_path
      filetype                = 'ASC'
      write_field_separator   = abap_false
    CHANGING
      data_tab                = lt_lines
    EXCEPTIONS
      OTHERS                  = 24 ).

  IF sy-subrc <> 0.
    MESSAGE 'Export failed — check the file path and GUI connection.' TYPE 'I'.
  ELSE.
    MESSAGE |Exported to { iv_path }| TYPE 'S'.
  ENDIF.

ENDFORM.
