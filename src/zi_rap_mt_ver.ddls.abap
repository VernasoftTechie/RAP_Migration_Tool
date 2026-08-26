@AbapCatalog.sqlViewName: 'ZIRAPMTVER'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'RAP MT - Version'
define view entity ZI_RAP_MT_VER
  as select from zrap_mt_ver

  association to parent ZI_RAP_MT_HDR as _Header
    on $projection.MigrationID = _Header.MigrationID

  composition [0..*] of ZI_RAP_MT_OBJ  as _Object
  composition [0..*] of ZI_RAP_MT_CFG  as _Config
  composition [0..*] of ZI_RAP_MT_OPT  as _Finding
  composition [0..*] of ZI_RAP_MT_BLK  as _Blocker
  composition [0..*] of ZI_RAP_MT_DOC  as _Document
  composition [0..*] of ZI_RAP_MT_NOTE as _Note
{
  key migration_id           as MigrationID,
  key version_no              as VersionNo,
      scan_timestamp           as ScanTimestamp,
      tr_number                as TRNumber,
      is_immutable             as IsImmutable,
      created_by               as CreatedBy,
      created_on               as CreatedOn,
      readiness_repo_pct       as ReadinessRepositoryPct,
      readiness_ddic_pct       as ReadinessDdicPct,
      readiness_cfg_pct        as ReadinessConfigPct,
      readiness_doc_pct        as ReadinessDocumentationPct,
      readiness_opt_health     as ReadinessOptimizationHealth,
      readiness_blocker_count  as ReadinessBlockerCount,

      _Header,
      _Object,
      _Config,
      _Finding,
      _Blocker,
      _Document,
      _Note
}
