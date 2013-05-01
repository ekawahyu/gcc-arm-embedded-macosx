#!/bin/bash
#
# Copyright (c) 2012 Michael Smith
# Portions Copyright (c) 2012 Ekawahyu Susilo
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
distribution=gcc-arm-none-eabi-4_7-2013q1-20130313

#
# Establish the location of the distribution archives and make a working
# directory.  Set up some more directory names
#
base_dir=`pwd -P`
src_dir=$base_dir/$distribution/src

# GCC used to compile the toolchain (default is system gcc)
gcc_used=system
# GCC version used when building from pristine source
# gcc_version=gcc-4.7.3
gcc_version=gcc-4.6.4
# Where is libstdc++?
gcc_libstdcpp=/usr/lib/gcc/x86_64-linux-gnu/4.7

toolchain_args=""
for arg
do
	case $arg in
		--with-embedded-gcc)
			# use the GCC from the toolchain
			gcc_used=embedded
			gcc_source_dir=$src_dir/gcc
			;;
		--with-source-gcc)
			# use pristine sources of GCC
			gcc_used=source
			gcc_source_dir=$base_dir/$gcc_version
			;;
		--skip_mingw32|--debug|--ppa)
			# Pass other stuff upstream!
			toolchain_args="$toolchain_args $arg"
			;;
		*)
			echo "Usage: $0 [--with-embedded-gcc|--with-source-gcc]"
			exit 1
			;;
	esac
done

#
# Check for the source files
#
if [ ! -r $base_dir/$distribution-src.tar.bz2 ]; then
	echo ""
	echo "  Can't find the distribution files for $distribution"
	echo "  (looked in the current directory only)"
	echo "  They can be downloaded from https://launchpad.net/gcc-arm-embedded"
	echo ""
	exit 1
fi
if [ "$gcc_used" = "source" -a ! -r $base_dir/$gcc_version.tar.bz2 ]; then
	echo ""
	echo "  Can't find the distribution files for $gcc_version"
	echo "  (looked in the current directory only)"
	echo "  They can be downloaded from ftp://ftp.gnu.org/gnu/gcc/$gcc_version/$gcc_version.tar.bz2"
	echo ""
	exit 1
fi
if [ "$gcc_used" != "system" -a ! -f $gcc_libstdcpp/libstdc++.a ]; then
	echo ""
	echo "  Can't find your libstdc++.a in $gcc_libstdcpp"
	echo "  Please locate libstdc++.a for your architecture and update gcc_libstdcpp in this script"
	echo ""
	exit 1
fi

#
# Unpack the archives
#
if [ "$gcc_used" = "source" ]; then
	if [ -d $gcc_version ]; then
		echo "Warning: GCC source directory already exists, please remove if you want a clean build"
	else
		echo "Unpacking gcc archive..."
		tar xjU -f $gcc_version.tar.bz2
	fi
fi
if [ -d $distribution ]; then
	echo "Warning: distrubution directory already exists, please remove if you want a clean build"
