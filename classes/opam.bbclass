# Register the Opam fetcher for opam:// SRC_URIs
python() {
    import opam
    bb.fetch2.methods.append( opam.Opam() )
}

# For opam:// SRC_URIs, using opam to calculate what must be fetched means
# that a copy of opam and the opam root to work with is needed in the native sysroot
# before performing the fetch task, so:
#
# * Reorder the tasks so that do_fetch is _after_ the native sysroot is prepared.
#
# * Move the "clean_recipe_sysroot" function that usually runs before fetch,
#   because otherwise it erases the native sysroot that we need.

deltask do_fetch
addtask do_fetch after do_prepare_recipe_sysroot before do_unpack
python () {
    tmp_funcs = d.getVarFlag('do_fetch', 'prefuncs')
    tmp_funcs = tmp_funcs.replace('clean_recipe_sysroot', "")
    d.setVarFlag('do_fetch', 'prefuncs', tmp_funcs)
    d.appendVarFlag('do_prepare_recipe_sysroot', 'prefuncs', 'clean_recipe_sysroot')
}

export OPAMROOT="${WORKDIR}/opam-root"
export OE_OCAMLRUN_ROOT="${OPAMROOT}"

# Create an opam root in the WORKDIR, populated from data in the native recipe sysroot.
# This is the working directory that opam will populate during the build.
# Some config files need to have file paths updated to reflect the new location
# in workdir instead of pointing into the sysroot.
do_unpack_opam_root() {
    export OPAMFETCH=/bin/false

    rm -rf "${WORKDIR}/opam-root"
    mkdir -p "${WORKDIR}/opam-root"
    # TODO: this could be a very large data transfer: look for possible optimization:
    rsync -rl "${RECIPE_SYSROOT_NATIVE}${datadir_native}/ocaml/opam-root/" "${WORKDIR}/opam-root/"

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
do_unpack_append() {
    bb.build.exec_func('do_unpack_opam_root', d)
}

do_patch() {
    # Override the default do_patch implementation because patches
    # are applied to the packages and dependencies by an opam hook.
    echo "opam will apply any patches during the compile step."

    # Check that all patches have the necessary "applyto=" data:
    for SINGLE_SRC_URI in $SRC_URI ; do
        OBJECT="$(echo "$SINGLE_SRC_URI" | sed -ne 's,^[a-z]*://\([^;]*\).*,\1,p')"

        IS_PATCH=0
        PATCH_INDICATOR="$(echo "$SINGLE_SRC_URI" | sed -ne 's,^.*;patch=\([^;]*\).*$,\1,p')"
        case $PATCH_INDICATOR in
            1) IS_PATCH=1 ;;
            0) ;;
            *) case $OBJECT in
                    *.patch) IS_PATCH=1 ;;
               esac
               ;;
        esac
        [ $IS_PATCH = 1 ] || continue

        APPLY_TO="$(echo "$SINGLE_SRC_URI" | sed -ne 's,^.*;applyto=\([^;]*\).*$,\1,p')"
        if [ -z "$APPLY_TO" ] ; then
            bberror "In SRC_URI, patch $OBJECT is missing \"applyto=<opam-package-name>.<version>\"">&2
            bberror "This is needed to identify which opam package to apply the patch to.">&2
            bbfatal "Please append \";applyto=<opam-package-name>.<version>\" to $SINGLE_SRC_URI">&2
        fi
    done

    # TODO: check each of the patches supplied against the solution file
    #       and verify that they are patches against packages that will be built
    #       and raise an error if not.
}

