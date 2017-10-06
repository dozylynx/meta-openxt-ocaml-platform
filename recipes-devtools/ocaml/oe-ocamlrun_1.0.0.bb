DESCRIPTION = "Tool to assist hashbang OCaml in OE native environment"
LICENSE = "MIT"
LIC_FILES_CHKSUM="file://LICENSE;md5=2e7f3427ab08fda49476f7eec09fe84c"

# OEocamlrun tool
# Written by; Christopher Clark, October 2017.
# Copyright (c) 2017, BAE Systems.
#
# ----------
# Background:
#
# One form of the output from the OCaml compiler is a bytecode file
# with a hashbang line pointing to the absolute filesystem path of the
# OCaml bytecode interpreter, ocamlrun.
#
# Hashbang lines have a maximum line length of 128 characters on Linux.
# Any characters after that are ignored, usually resulting in a failure
# to run with "Bad interpreter".
#
# OpenEmbedded produces recipe-specific sysroots to supply the build
# environment for each recipe. This means that tools used to build are
# at different filesystem locations for building each recipe. The
# filesystem location of the tools can be nested several directories
# deep below the top of the OE build root.
#
# Ocaml's OPAM package management tool provides a "switch" function for enabling
# simultaneous installation of multiple compiler toolchains.
#
# In an OpenEmbedded build environment, bytecode produced by a given switch
# compiler will by default contain a hashbang line pointing to that switch's
# ocamlrun interpreter in the native sysroot of the recipe that compiled it.
#
# ---------
# This tool:
#
# This tool locates and executes the ocamlrun interpreter for a specified OPAM
# switch within the currently-active native sysroot.
# It is expected to be available within the PATH.
#
# The switch is identified by the last argument to this tool: the reason for
# this less-conventional use of positional argument is to fit the code to call
# it within the length limit of a hashbang line.
#
# The bytecode compiler in each switch is modified to insert a non-default hashbang
# line into the output it produces, which:
#
# * Queries for the presence of this tool, OEocamlrun, in the PATH, and if found,
#   invokes it passing all the arguments to the command, plus a tag identifying
#   the switch that contains the ocamlrun interpreter to use.
#
# * If OEocamlrun is not found, then it just invokes the ocamlrun found in the
#   PATH, if any, without supplying the final switch-identifier argument.
#   This is to make the compiler output portable outside of the OE native
#   environment.
#
# Here is an example hashbang line, requesting the "4.00.1" switch:
# ---
#!/usr/bin/awk {for(i=1;i<ARGC;){t=t" "ARGV[i++]}q="ocamlrun";p=q t;exit system(system("OE"q" 2>/dev/null")?p:"OE"p" 4.00.1")}
# ---

BBCLASSEXTEND = "native"

SRC_URI = "file://OEocamlrun file://LICENSE"
S = "${WORKDIR}"

FILESEXTRAPATHS_prepend := "${THISDIR}/oe-ocamlrun:"

BBCLASSEXTEND = "native"

do_install() {
    mkdir -p "${D}${bindir}"
    install -m 755 "${S}/OEocamlrun" "${D}${bindir}/OEocamlrun"
}
