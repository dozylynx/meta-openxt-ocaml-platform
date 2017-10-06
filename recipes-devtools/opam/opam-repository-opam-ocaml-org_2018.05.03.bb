SUMMARY = "OCaml software repository metadata for the opam tool"
LICENSE = "CC0-1.0"
LIC_FILES_CHKSUM="file://COPYING;md5=3853e2a78a247145b4aa16667736f6de"

DEPENDS = "ocaml opam"

# This SRCREV is from Thu May 3 2018
SRCREV = "8acdbc1ac7108cb3eeef88881c790a1093beb07b"

# Deliberately use the tarball download from github because
# it is shallow and so smaller in size.
SRC_URI = " \
    https://github.com/ocaml/opam-repository/archive/${SRCREV}.tar.gz \
    file://opam-root-config-append \
    file://fetch-findlib-from-debian-source.patch \
    "
SRC_URI[md5sum] = "c008efcd5ecf1f88ef126f1791ffb0d0"
SRC_URI[sha256sum] = "73ff7815f272b3fe80ea2d5cac5cc3088d9dde020244df1a0e81968d90f1578f"
S = "${WORKDIR}/opam-repository-${SRCREV}"

BBCLASSEXTEND = "native"

inherit ocaml

do_configure() {
}

do_compile() {
}

do_install() {
    REPO="${datadir}/ocaml/opam-repository"
    mkdir -p "${D}${REPO}"
    cp -r "${S}/compilers" \
          "${S}/packages" \
          "${S}/repo" \
          "${S}/version" \
       "${D}${REPO}"

    export OPAM_COMPILER_HASHES="${RECIPE_SYSROOT_NATIVE}/etc/opam-compilers-to-packages-url-hashes"

    OPAMROOT="${datadir}/ocaml/opam-root"

    rm -rf "${D}${OPAMROOT}"
    OPAMFETCH=/bin/false \
        opam init \
                  --root "${D}${OPAMROOT}" \
                  --dot-profile="${D}${sysconfdir}/opam.profile" \
                  --auto-setup \
                  --kind=local \
                  --no-opamrc \
                  --bare \
                  --solver='mccs -i %{input}% -o %{output}% -lexagregate[%{criteria}%]' \
                  default "${D}${REPO}"

    # The repo cache contains absolute paths so drop it
    opam clean --repo-cache --root "${D}${OPAMROOT}"

    # Remove absolute paths from the opam-init scripts and repos-config
    for SCRIPT in "${D}${OPAMROOT}/opam-init"/init* ; do
        sed -i'' -e "s,${D},,g" "${SCRIPT}"
    done
    sed -i'' -e "s,${D},," "${D}${OPAMROOT}/repo/repos-config"
}

do_install_append_class-native() {
    cat "${WORKDIR}/opam-root-config-append" >>"${D}${OPAMROOT}/config"
}

FILESEXTRAPATHS_prepend := "${THISDIR}/opam:${THISDIR}/opam-repository-opam-ocaml-org:"

FILES_${PN} = " \
    ${datadir}/ocaml/opam-repository \
    ${datadir}/ocaml/opam-root \
    ${sysconfdir}/opam.profile \
    "

do_package_write_ipk[noexec] = "1"
do_package_write_rpm[noexec] = "1"
do_package_write_deb[noexec] = "1"

# Some of the repository files mention bash and so trip the QA warning,
# so turn that warning off.
INSANE_SKIP_${PN} = "file-rdeps"
