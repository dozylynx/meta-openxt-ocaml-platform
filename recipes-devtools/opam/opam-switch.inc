SUMMARY = "An Opam switch with a specific OCaml compiler version"
LICENSE = "LGPL-2.1-with-OCaml-linking-exception"

# Recipes derived from this are only for native, cross and opam32-native; not target.
COMPATIBLE_MACHINE_class-target = "(NOboDY)"

DEPENDS = "ocaml-native \
    opam-native \
    rsync-native \
    oe-ocamlrun-native \
    opam-native-switch-tools-native \
    "

DEPENDS_append_class-cross = " \
    opam-ocaml-cross-configure-native \
    opam-cx-switch-tools-cross-${TARGET_ARCH} \
    util-linux \
    virtual/${TARGET_PREFIX}gcc \
    "

# Cross switches depend on either a -native or -opam32-native switch,
# depending on the host and the target's word size.
python () {
    if d.getVar("CLASSOVERRIDE") == "class-cross":
        bpn = d.getVar("BPN")
        translated_target_arch = d.getVar("TRANSLATED_TARGET_ARCH")
        host_arch = d.getVar("HOST_ARCH")
        if '64' not in translated_target_arch and '64' in host_arch:
            assist_pn = bpn + "-opam32-native"
            d.setVar("ASSIST_SWITCH_PREFIX", "nx-")
        else:
            assist_pn = bpn + "-native"
            d.setVar("ASSIST_SWITCH_PREFIX", "")
        d.setVar("DEPENDS", d.getVar("DEPENDS", False) + ' ' + assist_pn)
}

DEPENDS_append_class-opam32-native = " \
    util-linux \
    opam-opam32-switch-tools-native \
    libgcc \
    opam-switch-${PV}-${OPAM_REPOS}-native \
    "

RDEPENDS_${PN}_append = " opam-repository-${OPAM_REPOS}-native"

RDEPENDS_append_class-cross = " \
    opam-cx-switch-tools-cross-${TARGET_ARCH} \
    opam-native-switch-tools-native \
    "

SRC_URI_append = " \
    file://opam-root-config-append \
    file://post-inst.sh.in \
    file://ocamlc-wrapper.sh \
    file://ocamlcp-wrapper.sh \
    file://ocamldep-wrapper.sh \
    file://ocamllex-wrapper.sh \
    file://ocamlmklib-wrapper.sh \
    file://ocamlmktop-wrapper.sh \
    file://ocamlopt-wrapper.sh \
    file://ocamloptp-wrapper.sh \
    file://ocamlprof-wrapper.sh \
    file://ocamlyacc-wrapper.sh \
    file://ocamlbuild-wrapper.sh \
    file://ocamlfind-wrapper.sh \
    file://ocaml-wrapper.sh \
    "
S = "${WORKDIR}"

MY_CFLAGS := "${CFLAGS}"
MY_LDFLAGS := "${LDFLAGS}"

# Upstream cross recipes contain this, so defer to that wisdom:
# http://lists.openembedded.org/pipermail/openembedded-core/2017-April/135535.html
# Ignore how TARGET_ARCH is computed.
TARGET_ARCH[vardepvalue] = "${TARGET_ARCH}"

# Note the TARGET_ARCH variant subtype of cross in BBCLASSEXTEND:
# this seems to be the only way to get the manifest for populate_sysroot
# to be found at the correct ${BUILD_ARCH}_${TARGET_ARCH} location:
# it appends the ${TARGET_ARCH} to the package name, so that "-cross-"
# ends up in the generated package name, which staging.bbclass requires.
BBCLASSEXTEND = "cross:${TARGET_ARCH} native opam32-native"
BPN = "opam-switch-${PV}-${OPAM_REPOS}"
PN_class-cross = "opam-switch-${PV}-${OPAM_REPOS}-cross-${TARGET_ARCH}"
PROVIDES_class-cross = "${PN}"

# make the current package class being built accessible to the build:
export CLASSOVERRIDE

CFLAGS_class-cross = "${MY_CFLAGS}"
LDFLAGS_class-cross = "${MY_LDFLAGS}"

