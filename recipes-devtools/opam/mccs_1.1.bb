SUMMARY = "A CUDF package upgradability solver"
DESCRIPTION = "The Multi Criteria CUDF Solver is a Common Upgradeability Description Format problem solver"
HOMEPAGE = "http://www.i3s.unice.fr/~cpjm/misc/mccs.html"
SECTION = "devel"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM="file://LICENCE;md5=63d63e494f592577349f76a854e38a27"

SRC_URI = "http://www.i3s.unice.fr/~cpjm/misc/mccs-${PV}-srcs.tgz"
SRC_URI[md5sum] = "9e41002442367bdcfc098d6bd02b9c8f"
SRC_URI[sha256sum] = "b69a519eea835a9f489241aa21c5c5d143094739906fe02b0319447e4bb7bec9"

S = "${WORKDIR}/mccs-${PV}"

DEPENDS = "glpk bison flex"

BBCLASSEXTEND = "native"

do_configure() {
    # disable linking flex
    sed -i'' 's/-lfl //' makefile
}

do_compile() {
    CFLAGS="${CFLAGS}" \
    CCCOPT="${CPPFLAGS}" \
    LDFLAGS="${LDFLAGS}" \
        oe_runmake USEGLPK=1 GLPKDIR="${prefix}"
}

do_install() {
    mkdir -p "${D}${bindir}"
    install -m 755 "${S}/mccs" "${D}${bindir}/mccs"
}
