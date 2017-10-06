'''
BitBake Fetch implementation for the OCaml OPAM repository tool

The opam tool must be available in the native fetch environment;
this may be achieved via "inherit opam" in a recipe.

SRC_URI scheme:
SRC_URI = "opam://<package-name>;option1=<data1>;option2=<data2>;..."

options:
* version  : opam package version
* switch   : opam switch (ie. compiler version)
* repos    : name(s) of opam repositor(y|ies), comma separated
* solution : json solution file for locking down packages

'''
# Author: Christopher Clark
# Copyright (c) 2017-18 BAE Systems
#
# TODO: license terms here

import bb
import json
import os
import os.path
import re
import sys
import time
from bb.process import NotFoundError, ExecutionError, CmdError
from bb.fetch2 import FetchData
from bb.fetch2 import FetchError
from bb.fetch2 import FetchMethod
from bb.fetch2 import ParameterError
from bb.fetch2 import local
from bb.fetch2 import logger
from bb.fetch2 import runfetchcmd

__url_pattern__ = re.compile(r'''
 \s*                        # Strip preceding whitespace
 opam://                    # The URL scheme: opam for us
 (?P<src_uri_name>\S+?)          # Package name
 (;(?P<options>(\S)+))*     # URI suffix with other arguments
 $
''', re.VERBOSE)

#---
def dedupe(seq):
    seen = set()
    seen_add = seen.add
    return [x for x in seq if not (x in seen or seen_add(x))]

def get_data_from_opam_metadata(opam_data, extract_re):
    url_block = ""
    ready = False
    for line in opam_data.split("\n"):
        if ready:
            if line == "}":
                break
            else:
                url_block += line
                continue
        if line.startswith('url'):
            ready = True

    m = extract_re.search(url_block)
    if m:
        return m.group(1)
    return None

def get_url_from_opam_metadata(opam_data):
    src_re = re.compile('src:\s*"([^"]*)"')
    return get_data_from_opam_metadata(opam_data, src_re)

def get_md5_checksum_from_opam_metadata(opam_data):
    md5_checksum_re = re.compile('checksum:\s*"md5=([^"]*)"')
    return get_data_from_opam_metadata(opam_data, md5_checksum_re)

def get_license_from_opam_metadata(opam_data):
    #FIXME: match start of line
    license_re = re.compile('\nlicense:\s*"([^"]*)"')
    m = license_re.search(opam_data)
    if m:
        return m.group(1)
    return None

def get_uri_options(raw):
    if raw is None:
        return {}
    ret = {}
    for opt in raw.split(';'):
        (key, value) = opt.split('=')
        ret[key] = value
    return ret

def debug_print(msg):
    logger.debug(1, "OpamFetch: %s", msg)
    #logger.warning("OpamFetch: %s", msg)

def _native_sysroot_opamroot(d):
    recipe_sysroot_native = d.getVar('RECIPE_SYSROOT_NATIVE')
    if not os.path.exists(recipe_sysroot_native):
        raise Exception("native sysroot is required for the opam fetch method: inherit opam?")
    datadir_native = d.getVar('datadir_native')
    return os.path.join(recipe_sysroot_native + datadir_native, 'ocaml', 'opam-root')

def verbose_runfetchcmd(cmd, d):
    debug_print(cmd)
    return runfetchcmd(cmd, d)


#---
class OpamSrcUri(object):
    def __init__(self):
        self.name = None
        self.version = None
        self.switch = None
        self.repos = None
        self.solution = None

