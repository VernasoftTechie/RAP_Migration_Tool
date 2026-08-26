@AccessControl.authorizationCheck: #CHECK
@UI.headerInfo: {
  typeName: 'Configuration',
  typeNamePlural: 'Configurations',
  title: { type: #STANDARD, value: 'ConfigName' }
}
define view entity ZC_RAP_MT_CFG
  as projection on ZI_RAP_MT_CFG
{
  key MigrationID,
  key VersionNo,
  key ConfigUUID,

  @UI.lineItem: [ { position: 10 } ]
  @UI.selectionField: [ { position: 10 } ]
  ConfigType,

  @UI.lineItem: [ { position: 20 } ]
  ConfigName,

  @UI.lineItem: [ { position: 30 } ]
  ReferencedObject,

  Description,
  Detail,

  _Version : redirected to parent ZC_RAP_MT_VER,
  _Header
}
