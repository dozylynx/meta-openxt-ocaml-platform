SUMMARY = "Ocaml preprocessor"
HOMEPAGE = "https://mjambon.github.io/mjambon2016/cppo.html"
SECTION = "devel"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM="file://LICENSE.md;md5=89cce3f23d191fa38cc7cfa88817ec5f"

DEPENDS = "ocaml-findlib ocaml-jbuilder"

SRC_URI = "https://github.com/mjambon/cppo/archive/v1.6.0.tar.gz"
SRC_URI[md5sum] = "aee411b3546bc5d198c71ae9185cade4"
SRC_URI[sha256sum] = "29cb0223adc1f0c4c5238d6c7bf8931b909505aed349fde398fbf1a39eaa1819"
S = "${WORKDIR}/cppo-${PV}"

BBCLASSEXTEND = "native"

inherit ocaml

do_configure() {
}

do_compile() {
    oe_runmake all
}

do_install() {
    # Do not use the Makefile provided install method in order to avoid 
    # introducing a dependency on OPAM, as this is an OPAM dependency.
    mkdir -p "${D}${bindir}"
    install -m 755 "${S}/_build/default/src/cppo_main.exe" "${D}${bindir}/cppo"
    mkdir -p "${D}${libdir}/ocaml"
    cp -r "${S}/_build/install/default/lib/cppo" "${D}${libdir}/ocaml/"
    cp -r "${S}/_build/install/default/lib/cppo_ocamlbuild" "${D}${libdir}/ocaml/"
}
