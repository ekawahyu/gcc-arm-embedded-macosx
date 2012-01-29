# GNU Tools for ARM Embedded Processors (Mac OS X version)

This is a wrapper script that knows how to patch and build the
ARM-maintained toolchain for the ARM Cortex-M and Cortex-R processors.

Prerequisites:
* Mac OS X 10.6 (Snow Leopard) or later.
* Xcode
* The p7zip archiver.  You can install this via Homebrew or MacPorts.

ARM host the toolchain at https://launchpad.net/gcc-arm-embedded and
you will need to download the distribution archives yourself.  Place
them in the same directory as the build-macosx.sh script and run it.

Unlike other toolchain distributions, this one includes all of the 
prerequisites, so it is not necessary to go chasing around after
the various libraries that gcc normally requires.
