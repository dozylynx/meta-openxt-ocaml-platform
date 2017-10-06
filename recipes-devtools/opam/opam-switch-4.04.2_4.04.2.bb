SRC_URI = "https://github.com/ocaml/ocaml/archive/${PV}.tar.gz;unpack=0"
SRC_URI[md5sum] = "5ce661a2d8b760dc77c2facf46ccddd1"
SRC_URI[sha256sum] = "6277a477956fc7b76f28af9941dce2984d0df809a0361093eb2e28234bf9c8ed"
LIC_FILES_CHKSUM="file://LICENSE;md5=4f72f33f302a53dc329f4d3819fe14f9"

DEPENDS_append = " opam-repository-xapi"
RDEPENDS_${PN}_append = " opam-repository-xapi"
REPOSITORY_DIR = "${datadir}/ocaml/opam-repository-xapi"
COMPILER_TARBALL="${WORKDIR}/${PV}.tar.gz"
require opam-switch.inc
