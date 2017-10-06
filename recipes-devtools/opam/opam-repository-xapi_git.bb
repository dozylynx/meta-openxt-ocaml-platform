SUMMARY = "Xapi Project OCaml software repository metadata for the opam tool"
HOMEPAGE = "https://www.xenproject.org/developers/teams/xapi.html"
LICENSE = "MIT"
LIC_FILES_CHKSUM="file://LICENSE;md5=b9831a191988f6a6b246950b444fd432"

DEPENDS = "ocaml opam"

PV = "0+git${SRCPV}"

SRC_URI = " \
    git://github.com/xapi-project/xs-opam.git;branch=master \
    file://opam-root-config-append \
    file://fetch-findlib-from-debian-source.patch;patch=1 \
    file://lockdown-sources-20171107.patch;patch=1 \
    "
# Disable autorev as this thing churns!...
# 7th November 2017
SRCREV = "f83a087f307a02182db0b0817392a86f02f0aa57"

#SRCREV = "${AUTOREV}"
# 12th Oct 2017
#SRCREV = "bd7652a0a6f243290e6f1363a9c411dfa709ac15"
S = "${WORKDIR}/git"

BBCLASSEXTEND = "native"

inherit ocaml

apply_lockdown_to_package_dirs() {
    # Rename the directories of packages that need version lockdown
    # from their directory names that end in ".master"
    # to a name that ends with the version number as specified
    # in the lockdown patch.
    cd "${S}"
    for PACKAGE in $(sed -ne 's,^+++ b/\(.*\)/url,\1,p' <"${WORKDIR}/lockdown-sources-20171107.patch")
    do
        MASTER="$(echo $PACKAGE | sed 's,\..*$,\.master,')"
        mv "$MASTER" "$PACKAGE"
    done
    cd -
}
do_patch_prepend() {
    bb.build.exec_func('apply_lockdown_to_package_dirs', d)
}

do_configure() {
    # FIXME: put this in a patch
    sed -i'' '/  "systemd".*$/d' \
        packages/xs-extra/xapi-forkexecd.*/opam
}

do_compile() {
}

do_install() {
    REPO="${datadir}/ocaml/opam-repository-xapi"
    mkdir -p "${D}${REPO}"
    cp -r "${S}/compilers" \
          "${S}/packages" \
       "${D}${REPO}"

    OPAMROOT="${datadir}/ocaml/opam-root"

    OPAMFETCH=/bin/false
        opam init \
                  --root "${D}${OPAMROOT}" \
                  --dot-profile="${D}${sysconfdir}/opam.profile" \
                  --auto-setup \
                  --kind=local \
                  --no-opamrc \
                  --bare \
                  --solver='mccs -i %{input}% -o %{output}% -lexagregate[%{criteria}%]' \
                  default "${D}${REPO}"

    # The repo cache contains absolute paths so drop it:
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

FILESEXTRAPATHS_prepend := "${THISDIR}/opam:${THISDIR}/opam-repository-xapi:"

FILES_${PN} = " \
    ${datadir}/ocaml/opam-repository-xapi \
    ${datadir}/ocaml/opam-root \
    ${sysconfdir}/opam.profile \
    "

do_package_write_ipk[noexec] = "1"
do_package_write_rpm[noexec] = "1"
do_package_write_deb[noexec] = "1"

# Some of the repository files mention bash and so trip the QA warning,
# so turn that warning off.
INSANE_SKIP_${PN} = "file-rdeps"
