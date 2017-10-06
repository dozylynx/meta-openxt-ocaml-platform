#!/bin/bash
TOOLNAME="ocamlyacc"
TOOL="${OPAM_SWITCH_PREFIX}/bin/${TOOLNAME}"
exec $TOOL "$@"
