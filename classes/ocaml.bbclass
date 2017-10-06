B_OUT="${S}/build-output/"

# Standard OCaml environment variables enable the tools to locate the installation
export OCAMLFIND_CONF="${B_OUT}etc/ocamlfind.conf"
export OCAMLLIB = "${STAGING_LIBDIR}/ocaml"
export CAML_LD_LIBRARY_PATH = "${STAGING_LIBDIR}/ocaml/stublibs:${B_OUT}ocaml/stublibs"

do_configure_prepend() {
    OCAMLFIND_DEST="${B_OUT}ocaml"
    mkdir -p "${OCAMLFIND_DEST}/stublibs"

    OCAMLFIND_LDCONF="${B_OUT}ocaml/ld.conf"
    echo "${B_OUT}ocaml/stublibs" >"${OCAMLFIND_LDCONF}"
    echo "${B_OUT}ocaml"         >>"${OCAMLFIND_LDCONF}"

    OCAMLFIND_PATH="${STAGING_LIBDIR}/ocaml:${OCAMLFIND_DEST}"
    mkdir -p "$(dirname "${OCAMLFIND_CONF}")"
    echo "destdir=\"${OCAMLFIND_DEST}\""    >"${OCAMLFIND_CONF}"
    echo    "path=\"${OCAMLFIND_PATH}\""   >>"${OCAMLFIND_CONF}"
    echo  "ldconf=\"${OCAMLFIND_LDCONF}\"" >>"${OCAMLFIND_CONF}"
}

do_install_prepend() {
    # Update the ocamlfind destination path for the install task.
    # ocamlfind will install libraries into the path specified in the
    # destdir of the OCAMLFIND_CONF file. Ensure that directory exists.
    mkdir -p "${D}${libdir}/ocaml"
    # Change the OCaml install destination path to inside ${D}
    # Add the install path to the library path
    OCAMLFIND_DEST="${D}${libdir}/ocaml"
    OCAMLFIND_PATH="${STAGING_LIBDIR}/ocaml:${B_OUT}ocaml:${D}${libdir}/ocaml"
    mkdir -p "$(dirname "${OCAMLFIND_CONF}")"
    echo "destdir=\"${OCAMLFIND_DEST}\""  >"${OCAMLFIND_CONF}"
    echo    "path=\"${OCAMLFIND_PATH}\"" >>"${OCAMLFIND_CONF}"
}

DEPENDS_append = " oe-ocamlrun-native"
