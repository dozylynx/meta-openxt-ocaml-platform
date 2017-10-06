SUMMARY = "A spoof cc binary that invokes $CC as a compiler to satisfy other packages"
DESCRIPTION = "Make 'cc' available by invoking environment variable CC"
LICENSE = "MIT"
LIC_FILES_CHKSUM="file://LICENSE;md5=79cb95e9ed0ec951adb8c0e789de03c1"

# Ocaml's OPAM tool needs 'cc' to be in the PATH.
# This package provides a small shell script called 'cc' that invokes ${CC}.

SRC_URI = " \
    file://cc \
    file://ccld \
    file://LICENSE \
    "
S = "${WORKDIR}"

BBCLASSEXTEND = "native"

do_install() {
    mkdir -p "${D}${bindir}"
    install -m 0755 "${WORKDIR}/cc" "${D}${bindir}/cc"
    install -m 0755 "${WORKDIR}/ccld" "${D}${bindir}/ccld"
}

FILESEXTRAPATHS_prepend := "${THISDIR}/faux-cc:"
