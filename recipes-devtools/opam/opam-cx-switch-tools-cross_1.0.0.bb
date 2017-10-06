SUMMARY = "Wrappers for CC, LD and AS with correct flags for building cross switch"
DESCRIPTION = "wrappers for OCaml tools to hardcode to and handle per-recipe-sysroots"
LICENSE = "MIT"
LIC_FILES_CHKSUM="file://LICENSE;md5=79cb95e9ed0ec951adb8c0e789de03c1"

export MY_TARGET_CC = "${TARGET_PREFIX}${CC} ${TARGET_CC_ARCH}"
export MY_TARGET_LD = "${TARGET_PREFIX}${LD} ${TARGET_LD_ARCH}"
export MY_TARGET_AS = "${TARGET_PREFIX}${AS} ${TARGET_AS_ARCH}"
# observe colon-assignment here:
export MY_TARGET_CFLAGS := "${TARGET_CFLAGS}"
export MY_TARGET_LDFLAGS := "${TARGET_LDFLAGS}"

inherit cross

BPN = "opam-cx-switch-tools"
PN = "opam-cx-switch-tools-cross-${TARGET_ARCH}"
PROVIDES = "opam-cx-switch-tools-cross-${TARGET_ARCH}"

SRC_URI = "file://LICENSE"
S = "${WORKDIR}"

do_install() {
    mkdir -p "${D}${bindir}"

    # TODO: MY_TARGET_CFLAGS contains debug-prefix-map entries
    #       that hardcode the recipe build directory.
    #       Not a showstopper but not great either.

    cat >"${D}${bindir}/oe-opam-cc" <<EOF
#!/bin/sh
exec $MY_TARGET_CC $MY_TARGET_CFLAGS "\$@" "--sysroot=${STAGING_DIR_TARGET}"
EOF
    chmod 755 "${D}${bindir}/oe-opam-cc"

    # Process the linker flags in $MY_TARGET_LDFLAGS: they are
    # intended for supplying to a compiler rather than directly to the linker.
    export LINKER_FLAGS="$(echo "${MY_TARGET_LDFLAGS}" | sed 's/-Wl,//g')"
    cat >"${D}${bindir}/oe-opam-ld" <<EOF
#!/bin/sh
exec $MY_TARGET_LD ${LINKER_FLAGS} "\$@" "--sysroot=${STAGING_DIR_TARGET}"
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
