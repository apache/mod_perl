for interpreter pool support, apply the patch below and configure Perl
5.6.0 like so:
./Configure -des -Dusethreads

--- thread.h~	Sat Mar 11 08:42:45 2000
+++ thread.h	Thu Apr 20 17:38:17 2000
@@ -229,18 +229,6 @@
     } STMT_END
 #endif /* JOIN */
 
-#ifndef PERL_GET_CONTEXT
-#  define PERL_GET_CONTEXT	pthread_getspecific(PL_thr_key)
-#endif
-
-#ifndef PERL_SET_CONTEXT
-#  define PERL_SET_CONTEXT(t) \
-    STMT_START {						\
-	if (pthread_setspecific(PL_thr_key, (void *)(t)))	\
-	    Perl_croak_nocontext("panic: pthread_setspecific");	\
-    } STMT_END
-#endif /* PERL_SET_CONTEXT */
-
 #ifndef INIT_THREADS
 #  ifdef NEED_PTHREAD_INIT
 #    define INIT_THREADS pthread_init()
@@ -263,6 +251,18 @@
 #endif /* THREAD_RET */
 
 #if defined(USE_THREADS)
+
+#ifndef PERL_GET_CONTEXT
+#  define PERL_GET_CONTEXT	pthread_getspecific(PL_thr_key)
+#endif
+
+#ifndef PERL_SET_CONTEXT
+#  define PERL_SET_CONTEXT(t) \
+    STMT_START {						\
+	if (pthread_setspecific(PL_thr_key, (void *)(t)))	\
+	    Perl_croak_nocontext("panic: pthread_setspecific");	\
+    } STMT_END
+#endif /* PERL_SET_CONTEXT */
 
 /* Accessor for per-thread SVs */
 #  define THREADSV(i) (thr->threadsvp[i])
