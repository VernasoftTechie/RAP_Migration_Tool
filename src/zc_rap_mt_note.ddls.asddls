@Metadata.layer: #CORE
@UI.headerInfo: {
  typeName: 'Architect Note',
  typeNamePlural: 'Architect Notes',
  title: { type: #STANDARD, value: 'CreatedBy' }
}
define view entity ZC_RAP_MT_NOTE
  as projection on ZI_RAP_MT_NOTE
{
  key MigrationID,
  key VersionNo,
  key NoteUUID,

  @UI.lineItem: [ { position: 10 } ]
  NoteText,

  @UI.lineItem: [ { position: 20 } ]
  CreatedBy,

  @UI.lineItem: [ { position: 30 } ]
  CreatedOn,

  _Version : redirected to parent ZC_RAP_MT_VER
}
