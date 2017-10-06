#!/bin/bash
TOOLNAME="ocamllex"
TOOL="${OPAM_SWITCH_PREFIX}/bin/${TOOLNAME}"
exec $TOOL "$@"