# Set OCaml and opam environment variables to match whichever switch is active.
# This is used when pinning dependencies to versions specfied in the solution file
# and when performing the build.
prep_opam_env() {
    if [ "x${OPAM_SWITCH}" != "x" ] ; then
        export OCAMLFIND_CONF="${OPAMROOT}/${OPAM_SWITCH}/lib/findlib.conf"
        export OCAMLLIB="${OPAMROOT}/${OPAM_SWITCH}/lib/ocaml"
        export OCAMLFIND_LDCONF="${OPAMROOT}/${OPAM_SWITCH}/lib/ocaml/ld.conf"

        mkdir -p "$(dirname "${OCAMLFIND_CONF}")"
        opam switch "${OPAM_SWITCH}"

        eval $(opam env --root="${OPAMROOT}")

        TARGET_CHECK="$(echo ${OPAM_SWITCH} | cut -c1-3)"
        if [ "x$TARGET_CHECK" = "xcx-" ] ; then
            cat >${OCAMLFIND_CONF} <<EOF
destdir="${OPAMROOT}/${OPAM_SWITCH}/lib"
path="${OPAMROOT}/${OPAM_SWITCH}/lib"
ocamlc     = "ocamlc"
ocamlopt   = "ocamlopt"
ocamlcp    = "ocamlcp"
ocamlmktop = "ocamlmktop"
EOF
        else
            cat >${OCAMLFIND_CONF} <<EOF
destdir="${OPAMROOT}/${OPAM_SWITCH}/lib"
path="${OPAMROOT}/${OPAM_SWITCH}/lib"
ocamlc     = "ocamlc.opt"
ocamlopt   = "ocamlopt.opt"
ocamlcp    = "ocamlcp.opt"
ocamlmktop = "ocamlmktop.opt"
EOF
        fi
    else
        # Standard OCaml environment variables enable the tools to locate the installation
        # FIXME: this is duplicating stuff from ocaml.bbclass
        export B_OUT="${S}/build-output/"
        export OCAMLFIND_CONF="${B_OUT}etc/ocamlfind.conf"
        export OCAMLLIB="${STAGING_LIBDIR}/ocaml"
        export CAML_LD_LIBRARY_PATH="${STAGING_LIBDIR}/ocaml/stublibs:${B_OUT}ocaml/stublibs"

        opam switch "default"
    fi
}

python do_opam_pin_dependencies() {
    import json
    import os.path
    import bb.process

    src_uris = d.getVar("SRC_URI").split()
    switches = []
    for opam_uri in filter(lambda x:x.startswith('opam://'), src_uris):
        uri_info =  data_from_opam_uri(opam_uri)

        if uri_info['solution'] is None:
            continue

        # ---
        solution_json = os.path.join(d.getVar('WORKDIR'), uri_info['solution'])
        with open(solution_json) as json_data:
            solution_data = json.load(json_data)

        if not 'solution' in solution_data:
            raise Exception('No solution found for install of %s' % uri_info['package'])

        # ---
        opam_switch = uri_info['switch']
        if opam_switch is None:
            opam_switch = 'default'
            d.delVar("OPAM_SWITCH")
        else:
            class_override = d.getVar("CLASSOVERRIDE")
            if class_override == "class-target" or \
               class_override == "":
                opam_switch = "cx-" + opam_switch
            d.setVar("OPAM_SWITCH", opam_switch)

        bb.build.exec_func("prep_opam_env", d)

        # ---
        packages = []
        for action in solution_data['solution']:
            packages.append(action['install'])

        for package in packages:
            cmd = 'opam pin --no-action --kind=version add "%s" "%s"' \
                  % (package['name'], package['version'])
            try:
                bb.process.run(cmd)
            except Exception as e:
                # Pin failed
                raise Exception('Failed to pin opam package "%s" to version "%s". %s' \
                                % (package['name'], package['version'], str(e)))
}

addtask do_opam_pin_dependencies after do_patch before do_configure

# Clear the standard build environment variables used by OE during compile
# because they confuse the build of components being built by opam.
#
# Set OPAMFETCH to use the script that obtains source tarballs from the
# OE download directory.
#
do_compile_prepend() {
    export OPAMFETCH="oe-opam-fetch"
    # WORKDIR is needed by oe-opam-fetch in order to access
    # the file downloads retrieved in the OE fetch task.
    export OE_OPAMFETCH_DIR="${WORKDIR}"

    unset base_bindir
    unset base_libdir
    unset base_prefix
    unset base_sbindir
    unset bindir
    unset datadir
    unset docdir
    unset exec_prefix
    unset includedir
    unset infodir
    unset libexecdir
    unset localstatedir
    unset mandir
    unset sbindir
    unset sysconfdir
    unset prefix
    unset libdir
}

