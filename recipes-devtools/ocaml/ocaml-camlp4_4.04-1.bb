SRC_URI[md5sum] = "305f61ffd98c4c03eb0d9b7749897e59"
SRC_URI[sha256sum] = "6044f24a44053684d1260f19387e59359f59b0605cdbf7295e1de42783e48ff1"
SRC_URI = "https://github.com/ocaml/camlp4/archive/4.04+1.tar.gz"
DEPENDS = "ocaml-ocamlbuild ocaml-cross"

require ocaml-camlp4.inc

inherit cross
