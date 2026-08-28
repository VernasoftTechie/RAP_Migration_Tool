# ZRAP_MT — Behavior Design

**Phase 1 — Doc 5/12.** Defines the root behavior definition, its actions,
validations, determinations, and authorization — the doc that makes Golden
Constitution Rules 1–4 executable, not just structural.

**Implementation correction (found via real ADT scaffolding, not
guessed):** a behavior definition is **one ABAP repository object per
composition tree**, not one per CDS entity. All 9 entities'
`define behavior for X { }` blocks live in a single source file/object,
named after the root (`ZI_RAP_MT_HDR`). Also: the implementation class
name ADT actually generates is `ZBP_I_RAP_MT_HDR` (with the `I_` infix),
not `ZBP_RAP_MT_HDR` as first drafted here — corrected below and in
Golden Constitution Rule 7's examples going forward. Every child entity's
default-scaffolded `update;`/`delete;` operations were removed in the
real implementation, keeping only `create` (via the parent association)
and pass-through associations — consistent with this doc's own "no
update/delete below the root" design, just enforced across the whole
tree rather than only described for the root.

**Second correction:** every field referenced in a to-parent association's
`ON` clause must be declared `field(readonly)` in that child's own block —
independent of whether `update` itself is even declared. And `lock`/
`authorization dependent by` must reference an association pointing
**directly** at the entity marked `lock master`/`authorization master`
(`ZI_RAP_MT_HDR`) — it does not chain transitively through `_Version`.
Every entity below `ZI_RAP_MT_VER` therefore carries an additional direct
`_Header` association (Doc 4) used only for this delegation, alongside
its normal parent association used for data navigation.

## 1. Root Behavior Definition — `ZRAP_MT_HDR`

**Correction against the original sketch below:** `GenerateMigrationPackage`
is bound to `ZI_RAP_MT_VER`, not the root — this doc's own §3 always
described and implemented it that way (`READ ENTITY ... ZI_RAP_MT_VER`),
but the code sketch here originally, incorrectly, placed it under
`ZI_RAP_MT_HDR`. Also: `Package` → `Pack` (reserved-word rename, Doc 3/4),
no `with draft` (non-draft was already decided in Doc 1 §3), and
`UploadDocument`/`AddNote` are deferred — `AddNote` needs no custom action
at all (the plain `association _Note { create; }` already covers it
exactly as designed); `UploadDocument` needs its parameter shape properly
designed against the not-yet-built doc store adapter before it's worth
declaring.

```abap
managed implementation in class zbp_i_rap_mt_hdr unique;
strict(2);

define behavior for ZI_RAP_MT_HDR alias MigrationWorkspace
persistent table zrap_mt_hdr
lock master
authorization master ( instance )
etag master LastScanTimestamp
{
  create;
  field ( readonly ) MigrationID, CreatedBy, CreatedOn, CurrentVersionNo,
                      LastScanTimestamp, ScanStatus,
                      ReadinessRepositoryPct, ReadinessDdicPct,
                      ReadinessConfigPct, ReadinessDocumentationPct,
                      ReadinessOptimizationHealth, ReadinessBlockerCount;
  field ( mandatory ) ApplicationName, ApplicationType, Pack;

  action RunScan result [1] $self;
  action ( features : instance ) SaveVersion result [1] $self;

  association _Version { create; }
}

define behavior for ZI_RAP_MT_VER alias Version
persistent table zrap_mt_ver
lock dependent by _Header
authorization dependent by _Header
{
  action GenerateMigrationPackage parameter ZRAP_MT_A_GENPKG result [1] $self;

  association _Header;
  association _Object   { create; }
  association _Config   { create; }
  association _Finding  { create; }
  association _Blocker  { create; }
  association _Document { create; }
  association _Note     { create; }
}
```

`ZRAP_MT_A_GENPKG` is a CDS **abstract entity** (`define abstract entity
ZRAP_MT_A_GENPKG { Confirmed : abap_bool; }`) — the modern RAP pattern for
action parameter types, used instead of a raw DDIC structure.

`strict(2)` is deliberate — Phase 1 has no legacy compatibility need, so
the strictest RAP mode catches modeling mistakes (missing `field`
classifications, etc.) at activation time rather than at runtime.

`update` exists on Version only because `IsImmutable` needs to flip from
false → true as a side effect of `GenerateMigrationPackage` — everything
else on a Version row is genuinely immutable. No `delete` anywhere below
the root, and root `delete` is **deliberately absent too** — even the top
level Migration Workspace can't be deleted through this API, matching
"never delete historical migration snapshots" applied maximally strictly.
If a workspace is ever truly wrong (e.g. created against the wrong
application), the correct action is a new workspace, not deletion of the
mistaken one — the audit trail of "this was scanned incorrectly" has value
too.

## 2. `RunScan` — Validation as Rule 1 Enforcement

