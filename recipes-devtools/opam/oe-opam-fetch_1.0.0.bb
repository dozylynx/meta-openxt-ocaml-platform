SUMMARY = "Scripts to assist use of the opam tool in OE native"
LICENSE = "MIT"
LIC_FILES_CHKSUM="file://LICENSE;md5=79cb95e9ed0ec951adb8c0e789de03c1"

RDEPENDS_${PN} = "bash"

SRC_URI = " \
    file://oe-opam-fetch \
    file://LICENSE \
    "
S = "${WORKDIR}"

BBCLASSEXTEND = "native"

do_install() {
    mkdir -p "${D}${bindir}"
    install -m 0755 "oe-opam-fetch" "${D}${bindir}/oe-opam-fetch"
}

FILESEXTRAPATHS_prepend := "${THISDIR}/oe-opam-fetch:"
