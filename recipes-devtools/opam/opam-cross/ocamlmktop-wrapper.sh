#!/bin/bash
TOOLNAME="ocamlmktop"
TOOL="${OPAM_SWITCH_PREFIX}/bin/${TOOLNAME}"
exec $TOOL "$@"