# Make SRC_URI visible to tasks for two reasons:
# 1: Enable tasks to iterate over each of the opam:// URIs and act on
# the data in each opam URI.
# 2: Enable any patches to be applied by the opam hook in the compile step.
export SRC_URI

do_compile_prepend_class-cross() {
    CLASSOVERRIDE="class-cross"
}

do_compile_prepend_class-native() {
    CLASSOVERRIDE="class-native"
}

do_compile_prepend_class-opam32() {
    CLASSOVERRIDE="class-opam32"
}

do_compile_prepend_class-target() {
    CLASSOVERRIDE="class-target"
}

do_compile() {
    rm -rf "${S}/destdir"
    mkdir -p "${S}/destdir"

    for SINGLE_SRC_URI in $SRC_URI ; do
        [ "$(expr substr "$SINGLE_SRC_URI" 1 7)" = "opam://" ] || continue
        OPAM_PACKAGE="$(echo "$SINGLE_SRC_URI" | sed -ne 's,^opam://\([^;]*\).*$,\1,p')"
        OPAM_SOLUTION="$(echo "$SINGLE_SRC_URI" | sed -ne 's,^.*;solution=\([^;]*\).*$,\1,p')"

        OPAM_SWITCH="$(echo "$SINGLE_SRC_URI" | sed -ne 's,^.*;switch=\([^;]*\).*$,\1,p')"
        # Target packages are built using the cross-compile switch
        # which has a prefix to its name.
        if [ "$CLASSOVERRIDE" = "class-target" ] ; then
            OPAM_SWITCH="cx-$OPAM_SWITCH"
        fi

        prep_opam_env

        if [ "$CLASSOVERRIDE" = "class-cross" ] ; then
            opam install "${OPAM_PACKAGE}" \
                 --destdir="${S}/destdir${datadir_native}/ocaml/opam-root/${OPAM_SWITCH}" --yes

        else
            opam install "${OPAM_PACKAGE}" --destdir="${S}/destdir" --yes --verbose
        fi
    done
}

do_install_prepend() {
    export OPAMFETCH=/bin/false
}

do_install() {
    mkdir -p "${D}${base_prefix}"
    rsync -rl "${S}/destdir/" "${D}${base_prefix}/"
}

# Workaround stupid cross class bug
do_install_class-cross() {
    mkdir -p "${D}${base_prefix}"
    rsync -rl "${S}/destdir/" "${D}${base_prefix}/"
}

def data_from_opam_uri(opam_uri):
    data = {}
    semicolon_index = opam_uri.find(';')
    if semicolon_index == -1:
        data['package'] = opam_uri[7:]
    else:
        data['package'] = opam_uri[7:semicolon_index]
    for option in ['switch', 'solution']:
        delimiter = ';%s=' % option
        si = opam_uri.find(delimiter)
        if si == -1:
            data[option] = None
        else:
            ti = opam_uri.find(';', si + len(delimiter) + 1)
            if ti == -1:
                ti = len(opam_uri)
            data[option] = opam_uri[si+len(delimiter):ti]
    return data

