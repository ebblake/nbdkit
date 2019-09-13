#!/usr/bin/env bash
# nbdkit
# Copyright (C) 2018-2019 Red Hat Inc.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# * Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# * Neither the name of Red Hat nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY RED HAT AND CONTRIBUTORS ''AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL RED HAT OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
# USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

# Test the reflection plugin with base64-encoded export name.

source ./functions.sh
set -e
set -x

requires nbdsh -c 'import base64'

# Test if mode=base64exportname is supported in this build.
if ! nbdkit reflection --dump-plugin | grep -sq "reflection_base64=yes"; then
    echo "$0: mode=base64exportname is not supported in this build"
    exit 77
fi

sock=`mktemp -u`
files="reflection-base64.out reflection-base64.pid $sock"
rm -f $files
cleanup_fn rm -f $files

# Run nbdkit.
start_nbdkit -P reflection-base64.pid -U $sock \
       reflection mode=base64exportname

export e sock
for e in "" "test" "テスト" "-n" '\\' $'\n' \
         "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
do
    nbdsh -c '
import os
import base64

e = os.environ["e"]
b = base64.b64encode(e.encode("utf-8")).decode("utf-8")
print ("e = %r, b = %r" % (e,b))
h.set_export_name (b)
h.connect_unix (os.environ["sock"])

size = h.get_size ()
assert size == len (e.encode("utf-8"))

# Zero-sized reads are not defined in the NBD protocol.
if size > 0:
   buf = h.pread (size, 0)
   assert buf == e.encode("utf-8")
'
done

# Test that it fails if the caller passes in non-base64 data.  The
# server drops the connection in this case so it's not very graceful
# but we should at least get an nbd.Error and not something else.
nbdsh -c '
import os
import sys

h.set_export_name ("xyz")
try:
    h.connect_unix (os.environ["sock"])
    # This should not happen.
    sys.exit (1)
except nbd.Error as ex:
    sys.exit (0)
# This should not happen.
sys.exit (1)
'
