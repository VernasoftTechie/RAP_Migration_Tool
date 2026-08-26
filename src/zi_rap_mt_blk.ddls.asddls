@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'RAP MT - RAP Blocker'
define view entity ZI_RAP_MT_BLK
  as select from zrap_mt_blk

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
  key blocker_uuid     as BlockerUUID,
      object_uuid       as ObjectUUID,
      category           as Category,
      classification      as Classification,
      pattern              as Pattern,
      description           as Description,
      recommendation         as Recommendation,
      source_line             as SourceLine,

      _Version,
      _Object
}
