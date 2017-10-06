SUMMARY = "A source-based package manager for OCaml"
HOMEPAGE = "https://opam.ocaml.org/"
LICENSE = "LGPLv2.1"
LIC_FILES_CHKSUM="file://LICENSE;md5=d9e77cf0b09010013d038358f983b42a"

DEPENDS = " \
    ocaml \
    glpk \
    ocaml-findlib \
    mccs \
    rsync \
    unzip \
    faux-cc \
    ocaml-cppo \
    ocaml-extlib \
    ocaml-re \
    ocaml-cmdliner \
    ocaml-ocamlgraph \
    ocaml-cudf \
    ocaml-dose3 \
    ocaml-opam-file-format \
    ocaml-result \
    ocaml-jbuilder \
    "

SRC_URI = " \
    git://github.com/ocaml/opam.git;protocol=git;branch=master \
    file://avoid-bzip2.patch;patch=1 \
"
SRC_URI_append_class-native = " \
    file://avoid-switch-ocaml.patch;patch=1 \
    file://opam-cross-switch-path.patch;patch=1 \
    file://apply-recipe-patches.sh \
    file://patch-ocaml-compiler-for-oe-native.sh \
    file://opam-switch-gen-ocaml-config \
"

SRCREV = "324cd0e2ade04fc1fa2356121904334a5d2d7eb6"
S = "${WORKDIR}/git"

RDEPENDS_${PN} = "mccs rsync unzip mccs faux-cc"

FILESEXTRAPATHS_prepend := "${THISDIR}/ocaml-opam:"

BBCLASSEXTEND = "native"

inherit ocaml

do_configure() {
    ./configure -bindir "${bindir}" \
                -includedir "${includedir}" \
                -libdir "${libdir}" \
                -mandir "${datadir}/man" \
                -prefix "${prefix}" \
                --without-mccs \
                CC="${CC}" \
                CFLAGS="${CFLAGS}" \
                CPPFLAGS="${CPPFLAGS}" \
                LDFLAGS="${LDFLAGS}" \
                LIB_PREFIX="${prefix}"
}

do_compile() {
    oe_runmake CFLAGS="${CFLAGS}" \
               CPPFLAGS="${CPPFLAGS}" \
               CXXFLAGS="${CXXFLAGS}" \
               LDFLAGS="${LDFLAGS}"
}

do_install() {
    oe_runmake DESTDIR="${D}" install
}

do_install_append_class-native() {
    mkdir -p "${D}${bindir}"
    install -m 0755 "${WORKDIR}/patch-ocaml-compiler-for-oe-native.sh" \
                "${D}/${bindir}/patch-ocaml-compiler-for-oe-native.sh"
    install -m 0755 "${WORKDIR}/apply-recipe-patches.sh" \
                "${D}/${bindir}/apply-recipe-patches.sh"
    install -m 0755 "${WORKDIR}/opam-switch-gen-ocaml-config" \
                "${D}/${bindir}/opam-switch-gen-ocaml-config"
}

PARALLEL_MAKE=""
