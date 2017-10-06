SUMMARY = "A replacement configure script for cross switches"
DESCRIPTION = "Configure the ocaml compiler in the opam switch for OE compile"
# FIXME: part of gen-ocaml-makefile is derived from BSD-3-Clause so needs to carry that
LICENSE = "MIT"
LIC_FILES_CHKSUM="file://LICENSE;md5=79cb95e9ed0ec951adb8c0e789de03c1"

COMPATIBLE_HOST = '(x86_64.*).*-linux'

SRC_URI = " \
    file://configure-ocaml-cross-compiler \
    file://gen-ocaml-m-dot-h \
    file://gen-ocaml-s-dot-h \
    file://modify-ocaml-makefiles \
    file://LICENSE \
    "
S = "${WORKDIR}"

BBCLASSEXTEND = "native"

do_install() {
    mkdir -p "${D}${bindir}"
    install -m 0755 "${WORKDIR}/configure-ocaml-cross-compiler" \
                    "${D}${bindir}/configure-ocaml-cross-compiler"
    install -m 0755 "${WORKDIR}/gen-ocaml-m-dot-h" \
                    "${D}${bindir}/gen-ocaml-m-dot-h"
    install -m 0755 "${WORKDIR}/gen-ocaml-s-dot-h" \
                    "${D}${bindir}/gen-ocaml-s-dot-h"
    install -m 0755 "${WORKDIR}/modify-ocaml-makefiles" \
                    "${D}${bindir}/modify-ocaml-makefiles"
}

FILESEXTRAPATHS_prepend := "${THISDIR}/opam-ocaml-cross-configure:"