```abap
METHOD run_scan.
  " 1. Verify the application reference actually exists before scanning
  "    anything -- this IS Golden Rule 1, not just documentation of it.
  LOOP AT keys INTO DATA(ls_key).
    READ ENTITY IN LOCAL MODE ZI_RAP_MT_HDR
      FIELDS ( ApplicationName ApplicationType )
      WITH VALUE #( ( MigrationID = ls_key-MigrationID ) )
      RESULT DATA(lt_hdr).

    DATA(lv_verified) = verify_application_exists(
      iv_name = lt_hdr[ 1 ]-ApplicationName
      iv_type = lt_hdr[ 1 ]-ApplicationType ).

    IF lv_verified = abap_false.
      APPEND VALUE #( %key = ls_key-%key
                       %msg = new_message( id = 'ZRAP_MT' number = '001'
                                            severity = if_abap_behv_message=>severity-error ) )
             TO reported-migrationworkspace.
      APPEND ls_key TO failed-migrationworkspace.
      CONTINUE.
    ENDIF.

    " 2. Set status + submit background job (Doc 1 §5)
    MODIFY ENTITIES OF ZI_RAP_MT_HDR
      ENTITY MigrationWorkspace
      UPDATE FIELDS ( ScanStatus ) WITH VALUE #( ( MigrationID = ls_key-MigrationID ScanStatus = 'SCANNING' ) ).

    submit_scan_job( ls_key-MigrationID ).
  ENDLOOP.
ENDMETHOD.
```

`verify_application_exists` dispatches by `ApplicationType` to the
appropriate standard check (`RS_PROGRAM_CHECK`-family for PROG/MPOOL,
`SEO_CLASS_EXISTS`-family for CLAS, `TSTC` read for TRAN, `TDEVC` read for
PACK) — one small private method per type, not a single sprawling
`CASE` with inline logic, so a fifth application type later is additive.

## 3. `GenerateMigrationPackage` — Confirmation Enforced Server-Side

```abap
TYPES: BEGIN OF zrap_mt_a_genpkg,
         confirmed TYPE abap_bool,
       END OF zrap_mt_a_genpkg.
```

```abap
METHOD generate_migration_package.
  LOOP AT keys INTO DATA(ls_key).
    IF ls_key-%param-confirmed <> abap_true.
      " Reject regardless of what the UI dialog showed -- §13's
      " confirmation is a server-side gate, not just client UX.
      APPEND VALUE #( %key = ls_key-%key
                       %msg = new_message( id = 'ZRAP_MT' number = '002'
                                            severity = if_abap_behv_message=>severity-error ) )
             TO reported-version.
      APPEND ls_key TO failed-version.
      CONTINUE.
    ENDIF.

    READ ENTITY IN LOCAL MODE ZI_RAP_MT_VER
      FIELDS ( IsImmutable )
      WITH VALUE #( ( %tky = ls_key-%tky ) )
      RESULT DATA(lt_ver).

    IF lt_ver[ 1 ]-IsImmutable = abap_true.
      APPEND VALUE #( %key = ls_key-%key
                       %msg = new_message( id = 'ZRAP_MT' number = '003'
                                            severity = if_abap_behv_message=>severity-error ) )
             TO reported-version.
      APPEND ls_key TO failed-version.
      CONTINUE.
    ENDIF.

    " create TR, add objects, freeze -- delegates to ZCL_RAP_MT_TR_GENERATOR (Doc 11)
  ENDLOOP.
ENDMETHOD.
```

## 4. Determinations

| Determination | On | Trigger | Effect |
|---|---|---|---|
| `RecalcReadiness` | `ZI_RAP_MT_VER` | on save, after `_Finding`/`_Blocker`/`_Object` children change during `SaveVersion` | computes the six readiness metrics (Doc "17") from the just-written children, writes them onto the Version row — never left for the UI to compute client-side, so every consumer (Fiori, JSON export) sees the same numbers |
| `MirrorReadinessToHeader` | `ZI_RAP_MT_HDR` | after `RecalcReadiness` commits | copies the new Version's metrics onto Header's denormalized summary fields + bumps `CurrentVersionNo` |

## 5. Validations

| Validation | On | Checks |
|---|---|---|
| `ApplicationReferenceValid` | `ZI_RAP_MT_HDR`, on create | duplicate of the `RunScan` check, also enforced at creation time so a workspace can never exist pointing at a non-existent application, even before the first scan runs |
| `VersionNotImmutable` | `ZI_RAP_MT_VER`, before any child create | rejects `UploadDocument`/`AddNote` against a version where `IsImmutable = true` — closes a gap the constitution didn't explicitly call out: §12 says the *snapshot* is immutable, but didn't say whether new documents/notes could still be attached after TR creation. **Decision made**: no — immutable means immutable, full stop. Flagging this interpretation explicitly since it's a judgment call, not a literal spec requirement. |

## 6. Authorization

Single new object `ZRAP_MT_AUTH` (per Doc 1 §11), fields: `ACTVT` (standard
activity: 01 Create, 02 Change, 03 Display) and `DEVCLASS` (the standard
package auth field, reused rather than inventing one — also sidesteps the
`PACKAGE`-is-a-reserved-word issue hit on the DDIC tables) so authorization
can be scoped by which packages a user is allowed to run migration
intelligence against — a real landscape will have teams that shouldn't see
each other's in-flight migrations). Checked in `RunScan` and
`GenerateMigrationPackage` specifically — `03 Display` alone is enough for
every read-only page (§14 Pages 1–9 except the actions themselves);
`GenerateMigrationPackage` additionally checks `02 Change` given it writes
a Workbench TR, a higher-privilege side effect than anything else in the
tool.

## 7. Decisions Made In This Doc (flagging, not silently deciding)

1. Root **delete is absent entirely** — stricter than "never overwrite,"
   extended to "never delete the workspace either." Confirm this is the
   right read of the constitution, or whether a genuinely-wrong workspace
   should have some (audited, logged) deletion path.
2. **Post-immutability document/note attachment is blocked.** Confirm vs.
   an alternative where documents can still be added after TR creation
   (only the *technical* snapshot freezes, not the *document trail*).
