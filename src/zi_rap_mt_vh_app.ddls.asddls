@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'RAP MT - Application Reference (Value Help)'
define view entity ZI_RAP_MT_VH_APP
  as select from tstc
  left outer join tstct
    on  tstct.tcode = tstc.tcode
    and tstct.sprsl = $session.system_language
{
      'TRAN'                                  as ApplicationType,
  key tstc.tcode                              as ApplicationName,
      cast( tstct.ttext as abap.char( 60 ) )  as Description
}
union all
  select from trdir as prog
  where prog.subc = '1'
{
      'PROG'                                  as ApplicationType,
  key prog.name                               as ApplicationName,
      cast( '' as abap.char( 60 ) )           as Description
}
union all
  select from trdir as mpool
  where mpool.subc = 'M'
{
      'MPOOL'                                 as ApplicationType,
  key mpool.name                              as ApplicationName,
      cast( '' as abap.char( 60 ) )           as Description
}
union all
  select from seoclass
{
      'CLAS'                                  as ApplicationType,
  key seoclass.clsname                        as ApplicationName,
      cast( '' as abap.char( 60 ) )           as Description
}
union all
  select from tdevc
  left outer join tdevctext
    on  tdevctext.devclass = tdevc.devclass
    and tdevctext.spras    = $session.system_language
{
      'PACK'                                  as ApplicationType,
  key tdevc.devclass                          as ApplicationName,
      cast( tdevctext.ctext as abap.char( 60 ) ) as Description
}
