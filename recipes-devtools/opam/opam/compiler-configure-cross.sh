#!/bin/bash
#
# For a cross switch: configure needs to run differently
# in order to build for the target, not the build host.
#
# Copyright (c) 2018, BAE Systems
# Author: Christopher Clark

[ "x${OPAM_PACKAGE_NAME}" == "xocaml-base-compiler" ] || exit 0

[ "$CLASSOVERRIDE" == "class-cross" ] || exit 0

CONFIGURE_SCRIPT="${OPAM_SWITCH_PREFIX}/.opam-switch/build/${OPAM_PACKAGE_NAME}.${OPAM_PACKAGE_VERSION}/configure"

[ -e "${CONFIGURE_SCRIPT}" ] || exit 1

mv "${CONFIGURE_SCRIPT}" "${CONFIGURE_SCRIPT}.original"
cat >"${CONFIGURE_SCRIPT}" <<EOF
#!/bin/sh
exec "configure-ocaml-cross-compiler" "\$@"
EOF
chmod 755 "${CONFIGURE_SCRIPT}"
