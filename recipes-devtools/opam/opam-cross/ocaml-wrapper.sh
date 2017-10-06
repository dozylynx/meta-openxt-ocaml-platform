#!/bin/bash

export CAML_LD_LIBRARY_PATH=$(echo $CAML_LD_LIBRARY_PATH | \
                              sed 's,/opam-root/cx-,/opam-root/,g')

OCAML_BINARY=$(which ocaml | \
               sed -e 's,/opam-root/cx-,/opam-root/,g' -e 's,/cx/bin/,/bin/,g')

${OCAML_BINARY} "$@"
