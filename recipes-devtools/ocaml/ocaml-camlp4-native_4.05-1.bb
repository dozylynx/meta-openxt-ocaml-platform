SRC_URI = "https://github.com/ocaml/camlp4/archive/4.05+1.tar.gz"
SRC_URI[md5sum] = "c69d1c2aebf231ea98e7464f020cffc4"
SRC_URI[sha256sum] = "9819b5c7a5c1a4854be18020ef312bfec6541e26c798a5c863be875bfd7e8e2b"

DEPENDS = "ocaml-native ocaml-ocamlbuild-native"

inherit native ocaml
require ocaml-camlp4.inc
