#include "modperl_module.h"

static MP_INLINE SV *mpxs_Apache__CmdParms_info(pTHX_ cmd_parms *cmd_parms)
{
    const char *data = ((modperl_module_cmd_data_t *)cmd_parms->info)->cmd_data;

    if (data) {
        return newSVpv(data, 0);
    }

    return &PL_sv_undef;    
}
