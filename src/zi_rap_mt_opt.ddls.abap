@AbapCatalog.sqlViewName: 'ZIRAPMTOPT'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'RAP MT - Optimization Finding'
define view entity ZI_RAP_MT_OPT
  as select from zrap_mt_opt

  association to parent ZI_RAP_MT_VER as _Version
    on  $projection.MigrationID = _Version.MigrationID
    and $projection.VersionNo   = _Version.VersionNo

  association [0..1] to ZI_RAP_MT_OBJ as _Object
    on  $projection.MigrationID = _Object.MigrationID
    and $projection.VersionNo   = _Object.VersionNo
    and $projection.ObjectUUID  = _Object.ObjectUUID
{
  key migration_id   as MigrationID,
  key version_no      as VersionNo,
  key finding_uuid     as FindingUUID,
      object_uuid       as ObjectUUID,
      category           as Category,
      severity            as Severity,
      pattern              as Pattern,
      description           as Description,
      recommendation         as Recommendation,
      source_line             as SourceLine,

      _Version,
      _Object
}
