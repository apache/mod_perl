#ifndef MODPERL_IO_H
#define MODPERL_IO_H

#define IoFLUSH_off(gv) \
IoFLAGS(GvIOp((gv))) &= ~IOf_FLUSH

#define IoFLUSH_on(gv) \
IoFLAGS(GvIOp((gv))) |= IOf_FLUSH

#define IoFLUSH(gv) \
(IoFLAGS(GvIOp((gv))) & IOf_FLUSH)

MP_INLINE void modperl_io_handle_untie(pTHX_ GV *handle);

MP_INLINE void modperl_io_handle_tie(pTHX_ GV *handle,
                                     char *classname, void *ptr);

MP_INLINE int modperl_io_handle_tied(pTHX_ GV *handle, char *classname);

MP_INLINE GV *modperl_io_tie_stdout(pTHX_ request_rec *r);

MP_INLINE GV *modperl_io_tie_stdin(pTHX_ request_rec *r);

#endif /* MODPERL_IO_H */
