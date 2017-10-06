#!/bin/bash

# ocamlopt wrapper has a special case to support ocamlbuild:
# change build method for binaries linking ocamlbuild to use
# bytecode rather than native.

TOOLNAME="ocamlopt"
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

#-- Determine path to the native ocamlbuild.cmx file
CROSS_OCAMLBUILD=$(which ocamlbuild)
NATIVE_OCAMLBUILD=$(echo $CROSS_OCAMLBUILD |
                    sed 's,opam-root/cx-\([^/]*\)/cx/,opam-root/\1/,')
NATIVE_SWITCH_PATH=$(echo $NATIVE_OCAMLBUILD | \
                     sed 's,\(/opam-root/[^/]*/\).*$,\1,')
NATIVE_SWITCH=$(echo $NATIVE_OCAMLBUILD | \
                sed 's,^.*/opam-root/\([^/]*\)/.*$,\1,')
WHERE_TAIL=$($NATIVE_OCAMLBUILD -where | sed 's,^.*/opam-root/[^/]*/,,')
CMX="${NATIVE_SWITCH_PATH}${WHERE_TAIL}/ocamlbuild.cmx"
#--
CROSS_COMPILE="TRUE"

for ARG in "$@" ; do
    if [ "$ARG" == "$CMX" ] ; then
        CROSS_COMPILE="FALSE"
        ACTOR="ocamlbuild"
        break
    fi
    # FIXME: improve this detection
    if echo "$ARG" | grep -q '/ppx.exe$' ; then
        CROSS_COMPILE="FALSE"
        ACTOR="ppx"
        break
    fi
done

if [ "$CROSS_COMPILE" == "FALSE" ] ; then
    # Convert from the cross tool path to obtain the native tool path
    # and switch from ocamlopt to ocamlc

    export CAML_LD_LIBRARY_PATH=$(echo $CAML_LD_LIBRARY_PATH | \
                                  sed 's,/opam-root/cx-,/opam-root/,g')

    C_TOOL=$(which ocamlc | \
             sed 's,opam-root/cx-\([^/]*\)/cx/,opam-root/\1/,')
    ARGS=()
    for ARG in "$@" ; do
        ARGS+=("$(echo $ARG | sed -e 's/\.cmxa$/\.cma/' -e 's/\.cmx$/\.cmo/')")
    done

    # camlheader is needed in the search path for ocamlc in order
    # for it to insert the correct hashbang
    CAMLHEADER_PATH="$(echo "$C_TOOL" | sed 's,bin/ocamlc$,lib/ocaml,')"

    # ppxlib path
    PPXLIB_PATH="$(echo "$C_TOOL" | sed 's,bin/ocamlc$,lib/ppxlib,')"

    $C_TOOL -I "${CAMLHEADER_PATH}" -I "${PPXLIB_PATH}" "${ARGS[@]}"
    [ $? == 0 ] || exit $?

    if [ "${ACTOR}" == "ppx" ] ; then
        # Identify the output file
        while getopts ":o:" opt; do
            case $opt in
            o) BINARY_NAME="${OPTARG}" ;;
            esac
        done

    fi
    if [ "${ACTOR}" == "ocamlbuild" ] ; then
        # FIXME: detect the binary output filename, don't assume it
        BINARY_NAME="myocamlbuild"
    fi
    mv ${BINARY_NAME} ${BINARY_NAME}.binary
    cat >>${BINARY_NAME} <<EOF
#!/bin/bash

export CAML_LD_LIBRARY_PATH=\$(echo \$CAML_LD_LIBRARY_PATH | \
                                  sed 's,/opam-root/cx-,/opam-root/,g')

`which OEocamlrun` `pwd`/${BINARY_NAME}.binary "\$@" "${NATIVE_SWITCH}"
EOF
    exec chmod 755 ${BINARY_NAME}
fi

exec $TOOL -nostdlib -I "${OPAM_SWITCH_PREFIX}/lib/ocaml" "$@"
