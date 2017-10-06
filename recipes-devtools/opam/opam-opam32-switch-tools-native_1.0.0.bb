SUMMARY = "Wrappers for CC, LD and AS with correct flags for building cross switch"
DESCRIPTION = "wrappers for OCaml tools to hardcode to and handle per-recipe-sysroots"
LICENSE = "MIT"
LIC_FILES_CHKSUM="file://LICENSE;md5=79cb95e9ed0ec951adb8c0e789de03c1"

inherit native

SRC_URI = "file://LICENSE"
S = "${WORKDIR}"

# FIXME: remove the hardcoded i686 below - generate the
#        right prefix depending on host arch

do_install() {
    mkdir -p "${D}${bindir}"

    cat >"${D}${bindir}/i686-opam32-linux-gcc" <<EOF
#!/bin/sh
exec $CC $CFLAGS "\$@" -m32
EOF
    chmod 755 "${D}${bindir}/i686-opam32-linux-gcc"

    cat >"${D}${bindir}/i686-opam32-linux-ld" <<EOF
#!/bin/sh
exec $LD ${LDFLAGS} "\$@" -m32
EOF
    chmod 755 "${D}${bindir}/i686-opam32-linux-ld"

    cat >"${D}${bindir}/i686-opam32-linux-as" <<EOF
#!/bin/sh
exec $AS "\$@" --32
EOF
    chmod 755 "${D}${bindir}/i686-opam32-linux-as"

    cat >"${D}${bindir}/i686-opam32-linux-ar" <<EOF
#!/bin/sh
exec $AR "\$@"
EOF
    chmod 755 "${D}${bindir}/i686-opam32-linux-ar"

    cat >"${D}${bindir}/i686-opam32-linux-ranlib" <<EOF
#!/bin/sh
exec $RANLIB "\$@"
EOF
    chmod 755 "${D}${bindir}/i686-opam32-linux-ranlib"
}

FILESEXTRAPATHS_prepend := "${THISDIR}/opam:"
