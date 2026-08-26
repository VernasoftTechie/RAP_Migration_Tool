@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'RAP MT - Source Repository'
define view entity ZI_RAP_MT_SRC
  as select from zrap_mt_src

  association to parent ZI_RAP_MT_OBJ as _Object
    on  $projection.MigrationID = _Object.MigrationID
    and $projection.VersionNo   = _Object.VersionNo
    and $projection.ObjectUUID  = _Object.ObjectUUID
{
  key migration_id  as MigrationID,
  key version_no     as VersionNo,
  key object_uuid     as ObjectUUID,
      source_code      as SourceCode,

      _Object
}
