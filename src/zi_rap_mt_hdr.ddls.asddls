@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'RAP MT - Migration Workspace'
define root view entity ZI_RAP_MT_HDR
  as select from zrap_mt_hdr
  composition [0..*] of ZI_RAP_MT_VER as _Version
{
  key migration_id            as MigrationID,
      application_name        as ApplicationName,
      application_type        as ApplicationType,
      dev_package              as Pack,
      description              as Description,
      created_by               as CreatedBy,
      created_on               as CreatedOn,
      current_version_no       as CurrentVersionNo,
      last_scan_timestamp      as LastScanTimestamp,
      scan_status              as ScanStatus,
      readiness_repo_pct       as ReadinessRepositoryPct,
      readiness_ddic_pct       as ReadinessDdicPct,
      readiness_cfg_pct        as ReadinessConfigPct,
      readiness_doc_pct        as ReadinessDocumentationPct,
      readiness_opt_health     as ReadinessOptimizationHealth,
      readiness_blocker_count  as ReadinessBlockerCount,

      _Version
}