#---
class OpamSolution(object):
    def __init__(self, ud, d):
        self.ud = ud
        self.d = d
        self.native_sysroot_opamroot = _native_sysroot_opamroot(d)

    @staticmethod
    def generate_solution_file(opamroot, dldir_solution, src_uri_name, src_uri_version, d):
        debug_print("generate_solution_file")

        pre_solution_versioned_pkgname = src_uri_name
        if src_uri_version is not None:
            pre_solution_versioned_pkgname += "." + src_uri_version
        cmd = 'opam install --root="%s" --dry-run --json="%s" "%s" --yes' % \
            (opamroot, dldir_solution, pre_solution_versioned_pkgname)
        try:
            verbose_runfetchcmd(cmd, d)
        except FetchError as e:
            debug_print("Semi-expected solution error") #: %s" % str(e))
            # Note that this usually returns a failure, even when it succeeds,
            # because opam's "dry-run" support is currently rough.
            # Typically says: command not found.
            pass

    @staticmethod
    def query_packages_metadata(opamroot, dldir_solution, d):
        with open(dldir_solution) as json_data:
            solution_data = json.load(json_data)

        if not 'solution' in solution_data:
            debug_print("No solution found in the data file")
            raise FetchError('No solution found for install')

        packages = []
        for action in solution_data['solution']:
            packages.append(action['install'])

        debug_print("Checking solution for source URL, checksum and license data")

        for package in packages:
            if package.get('no-url') == '1':
                continue
            if package.get('license') != '':
                if 'url' in package and package.get('md5-checksum') != '':
                    continue

            # FIXME: if we're here, we will need to abort the build
            #        because it means the solution file is missing
            #        essential metadata.

            dotted_name = "%s.%s" % (package['name'], package['version'])
            debug_print("Querying opam for: %s" % dotted_name)
            cmd = '''opam show --root=%s --field=opam-file "%s"''' \
                  % (opamroot, dotted_name)
            opam_metadata = runfetchcmd(cmd, d)

            if not package.get('url'):
                url = get_url_from_opam_metadata(opam_metadata)
                if url is not None:
                    package['url'] = url
                else:
                    package['no-url'] = '1'

            if not package.get('md5-checksum'):
                md5_checksum = get_md5_checksum_from_opam_metadata(opam_metadata)
                if md5_checksum is not None:
                    package['md5-checksum'] = md5_checksum

            if not package.get('license'):
                license = get_license_from_opam_metadata(opam_metadata)
                if license is not None:
                    package['license'] = license

        # FIXME: need to detect and handle packages that have
        #        no software license metadata here.
        #        The opam repository may not have that data available;
        #        OE must have it, so manual annotation of the solution
        #        file is required.

        solution_data['solution'] = list( \
            map(lambda x: {"install": x }, packages) )

        return solution_data

    @staticmethod
    def get_uri_solution_file(ud, d):
        lockdown_url = "file://%s" % ud.src_uri.solution
        for fetch_method in bb.fetch2.methods:
            if fetch_method.supports(FetchData(lockdown_url, d), d):
                local_fetch_method = fetch_method
                break
        return local_fetch_method.localpath(FetchData(lockdown_url, d), d)

    def fetch_solution_with_package_metadata(self):
        if self.ud.src_uri.switch:
            cmd = 'opam switch --root="%s" "%s"' % \
                    (self.native_sysroot_opamroot, self.ud.src_uri.switch)
            verbose_runfetchcmd(cmd, self.d)

        if self.ud.src_uri.solution is not None:
            self.ud.uri_solution_file = \
                OpamSolution.get_uri_solution_file(self.ud, self.d)

            debug_print("Using the opam solution file supplied by the recipe: %s" \
                       % self.ud.uri_solution_file)

            if not bb.utils.copyfile(self.ud.uri_solution_file, self.ud.dldir_solution):
                raise FetchError("Failed to copy opam solution from %s to %s" \
                                 % (self.ud.uri_solution_file, self.ud.dldir_solution))
        else:
            debug_print("Using opam to generate the install solution file")

            OpamSolution.generate_solution_file( \
                    self.native_sysroot_opamroot, self.ud.dldir_solution, \
                    self.ud.src_uri.name, self.ud.src_uri.version, self.d)

        solution_data = OpamSolution.query_packages_metadata( \
                    self.native_sysroot_opamroot, self.ud.dldir_solution, self.d)

        # rewrite the solution file to add the extra data.
        with open(self.ud.dldir_solution, 'w') as outfile:
            json.dump(solution_data, outfile, indent = 4)

    def get_package_version(self, package_name):
        with open(self.ud.dldir_solution) as json_data:
            solution_data = json.load(json_data)

        if not 'solution' in solution_data:
            debug_print("No solution found in the data file")
            raise FetchError('No solution found for install')

        for action in solution_data['solution']:
            package = action['install']
            if package['name'] == package_name:
                return package['version']
        raise FetchError("Could not determine package version for: %s" % package_name)


    def read_solution_data(self, dldir_solution):

        with open(dldir_solution) as json_data:
            solution_data = json.load(json_data)

        if not 'solution' in solution_data:
            raise FetchError('No solution found for install')

        packages = []
        for action in solution_data['solution']:
            packages.append(action['install'])

        debug_print("Obtaining all dependency URLs")

        urls = []
        url_to_first_package = {}

        for package in packages:
            # Prefer to use a URL from the solution file, if available
            if package.get('url'):
                url = package['url']
            else:
                url = None
                if not package.get('no-url'):
                    # URL is not found in the solution file, and there
                    # is not an explicit mark indicating that this package
                    # has no URL, so query opam.
                    dotted_name = "%s.%s" % (package['name'], package['version'])
                    debug_print("Querying: %s" % dotted_name)
                    cmd = '''opam show --root=%s --field=opam-file "%s"''' \
                          % (self.native_sysroot_opamroot, dotted_name)
                    opam_metadata = verbose_runfetchcmd(cmd, d)
                    url = get_url_from_opam_metadata(opam_metadata)
                    package['url'] = url

            if url is not None:
                url_filename = url.split("/")[-1]
                package['filename'] = package['name'] + \
                                      '.' + package['version'] + \
                                      '_' + url_filename

                if url not in url_to_first_package:
                    urls.append(url)
                    url_to_first_package[url] = package

        self.urls = dedupe(urls)

        self.annotated_urls = []
        for url in self.urls:
            package = url_to_first_package[url]
            url += ';%s=%s;%s=%s' % ('name', package['name'], \
                                     'downloadfilename', package['filename'])
            self.annotated_urls.append(url)

        self.packages = packages
        self.url_to_first_package = url_to_first_package

