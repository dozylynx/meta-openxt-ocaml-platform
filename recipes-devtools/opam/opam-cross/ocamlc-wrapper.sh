#!/bin/bash

TOOLNAME="ocamlc"
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
#--
CROSS_COMPILE="TRUE"

for ARG in "$@" ; do
    if [ "$ARG" = "-custom" ] ; then
        CROSS_COMPILE="FALSE"
        break
    fi
    # FIXME: improve this detection
    if echo "$ARG" | grep -q '/gen/gen.exe$' ; then
        CROSS_COMPILE="FALSE"
        break
    fi
    if echo "$ARG" | grep -q 'tools/pp.exe$' ; then
        CROSS_COMPILE="FALSE"
        break
    fi
done

# FIXME: this is HORRIBLE. hack to make lwt cross compile (yuck)
if [ "$CROSS_COMPILE" == "FALSE" ] ; then
    for ARG in "$@" ; do
        if [[ "$ARG" =~ .*/lwt_stub.* ]] ; then
            CROSS_COMPILE="TRUE"
            break
        fi
    done
fi

if [ "$CROSS_COMPILE" == "FALSE" ] ; then
    # Convert from the cross tool path to obtain the native tool path
    # and switch from ocamlopt to ocamlc

    # Strip out -custom
    for arg do
      shift
      [ "$arg" = "-custom" ] && continue
      set -- "$@" "$arg"
    done

    # Identify the output file
    OUTPUT_FILE=
    while getopts ":o:" opt; do
      case $opt in
        o)
          OUTPUT_FILE="${OPTARG}"
          ;;
      esac
    done

    export CAML_LD_LIBRARY_PATH=$(echo $CAML_LD_LIBRARY_PATH | \
                                  sed 's,/opam-root/cx-,/opam-root/,g')

    # FIXME: check this
    ARGS=()
    for ARG in "$@" ; do
        ARGS+=("$(echo $ARG | sed -e 's,opam-root/cx-,opam-root/,g')")
    done

    C_TOOL=$(which ocamlc | \
             sed 's,opam-root/cx-\([^/]*\)/cx/,opam-root/\1/,')

    # camlheader is needed in the search path for ocamlc in order
    # for it to insert the correct hashbang
    CAMLHEADER_PATH="$(echo "$C_TOOL" | sed 's,bin/ocamlc$,lib/ocaml,')"

    # ppxlib path
    PPXLIB_PATH="$(echo "$C_TOOL" | sed 's,bin/ocamlc$,lib/ppxlib,')"

    $C_TOOL -I "${CAMLHEADER_PATH}" -I "${PPXLIB_PATH}" "${ARGS[@]}"
    RET=$?
    if [ "$RET" == 0 ] ; then
        mv "${OUTPUT_FILE}" "${OUTPUT_FILE}.d"
        cat >"${OUTPUT_FILE}" <<EOF
#!/bin/bash
export CAML_LD_LIBRARY_PATH="${CAML_LD_LIBRARY_PATH}"
exec "$(pwd)/${OUTPUT_FILE}.d" "\$@"
EOF
        chmod 755 "${OUTPUT_FILE}"
    fi
    exit $RET
else
    exec $TOOL -nostdlib -I "${OPAM_SWITCH_PREFIX}/lib/ocaml" "$@"
fi
