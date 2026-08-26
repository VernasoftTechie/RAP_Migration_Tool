@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'RAP MT - Document'
define view entity ZI_RAP_MT_DOC
  as select from zrap_mt_doc

  association to parent ZI_RAP_MT_VER as _Version
    on  $projection.MigrationID = _Version.MigrationID
    and $projection.VersionNo   = _Version.VersionNo
{
  key migration_id     as MigrationID,
  key version_no        as VersionNo,
  key doc_uuid            as DocUUID,
      doc_type              as DocType,
      opentext_id            as OpenTextID,
      is_stubbed              as IsStubbed,
      file_name                as FileName,
      uploaded_by               as UploadedBy,
      upload_timestamp           as UploadTimestamp,

      _Version
}
