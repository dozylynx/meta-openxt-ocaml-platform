#!/bin/bash

OCAMLFIND_BINARY=$(which ocamlfind | \
                   sed -e 's,/opam-root/cx-,/opam-root/,g' -e 's,/cx/bin/,/bin/,g')
CROSS_SWITCH_PATH=$(which ocamlfind | \
                    sed 's,\(/opam-root/[^/]*/\).*$,\1,')

export OCAMLFIND_LDCONF="${CROSS_SWITCH_PATH}/lib/ocaml/ld.conf"
export OCAMLFIND_CONF="${CROSS_SWITCH_PATH}/lib/findlib.conf"
export OCAMLLIB="${CROSS_SWITCH_PATH}lib/ocaml"

if [ $# == "2" ] && [ $1 == "printconf" ] && [ $2 == "conf" ] ; then
    echo "${OPAMROOT}/${OPAMSWITCH}/lib/findlib.conf"
else
    "${OCAMLFIND_BINARY}" "$@"
fi
