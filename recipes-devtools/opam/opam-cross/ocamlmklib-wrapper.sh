#!/bin/bash
TOOLNAME="ocamlmklib"
TOOL="${OPAM_SWITCH_PREFIX}/bin/${TOOLNAME}"
exec $TOOL "$@"
