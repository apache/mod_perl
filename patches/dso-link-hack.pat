Index: src/build/program.mk
===================================================================
RCS file: /home/cvs/apache-2.0/src/build/program.mk,v
retrieving revision 1.3
diff -u -u -r1.3 program.mk
--- src/build/program.mk	2000/03/31 07:02:31	1.3
+++ src/build/program.mk	2000/04/21 18:47:36
@@ -57,4 +57,4 @@
 PROGRAM_OBJECTS = $(PROGRAM_SOURCES:.c=.lo)
 
 $(PROGRAM_NAME): $(PROGRAM_DEPENDENCIES) $(PROGRAM_OBJECTS)
-	$(LINK) $(PROGRAM_LDFLAGS) $(PROGRAM_OBJECTS) $(PROGRAM_LDADD)
+	$(LINK) $(PROGRAM_LDFLAGS) $(PROGRAM_OBJECTS) $(PROGRAM_LDADD) -rdynamic -ldl
