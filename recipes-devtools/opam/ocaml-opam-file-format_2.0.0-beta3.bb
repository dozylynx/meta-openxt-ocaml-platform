SUMMARY = "OCaml parser for OPAM file syntax"
HOMEPAGE = "https://opam.ocaml.org/"
SECTION = "devel"
LICENSE = "LGPL-2.1-with-OCaml-linking-exception"
LIC_FILES_CHKSUM="file://opam;md5=f323e6b168011d0a0bc019637af6521a"

DEPENDS = "ocaml"

SRC_URI = "https://github.com/ocaml/opam-file-format/archive/${PV}.tar.gz"
SRC_URI[md5sum] = "fb461d14a44aac3a43751aa936e79143"
SRC_URI[sha256sum] = "522773503b30ff755d04c4e11efb4657e21ac59499da270ef8040d88b4371b59"
S = "${WORKDIR}/opam-file-format-${PV}"

BBCLASSEXTEND = "native"

inherit ocaml

do_configure() {
}

do_compile() {
    oe_runmake all
}

do_install() {
    oe_runmake install DESTDIR="${D}" LIBDIR="${libdir}/ocaml"
}
