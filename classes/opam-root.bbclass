# Create an opam root in the WORKDIR, populated from data in the native recipe sysroot.
# This is the working directory that opam will populate during the build.
# Some config files need to have file paths updated to reflect the new location
# in workdir instead of pointing into the sysroot.

export OPAMROOT="${WORKDIR}/opam-root"

do_prepare_opam_root() {
    export OPAMFETCH=/bin/false

    rm -rf "${WORKDIR}/opam-root"
    mkdir -p "${WORKDIR}/opam-root"
    # TODO: this could be a very large data transfer: look for possible optimization:
    tar -C "${RECIPE_SYSROOT_NATIVE}${datadir_native}/ocaml" -cf - opam-root | \
        tar -C "${WORKDIR}" -xf -

    # correct absolute paths in the config files of the new work directory opam-root:
    for CONFIG_FILE in \
        "${WORKDIR}"/opam-root/opam-init/init* \
        "${WORKDIR}"/opam-root/*/.opam-switch/config/ocaml.config \
        "${WORKDIR}"/opam-root/*/.opam-switch/environment \
        "${WORKDIR}"/opam-root/*/.opam-switch/switch-config \
    ; do
        if [ -f "${CONFIG_FILE}" ] ; then
            sed -i'' "s,${RECIPE_SYSROOT_NATIVE}${datadir_native}/ocaml,${WORKDIR},g" "${CONFIG_FILE}"
        fi
    done

    eval $(opam env --root="${WORKDIR}/opam-root")

    # Clean the repo-cache to excise any embedded absolute file paths:
    opam clean --repo-cache
}
do_prepare_recipe_sysroot_append() {
    bb.build.exec_func('do_prepare_opam_root', d)
}
