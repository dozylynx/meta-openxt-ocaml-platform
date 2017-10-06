#!/bin/bash
#
# Change the linker used by ocaml tools in the native switch.
# See opam-native-switch-tools-native recipe.
#
# Copyright (c) 2018, BAE Systems
# Author: Christopher Clark

[ "x${OPAM_PACKAGE_NAME}" == "xocaml-base-compiler" ] || exit 0

[ "x$CLASSOVERRIDE" == "xclass-native" ] || exit 0

CONFIGURE_SCRIPT="${OPAM_SWITCH_PREFIX}/.opam-switch/build/${OPAM_PACKAGE_NAME}.${OPAM_PACKAGE_VERSION}/configure"

[ -e "${CONFIGURE_SCRIPT}" ] || exit 1

sed -e 's/^partialld="ld -r"$/partialld="oe-opam-ld-native -r"/' \
    -i'' "${CONFIGURE_SCRIPT}"
