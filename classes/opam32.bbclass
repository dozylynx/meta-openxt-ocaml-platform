# Class for use in BBCLASSEXTEND to make it easier to have a single recipe that
# can build both 32-bit and 64-bit output suitable for execution on the native host.
# Intended for to assist producing 32-bit native Opam switches for use
# supporting a cross-compile toolchain for a 32-bit target on a 64-bit host.
#
# This is really a kind of native package.
# Note that when mapping dependencies below, it maps to -native,
# rather than -opam32. This is intentional.
#
# Usage:
# BBCLASSEXTEND = "opam32"

# This must precede inherit native:
OPAM32_TARGET_PREFIX := "${TARGET_PREFIX}"
OPAM32_TARGET_ARCH = "${TARGET_ARCH}"

inherit native

CLASSOVERRIDE = "class-opam32"
SPECIAL_PKGSUFFIX .= " -opam32"

export lt_cv_sys_lib_dlsearch_path_spec = "${libdir} ${base_libdir} /lib /usr/lib"

python opam32_virtclass_handler () {
    pn = e.data.getVar("PN")
    if not pn.endswith("-opam32"):
        return

    # This logic from native.bbclass:
    # Set features here to prevent appends and distro features backfill
    # from modifying native distro features
    features = set(d.getVar("DISTRO_FEATURES_NATIVE").split())
    filtered = set(bb.utils.filter("DISTRO_FEATURES", d.getVar("DISTRO_FEATURES_FILTER_NATIVE"), d).split())
    d.setVar("DISTRO_FEATURES", " ".join(sorted(features | filtered)))

    # No need to map dependencies if this is inherited rather than
    # in use via BBCLASSEXTEND
    classextend = e.data.getVar('BBCLASSEXTEND') or ""
    if "opam32" not in classextend:
        return

    def map_dependencies(varname, d, suffix = ""):
        if suffix:
            varname = varname + "_" + suffix
        deps = d.getVar(varname)
        if not deps:
            return
        deps = bb.utils.explode_deps(deps)
        newdeps = []
        for dep in deps:
            if dep == pn:
                continue
            #---
            # FIXME: This is not at all pleasant, but has the required effect:
            elif dep.startswith('virtual/') and dep.endswith('gcc'):
                newdeps.append(dep)
                newdeps.append('libgcc')
            #---
            elif "-cross-" in dep:
                newdeps.append(dep[0:dep.index('-cross')] + '-native')
            elif not dep.endswith("-native"):
                newdeps.append(dep + "-native")
            else:
                newdeps.append(dep)
        d.setVar(varname, " ".join(newdeps))

    e.data.setVar("OVERRIDES", e.data.getVar("OVERRIDES", False) + ":virtclass-opam32")

    map_dependencies("DEPENDS", e.data)
    for pkg in [e.data.getVar("PN"), "", "${PN}"]:
        map_dependencies("RDEPENDS", e.data, pkg)
        map_dependencies("RRECOMMENDS", e.data, pkg)
        map_dependencies("RSUGGESTS", e.data, pkg)
        map_dependencies("RPROVIDES", e.data, pkg)
        map_dependencies("RREPLACES", e.data, pkg)

    provides = e.data.getVar("PROVIDES")
    nprovides = []
    for prov in provides.split():
        if prov.find(pn) != -1:
            nprovides.append(prov)
        elif not prov.endswith("-opam32"):
            nprovides.append(prov.replace(prov, prov + "-opam32"))
        else:
            nprovides.append(prov)
    e.data.setVar("PROVIDES", ' '.join(nprovides))
}

addhandler opam32_virtclass_handler
opam32_virtclass_handler[eventmask] = "bb.event.RecipePreFinalise"
