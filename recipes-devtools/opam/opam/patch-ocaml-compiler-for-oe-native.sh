#!/bin/bash
#
# Script to patch the OCaml compiler source distribution to work
# when built native for the OpenEmbedded build environment,
# as either a native or cross compiler.
# Changes the hashbang output of the OCaml bytecode compiler
# and for cross-compiling, changes input to the compiler configure script.
#
# Copyright (c) 2017, BAE Systems
# Author: Christopher Clark

# There is only one compiler package to modify, so if this script
# is run for any other package, do nothing and exit.
# "ocaml-base-compiler" is built with the OE native Ocaml compiler.
[ "x${OPAM_PACKAGE_NAME}" == "xocaml-base-compiler" ] || exit 0

SWITCH_NAME="$1"
[ -n ${SWITCH_NAME} ] || exit 1

# Cross-compiler switches have a 3 character prefix: cx-
if [ "$(expr substr "$SWITCH_NAME" 1 3)" = "cx-" ] ; then
    BUILDING_A_CROSS_SWITCH=true
    # To obtain the name of an equivalent native switch,
    # which contains a native ocamlrun interpreter that is compatible with
    # the build host, drop the 3-character-long 'cx-' prefix:
    NATIVE_SWITCH_NAME="${SWITCH_NAME:3}"
else
    NATIVE_SWITCH_NAME="${SWITCH_NAME}"
fi

# Makefiles in the compiler source to modify:
# build is used for the build, source is used for archiving.
BUILD_MAKEFILE="${OPAM_SWITCH_PREFIX}/.opam-switch/build/${OPAM_PACKAGE_NAME}.${OPAM_PACKAGE_VERSION}/stdlib/Makefile"
SOURCE_MAKEFILE="${OPAM_SWITCH_PREFIX}/.opam-switch/sources/${OPAM_PACKAGE_NAME}.${OPAM_PACKAGE_VERSION}/stdlib/Makefile"

[ -e "${BUILD_MAKEFILE}" ] || exit 0

# -----------------------
# Change the hashbang line that the OCaml compiler inserts into
# bytecode output.
#
# The original hashbang line inserted by the OCaml compiler is
# generated from expanding BINDIR and TARGET_BINDIR into
# absolute paths at compile time in:
#--
#!$(BINDIR)/ocamlrun
#!$(TARGET_BINDIR)/ocamlrun
#--
#
# For the OE native environment:
# The main problems are that BINDIR and TARGET_BINDIR can exceed the
# maximum length (128 characters on Linux) when expanded in an
# OpenEmbedded build environment; and that OpenEmbedded relocates
# tools as it constructs recipe sysroots, so hardcoded paths break.
#
# We introduce a new tool, OEocamlrun, that takes an argument which
# identifies the intended version of the ocamlrun interpreter.
# The tool uses that identifier to construct the right absolute path.
# OEocamlrun is found in the bindir of the receipe native sysroot,
# so it itself does not have a fixed absolute path, but it can be
# found within $PATH.
#
# The hashbang line is changed to use awk, which is a required OE
# host tool found at a fixed absolute path on the host filesytem, which is important.
# awk then runs the program on the hashbang line, which executes OEocamlrun.
# OEocamlrun is located by searching $PATH, as per usual when running a command.
# The awk hashbang program supplies these arguments to OEocamlrun:
# * all the arguments originally supplied to the program, with escaping
#   as needed to handle arguments with whitespace and quote characters,
# * plus an additional argument identifying the active OCaml switch.
# When OEocamlrun executes, it uses the switch-identifier argument to
# locate the ocamlrun binary within that switch, and then it runs
# that ocamlrun interpreter with the bytecode program and the original
# arguments to it, at which point: all is running as intended.
#
# The result is that the hashbang line, inserted into bytecode output,
# now looks like this:
#
#!/usr/bin/awk {for(i=1;i<ARGC;){a=ARGV[i++];gsub(/'/,"'\\''",a);t=t" '"a"'"}exit system("OEocamlrun "t" 4.00.1")}
#
# where "4.00.1" in the line above is an example switch name.
#
# The following lines modify the OCaml compiler Makefiles to make
# this change. The extreme escaping that makes this code look like
# executable line noise arises because this data is interpreted by:
# * the shell running this script
# * the sed interpreter performing the substitution
# * the make tool running the compiler build
# * the awk interpreter used to locate OEocamlrun
# * the shell used within the OEocamlrun script
# * the ocamlrun interpreter
# * the bytecode program being run

NATIVE_ESCAPED_HASHBANG='#!/usr/bin/awk {for(i=1;i<ARGC;){a=ARGV[i++];gsub(/'"'"'"'"'"'"'"'"'/,"'"'"'"'"'"'"'"'"'\\\\\\\\'"'"'"'"'"''"'"'"'"'"'",a);t=t" '"'"'"'"'"'"'"'"'"a"'"'"'"'"'"'"'"'"'"}exit system("OEocamlrun "t" '"${NATIVE_SWITCH_NAME}"'")}'

