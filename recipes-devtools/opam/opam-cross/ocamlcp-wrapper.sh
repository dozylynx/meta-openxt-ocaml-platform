#!/bin/bash

TOOLNAME="ocamlcp"
TOOL="${OPAM_SWITCH_PREFIX}/bin/${TOOLNAME}"
STDLIB="${OPAM_SWITCH_PREFIX}/lib/ocaml"

if [ "x$1" == "x-where" ] ; then
    echo "${STDLIB}"
    exit 0
elif [ "x$1" == "x-config" ] ; then
    STDRUN="$(which ocamlrun)"
    $TOOL -config | \
        sed -e 's|^\(standard_library_default:\).*$|\1 '"${STDLIB}"'|' \
            -e 's|^\(standard_library:\).*$|\1 '"${STDLIB}"'|' \
            -e 's|^\(standard_runtime:\).*$|\1 '"${STDRUN}"'|'
    exit 0
fi
exec $TOOL -nostdlib -I "${OPAM_SWITCH_PREFIX}/lib/ocaml" "$@"