#---
class Opam(FetchMethod):

    def supports(self, ud, d):
        """
        Query: can this fetcher support the given URL
        """
        return ud.type in ['opam']

    def supports_checksum(self, ud):
        # Checksums are handled differently by the opam fetcher:
        # they are not written into the recipe file. Instead,
        # individual opam packages are specified in the solution file
        # along with their checksums.
        # Return False here to allow the recipe to be built without
        # checksums specified within the recipe.
        return False

    def recommends_checksum(self, ud):
        # Since the opam checksums are in the solution file, not
        # the recipe, we don't recommend the standard checksum
        # handling here. Return False.
        return False

    def urldata_init(self, ud, d):
        """
        Called in FetchData __init__ as fetcher state for a given URI is init'd.
        """
        debug_print("urldata_init: %s" % ud.url)

        m = __url_pattern__.match(ud.url)
        src_uri_name = m.group('src_uri_name')

        ud.src_uri = OpamSrcUri()
        ud.src_uri.name = src_uri_name

        options = get_uri_options(m.group('options'))
        debug_print("package: %s options: %s" % (src_uri_name, str(options)))
        ud.src_uri.version  = options.get('version')
        ud.src_uri.switch   = options.get('switch')
        ud.src_uri.repos    = options.get('repos')
        ud.src_uri.solution = options.get('solution')

        manifest_stem = d.expand("${PN}.${PV}.%s.%s" % \
                                 (src_uri_name, str(ud.src_uri.switch)))

        if ud.src_uri.solution is not None:
            ud.solution_json_filename = ud.src_uri.solution
        else:
            ud.solution_json_filename = manifest_stem + ".solution.json"

        solution_json_dir = d.expand("${DL_DIR}/opam")
        if not os.path.exists(solution_json_dir):
            bb.utils.mkdirhier(solution_json_dir)
        ud.dldir_solution = os.path.join(solution_json_dir, ud.solution_json_filename)
        debug_print("package: %s dldir_solution: %s" % (src_uri_name, ud.dldir_solution))
        # localpath is the path of the file used to determine whether the fetch
        # has been successful or not.
        ud.localpath = d.expand("${DL_DIR}/opam/%s.manifest" % \
                                manifest_stem)
        debug_print("package: %s localpath: %s" % (src_uri_name, ud.localpath))

        #ud.write_tarballs = ((d.getVar("BB_GENERATE_MIRROR_TARBALLS") or "0") != "0")
        #mirrortarball = 'opam_%s.tar.xz' % (ud.versioned_pkgname)
        #mirrortarball = mirrortarball.replace('/', '-')
        #ud.fullmirror = os.path.join(d.getVar("DL_DIR"), mirrortarball)

    def need_update(self, ud, d):
        """
        Force a fetch even if localpath exists?
        """
        # check that all the dependent downloads are present.
        solution = OpamSolution(ud, d)
        solution.fetch_solution_with_package_metadata()
        solution.read_solution_data(ud.dldir_solution)

        url_fetcher = bb.fetch2.Fetch(solution.annotated_urls, d)
        ret = False
        for url in solution.annotated_urls:
            url_ud = url_fetcher.ud[url]
            if url_ud.method.need_update(url_ud, d):
                ret = True
                break

        debug_print("need_update: %s" % str(ret))
        return ret

    def download(self, ud, d):
        """
        Fetch urls
        Assumes localpath was called first
        """
        debug_print("entering download")

        solution = OpamSolution(ud, d)
        solution.fetch_solution_with_package_metadata()
        solution.read_solution_data(ud.dldir_solution)

        # Write localpath first, so if we're interrupted,
        # clean will be able to read it and remove any downloads.
        with open(ud.localpath, 'w') as outfile:
            for url in solution.urls:
                package = solution.url_to_first_package[url]
                url_filename = package['filename']
                outfile.write("%s %s %s %s\n" % \
                    (package['name'], package['version'], \
                     package['url'],  url_filename))

        url_fetcher = bb.fetch2.Fetch(solution.annotated_urls, d)

        mod = {}
        if ud.ignore_checksums:
            logger.warning('Disabling checksum verification')
            for (annotated_url, value) in url_fetcher.ud.items():
                value.ignore_checksums = True
                mod[annotated_url] = value
        else:
            for (annotated_url, value) in url_fetcher.ud.items():
                url = annotated_url.split(';')[0]
                if solution.url_to_first_package.get(url):
                    package = solution.url_to_first_package[url]
                    if package.get('md5-checksum'):
                        value.md5_expected = package['md5-checksum']
                    else:
                        logger.warning( \
        'Missing md5-checksum in solution file for package %s at %s' % \
                                       (package['name'], url))
                mod[annotated_url] = value
        url_fetcher.ud = mod

        url_fetcher.download()

        return True

    def clean(self, ud, d):
        """
        Clean any existing full or partial download
        """
        debug_print("clean called for: %s" % ud.src_uri.name)

        # Delegate cleaning to the fetcher that is used for
        # retrieval. Read the manifest written by the download
        # method to produce annotated urls for the fetcher.
        annotated_urls = []
        with open(ud.localpath, 'r') as infile:
            for line in infile:
                (in_name, in_version, in_url, in_filename) = line.rstrip().split(' ')
                annotated_urls.append('%s;name=%s;downloadfilename=%s' % \
                    (in_url, in_name, in_filename))

        url_fetcher = bb.fetch2.Fetch(annotated_urls, d)

        for annotated_url in annotated_urls:
            debug_print("cleaning: %s" % annotated_url)
            url_ud = url_fetcher.ud[annotated_url]
            url_ud.method.clean(url_ud, d)

        bb.utils.remove(ud.localpath, recurse=False)

    def unpack(self, ud, destdir, d):
        debug_print("unpack for %s to %s" % (ud.src_uri.name, destdir))

        # It's possible to make the opam fetcher script pull bits directly from the
        # download directory, but: 
        #
        # * it's more intuitive to see what's going on if the downloaded files
        #   that are used by a recipe are visible within its build work directory
        #
        # * and it's cleaner to expose the recipe work directory rather than the
        #   shared download directory to the recipe environment.
        #
        # * since there are potentially a _lot_ of downloaded tarballs, use symlinks
        #   rather than copies for both speed and space advantage.
        #
        # so: symlink from the workdir to the downloaded files for the recipe.

        pkgfile = None
        pkgversion = None

        with open(ud.localpath, 'r') as infile:
            dl_dir = d.expand("${DL_DIR}")
            for row in infile.readlines():
                row = row.strip()
                (r_name, r_pkgversion, r_pkgurl, r_pkgfile) = row.split(' ')
                target = os.path.join(dl_dir, r_pkgfile)
                new_link = os.path.join(destdir, r_pkgfile)

                if os.path.islink(new_link):
                    if os.readlink(new_link) != target:
                        raise Exception("Unexpected symlink to wrong target found in workdir: %s" % new_link)
                else:
                    os.symlink(target, new_link)

                if r_name == ud.src_uri.name:
                    pkgfile = r_pkgfile
                    pkgversion = r_pkgversion

        target = os.path.join(destdir, 'download-manifest')
        if not bb.utils.copyfile(ud.localpath, target):
            raise Exception("Failed to copy download manifest to workdir")

        workdir_solution = d.expand("${WORKDIR}/%s" % ud.solution_json_filename)
        if not bb.utils.copyfile(ud.dldir_solution, workdir_solution):
            raise Exception("Failed to copy opam solution from %s to %s" \
                             % (ud.dldir_solution, workdir_solution))

        # FIXME: check the license extraction logic below:
        #        the concern is with multiple opam SRC_URIs (which is
        #        common for -cross-deps packages), will the last one
        #        listed as SRC_URI overwrite earlier license files?
        #        This looks fragile.

        # Extract the software license file from the package archive
        # to enable verification by OE.
        if pkgfile is not None:
            lic_files_chksum = d.expand("${LIC_FILES_CHKSUM}")
            if lic_files_chksum is not None:
                if lic_files_chksum[:7] == 'file://':
                    lic_filename = lic_files_chksum.split(';')[0][7:]
                    workdir_lic_filename = d.expand("${WORKDIR}/%s" % lic_filename)
                    if not os.path.exists(workdir_lic_filename):

                        import tarfile
                        t = tarfile.open(pkgfile, 'r')

                        mp_prefixed = os.path.join( \
                            ud.src_uri.name + '-' + pkgversion.translate(str.maketrans('+', '-')), \
                            lic_filename)
                        for member_path in [mp_prefixed, lic_filename]:
                            try:
                                if t.getmember(member_path):
                                    f = t.extractfile(member_path)
                                    lic_file_contents = f.read()
                                    bb.utils.mkdirhier(os.path.dirname(workdir_lic_filename))
                                    with open(workdir_lic_filename, 'wb') as outfile:
                                        outfile.write(lic_file_contents)
                                    break
                            except KeyError:
                                pass