else
	echo "Unpacking distribution archive..."
	tar xjU -f $distribution-src.tar.bz2

	#
	# Unpack individual source archives
	#
	for archive in $src_dir/*.tar.bz2; do
		echo "Unpacking $archive..."
		tar xjU -C $src_dir -f $archive 
	done
	for archive in $src_dir/*.tar.gz; do
		echo "Unpacking $archive..."
		tar xzU -C $src_dir -f $archive 
	done

	#
	# Do pre-build fixups
	#
	echo "Doing pre-build fixups..."

	# zlib
	pushd $src_dir/zlib-1.2.5
	patch < ../zlib-1.2.5.patch
	popd

	#
	# Patch the build scripts
	#
	echo "Patching the build scripts..."
	pushd $base_dir/$distribution

	# Patch for native x86_64 toolchain
	if [ `uname -m` == x86_64 ]; then
		patch <<-'EOF'
			--- build-common.sh-	2013-03-12 19:37:56.000000000 +0100
			+++ build-common.sh	2013-05-01 11:29:48.119046955 +0200
			@@ -302,6 +302,8 @@
			         RELEASEVER=${release_year}q4
			         ;;
			 esac
			+# Release version based on source not actual date!
			+RELEASEVER=2013q1
			 
			 RELEASE_FILE=release.txt
			 README_FILE=readme.txt
			@@ -329,8 +331,8 @@
			 # on Ubuntu and Mac OS X.
			 uname_string=`uname | sed 'y/LINUXDARWIN/linuxdarwin/'`
			 if [ "x$uname_string" == "xlinux" ] ; then
			-    BUILD=i686-linux-gnu
			-    HOST_NATIVE=i686-linux-gnu
			+    BUILD=x86-64-linux-gnu
			+    HOST_NATIVE=x86-64-linux-gnu
			     READLINK=readlink
			     JOBS=`grep ^processor /proc/cpuinfo|wc -l`
			     GCC_CONFIG_OPTS_LCPP="--with-host-libstdcxx=-static-libgcc -Wl,-Bstatic,-lstdc++,-Bdynamic -lm"
EOF

		# We need to add '-lm' to build cloog on Ubuntu 13.04
		patch <<-'EOF'
			--- build-prerequisites.sh-	2013-03-12 19:37:56.000000000 +0100
			+++ build-prerequisites.sh	2013-05-01 11:22:26.643046955 +0200
			@@ -163,7 +163,7 @@
			     --prefix=$BUILDDIR_NATIVE/host-libs/usr \
			     --disable-shared \
			     --disable-nls \
			-    --with-host-libstdcxx='-lstdc++'    \
			+    --with-host-libstdcxx='-lstdc++ -lm'    \
			     --with-gmp=$BUILDDIR_NATIVE/host-libs/usr \
			     --with-ppl=$BUILDDIR_NATIVE/host-libs/usr
			 
EOF

	fi

	popd
fi

if [ "$gcc_used" = "system" ]; then
	echo "Toolchain will be built using your system GCC"
else
	gcc_build_dir=$base_dir/gcc/build
	gcc_target_dir=$base_dir/gcc/target
	if [ -x $gcc_target_dir/bin/gcc ]; then
		echo "Warning: non-system gcc already built, remove gcc directory for a clean build"
	else
		echo "%%% Building GCC from source"
		echo "    Logs saved to ggc.<step>.log"
		mkdir -p $gcc_build_dir $gcc_target_dir
		pushd $gcc_build_dir
		echo "... Configure"
		$gcc_source_dir/configure \
			--build=x86_64-linux-gnu \
			--host=x86_64-linux-gnu \
			--target=x86_64-linux-gnu \
			--enable-languages=c,c++ \
			--enable-shared \
			--enable-threads=posix \
			--disable-decimal-float \
			--disable-libffi \
			--disable-libgomp \
			--disable-libmudflap \
			--disable-libssp \
			--disable-libstdcxx-pch \
			--disable-multilib \
			--disable-nls \
			--with-gnu-as \
			--with-gnu-ld \
			--enable-libstdcxx-debug \
			--enable-targets=all \
			--enable-checking=release \
			--prefix=$gcc_target_dir \
			--with-host-libstdcxx="-static-libgcc -L $gcc_libstdcpp -lstdc++ -lsupc++ -lm" > $base_dir/gcc.configure.log 2>&1 
		echo "... Make"
		jobs=`grep ^processor /proc/cpuinfo|wc -l`
		make -j$jobs > $base_dir/gcc.make.log 2>&1
		echo "... Install"
		make install > $base_dir/gcc.install.log 2>&1
		popd
	fi
	PATH=$gcc_target_dir/bin:$PATH
	export PATH
	echo "Toolchain will be built using your custom GCC in $gcc_target_dir:"
	gcc --version
fi

#
# Ok, let's build
#
echo "%%% Building prerequisites..."
echo "    Logs saved to prerequisites.log"
(cd $base_dir/$distribution && /bin/bash ./build-prerequisites.sh $toolchain_args ) 2>&1 | tee $base_dir/prerequisites.log | grep '^Task '

echo "%%% Building toolchain..."
echo "    Logs saved to toolchain.log"
(cd $base_dir/$distribution && /bin/bash ./build-toolchain.sh $toolchain_args ) 2>&1 | tee $base_dir/toolchain.log | grep '^Task '

echo "%%% Done."
