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
    file://url-hashes-cache-file.patch;patch=1 \
    file://apply-recipe-patches.sh \
    file://compiler-hashbang.sh \
    file://compiler-native-linker-script.sh \
    file://compiler-mksharedlib-rpath-link.sh \
    file://compiler-configure-cross.sh \
    file://compiler-configure-opam32.sh \
    file://opam-switch-gen-ocaml-config \
    file://opam-compilers-to-packages-url-hashes \
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
    install -m 0755 "${WORKDIR}/apply-recipe-patches.sh" \
                "${D}/${bindir}/apply-recipe-patches.sh"
    install -m 0755 "${WORKDIR}/compiler-hashbang.sh" \
                "${D}/${bindir}/compiler-hashbang.sh"
    install -m 0755 "${WORKDIR}/compiler-native-linker-script.sh" \
                "${D}/${bindir}/compiler-native-linker-script.sh"
    install -m 0755 "${WORKDIR}/compiler-mksharedlib-rpath-link.sh" \
                "${D}/${bindir}/compiler-mksharedlib-rpath-link.sh"
    install -m 0755 "${WORKDIR}/compiler-configure-cross.sh" \
                "${D}/${bindir}/compiler-configure-cross.sh"
    install -m 0755 "${WORKDIR}/compiler-configure-opam32.sh" \
                "${D}/${bindir}/compiler-configure-opam32.sh"
    install -m 0755 "${WORKDIR}/opam-switch-gen-ocaml-config" \
                "${D}/${bindir}/opam-switch-gen-ocaml-config"
    mkdir -p "${D}${sysconfdir}"
    install -m 0644 "${WORKDIR}/opam-compilers-to-packages-url-hashes" \
                "${D}/${sysconfdir}/opam-compilers-to-packages-url-hashes"
}

PARALLEL_MAKE=""
