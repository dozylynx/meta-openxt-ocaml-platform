#!/bin/bash
TOOLNAME="ocamlprof"
TOOL="${OPAM_SWITCH_PREFIX}/bin/${TOOLNAME}"
exec $TOOL "$@"
