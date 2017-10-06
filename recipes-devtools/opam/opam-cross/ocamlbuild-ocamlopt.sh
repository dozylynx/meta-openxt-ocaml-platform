#!/bin/bash
# ocamlbuild cross compile support
# Special case for ocamlbuild binaries that need to run on the host:
# build these with the native bytecode compiler instead.

P_TOOL=$(which ocamlopt)
WRAPPER_DIR=$(dirname $P_TOOL)
REMEMBER_PATH="${PATH}"

# Remove the wrapper dir from PATH:
PATH=:$PATH:
PATH=${PATH//:$WRAPPER_DIR:/:}
PATH=${PATH#:}; PATH=${PATH%:}

C_TOOL=$(which ocamlc)
P_TOOL=$(which ocamlopt)
PATH="${REMEMBER_PATH}"


if echo $P_TOOL | grep -q cx- ; then
    CROSS_COMPILE="TRUE"

    #-- Determine path to the native ocamlbuild.cmx file
    CROSS_OCAMLBUILD=$(which ocamlbuild)
    NATIVE_OCAMLBUILD=$(echo $CROSS_OCAMLBUILD |
                        sed 's,opam-root/cx-\([^/]*\)/cx/,opam-root/\1/,')
    NATIVE_SWITCH_PATH=$(echo $NATIVE_OCAMLBUILD | \
                         sed 's,\(/opam-root/[^/]*/\).*$,\1,')
    WHERE_TAIL=$($NATIVE_OCAMLBUILD -where | sed 's,^.*/opam-root/[^/]*/,,')
    CMX="${NATIVE_SWITCH_PATH}${WHERE_TAIL}/ocamlbuild.cmx"
    #--

    for ARG in "$@" ; do
        if [ "$ARG" == "$CMX" ] ; then
            CROSS_COMPILE="FALSE"
            break
        fi
    done

    if [ "$CROSS_COMPILE" == "FALSE" ] ; then
        # Convert from the cross tool path to obtain the native tool path
        # and switch from ocamlopt to ocamlc

        export CAML_LD_LIBRARY_PATH=$(echo $CAML_LD_LIBRARY_PATH | \
                                      sed 's,/opam-root/cx-,/opam-root/,g')

        C_TOOL=$(echo $C_TOOL | \
                 sed 's,opam-root/cx-\([^/]*\)/cx/,opam-root/\1/,')
        ARGS=()
        for ARG in "$@" ; do
            ARGS+=("$(echo $ARG | sed -e 's/\.cmxa$/\.cma/' -e 's/\.cmx$/\.cmo/')")
        done

        $C_TOOL "${ARGS[@]}"
        [ $? == 0 ] || exit $?

        # FIXME: don't hardcode the name of the ocamlbuild binary here
        #        -- read it from the args instead.
        mv myocamlbuild myocamlbuild.binary
        cat >>myocamlbuild <<EOF
#!/bin/bash

export CAML_LD_LIBRARY_PATH=\$(echo \$CAML_LD_LIBRARY_PATH | \
                                  sed 's,/opam-root/cx-,/opam-root/,g')

`pwd`/myocamlbuild.binary "\$@"
EOF
        exec chmod 755 myocamlbuild
    fi
fi

exec $P_TOOL -nostdlib -I "${OPAM_SWITCH_PREFIX}/lib/ocaml" "$@"
