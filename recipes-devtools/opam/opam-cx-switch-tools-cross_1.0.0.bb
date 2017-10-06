SUMMARY = "Wrappers for CC, LD and AS with correct flags for building cross switch"
DESCRIPTION = "sysroot changes for each recipe so ..."
LICENSE = "MIT"
LIC_FILES_CHKSUM="file://LICENSE;md5=79cb95e9ed0ec951adb8c0e789de03c1"

# Stash copies of these variables before 'inherit cross' eats them for lunch.
export MY_TARGET_CC = "${TARGET_PREFIX}${CC}"
export MY_TARGET_LD = "${TARGET_PREFIX}${LD}"
export MY_TARGET_AS = "${TARGET_PREFIX}${AS}"
export MY_LDFLAGS := "${LDFLAGS}"
export MY_STAGING_DIR_TARGET := "${LDFLAGS}"

inherit cross
BPN = "opam-cx-switch-tools"
PN = "opam-cx-switch-tools-cross-${TARGET_ARCH}"
PROVIDES = "opam-cx-switch-tools-cross-${TARGET_ARCH}"

SRC_URI = "file://LICENSE"
S = "${WORKDIR}"

do_install() {
    mkdir -p "${D}${bindir}"

    # FIXME: TARGET_CFLAGS are wrong -> point to native sysroot, not target

    cat >"${D}${bindir}/oe-opam-cc" <<EOF
#!/bin/sh
exec $MY_TARGET_CC $TARGET_CFLAGS "\$@" "--sysroot=${STAGING_DIR_TARGET}"
EOF
    chmod 755 "${D}${bindir}/oe-opam-cc"

    cat >"${D}${bindir}/oe-opam-ld" <<EOF
#!/bin/sh
exec $MY_TARGET_LD "\$@" "--sysroot=${STAGING_DIR_TARGET}"
EOF
    chmod 755 "${D}${bindir}/oe-opam-ld"

    # Add a symlink to redirect invocations of 'ld'
    # to the cross linker. There are multiple ocaml packages
    # that directly invoke "ld" which is incorrect for cross compiling.
    ln -s oe-opam-ld "${D}${bindir}/ld"

    cat >"${D}${bindir}/oe-opam-as" <<EOF
#!/bin/sh
exec $MY_TARGET_AS "\$@"
EOF
    chmod 755 "${D}${bindir}/oe-opam-as"
}

FILESEXTRAPATHS_prepend := "${THISDIR}/opam:"
