# GNU Tools for ARM Embedded Processors (Mac OS X version)

This is a wrapper script that knows how to patch and build the
ARM-maintained toolchain for the ARM Cortex-M and Cortex-R processors.

Prerequisites:

* Mac OS X 10.6 (Snow Leopard) or later.
* Xcode (Snow Leopard) or command line tools install (Lion and Mountain Lion).
* Unix tools: autoconf automake via Homebrew or MacPorts.

ARM host the toolchain at https://launchpad.net/gcc-arm-embedded and
you will need to download the distribution archives yourself.  Place
them in the same directory as the build-macosx.sh script and run it.

Unlike other toolchain distributions, this one includes all of the 
prerequisites, so it is not necessary to go chasing around after
the various libraries that gcc normally requires.

Update: added build script for linux, namely build-linux.sh

Update:

* Linux build for 2013q1
* On a bare Debian Wheezy builds with the following packages: bison build-essential debhelper flex gettext libncurses5-dev texlive texinfo
* To build native gcc, you will also need: libgmp-dev libmpfr-dev libmpc-dev (libgmp3-dev gcc-multilib)
