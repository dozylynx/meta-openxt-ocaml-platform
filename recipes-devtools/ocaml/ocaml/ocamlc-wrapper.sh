#!/bin/bash
tool="$0".byte
interp=$(which ocamlrun)

sysroot_path=$(expr match "$interp" '\(.*/recipe-sysroot-native\)')
ocaml_stdlib_path="${sysroot_path}##OCAMLLIBDIR##"

# Tool definition:
# ocaml -where : Print location of standard library and exit
# Intercept this because it changes with each recipe-specific sysroot.
if [ "$#" -eq 1 ] && [ "$1" == "-where" ] ; then
    echo "${ocaml_stdlib_path}"
    exit 0
fi

if [ "$#" -eq 1 ] && [ "$1" == "-v" ] ; then
    "${interp}" "$tool"  \
     "-I" "${ocaml_stdlib_path}" \
     "-I" "${ocaml_stdlib_path}/compiler-libs" \
     "-I" "${ocaml_stdlib_path}/stublibs" \
     "-I" "${ocaml_stdlib_path}/vmthreads" \
     $@ | head -1
    echo "Standard library directory: ${ocaml_stdlib_path}"
    exit 0
fi

# FIXME: check for nostdlib argument
exec "${interp}" "$tool" \
     "-I" "${ocaml_stdlib_path}" \
     "-I" "${ocaml_stdlib_path}/compiler-libs" \
     "-I" "${ocaml_stdlib_path}/stublibs" \
     "-I" "${ocaml_stdlib_path}/vmthreads" \
     $@