# -----------------------
# For a cross switch:
# If this script is being applied to a cross-compiler switch, the change is
# different than if it is a native switch.
#
# A cross switch is identified by a "cx-" prefix on the switch name.
#
if [ "$BUILDING_A_CROSS_SWITCH" = true ] ; then
    # For the output of the compiler in a cross switch, the paths
    # to ocamlrun need to match the target (not native) filesystem layout.

    # For the OE target environment:
    # The hashbang just needs to point to the switch location on the target.
    #
    # Point to the ocamlrun executable in the correct switch on the target.
    TARGET_ESCAPED_HASHBANG='#!/usr/share/ocaml/opam-root/'"${NATIVE_SWITCH_NAME}"'/bin/ocamlrun'
else
    # On a native switch, use the NATIVE_ESCAPED_HASHBANG for the target.
    TARGET_ESCAPED_HASHBANG="${NATIVE_ESCAPED_HASHBANG}"
fi

sed -e 's%#!$(BINDIR)/ocamlrun%'"${NATIVE_ESCAPED_HASHBANG}"'%' \
    -i'' "${SOURCE_MAKEFILE}"
sed -e 's%#!$(BINDIR)/ocamlrun%'"${NATIVE_ESCAPED_HASHBANG}"'%' \
    -i'' "${BUILD_MAKEFILE}"
sed -e 's%#!$(TARGET_BINDIR)/ocamlrun%'"${TARGET_ESCAPED_HASHBANG}"'%' \
    -i'' "${SOURCE_MAKEFILE}"
sed -e 's%#!$(TARGET_BINDIR)/ocamlrun%'"${TARGET_ESCAPED_HASHBANG}"'%' \
    -i'' "${BUILD_MAKEFILE}"

#----

CONFIGURE_SCRIPT="${OPAM_SWITCH_PREFIX}/.opam-switch/build/${OPAM_PACKAGE_NAME}.${OPAM_PACKAGE_VERSION}/configure"
[ -e "${CONFIGURE_SCRIPT}" ] || exit 1

if [ "$CLASSOVERRIDE" = "class-native" ] ; then
    # Change the linker used by ocaml tools in the native switch.
    # See opam-native-switch-tools-native recipe.
    sed -e 's/^partialld="ld -r"$/partialld="oe-opam-ld-native -r"/' \
        -i'' "${CONFIGURE_SCRIPT}"

    # Nothing to do for native beyond this point.
    # Exiting here avoids the patch below, which leaves
    # mksharedlib using -rpath, not -rpath-link
    # for the native switch.
    exit 0
fi

TOP_MAKEFILE="${OPAM_SWITCH_PREFIX}/.opam-switch/build/${OPAM_PACKAGE_NAME}.${OPAM_PACKAGE_VERSION}/Makefile"
[ -e "${TOP_MAKEFILE}" ] || exit 1

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

# For a cross switch: configure needs to run differently
# in order to build for the target, not the build host.
if [ "$CLASSOVERRIDE" = "class-cross" ] ; then
    mv "${CONFIGURE_SCRIPT}" "${CONFIGURE_SCRIPT}.original"
    cat >"${CONFIGURE_SCRIPT}" <<EOF
#!/bin/sh
exec "configure-cross-switch" "\$@"
EOF
    chmod 755 "${CONFIGURE_SCRIPT}"
fi

# For an opam32 switch, it's built to run on native, to produce output
# that will run on native, but the output is to be 32-bit. This is
# intended to support cross compiling for 32-bit targets on 64-bit hosts,
# since a 32-bit ocamlrun tool is needed to execute bytecode that has
# been compiled for the target.
if [ "$CLASSOVERRIDE" = "class-opam32" ] ; then

    mv "${CONFIGURE_SCRIPT}" "${CONFIGURE_SCRIPT}.original"
    cat >"${CONFIGURE_SCRIPT}" <<EOF
#!/bin/sh
export CFLAGS="\${CFLAGS} -m32"
exec linux32 \
     "${CONFIGURE_SCRIPT}.original" "\$@" \
     -cc "\${CC} -m32" \
     -mksharedlib "\${CCLD} -m32 -shared" \
     -as "\${AS} --32" \
     -aspp "\${CC} -m32 -c"
EOF
    chmod 755 "${CONFIGURE_SCRIPT}"

    # Disable the opt.opt target:
	# the build won't succeed in this cross-compile, but it is not
	# essential for opam32 anyway.
    sed -e 's/ opt.opt$/ all/' -i'' "${TOP_MAKEFILE}"
fi
