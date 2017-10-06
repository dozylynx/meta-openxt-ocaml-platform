SUMMARY = "A replacement configure script for cross switches"
DESCRIPTION = "Configure the ocaml compiler in the opam switch for OE compile"
LICENSE = "MIT"
LIC_FILES_CHKSUM="file://LICENSE;md5=79cb95e9ed0ec951adb8c0e789de03c1"

SRC_URI = " \
    file://configure-cross-switch \
    file://LICENSE \
    "
S = "${WORKDIR}"

BBCLASSEXTEND = "native"

do_install() {
    mkdir -p "${D}${bindir}"
    install -m 0755 "${WORKDIR}/configure-cross-switch" \
                    "${D}${bindir}/configure-cross-switch"
}

FILESEXTRAPATHS_prepend := "${THISDIR}/opam:"
