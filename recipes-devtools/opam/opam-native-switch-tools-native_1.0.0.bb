SUMMARY = "Wrappers for LD for a native opam switch"
LICENSE = "MIT"
LIC_FILES_CHKSUM="file://LICENSE;md5=79cb95e9ed0ec951adb8c0e789de03c1"

# Change the linker used by the ocaml tools in native switches:
# instead of the default "ld", use "oe-opam-ld-native" that this
# recipe supplies.
# This allows "ld" to be redirected when cross compiling to use
# the cross linker, rather than the host, as many OCaml components
# directly invoke "ld" during their build, which fails without this.

inherit native

SRC_URI = "file://LICENSE"
S = "${WORKDIR}"

do_install() {
    mkdir -p "${D}${bindir}"

    cat >"${D}${bindir}/oe-opam-ld-native" <<EOF
#!/bin/sh
exec "${HOSTTOOLS_DIR}/ld" "\$@"
EOF
    chmod 755 "${D}${bindir}/oe-opam-ld-native"
}

FILESEXTRAPATHS_prepend := "${THISDIR}/opam:"
