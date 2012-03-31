#!/bin/bash
#
# Copyright (c) 2012 Michael Smith
# All Rights Reserved
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

set -e

#
# Distribution archive name (without the chunk suffix)
#
distribution=arm-none-eabi-gcc-4_6-20111208

#
# Establish the location of the distribution archives and make a working
# directory.  Set up some more directory names
#
base_dir=`pwd -P`
src_dir=$base_dir/$distribution/src

#
# Check for the source files
#
if [ ! -r $base_dir/$distribution-src.7z.001 ]; then
	echo ""
	echo "  Can't find the distribution files for $distribution"
	echo "  (looked in the current directory only)"
	echo "  They can be downloaded from https://launchpad.net/gcc-arm-embedded"
	echo ""
	exit 1
fi

#
# Unpack the distribution
#
sevenzip=`which 7z` || true
if [ -z $sevenzip ]; then
	echo ""
	echo "  Install the p7zip unpacker and try again."
	echo "  (for Homebrew users, 'brew install p7zip' will be sufficient)"
	echo ""
	exit 1
fi
$sevenzip -y x $base_dir/$distribution-src.7z.001
echo "Unpacking distribution archive..."
tar xzU -f $distribution-src.tar.bz2

#
# Unpack individual source archives
#
for archive in $src_dir/*.tar.*; do
	echo "Unpacking $archive..."
	tar xzU -C $src_dir -f $archive 
done

#
# Do pre-build fixups
#
echo "Doing pre-build fixups..."

# Cloog
pushd $src_dir/cloog-ppl-0.15.11
patch <<-'EOF'
	--- autogen.sh~	2009-05-09 03:57:18.000000000 -0700
	+++ autogen.sh	2012-01-26 22:07:50.000000000 -0800
	@@ -1,5 +1,5 @@
	 #!/bin/sh
	-libtoolize -c --force
	+glibtoolize -c --force
	 aclocal
	 automake -a -c --foreign
	 autoconf
EOF
sh ./autogen.sh
popd

# zlib
pushd $src_dir/zlib-1.2.5
patch < ../zlib-1.2.5.patch
popd

#
# Patch the build scripts
#
echo "Patching the build scripts..."
pushd $base_dir/$distribution
patch <<-'EOF'
	--- ../build-common.sh	2011-12-07 08:56:12.000000000 -0800
	+++ ./build-common.sh	2012-01-27 20:08:13.000000000 -0800
	@@ -196,9 +196,9 @@
	 ROOT=`pwd`
	 SRCDIR=$ROOT/src
	 
	-BUILDDIR_LINUX=$ROOT/build-linux
	+BUILDDIR_LINUX=$ROOT/build-macosx
	 BUILDDIR_MINGW=$ROOT/build-mingw
	-INSTALLDIR_LINUX=$ROOT/install-linux
	+INSTALLDIR_LINUX=$ROOT/install-macosx
	 INSTALLDIR_MINGW=$ROOT/install-mingw
	 
	 PACKAGEDIR=$ROOT/pkg
	@@ -238,10 +238,10 @@
	 LICENSE_FILE=license.txt
	 GCC_VER=`cat $SRCDIR/$GCC/gcc/BASE-VER`
	 GCC_VER_NAME=`echo $GCC_VER | cut -d'.' -f1,2 | sed -e 's/\./_/g'`
	-JOBS=`grep ^processor /proc/cpuinfo|wc -l`
	+JOBS=`sysctl -n hw.ncpu`
	 
	-BUILD=i686-linux-gnu
	-HOST_LINUX=i686-linux-gnu
	+BUILD=x86_64-apple-darwin10
	+HOST_LINUX=x86_64-apple-darwin10
	 HOST_MINGW=i586-mingw32
	 HOST_MINGW_TOOL=i586-mingw32msvc
	 TARGET=arm-none-eabi
EOF
patch <<-'EOF'
	--- ../build-prerequisites.sh	2011-12-07 08:56:12.000000000 -0800
	+++ ./build-prerequisites.sh	2012-01-27 20:33:15.000000000 -0800
	@@ -35,7 +35,7 @@
	 
	 exec < /dev/null
	 
	-script_path=`dirname $(readlink -f $0)`
	+script_path=`cd $(dirname $0) && pwd -P`
	 . $script_path/build-common.sh
	 
	 # This file contains the sequence of commands used to build the prerequisites
	@@ -49,7 +49,11 @@
	 if [ $# -gt 1 ] ; then
	     usage
	 fi
	-skip_mingw32=no
	+if [ `uname` == Darwin ]; then
	+    skip_mingw32=yes
	+else
	+    skip_mingw32=no
	+fi
	 for ac_arg; do
	     case $ac_arg in
	         --skip_mingw32)
EOF
patch <<-'EOF'
	--- ../build-toolchain.sh	2011-12-07 08:56:12.000000000 -0800
	+++ ./build-toolchain.sh	2012-01-27 21:08:15.000000000 -0800
	@@ -35,7 +35,7 @@
	 
	 exec < /dev/null
	 
	-script_path=`dirname $(readlink -f $0)`
	+script_path=`cd $(dirname $0) && pwd -P`
	 . $script_path/build-common.sh
	 
	 # This file contains the sequence of commands used to build the ARM EABI toolchain.
	@@ -48,7 +48,11 @@
	 if [ $# -gt 2 ] ; then
	     usage
	 fi
	-skip_mingw32=no
	+if [ `uname` == Darwin ]; then
	+    skip_mingw32=yes
	+else
	+    skip_mingw32=no
	+fi
	 DEBUG_BUILD_OPTIONS=no
	 for ac_arg; do
	     case $ac_arg in
	@@ -95,7 +99,8 @@
	     make -j$JOBS
	 fi
	 
	-make htmldir=$INSTALLDIR_LINUX/share/doc/html pdfdir=$INSTALLDIR_LINUX/share/doc/pdf infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install install-html install-pdf
	+make infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install
	+
	 restoreenv
	 popd
	 
	@@ -132,20 +137,20 @@
	     --with-ppl=$BUILDDIR_LINUX/host-libs/usr \
	     --with-cloog=$BUILDDIR_LINUX/host-libs/usr \
	     --with-libelf=$BUILDDIR_LINUX/host-libs/usr \
	-    "--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm" \
	+    "--with-host-libstdcxx=-lstdc++" \
	     "--with-pkgversion=$PKGVERSION" \
	     --with-extra-multilibs=armv6-m,armv7-m,armv7e-m,armv7-r
	 
	 make -j$JOBS all-gcc
	 
	-make htmldir=$INSTALLDIR_LINUX/share/doc/html pdfdir=$INSTALLDIR_LINUX/share/doc/pdf infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install-gcc
	+make infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install-gcc
	 
	 popd
	 
	 pushd $INSTALLDIR_LINUX
	 rm -rf bin/arm-none-eabi-gccbug
	 rm -rf ./lib/libiberty.a
	-rmdir include
	+test -d include && rmdir include
	 popd
	 
	 echo Task [1-10] /$HOST_LINUX/newlib/
	@@ -164,25 +169,16 @@
	     --disable-newlib-supplied-syscalls \
	     --disable-nls
	 
	-make -j$JOBS
	-
	-make htmldir=$INSTALLDIR_LINUX/share/doc/html pdfdir=$INSTALLDIR_LINUX/share/doc/pdf infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install
	+make -j$JOBS 
	 
	-make pdf
	-mkdir -p $INSTALLDIR_LINUX/share/doc/pdf
	-cp $BUILDDIR_LINUX/newlib/arm-none-eabi/newlib/libc/libc.pdf $INSTALLDIR_LINUX/share/doc/pdf/libc.pdf
	-cp $BUILDDIR_LINUX/newlib/arm-none-eabi/newlib/libm/libm.pdf $INSTALLDIR_LINUX/share/doc/pdf/libm.pdf
	-
	-make html
	-mkdir -p $INSTALLDIR_LINUX/share/doc/html
	-copy_dir $BUILDDIR_LINUX/newlib/arm-none-eabi/newlib/libc/libc.html $INSTALLDIR_LINUX/share/doc/html/libc
	-copy_dir $BUILDDIR_LINUX/newlib/arm-none-eabi/newlib/libm/libm.html $INSTALLDIR_LINUX/share/doc/html/libm
	+make infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install
	 
	 popd
	 restoreenv
	 
	 echo Task [1-11] /$HOST_LINUX/gcc-final/
	 rm -f $INSTALLDIR_LINUX/arm-none-eabi/usr
	+mkdir -p $INSTALLDIR_LINUX/arm-none-eabi
	 ln -s . $INSTALLDIR_LINUX/arm-none-eabi/usr
	 
	 rm -rf $BUILDDIR_LINUX/gcc-final && mkdir -p $BUILDDIR_LINUX/gcc-final
	@@ -214,7 +210,7 @@
	     --with-ppl=$BUILDDIR_LINUX/host-libs/usr \
	     --with-cloog=$BUILDDIR_LINUX/host-libs/usr \
	     --with-libelf=$BUILDDIR_LINUX/host-libs/usr \
	-    "--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm" \
	+    "--with-host-libstdcxx=-lstdc++" \
	     "--with-pkgversion=$PKGVERSION" \
	     --with-extra-multilibs=armv6-m,armv7-m,armv7e-m,armv7-r
	 
	@@ -224,7 +220,7 @@
	     make -j$JOBS
	 fi
	 
	-make htmldir=$INSTALLDIR_LINUX/share/doc/html pdfdir=$INSTALLDIR_LINUX/share/doc/pdf infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install install-html install-pdf
	+make htmldir=$INSTALLDIR_LINUX/share/doc/html pdfdir=$INSTALLDIR_LINUX/share/doc/pdf infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install
	 
	 pushd $INSTALLDIR_LINUX
	 rm -rf bin/arm-none-eabi-gccbug
	@@ -233,7 +229,7 @@
	     rm -rf $libiberty_lib
	 done
	 rm -rf ./lib/libiberty.a
	-rmdir include
	+test -d include && rmdir include
	 popd
	 
	 rm -f $INSTALLDIR_LINUX/arm-none-eabi/usr
	@@ -263,7 +259,8 @@
	     make -j$JOBS
	 fi
	 
	-make htmldir=$INSTALLDIR_LINUX/share/doc/html pdfdir=$INSTALLDIR_LINUX/share/doc/pdf infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install install-html install-pdf
	+make infodir=$INSTALLDIR_LINUX/share/doc/info mandir=$INSTALLDIR_LINUX/share/doc/man install
	+
	 restoreenv
	 popd
	 
	@@ -322,8 +319,6 @@
	 cp $ROOT/$LICENSE_FILE $INSTALLDIR_LINUX/
	 ln -s $INSTALLDIR_LINUX $INSTALL_PACKAGE_NAME
	 tar cjf $PACKAGEDIR/$PACKAGE_NAME.tar.bz2   \
	-    --owner=0                               \
	-    --group=0                               \
	     --exclude=host-$HOST_LINUX              \
	     --exclude=host-$HOST_MINGW              \
	     $INSTALL_PACKAGE_NAME/arm-none-eabi     \
	@@ -334,9 +329,15 @@
	     $INSTALL_PACKAGE_NAME/$RELEASE_FILE     \
	     $INSTALL_PACKAGE_NAME/$README_FILE      \
	     $INSTALL_PACKAGE_NAME/$LICENSE_FILE
	+
	 rm -f $INSTALL_PACKAGE_NAME
	 popd
	 
	+if [ `uname` == Darwin ]; then
	+    # no need to repackage the sources
	+    exit 0
	+fi
	+
	 # skip building mingw32 toolchain if "--skip_mingw32" specified
	 # this huge if statement controls all $BUILDDIR_MINGW tasks till "task [3-1]"
	 if [ "x$skip_mingw32" != "xyes" ] ; then
EOF
patch <<-'EOF'
	--- ../readme.txt	2011-12-21 18:21:58.000000000 -0800
	+++ ./readme.txt	2012-01-27 22:03:35.000000000 -0800
	@@ -1,34 +1,27 @@
	 GNU Tools for ARM Embedded Processors
	 
	 Table of Contents
	-* Installing executables on Linux
	-* Installing executables on Windows 
	+* Installing executables on Mac OS X
	 * Invoking GCC
	 * Architecture options usage
	 * C Libraries usage
	 * Linker scripts
	 * Startup code
	 
	-* Installing executables on Linux *
	+* Installing executables on Mac OS X *
	 Unpack the tarball to the target directory, like this:
	 $ cd target_dir && tar xjf arm-none-eabi-gcc-4_x-YYYYMMDD.tar.bz2
	 
	-* Installing executables on Windows *
	-Run the installer (arm-none-eabi-gcc-4_x-YYYYMMDD.exe) and follow the
	-instructions.
	+Note that the HTML and PDF documentation is not included in this distribution.
	 
	 * Invoking GCC *
	-On Linux, either invoke with the complete path like this:
	+On Mac OS X, either invoke with the complete path like this:
	 $ target_dir/arm-none-eabi-gcc-4_x/bin/arm-none-eabi-gcc
	 
	 Or set path like this:
	 $ export PATH=$PATH:target_dir/arm-none-eabi-gcc-4_x/bin/arm-none-eabi-gcc/bin
	 $ arm-none-eabi-gcc
	 
	-On Windows (although the above approaches also work), it can be more
	-convenient to either have the installer register environment variables, or run
	-INSTALL_DIR\bin\gccvar.bat to set environment variables for the current cmd. 
	-
	 * Architecture options usage *
	 
	 This toolchain is built and optimized for Cortex-R/M bare metal development.
EOF
patch <<-'EOF'
	--- ../release.txt	2011-12-21 18:21:58.000000000 -0800
	+++ ./release.txt	2012-01-28 17:53:17.000000000 -0800
	@@ -2,57 +2,15 @@
	 *************************************************
	 GNU Tools for ARM Embedded Processors
	                            - Dec 2011
	+Modified binary-only distribution for Mac OS X
	+                           - Feb 2012
	 *************************************************
	 
	 This release includes the following items:
	-* Bare metal EABI pre-built binaries for running on a Windows host
	-* Bare metal EABI pre-built binaries for running on a Linux host
	-* Source code package (together with build scripts and instructions to setup
	-  build environment), composed of:
	-  * gcc : ARM/embedded-4_6-branch revision 182083
	-    http://gcc.gnu.org/svn/gcc/branches/ARM/embedded-4_6-branch/
	-
	-  * binutils : 2.21 with mainline backports
	-    git://sourceware.org/git/binutils.git
	-    SHA: 47639bbc8b5fd6cf58aeefafbc99e0b1227d357c
	-
	-  * newlib : 1.19 with mainline backports
	-    ftp://sources.redhat.com/pub/newlib/newlib-1.19.0.tar.gz
	-
	-  * gdb : 7.3.1 with mainline backports, without target sim support
	-    git://sourceware.org/git/gdb.git
	-    SHA: 5c912c6308dbb9c3163b60381c8f3ee037e28d2b
	-
	-  * cloog-ppl 0.15.11 : 
	-    ftp://gcc.gnu.org/pub/gcc/infrastructure/cloog-ppl-0.15.11.tar.gz
	-
	-  * expat 2.0.1 :
	-    http://space.dl.sourceforge.net/project/expat/expat/2.0.1/expat-2.0.1.tar.gz
	-
	-  * gmp 4.3.2 : ftp://gcc.gnu.org/pub/gcc/infrastructure/gmp-4.3.2.tar.bz2
	-
	-  * libelf 0.8.13 : http://www.mr511.de/software/libelf-0.8.13.tar.gz
	-
	-  * libiconv 1.11.1 :
	-    http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.11.1.tar.gz
	-
	-  * mpc 0.8.1 : ftp://gcc.gnu.org/pub/gcc/infrastructure/mpc-0.8.1.tar.gz
	-
	-  * mpfr 2.4.2 : ftp://gcc.gnu.org/pub/gcc/infrastructure/mpfr-2.4.2.tar.bz2
	-
	-  * ppl 0.11 : ftp://gcc.gnu.org/pub/gcc/infrastructure/ppl-0.11.tar.gz
	-
	-  * zlib 1.2.5 with makefile patch : 
	-    http://sourceforge.net/projects/libpng/files/zlib/1.2.5/zlib-1.2.5.tar.bz2/download
	-
	-  * ncurses 5.9 :
	-    http://ftp.gnu.org/pub/gnu/ncurses/ncurses-5.9.tar.gz
	+* Bare metal EABI pre-built binaries for running on a Mac OS X host
	 
	 Supported hosts:
	-* Windows 32/64 bits (with installer)
	-* Linux 32/64 bits (tarball)
	-  - Ubuntu 8.x/9.x/10.x
	-  - RHEL 4/5
	+* Mac OS X 10.6 or later
	 
	 Supported target OS:
	 * Bare metal EABI only
EOF
popd

#
# Ok, let's build
#
echo "%%% Building prerequisites..."
(cd $base_dir/$distribution && /bin/bash ./build-prerequisites.sh)

echo "%%% Building toolchain..."
(cd $base_dir/$distribution && /bin/bash ./build-toolchain.sh)

echo "%%% Done."
