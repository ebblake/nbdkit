/* nbdkit
 * Copyright (C) 2013-2022 Red Hat Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 * * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * * Neither the name of Red Hat nor the names of its contributors may be
 * used to endorse or promote products derived from this software without
 * specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY RED HAT AND CONTRIBUTORS ''AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL RED HAT OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF
 * USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
 * OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <config.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#include <nbdkit-plugin.h>

static void
disconnect_unload (void)
{
  nbdkit_debug ("clean disconnect");
}

static void *
disconnect_open (int readonly)
{
  return NBDKIT_HANDLE_NOT_NEEDED;
}

static int64_t
disconnect_get_size (void *handle)
{
  return 1024*1024;
}

#define THREAD_MODEL NBDKIT_THREAD_MODEL_PARALLEL

/* Reads are delayed to show effect of disconnect on in-flight commands */
static int
disconnect_pread (void *handle, void *buf, uint32_t count, uint64_t offset)
{
  memset (buf, 0, count);
  if (nbdkit_nanosleep (2, 0) == -1)
    nbdkit_debug ("read delay ended early, returning success anyway");
  return 0;
}

/* Writing causes a disconnect; export name determines severity. */
static int
disconnect_pwrite (void *handle, const void *buf, uint32_t count,
                   uint64_t offset)
{
  const char *name = nbdkit_export_name ();
  bool hard = name && *name;
  nbdkit_debug ("%s disconnect triggered!", hard ? "hard" : "soft");
  nbdkit_disconnect (hard);
  /* Despite the disconnect, we still claim the write succeeded */
  return 0;
}

static struct nbdkit_plugin plugin = {
  .name              = "disconnect",
  .version           = PACKAGE_VERSION,
  .unload            = disconnect_unload,
  .open              = disconnect_open,
  .get_size          = disconnect_get_size,
  .pread             = disconnect_pread,
  .pwrite            = disconnect_pwrite,
};

NBDKIT_REGISTER_PLUGIN(plugin)
