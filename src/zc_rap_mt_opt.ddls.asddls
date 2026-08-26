@UI.headerInfo: {
  typeName: 'Optimization Finding',
  typeNamePlural: 'Optimization Findings',
  title: { type: #STANDARD, value: 'Pattern' }
}
define view entity ZC_RAP_MT_OPT
  as projection on ZI_RAP_MT_OPT
{
  key MigrationID,
  key VersionNo,
  key FindingUUID,

  ObjectUUID,

  @UI.lineItem: [ { position: 10 } ]
  Category,

  @UI.lineItem: [ { position: 20 } ]
  @UI.selectionField: [ { position: 10 } ]
  Severity,

  @UI.lineItem: [ { position: 30 } ]
  Pattern,

  Description,
  Recommendation,
  SourceLine,

  _Version : redirected to parent ZC_RAP_MT_VER,
  _Object  : redirected to ZC_RAP_MT_OBJ
}
