@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'RAP MT - Repository Object'
define view entity ZI_RAP_MT_OBJ
  as select from zrap_mt_obj

  association to parent ZI_RAP_MT_VER as _Version
    on  $projection.MigrationID = _Version.MigrationID
    and $projection.VersionNo   = _Version.VersionNo

  composition [0..1] of ZI_RAP_MT_SRC as _Source

  association [0..1] to ZRAP_MT_OTYPE_T as _ObjectTypeText
    on $projection.ObjectType = _ObjectTypeText.ObjectType
{
  key migration_id              as MigrationID,
  key version_no                 as VersionNo,
  key object_uuid                 as ObjectUUID,
      object_name                  as ObjectName,
      object_type                   as ObjectType,
      dev_package                    as Pack,
      last_changed_by                as LastChangedBy,
      last_changed_on                as LastChangedOn,
      fingerprint                     as Fingerprint,
      discovered_by_detector_id       as DiscoveredByDetectorID,

      _Version,
      _Source,
      _ObjectTypeText
}