# Cross compiler needs to know the target architecture
export TRANSLATED_TARGET_ARCH

inherit ocaml

do_unpack_append() {
    bb.build.exec_func('do_extract_license', d)
}

do_extract_license() {
    tar -zxf "${COMPILER_TARBALL}" "ocaml-${PV}/LICENSE"
    mv "ocaml-${PV}/LICENSE" "${WORKDIR}"
    rmdir "ocaml-${PV}"
}

WORKDIR_OPAMROOT="${S}/opam-root"

# Switches are named differently in the opam root depending on the package class.
# * native switches are named the same as the compiler version.
# * cross switches are also named by compiler version but with a prefix.
# The above is to allow side-by-side installation in the same opam root.
# * A target switch would be named the same as the compiler version.

python () {
    pv = d.getVar("PV")
    if d.getVar("CLASSOVERRIDE") == "class-cross":
        switch_name = "cx-" + pv
    elif d.getVar("CLASSOVERRIDE") == "class-opam32-native":
        switch_name = "nx-" + pv

        # Building the opam32 as a cross compiler needs the native
        # tools of the same version in $PATH
        d.setVar("PATH", d.getVar("RECIPE_SYSROOT_NATIVE", False) + "/usr/share/ocaml/opam-root/" + pv + "/bin:" + d.getVar("PATH", False))

    else:
        switch_name = pv
    d.setVar("SWITCH", switch_name)
    d.setVar("COMPILER", 'ocaml-base-compiler.' + pv)
}

inherit opam-root

populate_cache_with_compiler_tarball() {
    # Prepopulate the download cache with the compiler source tarball.
    # OE performs the tarball download in do_fetch and this makes it available
    # for opam to find rather than attempt a download itself.
    TARBALL_MD5="$(md5sum "${COMPILER_TARBALL}" | cut -f1 -d' ')"
    TWO_CHARS="$(echo ${TARBALL_MD5} | cut -c1-2)"
    mkdir -p "${WORKDIR_OPAMROOT}/download-cache/md5/${TWO_CHARS}"
    rm -f "${WORKDIR_OPAMROOT}/download-cache/md5/${TWO_CHARS}/${TARBALL_MD5}"
    ln "${COMPILER_TARBALL}" "${WORKDIR_OPAMROOT}/download-cache/md5/${TWO_CHARS}/${TARBALL_MD5}"
}

do_configure() {
    populate_cache_with_compiler_tarball

    INSTALLED_SWITCHES="$(for SWITCHDIR in \
        $(find "${OPAMROOT}" -maxdepth 2 -name .opam-switch -exec dirname {} \;) ; do \
            echo \"$(basename $SWITCHDIR)\" ; done | tr '\n' ' ')"

    if [ $(echo "${INSTALLED_SWITCHES}" | wc -w) != '1' ] ; then
        PRE_BRACKET='['
        POST_BRACKET=']'
    fi

    if grep -q '^installed-switches:' "${WORKDIR_OPAMROOT}/config" ; then
        sed -i'' 's,^\(installed-switches:\) .*$,\1 '"${PRE_BRACKET}${INSTALLED_SWITCHES}${POST_BRACKET}"',' "${WORKDIR_OPAMROOT}/config"
    else
        echo "installed-switches: ${PRE_BRACKET}${INSTALLED_SWITCHES}${POST_BRACKET}" >> "${WORKDIR_OPAMROOT}/config"
    fi
}

do_configure_class-native() {
    export OPAM_COMPILER_HASHES="${RECIPE_SYSROOT_NATIVE}/etc/opam-compilers-to-packages-url-hashes"
    rm -rf "${WORKDIR_OPAMROOT}"
    mkdir -p "${WORKDIR_OPAMROOT}"
    OPAMFETCH=/bin/false \
        opam init \
                  --root "${WORKDIR_OPAMROOT}" \
                  --dot-profile="${S}/opam.profile" \
                  --auto-setup \
                  --kind=local \
                  --no-opamrc \
                  --bare \
                  --solver='mccs -i %{input}% -o %{output}% -lexagregate[%{criteria}%]' \
                  default "${REPOSITORY_DIR}"

    populate_cache_with_compiler_tarball

    # The native append is used for both -native and -cross builds.
    cat "${WORKDIR}/opam-root-config-append" >>"${WORKDIR_OPAMROOT}/config"
}

