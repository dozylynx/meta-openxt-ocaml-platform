SRC_URI[md5sum] = "000d2ebad1333f9afcccdcd68c19f14d"
SRC_URI[sha256sum] = "2603be3709634b6191dd00627213cff56f15200f2d0a24e0af58a18a0580b71e"
DESCRIPTION = "ocamlbuild"
LICENSE = "GPLv2"
LIC_FILES_CHKSUM = "file://LICENSE;md5=5123b1988300c0d24c79e04f09d86dc0"

SRC_URI = "https://github.com/ocaml/ocamlbuild/archive/0.10.1.tar.gz \
"

S = "${WORKDIR}/ocamlbuild-${PV}"

RDEPENDS_${PN}-dev = ""
