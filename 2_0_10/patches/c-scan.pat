--- Scan.pm~	Thu Mar 23 06:14:18 2000
+++ Scan.pm	Sun Jan  7 11:56:04 2001
@@ -400,7 +400,12 @@
     } else {
       $vars = parse_vars($chunk);
     }
-    push @$struct, @$vars;
+    if ($vars) {
+      push @$struct, @$vars;
+    }
+    else {
+      warn "unable to parse chunk: `$chunk'" if $C::Scan::Warn;
+    }
   }
   $structs->{$structname} = $struct;
   $structname;
