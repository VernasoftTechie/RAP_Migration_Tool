@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'RAP MT - Configuration Reference'
define view entity ZI_RAP_MT_CFG
  as select from zrap_mt_cfg

  association to parent ZI_RAP_MT_VER as _Version
    on  $projection.MigrationID = _Version.MigrationID
    and $projection.VersionNo   = _Version.VersionNo
{
  key migration_id       as MigrationID,
  key version_no          as VersionNo,
  key config_uuid          as ConfigUUID,
      config_type           as ConfigType,
      config_name            as ConfigName,
      referenced_object       as ReferencedObject,
      description              as Description,
      detail                    as Detail,

      _Version
}
