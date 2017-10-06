SUMMARY = "OCaml Dose3 dependency toolkit library"
DESCRIPTION = "Dose is a library and a collection of tools to perform a large spectrum of analysis on software package repositories"
HOMEPAGE = "http://dose.gforge.inria.fr/"
SECTION = "devel"
LICENSE = "LGPL-3.0-with-OCaml-linking-exception"
LIC_FILES_CHKSUM="file://COPYING;md5=d3adee67451d4d565a1071e22b5e3014"

DEPENDS = " \
    ocaml-findlib \
    ocaml-cppo \
    ocaml-cudf \
    ocaml-ocamlbuild \
    ocaml-ocamlgraph \
    ocaml-re \
    ocaml-extlib \
    "

SRC_URI = "https://gforge.inria.fr/frs/download.php/file/36063/dose3-${PV}.tar.gz"
SRC_URI[md5sum] = "e7d4b1840383c6732f29a47c08ba5650"
SRC_URI[sha256sum] = "558af92b0ec5dd219e67802c95a850cab9582df381bddd2cfe431049aaf3db03"
S = "${WORKDIR}/dose3-${PV}"

BBCLASSEXTEND = "native"

inherit ocaml

do_configure() {
    ./configure --prefix ${prefix} --bindir ${bindir} --libdir ${libdir}
    # Remove absolute paths from created symlinks
    sed -i'' 's,\(@$(LN)\) $(BINDIR)/distcheck ,\1 distcheck ,' Makefile
}

do_compile() {
    oe_runmake HTMLA=""
}

do_install() {
    oe_runmake install DESTDIR="${D}"
}

PARALLEL_MAKE=""
INHIBIT_SYSROOT_STRIP = "1"
INHIBIT_PACKAGE_STRIP = "1"