do_compile() {
    export OE_OCAMLRUN_ROOT="${WORKDIR_OPAMROOT}"
    eval $(opam env --root="${WORKDIR_OPAMROOT}")

    OPAMFETCH=/bin/false \
        opam switch create "${SWITCH}" "${COMPILER}" --root "${WORKDIR_OPAMROOT}"

    # Workaround for ocamlbuild installing itself in incorrect location
    if [ -e "${WORKDIR_OPAMROOT}/${SWITCH}/lib/ocamlbuild" ] ; then
        ln -s ../ocamlbuild "${WORKDIR_OPAMROOT}/${SWITCH}/lib/ocaml/ocamlbuild"
    fi
}

POSTINST="${RECIPE_SYSROOT_NATIVE}${bindir_native}/postinst-${PN}"

common_do_install() {
    DEST_ROOT="${datadir}/ocaml/opam-root"
    mkdir -p "${D}${DEST_ROOT}"
    rsync -rl "${WORKDIR_OPAMROOT}/${SWITCH}" "${D}${DEST_ROOT}/"

    # Update paths for new switch location:
    for CONFIG_FILE in \
        "${D}${DEST_ROOT}/${SWITCH}/.opam-switch/config/ocaml.config" \
        "${D}${DEST_ROOT}/${SWITCH}/.opam-switch/environment" \
        "${D}${DEST_ROOT}/${SWITCH}/.opam-switch/switch-config" \
    ; do
        sed -i'' "s,${WORKDIR_OPAMROOT},${DEST_ROOT},g" "${CONFIG_FILE}"
    done

    # Add a post-install script to enable the switch when installed into
    # a recipe's native sysroot.
    mkdir -p "${D}${RECIPE_SYSROOT_NATIVE}${bindir_native}"
    install -m 0755 "${WORKDIR}/post-inst.sh.in" "${D}${POSTINST}"
    sed -i'' -e 's/%SWITCH%/'"${SWITCH}"'/' "${D}${POSTINST}"
    sed -i'' -e 's,%STAGING_DATADIR_NATIVE%,'"${STAGING_DATADIR_NATIVE}"',' "${D}${POSTINST}"
}

# Ensure that the post-install script is included in the -cross sysroot
SYSROOT_DIRS_append_class-cross = " ${RECIPE_SYSROOT_NATIVE}${bindir_native}"
SYSROOT_DIRS_append_class-opam32-native = " ${RECIPE_SYSROOT_NATIVE}${bindir_native}"

# The two versions of do_install below are a workaround for this bug:
# cross in BBCLASSEXTEND will replace the recipe's do_install.
# https://bugzilla.yoctoproject.org/show_bug.cgi?id=9272
# Providing a class-cross suffixed function enables overriding that
# unwanted default one produced by the BBCLASSEXTEND.

do_install_class-native() {
    common_do_install
}

do_install_class-opam32-native() {
    common_do_install
}

