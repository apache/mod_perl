#include "../../APR/PerlIO/apr_perlio.h"

#ifndef MP_SOURCE_SCAN
#include "apr_optional.h"

static APR_OPTIONAL_FN_TYPE(apr_perlio_apr_file_to_glob) *apr_file_to_glob;
#endif

/* XXX: probably needs a lot more error checkings */

typedef struct {
    apr_int32_t    in_pipe;
    apr_int32_t    out_pipe;
    apr_int32_t    err_pipe;
    apr_cmdtype_e  cmd_type;
} exec_info;

#define FAILED(command) ((rc = command) != APR_SUCCESS)

#define SET_TIMEOUT(fp) \
    apr_file_pipe_timeout_set(fp, \
                              (int)(r->server->timeout * APR_USEC_PER_SEC))

static int modperl_spawn_proc_prog(request_rec *r,
                                   const char *command,
                                   const char ***argv,
                                   apr_file_t **script_in,
                                   apr_file_t **script_out,
                                   apr_file_t **script_err)
{
    exec_info e_info;
    apr_pool_t *p;
    const char * const *env;

    apr_procattr_t *procattr;
    apr_proc_t *procnew;
    apr_status_t rc = APR_SUCCESS;

    e_info.in_pipe   = APR_CHILD_BLOCK;
    e_info.out_pipe  = APR_CHILD_BLOCK;
    e_info.err_pipe  = APR_CHILD_BLOCK;
    e_info.cmd_type  = APR_PROGRAM;
 
    p = r->main ? r->main->pool : r->pool;

    *script_out = *script_in = *script_err = NULL;

    env = (const char * const *)ap_create_environment(p, r->subprocess_env);

    if (FAILED(apr_procattr_create(&procattr, p)) ||
        FAILED(apr_procattr_io_set(procattr, e_info.in_pipe,
                                   e_info.out_pipe, e_info.err_pipe)) ||
        FAILED(apr_procattr_dir_set(procattr, 
                                    ap_make_dirstr_parent(r->pool,
                                                          r->filename))) ||
        FAILED(apr_procattr_cmdtype_set(procattr, e_info.cmd_type)))
    {
        /* Something bad happened, tell the world. */
        ap_log_rerror(APLOG_MARK, APLOG_ERR, rc, r,
                      "couldn't set child process attributes: %s",
                      r->filename);
        return rc;
    }

    procnew = apr_pcalloc(p, sizeof(*procnew));
    if (FAILED(ap_os_create_privileged_process(r, procnew, command,
                                              *argv, env, procattr, p)))
    {
        /* Bad things happened. Everyone should have cleaned up. */
        ap_log_rerror(APLOG_MARK, APLOG_ERR, rc, r,
                      "couldn't create child process: %d: %s",
                      rc, r->filename);
        return rc;
    }

    apr_pool_note_subprocess(p, procnew, kill_after_timeout);

    if (!(*script_in = procnew->in)) {
        /* XXX: this needs to be Perl_croak(aTHX_ ...)
         * or go away so we can compile with -DPERL_CORE
         */
        croak("broken program-in stream");
        return APR_EBADF;
    }
    SET_TIMEOUT(*script_in);

    if (!(*script_out = procnew->out)) {
        croak("broken program-out stream");
        return APR_EBADF;
    }
    SET_TIMEOUT(*script_in);

    if (!(*script_err = procnew->err)) {
        croak("broken program-err stream");
        return APR_EBADF;
    }
    SET_TIMEOUT(*script_err);

    return rc;
}

static XS(MPXS_modperl_spawn_proc_prog)
{
    dXSARGS;
    const char *usage = "Usage: spawn_proc_prog($r, $command, [\\@argv])";
    
    if (items < 2) {
        Perl_croak(aTHX_ usage);
    }
    
    SP -= items;
    {
        apr_file_t *script_in, *script_out, *script_err;
        apr_status_t rc;
        const char **argv;
        int i;
        AV *av_argv;
        I32 len=-1, av_items=0;
        request_rec *r = modperl_xs_sv2request_rec(aTHX_ ST(0), NULL, cv);
        const char *command = (const char *)SvPV_nolen(ST(1));

        if (items == 3) {
            if (SvROK(ST(2)) && SvTYPE(SvRV(ST(2))) == SVt_PVAV) {
                av_argv = (AV*)SvREFCNT_inc(SvRV(ST(2)));
                len = AvFILLp(av_argv);
                av_items = len+1;
            }
            else {
                Perl_croak(aTHX_ usage);
            }
        }
        else {
            av_argv = newAV();
        }

        /* ap_os_create_privileged_process expects ARGV as char
         * **argv, with terminating NULL and the program itself as a
         * first item.
         */
        argv = apr_palloc(r->pool, (av_items + 2) * sizeof(char *));
        argv[0] = command;
        for (i = 0; i <= len; i++) {
            argv[i+1] = (const char *)SvPV_nolen(AvARRAY(av_argv)[i]);
        }
        argv[i+1] = NULL;
#if 0
        for (i=0; i<=len+2; i++) {
            Perl_warn(aTHX_ "arg: %d %s\n",
                      i, argv[i] ? argv[i] : "NULL");
        }
#endif
        rc = modperl_spawn_proc_prog(r, command, &argv,
                                     &script_in, &script_out,
                                     &script_err);

        SvREFCNT_dec(av_argv);

        if (rc == APR_SUCCESS) {
            /* XXX: apr_file_to_glob should be set once in the BOOT: section */
            apr_file_to_glob =
                APR_RETRIEVE_OPTIONAL_FN(apr_perlio_apr_file_to_glob);
            
            if (GIMME == G_SCALAR) {
                /* XXX: need to do lots of error checking before
                 * putting the object on the stack
                 */
                SV *out = apr_file_to_glob(aTHX_ script_out, r->pool,
                                           APR_PERLIO_HOOK_READ);
                XPUSHs(out);

                rc = apr_file_close(script_in);
                if (rc != APR_SUCCESS) {
                    XSRETURN_UNDEF;
                }

                rc = apr_file_close(script_err);
                if (rc != APR_SUCCESS) {
                    XSRETURN_UNDEF;
                }
            }
            else {
                XPUSHs(apr_file_to_glob(aTHX_ script_in,
                                        r->pool, APR_PERLIO_HOOK_WRITE));
                XPUSHs(apr_file_to_glob(aTHX_ script_out,
                                        r->pool, APR_PERLIO_HOOK_READ));
                XPUSHs(apr_file_to_glob(aTHX_ script_err,
                                        r->pool, APR_PERLIO_HOOK_READ));
            }
        }
        else {
            XSRETURN_UNDEF;
        }
    }

    PUTBACK;
}
