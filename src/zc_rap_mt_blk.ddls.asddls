@AccessControl.authorizationCheck: #CHECK
@UI.headerInfo: {
  typeName: 'RAP Blocker',
  typeNamePlural: 'RAP Blockers',
  title: { type: #STANDARD, value: 'Pattern' }
}
define view entity ZC_RAP_MT_BLK
  as projection on ZI_RAP_MT_BLK
{
  key MigrationID,
  key VersionNo,
  key BlockerUUID,

  ObjectUUID,

  @UI.lineItem: [ { position: 10 } ]
  Category,

  @UI.lineItem: [ { position: 20 } ]
  @UI.selectionField: [ { position: 10 } ]
  Classification,

  @UI.lineItem: [ { position: 30 } ]
  Pattern,

  Description,
  Recommendation,
  SourceLine,

  _Version : redirected to parent ZC_RAP_MT_VER,
  _Object  : redirected to ZC_RAP_MT_OBJ,
  _Header : redirected to ZC_RAP_MT_HDR
}