do_install_class-cross() {
    common_do_install

    # The cross switch bin directory fills with binaries compiled for the target
    # as the switch is used. We don't want those in the PATH, so we populate
    # a separate bin directory that can safely be included in PATH.
    mkdir -p "${D}${DEST_ROOT}/${SWITCH}/cx/bin"

    # In a cross switch, the ocamlrun interpreter ends up built to run
    # on the target, rather than native. This is not what is wanted.
    # (If a target interpreter is needed, build one in a target switch.)
    #
    # The interpreter needs to:
    # * execute on the compile host
    # * be built to match the word-length of the target host
    #   ie. 64-bit if the target is 64-bit, or 32-bit if target is 32-bit.
    #
    # So: replace the "cross"-built interpreter with one from
    # either a native switch or an 'opam32' switch.
    rm "${D}${DEST_ROOT}/${SWITCH}/bin/ocamlrun"
    ASSIST_SWITCH="${ASSIST_SWITCH_PREFIX}$(echo ${SWITCH} | cut -c 4-)"
    NATIVE_SWITCH="$(echo ${SWITCH} | cut -c 4-)"
    install -m 0755 "${RECIPE_SYSROOT_NATIVE}${datadir_native}/ocaml/opam-root/${ASSIST_SWITCH}/bin/ocamlrun" \
                    "${D}${DEST_ROOT}/${SWITCH}/bin/ocamlrun"

    # ocamlc has a burned-in absolute path to the standard library
    # which is supplied whenever 'ocamlc -where' is invoked.
    # We wrap the tool to intercept such invocations and supply the
    # current recipe-specific path.
    # In addition to that, we use wrappers for all the toolchain
    # tools in order to be able to dynamically switch between
    # compiling for native and for target, depending on whether
    # the package is needed on the build host or the target.
    install -m 0755 "${WORKDIR}/ocamlc-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamlc"
    install -m 0755 "${WORKDIR}/ocamlcp-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamlcp"
    install -m 0755 "${WORKDIR}/ocamldep-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamldep"
    install -m 0755 "${WORKDIR}/ocamllex-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamllex"
    install -m 0755 "${WORKDIR}/ocamlmklib-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamlmklib"
    install -m 0755 "${WORKDIR}/ocamlmktop-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamlmktop"
    install -m 0755 "${WORKDIR}/ocamlopt-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamlopt"
    install -m 0755 "${WORKDIR}/ocamloptp-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamloptp"
    install -m 0755 "${WORKDIR}/ocamlprof-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamlprof"
    install -m 0755 "${WORKDIR}/ocamlyacc-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamlyacc"
    install -m 0755 "${WORKDIR}/ocaml-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocaml"
    install -m 0755 "${WORKDIR}/ocamlfind-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamlfind"
    install -m 0755 "${WORKDIR}/ocamlbuild-wrapper.sh" \
       "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamlbuild"

    # We didn't build the opt versions, but we don't want other opt
    # tools accessible via the PATH, so just symlink to non-opt tool.
    # Also create symlinks for byte.
    # Also create named symlinks to native tools in the native switch.
    # TODO: consider wrapping the native switch tools to reset env variables.
    for F in ocamlc ocamlcp ocamldep ocamllex ocamlmklib ocamlmktop \
             ocamlopt ocamloptp ocamlprof ; do
        ln -s "$F" "${D}${DEST_ROOT}/${SWITCH}/cx/bin/$F.opt"
        ln -s "$F" "${D}${DEST_ROOT}/${SWITCH}/cx/bin/$F.byte"
        ln -s "../../../${NATIVE_SWITCH}/bin/${F}" \
              "${D}${DEST_ROOT}/${SWITCH}/cx/bin/$F.native"
    done

    ln -s "ocamlbuild" "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamlbuild.byte"
    ln -s "ocamlbuild" "${D}${DEST_ROOT}/${SWITCH}/cx/bin/ocamlbuild.native"

    for BINARYPATH in "${D}${DEST_ROOT}/${SWITCH}/bin/"* ; do
        BINARY="$(basename $BINARYPATH)"
        if [ ! -e "${D}${DEST_ROOT}/${SWITCH}/cx/bin/${BINARY}" ] ; then
            ln -s "../../bin/${BINARY}" "${D}${DEST_ROOT}/${SWITCH}/cx/bin/${BINARY}"
        fi
    done
}

FILESEXTRAPATHS_prepend := "${THISDIR}/opam:${THISDIR}/ocamlbuild:${THISDIR}/opam-cross:"

# Copying the ocamlrun binary from native results in an 'already stripped' warning
# so disable the check for cross switches:
INSANE_SKIP_${BPN}-cross-${TARGET_ARCH} = "already-stripped"
INSANE_SKIP_${BPN}-opam32-native = "already-stripped"
INHIBIT_PACKAGE_STRIP_class-cross = "1"
INHIBIT_SYSROOT_STRIP_class-cross = "1"
