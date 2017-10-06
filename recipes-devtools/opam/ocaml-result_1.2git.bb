SUMMARY = "Ocaml result library"
DESCRIPTION = "Compatability library for using the new Result type while preserving compatability with older OCaml"
SECTION = "devel"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM="file://LICENSE;md5=0f0d371bfac9a53eae0d9c46bbd76bad"

PV = "1.2+git${SRCPV}"

DEPENDS = "ocaml-findlib"

FILES_${PN} = "${libdir}/ocaml/result/*"

# This SRCREV is last revision before switching build method to jbuilder
SRCREV = "de571c6057a6a38e8c8661d4e6ad42c950403c5d"
SRC_URI = "git://github.com/janestreet/result.git;protocol=git;branch=master"
S = "${WORKDIR}/git"

BBCLASSEXTEND = "native"

inherit ocaml

do_configure() {
}

do_compile() {
    oe_runmake all
}

do_install() {
    oe_runmake install
}

PARALLEL_MAKE=""
