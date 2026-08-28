@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'RAP MT - Application Reference (Value Help)'
define view entity ZC_RAP_MT_VH_APP
  as projection on ZI_RAP_MT_VH_APP
{
  key ApplicationType,
  key ApplicationName,
      Description
}
