DEPENDS = "ocaml-cross"
require ocaml-ocamlbuild.inc
inherit cross

do_configure() {
    oe_runmake configure OCAMLBUILD_PREFIX=${prefix} OCAMLBUILD_BINDIR=${bindir} \
        OCAMLBUILD_LIBDIR=${libdir}/ocaml OCAMLBUILD_MANDIR=${datadir}/man \
        OCAML_NATIVE=false OCAML_NATIVE_TOOLS=false
}

do_compile() {
    oe_runmake PREFIX="${prefix_native}" \
               BINDIR="${bindir_native}" \
               LIBDIR="${libdir_native}/ocaml" \
               MANDIR="${datadir_native}/man" \
               OCAML_PREFIX="${prefix_native}"
}

do_install() {
    oe_runmake PREFIX="${D}/${prefix}" \
               BINDIR="${D}/${bindir}" \
               LIBDIR="${D}/${libdir}/ocaml" \
               MANDIR="${D}/${datadir}/man" \
               install
}
