SUMMARY = "jbuilder OCaml build tool"
DESCRIPTION = "A composable build system for OCaml"
HOMEPAGE = "https://github.com/janestreet/jbuilder"
SECTION = "devel"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM="file://LICENSE.md;md5=3b83ef96387f14655fc854ddc3c6bd57"

DEPENDS = "ocaml-findlib"

SRC_URI = "https://github.com/janestreet/jbuilder/archive/1.0+beta14.tar.gz"
SRC_URI[md5sum] = "579511fb64a35a98e60d6b20f4206a81"
SRC_URI[sha256sum] = "e0ebb0c7d781f5f6903803a7f6db9dbd02f9be4ca5b2e43ce6e4d62ac9624d1a"
S = "${WORKDIR}/jbuilder-${PV}"

BBCLASSEXTEND = "native"

inherit ocaml

do_configure() {
}

do_install() {
    # Install by copying the binary directly here rather than
    # the typical "make install" so as to avoid introducing a
    # dependency on OPAM, because jbuilder is used to build OPAM.
    mkdir -p "${D}${bindir}"
    install -m 755 "${S}/_build/install/default/bin/jbuilder" \
                   "${D}${bindir}/jbuilder"
}
