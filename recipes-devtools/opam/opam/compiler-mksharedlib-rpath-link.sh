#!/bin/bash
#
# Copyright (c) 2017-2018, BAE Systems
# Author: Christopher Clark

[ "x${OPAM_PACKAGE_NAME}" == "xocaml-base-compiler" ] || exit 0

[ "$CLASSOVERRIDE" != "class-native" ] || exit 0

CONFIGURE_SCRIPT="${OPAM_SWITCH_PREFIX}/.opam-switch/build/${OPAM_PACKAGE_NAME}.${OPAM_PACKAGE_VERSION}/configure"

[ -e "${CONFIGURE_SCRIPT}" ] || exit 1

# FIXME: this patch is switch-version specific. move it out of here:

cat >/tmp/patch <<EOF
diff --git a/configure b/configure
index 4ea1498..06c34cc 100755
--- a/configure
+++ b/configure
@@ -113,6 +113,8 @@ while : ; do
         target_type=\$2; shift;;
     -cc*)
         ccoption="\$2"; shift;;
+    -mksharedlib)
+        mksharedliboption="\$2"; shift;;
     -as)
         asoption="\$2"; shift;;
     -aspp)
@@ -690,10 +692,15 @@ if test \$with_sharedlibs = "yes"; then
       shared_libraries_supported=true;;
     *-*-linux-gnu|*-*-linux|*-*-freebsd[3-9]*|*-*-freebsd[1-9][0-9]*|*-*-openbsd*|*-*-netbsd*|*-*-gnu*|*-*-haiku*)
       sharedcccompopts="-fPIC"
-      mksharedlib="\$bytecc -shared"
+      if [[ -z \$mksharedliboption ]]; then
+         mksharedlib="\$bytecc -shared"
+         mksharedlibrpath="-Wl,-rpath-link,"
+      else
+         mksharedlib="\$mksharedliboption"
+         mksharedlibrpath="-Wl,-rpath-link,"
+      fi
       bytecclinkopts="\$bytecclinkopts -Wl,-E"
       byteccrpath="-Wl,-rpath,"
-      mksharedlibrpath="-Wl,-rpath,"
       natdynlinkopts="-Wl,-E"
       shared_libraries_supported=true;;
     alpha*-*-osf*)
EOF
cd "$(dirname "${CONFIGURE_SCRIPT}")"
patch -p1 </tmp/patch
cd -
rm /tmp/patch
