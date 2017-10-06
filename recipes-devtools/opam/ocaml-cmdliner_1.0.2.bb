SUMMARY = "OCaml comamnd line tool library"
SECTION = "devel"
LICENSE = "MIT"
LIC_FILES_CHKSUM="file://LICENSE.md;md5=ece8adb84cf4be995ad755e5ce5be00e"

SRC_URI = "https://github.com/dbuenzli/cmdliner/archive/v${PV}.tar.gz"
SRC_URI[md5sum] = "48243c64609ee6a7ab839f90b0f7a486"
SRC_URI[sha256sum] = "1854ba41a8a402b3f3a9127aa08fea05445e1021da8267d4f587d7c26bd5c0eb"
S = "${WORKDIR}/cmdliner-${PV}"

DEPENDS = "ocaml-findlib ocaml-result"

FILES_${PN} = "${libdir}/ocaml/cmdliner/*"

BBCLASSEXTEND = "native"

inherit ocaml

do_configure() {
    sed -i'' 's/^B=/CMDLINER_B=/' ${S}/Makefile
    sed -i'' 's/$(B)/$(CMDLINER_B)/' ${S}/Makefile
}

do_compile() {
    oe_runmake all
}

do_install() {
    oe_runmake LIBDIR=${D}${libdir}/ocaml/cmdliner \
               install
}

PARALLEL_MAKE=""
