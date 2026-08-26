@AccessControl.authorizationCheck: #CHECK
@UI.headerInfo: {
  typeName: 'Migration Workspace',
  typeNamePlural: 'Migration Workspaces',
  title: { type: #STANDARD, value: 'ApplicationName' },
  description: { type: #STANDARD, value: 'MigrationID' }
}
@Search.searchable: true
define root view entity ZC_RAP_MT_HDR
  provider contract transactional_query
  as projection on ZI_RAP_MT_HDR
{
  @UI.facet: [
    { id: 'Overview', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE, label: 'Overview', position: 10 },
    { id: 'VersionHistory', purpose: #STANDARD, type: #LINEITEM_REFERENCE, targetElement: '_Version', label: 'Version History', position: 20 }
  ]
  key MigrationID,

  @UI.lineItem: [ { position: 10, importance: #HIGH } ]
  @UI.identification: [ { position: 10 } ]
  @Search.defaultSearchElement: true
  ApplicationName,

  @UI.lineItem: [ { position: 20 } ]
  @UI.identification: [ { position: 20 } ]
  @UI.selectionField: [ { position: 10 } ]
  ApplicationType,

  @UI.identification: [ { position: 30 } ]
  Pack,

  @UI.identification: [ { position: 40 } ]
  Description,

  @UI.identification: [ { position: 50 } ]
  CreatedBy,

  @UI.identification: [ { position: 60 } ]
  CreatedOn,

  @UI.lineItem: [ { position: 30 } ]
  @UI.identification: [ { position: 70 } ]
  CurrentVersionNo,

  @UI.identification: [ { position: 80 } ]
  LastScanTimestamp,

  @UI.lineItem: [ { position: 40 } ]
  @UI.identification: [ { position: 90 } ]
  @UI.selectionField: [ { position: 20 } ]
  ScanStatus,

  @UI.dataPoint: { title: 'Repository %' }
  @UI.identification: [ { position: 100 } ]
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

  _Version : redirected to composition child ZC_RAP_MT_VER
}
