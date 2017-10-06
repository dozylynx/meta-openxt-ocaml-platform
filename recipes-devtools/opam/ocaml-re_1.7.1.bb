SUMMARY = "OCaml regular expression library"
HOMEPAGE = "https://github.com/ocaml/ocaml-re"
SECTION = "devel"
LICENSE = "LGPL-2.1-with-OCaml-linking-exception"
LIC_FILES_CHKSUM="file://LICENSE;md5=b5f67e44e00af312f52bf068e0fd2ea1"

DEPENDS = " \
    ocaml-findlib \
    ocaml-jbuilder \
    ocaml-ocamlbuild \
    "

SRC_URI = "https://github.com/ocaml/ocaml-re/archive/${PV}.tar.gz"
SRC_URI[md5sum] = "0e45743512b7ab5e6b175f955dc72002"
SRC_URI[sha256sum] = "eb18382d63459b0a4065315ce6fef854bc99152aec2b557bb8a43e664e6679e8"
S = "${WORKDIR}/ocaml-re-${PV}"

BBCLASSEXTEND = "native"

inherit ocaml

do_configure() {
    oe_runmake configure CONFIGUREFLAGS="--prefix ${prefix} --bindir ${bindir} --libdir ${libdir}"
}

do_compile() {
    oe_runmake build
}

do_install() {
    oe_runmake install INSTALLFLAGS="--destdir=${D}"
}
