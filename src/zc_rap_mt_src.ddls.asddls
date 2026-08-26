@AccessControl.authorizationCheck: #CHECK
@UI.headerInfo: {
  typeName: 'Source',
  typeNamePlural: 'Sources',
  title: { type: #STANDARD, value: 'ObjectUUID' }
}
define view entity ZC_RAP_MT_SRC
  as projection on ZI_RAP_MT_SRC
{
  key MigrationID,
  key VersionNo,
  key ObjectUUID,

  SourceCode,

  _Object : redirected to parent ZC_RAP_MT_OBJ,
  _Header
}
