#!/bin/bash
TOOLNAME="ocamldep"
TOOL="${OPAM_SWITCH_PREFIX}/bin/${TOOLNAME}"
exec $TOOL "$@"
