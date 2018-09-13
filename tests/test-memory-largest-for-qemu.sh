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
# by qemu and nbdkit.

source ./functions.sh
set -e

files="memory-largest-for-qemu.out memory-largest-for-qemu.pid memory-largest-for-qemu.sock"
rm -f $files

# Test that qemu-io works
if ! qemu-io --help >/dev/null; then
    echo "$0: missing or broken qemu-io"
    exit 77
fi

# Run nbdkit with memory plugin.
# size = (2^63-1) & ~511 which is the largest supported by qemu.
nbdkit -f -v -D memory.dir=1 \
       -P memory-largest-for-qemu.pid -U memory-largest-for-qemu.sock \
       memory size=9223372036854775296 &

# We may have to wait a short time for the pid file to appear.
for i in `seq 1 10`; do
    if test -f memory-largest-for-qemu.pid; then
        break
    fi
    sleep 1
done
if ! test -f memory-largest-for-qemu.pid; then
    echo "$0: PID file was not created"
    exit 1
fi

pid="$(cat memory-largest-for-qemu.pid)"

# Kill the nbdkit process on exit.
cleanup ()
{
    kill $pid
    rm -f $files
}
cleanup_fn cleanup

# Write some stuff to the beginning, middle and end.
qemu-io -f raw 'nbd+unix://?socket=memory-largest-for-qemu.sock' \
        -c 'w -P 1 0 512' \
        -c 'w -P 2 1000000001 65536' \
        -c 'w -P 3 9223372036854774784 512'

qemu-io -r -f raw 'nbd+unix://?socket=memory-largest-for-qemu.sock' \
        -c 'r -v 0 512' | grep -E '^[[:xdigit:]]+:' > memory-largest-for-qemu.out
if [ "$(cat memory-largest-for-qemu.out)" != "00000000:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000010:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000020:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000030:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000040:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000050:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000060:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000070:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000080:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000090:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
000000a0:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
000000b0:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
000000c0:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
000000d0:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
000000e0:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
000000f0:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000100:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000110:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000120:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000130:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000140:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000150:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000160:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000170:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000180:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
00000190:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
000001a0:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
000001b0:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
000001c0:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
000001d0:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
000001e0:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................
000001f0:  01 01 01 01 01 01 01 01 01 01 01 01 01 01 01 01  ................" ]
then
    echo "$0: unexpected memory:"
    cat memory-largest-for-qemu.out
    exit 1
fi

qemu-io -r -f raw 'nbd+unix://?socket=memory-largest-for-qemu.sock' \
        -c 'r -v 1000000001 512' | grep -E '^[[:xdigit:]]+:' > memory-largest-for-qemu.out
if [ "$(cat memory-largest-for-qemu.out)" != "3b9aca01:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9aca11:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9aca21:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9aca31:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9aca41:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9aca51:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9aca61:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9aca71:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9aca81:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9aca91:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acaa1:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acab1:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acac1:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acad1:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acae1:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acaf1:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acb01:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acb11:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acb21:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acb31:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acb41:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acb51:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acb61:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acb71:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acb81:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acb91:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acba1:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acbb1:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acbc1:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acbd1:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acbe1:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................
3b9acbf1:  02 02 02 02 02 02 02 02 02 02 02 02 02 02 02 02  ................" ]
then
    echo "$0: unexpected memory:"
    cat memory-largest-for-qemu.out
    exit 1
fi

# This block of memory was not set, so it should read back as zeroes.
qemu-io -r -f raw 'nbd+unix://?socket=memory-largest-for-qemu.sock' \
        -c 'r -v 2000000000 512' | grep -E '^[[:xdigit:]]+:' > memory-largest-for-qemu.out
if [ "$(cat memory-largest-for-qemu.out)" != "77359400:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359410:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359420:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359430:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359440:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359450:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359460:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359470:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359480:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359490:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
773594a0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
773594b0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
773594c0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
773594d0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
773594e0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
773594f0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359500:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359510:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359520:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359530:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359540:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359550:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359560:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359570:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359580:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
77359590:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
773595a0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
773595b0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
773595c0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
773595d0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
773595e0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................
773595f0:  00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00  ................" ]
then
    echo "$0: unexpected memory:"
    cat memory-largest-for-qemu.out
    exit 1
fi

qemu-io -r -f raw 'nbd+unix://?socket=memory-largest-for-qemu.sock' \
        -c 'r -v 9223372036854774784 512' | grep -E '^[[:xdigit:]]+:' > memory-largest-for-qemu.out
if [ "$(cat memory-largest-for-qemu.out)" != "7ffffffffffffc00:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffc10:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffc20:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffc30:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffc40:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffc50:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffc60:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffc70:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffc80:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffc90:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffca0:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffcb0:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffcc0:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffcd0:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffce0:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffcf0:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffd00:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffd10:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffd20:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffd30:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffd40:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffd50:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffd60:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffd70:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffd80:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffd90:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffda0:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffdb0:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffdc0:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffdd0:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffde0:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................
7ffffffffffffdf0:  03 03 03 03 03 03 03 03 03 03 03 03 03 03 03 03  ................" ]
then
    echo "$0: unexpected memory:"
    cat memory-largest-for-qemu.out
    exit 1
fi

# The cleanup() function is called implicitly on exit.
