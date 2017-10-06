SUMMARY = "Extension to the OCaml standard library"
HOMEPAGE = "https://github.com/ygrek/ocaml-extlib"
SECTION = "devel"
LICENSE = "LGPL-2.1-with-OCaml-linking-exception"
LIC_FILES_CHKSUM="file://LICENSE;md5=64b587ebdb7881dee0a8c95486b0d8b4"

DEPENDS = " \
    ocaml-findlib \
    ocaml-jbuilder \
    ocaml-cppo \
    "

SRC_URI = "http://ygrek.org.ua/p/release/ocaml-extlib/extlib-1.7.2.tar.gz"
SRC_URI[md5sum] = "0f550dd06242828399a73387c49e0eed"
SRC_URI[sha256sum] = "7505a2be41b29c5c039d1e2088aa3570ffdc5de8428b909384ac58039f83f564"
S = "${WORKDIR}/extlib-${PV}"

BBCLASSEXTEND = "native"

inherit ocaml

do_configure() {
}

do_compile() {
    oe_runmake build
}

do_install() {
    oe_runmake install PREFIX="${prefix}"
}
