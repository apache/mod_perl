#ifndef MODPERL_TYPES_H
#define MODPERL_TYPES_H

/* aliases */

typedef ap_array_header_t MpAV;
typedef ap_table_t        MpHV;

/* xs typemap */

typedef request_rec *  Apache;
typedef request_rec *  Apache__SubRequest;
typedef conn_rec    *  Apache__Connection;
typedef server_rec  *  Apache__Server;

typedef cmd_parms   *  Apache__CmdParms;
typedef module      *  Apache__Module;
typedef handler_rec *  Apache__Handler;
typedef command_rec *  Apache__Command;

typedef ap_table_t   * Apache__table;
typedef ap_pool_t    * Apache__Pool;

/* mod_perl structures */

typedef struct modperl_interp_t modperl_interp_t;

struct modperl_interp_t {
    ap_lock_t *mip_lock;
    PerlInterpreter *perl;
    modperl_interp_t *next;
    int flags;
};

typedef struct {
    ap_lock_t *mip_lock;
    int start; /* number of Perl intepreters to start (clone) */
    int min_spare; /* minimum number of spare Perl interpreters */
    int max_spare; /* maximum number of spare Perl interpreters */
    int size; /* current number of Perl interpreters */
    modperl_interp_t *parent; /* from which to perl_clone() */
    modperl_interp_t *head;
} modperl_interp_pool_t;

typedef struct {
    MpAV *handlers[MP_PROCESS_NUM_HANDLERS];
} modperl_process_config_t;

typedef struct {
    MpAV *handlers[MP_CONNECTION_NUM_HANDLERS];
} modperl_connection_config_t;

typedef struct {
    MpAV *handlers[MP_FILES_NUM_HANDLERS];
} modperl_files_config_t;

typedef struct {
    MpHV *SetVars;
    MpAV *PassEnv;
    MpAV *PerlRequire, *PerlModule;
    MpAV *handlers[MP_PER_SRV_NUM_HANDLERS];
    modperl_process_config_t *process_cfg;
    modperl_connection_config_t *connection_cfg;
    modperl_interp_pool_t *mip;
    int flags;
} modperl_srv_config_t;

typedef struct {
    char *location;
    char *PerlDispatchHandler;
    MpAV *handlers[MP_PER_DIR_NUM_HANDLERS];
    MpHV *SetEnv;
    MpHV *SetVars;
    int flags;
} modperl_dir_config_t;

typedef struct {
    HV *pnotes;
} modperl_per_request_config_t;

typedef struct {
    SV *obj;
    CV *cv;
    char *name;
    int flags;
} modperl_handler_t;

#endif /* MODPERL_TYPES_H */
