SUMMARY = "jbuilder OCaml build tool"
DESCRIPTION = "A composable build system for OCaml"
HOMEPAGE = "https://github.com/janestreet/jbuilder"
SECTION = "devel"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM="file://LICENSE.md;md5=3b83ef96387f14655fc854ddc3c6bd57"

DEPENDS = "ocaml-findlib"

SRC_URI = "https://github.com/janestreet/jbuilder/archive/1.0+beta14.tar.gz"
SRC_URI[md5sum] = "7c1e8fc5fd5aa36b72c3349ba2ff3162"
SRC_URI[sha256sum] = "eec821ba2b6affd8bdbbd938d0caf0d76a42171c192292e1ff881cbf840b0436"
S = "${WORKDIR}/dune-${PV}"

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
