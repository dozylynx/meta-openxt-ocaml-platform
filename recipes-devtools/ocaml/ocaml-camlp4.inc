DESCRIPTION = "caml4p"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://LICENSE;md5=77f085d1023152a31ada8288ffd6e8f1"

S = "${WORKDIR}/camlp4-${PV}"

RDEPENDS_${PN}-dev = ""

do_configure() {
	./configure --bindir=${bindir} --libdir=${libdir}/ocaml
}

do_compile() {
	oe_runmake
}

do_install() {
	oe_runmake install
}
