here's how to hack libmodperl.a into apache-2.0 until the build system 
is completed.  (ithrperl == -Dusethreads perl)

Index: src/build/program.mk
===================================================================
RCS file: /home/cvs/apache-2.0/src/build/program.mk,v
retrieving revision 1.3
diff -u -u -r1.3 program.mk
--- src/build/program.mk	2000/03/31 07:02:31	1.3
+++ src/build/program.mk	2000/04/16 16:54:10
@@ -53,8 +53,10 @@
 #
 # The build environment was provided by Sascha Schumann.
 #
+LIBMODPERL=../../modperl-2.0/src/modules/perl/libmodperl.a
+MP_LIBS = $(LIBMODPERL) `ithrperl -MExtUtils::Embed -e ldopts`
 
 PROGRAM_OBJECTS = $(PROGRAM_SOURCES:.c=.lo)
 
 $(PROGRAM_NAME): $(PROGRAM_DEPENDENCIES) $(PROGRAM_OBJECTS)
-	$(LINK) $(PROGRAM_LDFLAGS) $(PROGRAM_OBJECTS) $(PROGRAM_LDADD)
+	$(LINK) $(PROGRAM_LDFLAGS) $(PROGRAM_OBJECTS) $(PROGRAM_LDADD) $(MP_LIBS)
