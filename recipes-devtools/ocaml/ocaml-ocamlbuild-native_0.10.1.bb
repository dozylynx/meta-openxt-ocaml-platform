DEPENDS_append = " ocaml-native"
require ocaml-ocamlbuild.inc
inherit native ocaml

do_configure() {
    oe_runmake configure OCAMLBUILD_PREFIX=${prefix} \
                         OCAMLBUILD_BINDIR=${bindir} \
                         OCAMLBUILD_LIBDIR=${libdir}/ocaml \
                         OCAMLBUILD_MANDIR=${datadir}/man \
                         OCAML_NATIVE=true \
                         OCAML_NATIVE_TOOLS=true
}

do_compile() {
    oe_runmake PREFIX="${prefix}" \
               BINDIR="${bindir}" \
               LIBDIR="${libdir}/ocaml" \
               MANDIR="${datadir}/man"
}

do_install() {
    oe_runmake PREFIX="${D}/${prefix}" \
               BINDIR="${D}/${bindir}" \
               LIBDIR="${D}/${libdir}/ocaml" \
               MANDIR="${D}/${datadir}/man" \
               install
}

INHIBIT_SYSROOT_STRIP = "1"
INHIBIT_PACKAGE_STRIP = "1"
