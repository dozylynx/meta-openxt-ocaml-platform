#!/bin/bash
#
# Wrapper for ocamlbuild to change the filesystem paths and default tools
# to match the currently active recipe build environment
# in an OpenEmbedded cross compile opam switch.
#
# Copyright (c) 2018 BAE Systems
# Author: Christopher Clark
#

THIS_OCAMLBUILD=$(which ocamlbuild)
[ "$?" == 0 ] || exit $?

NATIVE_OCAMLBUILD=$(echo $THIS_OCAMLBUILD |
                    sed 's,opam-root/cx-\([^/]*\)/cx/,opam-root/\1/,')
CROSS_SWITCH_PATH=$(echo $THIS_OCAMLBUILD | \
                    sed 's,\(/opam-root/[^/]*/\).*$,\1,')
NATIVE_SWITCH_PATH=$(echo $NATIVE_OCAMLBUILD | \
                     sed 's,\(/opam-root/[^/]*/\).*$,\1,')
WHERE_TAIL=$($NATIVE_OCAMLBUILD -where | sed 's,^.*/opam-root/[^/]*/,,')

# P_LIBDIR needs to point to a directory containing ocamlbuild.cmo
# or ocamlbuild will fail.
P_LIBDIR="${NATIVE_SWITCH_PATH}${WHERE_TAIL}"

# P_BINDIR needs to point to the dedicated ocamlbuild bin directory
P_BINDIR="${CROSS_SWITCH_PATH}cx/bin"

ARGS=()

while [ $# != 0 ] ; do
  case "$1" in
    -install-lib-dir )  P_LIBDIR="$2"; shift 2 ;;
    -install-bin-dir )  P_BINDIR="$2"; shift 2 ;;

    *) ARGS+=("$1") ; shift ;;
  esac
done

exec "$NATIVE_OCAMLBUILD" \
    -install-lib-dir "${P_LIBDIR}" \
    -install-bin-dir "${P_BINDIR}" \
    -use-ocamlfind \
    "${ARGS[@]}"
