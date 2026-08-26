@Metadata.layer: #CORE
@UI.headerInfo: {
  typeName: 'Version',
  typeNamePlural: 'Versions',
  title: { type: #STANDARD, value: 'VersionNo' }
}
define view entity ZC_RAP_MT_VER
  as projection on ZI_RAP_MT_VER
{
  @UI.facet: [
    { id: 'Overview', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Overview', position: 10 },
    { id: 'Objects', purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Object', label: 'Repository Objects', position: 20 },
    { id: 'Config', purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Config', label: 'Configurations', position: 30 },
    { id: 'Findings', purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Finding', label: 'Optimization Findings', position: 40 },
    { id: 'Blockers', purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Blocker', label: 'RAP Blockers', position: 50 },
    { id: 'Documents', purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Document', label: 'Documents', position: 60 },
    { id: 'Notes', purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Note', label: 'Architect Notes', position: 70 }
  ]
  key MigrationID,
  key VersionNo,

  @UI.identification: [ { position: 10 } ]
  ScanTimestamp,

  @UI.identification: [ { position: 20 } ]
  TRNumber,

  @UI.lineItem: [ { position: 10 } ]
  @UI.identification: [ { position: 30 } ]
  IsImmutable,

  @UI.identification: [ { position: 40 } ]
  CreatedBy,

  @UI.identification: [ { position: 50 } ]
  CreatedOn,

  @UI.dataPoint: { title: 'Repository %' }
  ReadinessRepositoryPct,

  @UI.dataPoint: { title: 'DDIC %' }
  ReadinessDdicPct,

  @UI.dataPoint: { title: 'Config %' }
  ReadinessConfigPct,

  @UI.dataPoint: { title: 'Documentation %' }
  ReadinessDocumentationPct,

  @UI.dataPoint: { title: 'Optimization Health' }
  ReadinessOptimizationHealth,

  @UI.dataPoint: { title: 'Blockers' }
  ReadinessBlockerCount,

  _Header   : redirected to parent ZC_RAP_MT_HDR,
  _Object   : redirected to composition child ZC_RAP_MT_OBJ,
  _Config   : redirected to composition child ZC_RAP_MT_CFG,
  _Finding  : redirected to composition child ZC_RAP_MT_OPT,
  _Blocker  : redirected to composition child ZC_RAP_MT_BLK,
  _Document : redirected to composition child ZC_RAP_MT_DOC,
  _Note     : redirected to composition child ZC_RAP_MT_NOTE
}
