#!/bin/bash
#
# An opam32 switch is built to run native, to produce output that will
# run native, but the output needs to be for a 32-bit architecture.
# This is to support cross compiling for 32-bit targets on 64-bit hosts,
# since a native 32-bit ocamlrun tool is needed to execute bytecode that
# has been compiled 32-bit to match the target system.
#
# Copyright (c) 2017-2018, BAE Systems
# Author: Christopher Clark

[ "x${OPAM_PACKAGE_NAME}" == "xocaml-base-compiler" ] || exit 0

[ "$CLASSOVERRIDE" == "class-opam32-native" ] || exit 0

CONFIGURE_SCRIPT="${OPAM_SWITCH_PREFIX}/.opam-switch/build/${OPAM_PACKAGE_NAME}.${OPAM_PACKAGE_VERSION}/configure"
[ -e "${CONFIGURE_SCRIPT}" ] || exit 1

MAKEFILE="${OPAM_SWITCH_PREFIX}/.opam-switch/build/${OPAM_PACKAGE_NAME}.${OPAM_PACKAGE_VERSION}/Makefile"

mv "${CONFIGURE_SCRIPT}" "${CONFIGURE_SCRIPT}.original"

# FIXME: remove the hardcoded i686 from below

cat >"${CONFIGURE_SCRIPT}" <<EOF
#!/bin/bash
"${CONFIGURE_SCRIPT}.original" \
     "\$@" \
     -target i686-opam32-linux \
     -target-bindir nonsense \
     -mksharedlib "i686-opam32-linux-gcc -shared"

sed 's/world.opt/oldworld.opt/' -i ${MAKEFILE}
sed 's/^world:/world.opt:/' -i ${MAKEFILE}
EOF
chmod 755 "${CONFIGURE_SCRIPT}"
