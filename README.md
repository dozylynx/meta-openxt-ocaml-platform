# Opam integration research

This is an experimental branch investigating integration of Opam, the OCaml package manager, into OpenEmbedded. Enables writing OE recipes for building OCaml software via opam.

Cross-compilation support is currently incomplete, so setting both host and target as x86-64 is recommended.

--
Christopher Clark
22nd August 2018

# Build instructions

Obtain the source:

	git clone git://git.yoctoproject.org/poky
	cd poky
	git checkout sumo
	
	git clone git://github.com/dozylynx/meta-openxt-ocaml-platform
	cd meta-openxt-ocaml-platform
	git checkout sumo-opam-integration
	cd ..
	
	git clone git://github.com/dozylynx/meta-ocaml-apps
	cd meta-ocaml-apps
	git checkout sumo
	cd ..

Add lines for the layers to the config files here, substituting with correct full directory path:
	
	source oe-init-build-env
	
	EDITOR="vim"  # set whatever your preference is
	$EDITOR conf/bblayers.conf
 
 	 # insert the extra layer lines into the definition of BBLAYERS:

	  << full path here >> /poky/meta-openxt-ocaml-platform \
	  << full path here >> /poky/meta-ocaml-apps \
	
	 # save and exit
	
	$EDITOR conf/local.conf
	
	 # Change the MACHINE line:
	MACHINE = "genericx86-64"
	
	 # save and exit

 Optional step : prepopulate a downloads directory with tarballs, if you already have stuff; could also set up using a mirror.
 
Now run the build:
	
	 # This needs to be run in the same shell where you previously ran "source oe-init-build-env":
	bitbake vhd-tool vhd-tool-native mirage mirage-native
	
	 # build output is in:
	
	tmp/work/*/vhd-tool/*/
	tmp/work/*/vhd-tool-native/*/
	tmp/work/*/mirage/*/
	tmp/work/*/mirage-native/*/
	
	 # if you want to force a clean rebuild of a recipe, eg vhd-tool:
	
	bitbake -c cleansstate vhd-tool && bitbake vhd-tool
	
