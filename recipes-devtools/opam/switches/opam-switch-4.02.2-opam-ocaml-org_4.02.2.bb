SRC_URI = "http://caml.inria.fr/pub/distrib/ocaml-4.02/ocaml-${PV}.tar.gz;unpack=0"
SRC_URI[md5sum] = "359ad0ef89717341767142f2a4d050b2"
SRC_URI[sha256sum] = "9d50c91ba2d2040281c6e47254c0c2b74d91315dd85cc59b84c5138c3a7ba78c"
LIC_FILES_CHKSUM="file://LICENSE;md5=ff92c64086fe28f9b64a5e4e3fe24ebb"

OPAM_REPOS = "opam-ocaml-org"
DEPENDS_append = " opam-repository-opam-ocaml-org-native"
RDEPENDS_${PN}_append = " opam-repository-opam-ocaml-org-native"
REPOSITORY_DIR = "${RECIPE_SYSROOT_NATIVE}${datadir_native}/ocaml/opam-repository"
COMPILER_TARBALL="${WORKDIR}/ocaml-${PV}.tar.gz"
require ../opam-switch.inc
