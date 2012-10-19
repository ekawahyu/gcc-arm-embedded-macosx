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
distribution=gcc-arm-none-eabi-4_6-2012q2-20120614

#
# Establish the location of the distribution archives and make a working
# directory.  Set up some more directory names
#
base_dir=`pwd -P`
src_dir=$base_dir/$distribution/src

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

#
# Unpack the distribution
#
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

#
# Ok, let's build
#
echo "%%% Building prerequisites..."
(cd $base_dir/$distribution && /bin/bash ./build-prerequisites.sh)

echo "%%% Building toolchain..."
(cd $base_dir/$distribution && /bin/bash ./build-toolchain.sh)

echo "%%% Done."
