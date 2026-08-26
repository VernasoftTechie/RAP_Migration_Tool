@Metadata.layer: #CORE
@UI.headerInfo: {
  typeName: 'Repository Object',
  typeNamePlural: 'Repository Objects',
  title: { type: #STANDARD, value: 'ObjectName' }
}
define view entity ZC_RAP_MT_OBJ
  as projection on ZI_RAP_MT_OBJ
{
  key MigrationID,
  key VersionNo,
  key ObjectUUID,

  @UI.lineItem: [ { position: 10, importance: #HIGH } ]
  @UI.selectionField: [ { position: 10 } ]
  ObjectName,

  @UI.lineItem: [ { position: 20 } ]
  @UI.selectionField: [ { position: 20 } ]
  ObjectType,

  @UI.lineItem: [ { position: 30 } ]
  @UI.selectionField: [ { position: 30 } ]
  Pack,

  @UI.lineItem: [ { position: 40 } ]
  LastChangedBy,

  LastChangedOn,
  Fingerprint,
  DiscoveredByDetectorID,

  _Version : redirected to parent ZC_RAP_MT_VER,
  _Source  : redirected to composition child ZC_RAP_MT_SRC,
  _ObjectTypeText
}
