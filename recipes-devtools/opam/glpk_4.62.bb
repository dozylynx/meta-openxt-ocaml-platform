SUMMARY = "GNU Linear Programming Kit"
DESCRIPTION = "GNU Linear Programming Kit for solving large-scale linear programming"
SECTION = "devel"
LICENSE = "GPLv3"
LIC_FILES_CHKSUM="file://COPYING;md5=d32239bcb673463ab874e80d47fae504"

SRC_URI = "https://ftp.gnu.org/gnu/glpk/glpk-${PV}.tar.gz"
SRC_URI[md5sum] = "ad4f681463db1b78ad88b956b736fa25"
SRC_URI[sha256sum] = "096e4be3f83878ccf70e1fdb62ad1c178715ef8c0d244254c29e2f9f0c1afa70"

S = "${WORKDIR}/glpk-${PV}"

BBCLASSEXTEND = "native"

do_configure() {
    ./configure \
            CC="${BUILD_CC}" \
            CFLAGS="${BUILD_CFLAGS}" \
            -bindir=${bindir} \
            -libdir=${libdir} \
            -includedir=${includedir}
}

do_install() {
    oe_runmake prefix="${D}${prefix}" \
               bindir="${D}${bindir}" \
               libdir="${D}${libdir}" \
               includedir="${D}${includedir}" \
               install
}
