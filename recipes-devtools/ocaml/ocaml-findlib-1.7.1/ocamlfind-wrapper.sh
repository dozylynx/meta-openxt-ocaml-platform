#!/bin/bash
#
# Wrapper to generate a default findlib.conf before invoking ocamlfind.
# Calculates path and dest variables.

EXECUTABLE_DIR=$(dirname $0)

[ -z "${OCAMLFIND_CONF}" ] || exec ${EXECUTABLE_DIR}/ocamlfind.binary "$@"

TEMPORARY_OCAMLFIND_CONF="$(mktemp tmp-findlib.conf.XXXXX)"
echo "destdir=\"${OCAMLFIND_DEST}\""     >"${TEMPORARY_OCAMLFIND_CONF}"
echo "path=\"${OCAMLFIND_PATH}\""       >>"${TEMPORARY_OCAMLFIND_CONF}"

export OCAMLFIND_CONF="${TEMPORARY_OCAMLFIND_CONF}"
${EXECUTABLE_DIR}/ocamlfind.binary "$@"
RET=$?
rm -f "${TEMPORARY_OCAMLFIND_CONF}" >/dev/null 2>/dev/null
exit ${RET}
