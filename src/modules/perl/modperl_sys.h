#ifndef MODPERL_SYS_H
#define MODPERL_SYS_H

/*
 * system specific type stuff.
 * hopefully won't be much here since Perl/APR/Apache
 * take care of most portablity issues.
 */
int modperl_sys_dlclose(void *handle);

#endif /* MODPERL_SYS_H */
