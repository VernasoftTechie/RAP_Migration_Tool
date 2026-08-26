@AccessControl.authorizationCheck: #CHECK
@UI.headerInfo: {
  typeName: 'Document',
  typeNamePlural: 'Documents',
  title: { type: #STANDARD, value: 'FileName' }
}
define view entity ZC_RAP_MT_DOC
  as projection on ZI_RAP_MT_DOC
{
  key MigrationID,
  key VersionNo,
  key DocUUID,

  @UI.lineItem: [ { position: 10 } ]
  @UI.selectionField: [ { position: 10 } ]
  DocType,

  @UI.lineItem: [ { position: 20 } ]
  FileName,

  OpenTextID,

  @UI.lineItem: [ { position: 30 } ]
  IsStubbed,

  UploadedBy,
  UploadTimestamp,

  _Version : redirected to parent ZC_RAP_MT_VER
}
