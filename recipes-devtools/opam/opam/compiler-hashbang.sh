#!/bin/bash
#
# Script to patch the OCaml compiler source distribution to work
# when built native for the OpenEmbedded build environment,
# as either a native or cross compiler.
# Changes the hashbang output of the OCaml bytecode compiler
# and for cross-compiling, changes input to the compiler configure script.
#
# Copyright (c) 2017-2018, BAE Systems
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
    # 64-to-32 cross compiles use an opam32 switch, which has a nx- prefix.
    # 64-to-64 and 32-to-32 use a native switch which has no prefix.
    #
    # Obtain the name of the native or opam32 switch to use
    # which contains a native ocamlrun interpreter that is compatible with
    # the build host. Drop the 3-character-long 'cx-' prefix:
    if [ -e "${OPAM_ROOT}/nx-${SWITCH_NAME:3}/.opam-switch" ] ; then
        ASSIST_SWITCH_NAME="nx-${SWITCH_NAME:3}"
    else
        ASSIST_SWITCH_NAME="${SWITCH_NAME:3}"
    fi

else
    ASSIST_SWITCH_NAME="${SWITCH_NAME}"
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

NATIVE_ESCAPED_HASHBANG='#!/usr/bin/awk {for(i=1;i<ARGC;){a=ARGV[i++];gsub(/'"'"'"'"'"'"'"'"'/,"'"'"'"'"'"'"'"'"'\\\\\\\\'"'"'"'"'"''"'"'"'"'"'",a);t=t" '"'"'"'"'"'"'"'"'"a"'"'"'"'"'"'"'"'"'"}exit system("OEocamlrun "t" '"${ASSIST_SWITCH_NAME}"'")}'

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
    TARGET_ESCAPED_HASHBANG='#!/usr/share/ocaml/opam-root/'"${ASSIST_SWITCH_NAME}"'/bin/ocamlrun'
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
