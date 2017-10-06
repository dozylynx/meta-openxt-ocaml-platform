#!/bin/bash
#
# Script to configure patches from the recipe being built to
# be applied during the compilation driven by opam.
#
# Copyright (c) 2017, BAE Systems
# Author: Christopher Clark

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
    PACKAGE="$(echo "$APPLY_TO" | cut -f1 -d'.')"
    VERSION="$(echo "$APPLY_TO" | cut -f2- -d'.')"

    if [ "x${OPAM_PACKAGE_NAME}" = "x${PACKAGE}" ] &&
       [ "x${OPAM_PACKAGE_VERSION}" = "x${VERSION}" ]
    then
        # Note that we only apply the patch to the unpacked source in the
        # build directory.
        # Unfortunately the unpacked source in the sources directory does
        # not seem to have consistent directory naming, so we leave it alone.
        PATCH_DIR="${OPAM_SWITCH_PREFIX}/.opam-switch/build/${OPAM_PACKAGE_NAME}.${OPAM_PACKAGE_VERSION}/"
        set -e
        cd "$PATCH_DIR"
        patch -p1 <"$OE_OPAMFETCH_DIR/$OBJECT"
    fi
done
