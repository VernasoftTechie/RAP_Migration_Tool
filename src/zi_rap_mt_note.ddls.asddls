@AbapCatalog.sqlViewName: 'ZIRAPMTNOTE'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'RAP MT - Architect Note'
define view entity ZI_RAP_MT_NOTE
  as select from zrap_mt_note

  association to parent ZI_RAP_MT_VER as _Version
    on  $projection.MigrationID = _Version.MigrationID
    and $projection.VersionNo   = _Version.VersionNo
{
  key migration_id  as MigrationID,
  key version_no     as VersionNo,
  key note_uuid       as NoteUUID,
      note_text         as NoteText,
      created_by          as CreatedBy,
      created_on           as CreatedOn,

      _Version
}