do_devshell_prepend() {
    import re
    import subprocess

    src_uris = d.getVar("SRC_URI").split()
    class_override = d.getVar("CLASSOVERRIDE")
    switches = []
    opam_root = d.getVar("OPAMROOT")
    for opam_uri in filter(lambda x:x.startswith('opam://'), src_uris):
        uri_info =  data_from_opam_uri(opam_uri)
        opam_switch = uri_info['switch']
        if opam_switch is None:
            opam_switch = 'default'
            d.delVar("OPAM_SWITCH")
        else:
            if class_override == "class-target" or \
               class_override == "":
                opam_switch = "cx-" + opam_switch
            d.setVar("OPAM_SWITCH", opam_switch)

        bb.build.exec_func("prep_opam_env", d)

        d.setVar("OCAMLFIND_CONF", "%s/%s/lib/findlib.conf" % (opam_root, opam_switch))
        d.setVar("OCAMLLIB", "%s/%s/lib/ocaml" % (opam_root, opam_switch))
        d.setVar("OCAMLFIND_LDCONF", "%s/%s/lib/ocaml/ld.conf" % (opam_root, opam_switch))

    # read the environment variable values from executing: opam env
    # and add them to the environment.
    # OPAMROOT has been exported so no need to supply --root argument here.
    # FIXME: change this to use --sexp and redirect STDERR elsewhere
    opam_env_cmd = 'opam env --root=' + opam_root
    opam_env_output = \
        subprocess.check_output(opam_env_cmd.split(), \
                                stderr=subprocess.STDOUT).decode('utf-8')

    opam_env_lines = opam_env_output.split('\n')[:-1]

    # expected line format: VAR='data'; export VAR;
    env_line_re = re.compile("([^=]+)='([^']+)';.*$")

    for line in opam_env_lines:
        m = env_line_re.match(line)
        try:
            var_name = m.group(1)
            var_value = m.group(2)

            d.setVar(var_name, var_value)
            d.appendVar("OE_TERMINAL_EXPORTS", " " + var_name)
        except AttributeError:
            print("Unable to parse a line from opam env:")
            print("-- [ %s ] --" % line)

    for var_name in ['OCAMLFIND_CONF', 'OCAMLFIND_LDCONF', 'OCAMLLIB']:
        d.appendVar("OE_TERMINAL_EXPORTS", " " + var_name)
}

def get_opam_uri_data(d, tag):
    """
    get the list of opam tagged data indicated in the recipe SRC_URIs
    """
    src_uris = d.getVar("SRC_URI").split()
    switches = []
    for opam_uri in filter(lambda x:x.startswith('opam://'), src_uris):
        delimiter = ';%s=' % tag
        si = opam_uri.find(delimiter)
        if si == -1:
            continue
        ti = opam_uri.find(';', si + len(delimiter) + 1)
        if ti == -1:
            ti = len(opam_uri)
        switches.append(opam_uri[si+len(delimiter):ti])
    return switches

def get_opam_switches(d):
    """
    get the list of opam switches in SRC_URIs
    """
    return get_opam_uri_data(d, 'switch')

def get_opam_repositories(d):
    """
    get the list of opam repositories in SRC_URIs
    """
    raw_repos = get_opam_uri_data(d, 'repos')
    import functools
    return sorted(list(set(functools.reduce( \
        lambda y, z: []+y+z, map(lambda x: x.split(','), raw_repos)))))

def get_opam_switch_depends(d):
    """
    get the list of OE packages needed to supply the opam switches in SRC_URIs
    """
    switches = get_opam_switches(d)
    suffix = '-cross-' + d.getVar("TARGET_ARCH")
    if bb.data.inherits_class('native', d):
        suffix = '-native'
    if bb.data.inherits_class('cross', d):
        suffix = '-native'
    if bb.data.inherits_class('opam32', d):
        suffix = '-opam32'
    return " ".join(list(map(lambda x:'opam-switch-%s%s' % (x, suffix), switches)))

def get_opam_repos_depends(d):
    """
    get the list of OE packages needed to supply the opam switches in SRC_URIs
    """
    repos = get_opam_repositories(d)
    return " ".join(list(map(lambda x:'opam-repository-%s-native' % (x), repos)))

DEPENDS_append = " \
    ocaml-native \
    oe-ocamlrun-native \
    opam-native \
    oe-opam-fetch-native \
    ${@get_opam_switch_depends(d)} \
    ${@get_opam_repos_depends(d)} \
    "
