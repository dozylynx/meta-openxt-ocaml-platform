SUMMARY = "OCaml generic graph library"
HOMEPAGE = "https://github.com/ygrek/ocaml-extlib"
SECTION = "devel"
LICENSE = "LGPL-2.1-with-OCaml-linking-exception"
LIC_FILES_CHKSUM="file://LICENSE;md5=ba3525a68c09a5c9ea76d9c29d3c41c5"

DEPENDS = "ocaml-findlib"

SRC_URI = "http://ocamlgraph.lri.fr/download/ocamlgraph-${PV}.tar.gz"
SRC_URI[md5sum] = "e733b8309b9374e89d96e907ecaf4f76"
SRC_URI[sha256sum] = "df06ca06d25231bb8e162d6b853177cb7fc1565c8f1ec99ca051727d46c985a0"
S = "${WORKDIR}/ocamlgraph-${PV}"

BBCLASSEXTEND = "native"

inherit ocaml

do_configure() {
    ./configure --prefix "${prefix}" --bindir "${bindir}" --libdir "${libdir}"
}

do_install() {
    mkdir -p "${D}${libdir}/ocaml"
    oe_runmake install-findlib DESTDIR="${D}${libdir}/ocaml"
}
