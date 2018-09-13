#!/usr/bin/env bash
# nbdkit
# Copyright (C) 2018 Red Hat Inc.
# All rights reserved.
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

# Test the memory plugin with the largest possible size supported
# by nbdkit.

source ./functions.sh
set -e

files="memory-largest.out memory-largest.pid memory-largest.sock"
rm -f $files

# Test that qemu-io works
if ! qemu-io --help >/dev/null; then
    echo "$0: missing or broken qemu-io"
    exit 77
fi

# Run nbdkit with memory plugin.
# size = 2^63-1
nbdkit -f -v \
       -D memory.dir=1 \
       -P memory-largest.pid -U memory-largest.sock \
       memory size=9223372036854775807 &

# We may have to wait a short time for the pid file to appear.
for i in `seq 1 10`; do
    if test -f memory-largest.pid; then
        break
    fi
    sleep 1
done
if ! test -f memory-largest.pid; then
    echo "$0: PID file was not created"
    exit 1
fi

pid="$(cat memory-largest.pid)"

# Kill the nbdkit process on exit.
cleanup ()
{
    kill $pid
    rm -f $files
}
cleanup_fn cleanup

# qemu cannot open this image!
#
#   can't open device nbd+unix://?socket=memory-largest.sock: Could not get image size: File too large
#
# Therefore we skip the remainder of this test (in effect, testing
# only that nbdkit can create the file).
exit 77

# The cleanup() function is called implicitly on exit.
