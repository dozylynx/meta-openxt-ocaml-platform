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
 (?P<pkgname>\S+?)          # Package name
 (;(?P<options>(\S)+))*     # URI suffix with other arguments
 $
''', re.VERBOSE)

def dedupe(seq):
    seen = set()
    seen_add = seen.add
    return [x for x in seq if not (x in seen or seen_add(x))]

#---
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


#---
class Opam(FetchMethod):

    def supports(self, ud, d):
        return ud.type in ['opam']

    def supports_checksum(self, ud):
        # FIXME: need to implement this to have the donestamp method work.
        return False

    def recommends_checksum(self, ud):
        # FIXME: implement this
        return False

    def clean(self, ud, d):
        self.debug("clean called for: %s" % ud.pkgname)
        bb.utils.remove(ud.localpath, recurse=False)
        # FIXME:
        #bb.utils.remove(ud.dldir_solution, recurse=False)
        #bb.utils.remove(ud.pkgdatadir, recurse=True)
        #bb.utils.remove(ud.fullmirror, recurse=False)

    def need_update(self, ud, d):
        return not os.path.exists(ud.localpath)

    def debug(self, msg):
        #logger.debug(1, "OpamFetch: %s", msg)
        #logger.warning("OpamFetch: %s", msg)
        pass

    # FIXME: remove this and all call sites:
    def devel_debug(self, msg):
        #logger.warning("BANANA: %s", msg)
        pass

    def _get_uri_options(self, raw):
        if raw is None:
            return {}
        ret = {}
        for opt in raw.split(';'):
            (key, value) = opt.split('=')
            ret[key] = value
        return ret

    def urldata_init(self, ud, d):
        self.debug("urldata_init: %s" % ud.url)

        m = __url_pattern__.match(ud.url)
        pkgname = m.group('pkgname')
        ud.pkgname = pkgname
        options = self._get_uri_options(m.group('options'))
        ud.options = options
        self.debug("package: %s options: %s" % (pkgname, str(options)))

        ud.uri_solution_filename = options.get('solution')

        # Some of the urldata fields depend upon the version of the package, but
        # the version may not be known until after the opam solution has been generated.
        # If so, use generic 'opam' as version for these fields.
        if 'version' in options:
            ud.early_version = options['version']
        else:
            # FIXME: read the solution file, if one is present, to get the version
            ud.early_version = 'opam'

        ud.early_versioned_pkgname = pkgname + '-' + ud.early_version

        if ud.uri_solution_filename is not None:
            ud.solution_json_name = ud.uri_solution_filename
        else:
            ud.solution_json_name = "%s.%s.solution.json" % (pkgname, ud.early_version)
            ud.solution_json_name = ud.solution_json_name.replace('/', '-')

        ud.opam_manifest = "%s.download.manifest" % (ud.early_versioned_pkgname)
        ud.opam_manifest = ud.opam_manifest.replace('/', '-')

        # localpath is the path of the file used to determine whether the fetch
        # has been successful or not.
        ud.localpath = d.expand("${DL_DIR}/opam/%s" % ud.opam_manifest)
        self.debug("package: %s localpath: %s" % (pkgname, ud.localpath))

        prefixdir = "opam/%s" % ud.pkgname
        ud.pkgdatadir = d.expand("${DL_DIR}/%s" % prefixdir)
        if not os.path.exists(ud.pkgdatadir):
            bb.utils.mkdirhier(ud.pkgdatadir)
        self.debug("package: %s pkgdatadir: %s" % (pkgname, ud.pkgdatadir))

        ud.dldir_solution = os.path.join(ud.pkgdatadir, ud.solution_json_name)
        self.debug("package: %s dldir_solution: %s" % (pkgname, ud.dldir_solution))

        #ud.write_tarballs = ((d.getVar("BB_GENERATE_MIRROR_TARBALLS") or "0") != "0")
        #mirrortarball = 'opam_%s.tar.xz' % (ud.early_versioned_pkgname)
        #mirrortarball = mirrortarball.replace('/', '-')
        #ud.fullmirror = os.path.join(d.getVar("DL_DIR"), mirrortarball)

    def _run_solution_command(self, opamroot, dldir_solution, pkgname, options, d):
        self.debug("_run_solution_command")

        versioned_pkgname = pkgname
        if 'version' in options:
            versioned_pkgname += "." + options['version']
        cmd = 'opam install --root="%s" --dry-run --json="%s" "%s" --yes' % \
            (opamroot, dldir_solution, versioned_pkgname)
        self.debug(cmd)
        try:
            runfetchcmd(cmd, d)
        except FetchError as e:
            self.debug("Semi-expected solution error") #: %s" % str(e))
            # Note that this usually returns a failure, even when it succeeds,
            # because opam's "dry-run" support is currently rough.
            # Typically says: command not found.
            pass

    def _enhance_solution_metadata(self, opamroot, dldir_solution, d):
        self.devel_debug("_enhance_solution_metadata")
        with open(dldir_solution) as json_data:
            solution_data = json.load(json_data)

        if not 'solution' in solution_data:
            self.debug("No solution found in the data file")
            raise FetchError('No solution found for install')

        packages = []
        for action in solution_data['solution']:
            packages.append(action['install'])

        self.debug("Checking solution for source URL, checksum and license data")

        for package in packages:
            if package.get('url') and \
               package.get('md5-checksum') and \
               package.get('license'):
                continue

            dotted_name = "%s.%s" % (package['name'], package['version'])
            self.debug("Querying opam for: %s" % dotted_name)
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

        solution_data['solution'] = list( \
            map(lambda x: {"install": x }, packages) )

        # rewrite the solution file to add the extra data.
        with open(dldir_solution, 'w') as outfile:
            json.dump(solution_data, outfile, indent = 4)


    def _resolve_uri_solution_file(self, ud, d):
        lockdown_url = "file://%s" % ud.uri_solution_filename
        for m in bb.fetch2.methods:
            if m.supports(FetchData(lockdown_url, d), d):
                my_local = m
                break
        ud.uri_solution_file = my_local.localpath(FetchData(lockdown_url, d), d)


    def _fetch_solution(self, ud, native_sysroot_opamroot, d):

        if 'switch' in ud.options:
            cmd = 'opam switch --root="%s" "%s"' % (native_sysroot_opamroot, ud.options['switch'])
            self.debug(cmd)
            runfetchcmd(cmd, d)

        if ud.options.get('solution') is not None:
            self._resolve_uri_solution_file(ud, d)

            self.debug("Using the opam solution file supplied by the recipe: %s" \
                       % ud.uri_solution_file)
            if not bb.utils.copyfile(ud.uri_solution_file, ud.dldir_solution):
                raise FetchError("Failed to copy opam solution from %s to %s" \
                                 % (ud.uri_solution_file, ud.dldir_solution))
        else:
            self.debug("Using opam to generate the install solution file")
            self._run_solution_command(native_sysroot_opamroot, ud.dldir_solution, ud.pkgname, ud.options, d)
        self._enhance_solution_metadata(native_sysroot_opamroot, ud.dldir_solution, d)

    def _read_solution_data(self, dldir_solution, native_sysroot_opamroot, d):

        with open(dldir_solution) as json_data:
            solution_data = json.load(json_data)

        if not 'solution' in solution_data:
            raise FetchError('No solution found for install')

        packages = []
        for action in solution_data['solution']:
            packages.append(action['install'])

        self.debug("Obtaining all dependency URLs")

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
                    self.debug("Querying: %s" % dotted_name)
                    cmd = '''opam show --root=%s --field=opam-file "%s"''' \
                          % (native_sysroot_opamroot, dotted_name)
                    self.devel_debug(cmd)
                    opam_metadata = runfetchcmd(cmd, d)
                    url = get_url_from_opam_metadata(opam_metadata)
                    package['url'] = url

            if url is not None:
                url_filename = url.split("/")[-1]
                package['filename'] = package['name'] + '.' + package['version'] + '_' + url_filename

                if url not in url_to_first_package:
                    urls.append(url)
                    url_to_first_package[url] = package

        urls = dedupe(urls)
        return (packages, urls, url_to_first_package)

    def download(self, ud, d):
        self.debug("entering download")
        pkgname = ud.pkgname
        options = ud.options

        recipe_sysroot_native = d.getVar('RECIPE_SYSROOT_NATIVE')
        if not os.path.exists(recipe_sysroot_native):
            raise Exception("native sysroot is required for the opam fetch method: inherit opam?")
        datadir_native = d.getVar('datadir_native')
        native_sysroot_opamroot = os.path.join( recipe_sysroot_native + datadir_native, 'ocaml', 'opam-root')

        self._fetch_solution(ud, native_sysroot_opamroot, d)

        (packages, urls, url_to_first_package) = self._read_solution_data(ud.dldir_solution, native_sysroot_opamroot, d)

        annotated_urls = []
        for url in urls:
            package = url_to_first_package[url]
            url += ';%s=%s;%s=%s' % ('name', package['name'], \
                                     'downloadfilename', package['filename'])
            annotated_urls.append(url)

        self.devel_debug("sierra: pre fetcher")
        f = bb.fetch2.Fetch(annotated_urls, d)
        self.devel_debug("sierra: post fetcher")

        mod = {}
        if ud.ignore_checksums:
            logger.warning('Disabling checksum verification')
            # Disable checksum verification for each package
            for (annotated_url, value) in f.ud.items():
                value.ignore_checksums = True
                mod[annotated_url] = value
        else:
            # Supply individual checksums for download verification
            for (annotated_url, value) in f.ud.items():
                url = annotated_url.split(';')[0]
                if url_to_first_package.get(url):
                    package = url_to_first_package[url]
                    if package.get('md5-checksum'):
                        value.md5_expected = package['md5-checksum']
                    else:
                        logger.warning('Missing md5-checksum in solution file for package %s at %s' % \
                                       (package['name'], url))
                mod[annotated_url] = value
        f.ud = mod

        ##################
        # PERFORM DOWNLOAD
        f.download()
        ##################

        with open(ud.localpath, 'w') as outfile:
            for url in urls:
                package = url_to_first_package[url]
                url_filename = package['filename']
                outfile.write("%s %s %s %s\n" % \
                    (package['name'], package['version'], package['url'], url_filename))

        return True

    def unpack(self, ud, destdir, d):
        self.debug("unpack for %s to %s" % (ud.pkgname, destdir))

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
                (r_pkgname, r_pkgversion, r_pkgurl, r_pkgfile) = row.split(' ')
                target = os.path.join(dl_dir, r_pkgfile)
                new_link = os.path.join(destdir, r_pkgfile)

                if os.path.islink(new_link):
                    if os.readlink(new_link) != target:
                        raise Exception("Unexpected symlink to wrong target found in workdir: %s" % new_link)
                else:
                    os.symlink(target, new_link)

                if r_pkgname == ud.pkgname:
                    pkgfile = r_pkgfile
                    pkgversion = r_pkgversion

        target = os.path.join(destdir, 'download-manifest')
        if not bb.utils.copyfile(ud.localpath, target):
            raise Exception("Failed to copy download manifest to workdir")

        workdir_solution = d.expand("${WORKDIR}/%s" % ud.solution_json_name)
        if not bb.utils.copyfile(ud.dldir_solution, workdir_solution):
            raise Exception("Failed to copy opam solution from %s to %s" \
                             % (ud.dldir_solution, workdir_solution))

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
                            ud.pkgname + '-' + pkgversion.translate(str.maketrans('+', '-')), \
                            lic_filename)
                        for member_path in [mp_prefixed, lic_filename]:
                            if t.getmember(member_path):
                                f = t.extractfile(member_path)
                                lic_file_contents = f.read()
                                with open(workdir_lic_filename, 'wb') as outfile:
                                    outfile.write(lic_file_contents)
                                break
