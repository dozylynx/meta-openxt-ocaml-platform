SUMMARY = "OCaml Common Upgradeability Description Format library"
HOMEPAGE = "http://www.mancoosi.org/cudf/"
SECTION = "devel"
LICENSE = "LGPL-3.0-with-OCaml-linking-exception"
LIC_FILES_CHKSUM="file://COPYING;md5=d3adee67451d4d565a1071e22b5e3014"

DEPENDS = " \
    ocaml-findlib \
    ocaml-ocamlbuild \
    ocaml-extlib \
    "

SRC_URI = "https://gforge.inria.fr/frs/download.php/36602/cudf-${PV}.tar.gz"
SRC_URI[md5sum] = "a4c0e652e56e74c7b388a43f9258d119"
SRC_URI[sha256sum] = "9932e4d95dce235b1434862ff389ccdeb7a28ab7f402ea331b96732c29a7e11c"
S = "${WORKDIR}/cudf-${PV}"

BBCLASSEXTEND = "native"

inherit ocaml

do_configure() {
}

do_compile() {
    oe_runmake all
    oe_runmake opt
}

do_install() {
    oe_runmake install DESTDIR="${D}"
}
