/* nbdkit
 * Copyright (C) 2013-2020 Red Hat Inc.
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
#include <stdbool.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>

#include "ansi-colours.h"
#include "open_memstream.h"

#include "internal.h"

static void
prologue (FILE *fp)
{
  const char *name = threadlocal_get_name ();
  size_t instance_num = threadlocal_get_instance_num ();

  fprintf (fp, "%s: ", program_name);

  if (name) {
    fprintf (fp, "%s", name);
    if (instance_num > 0)
      fprintf (fp, "[%zu]", instance_num);
    fprintf (fp, ": ");
  }

  fprintf (fp, "debug: ");
}

/* Common debug function.
 * Note: preserves the previous value of errno.
 */
static void
debug_common (bool in_server, const char *fs, va_list args)
{
  int err = errno;
  int tty;
  CLEANUP_FREE char *str = NULL;
  size_t len = 0;
  FILE *fp;

  if (!verbose)
    return;

  fp = open_memstream (&str, &len);
  if (fp == NULL) {
  fail:
    /* Try to emit what we can. */
    errno = err;
    vfprintf (stderr, fs, args);
    fprintf (stderr, "\n");
    return;
  }

  tty = isatty (fileno (stderr));
  if (!in_server && tty) ansi_force_colour (ANSI_FG_BOLD_BLACK, fp);

  prologue (fp);

  errno = err;
  vfprintf (fp, fs, args);

  if (!in_server && tty) ansi_force_restore (fp);
  fprintf (fp, "\n");
  close_memstream (fp);

  if (str)
    fputs (str, stderr);
  else
    goto fail;

  errno = err;
}

/* Note: preserves the previous value of errno. */
NBDKIT_DLL_PUBLIC void
nbdkit_vdebug (const char *fs, va_list args)
{
  debug_common (false, fs, args);
}

/* Note: preserves the previous value of errno. */
NBDKIT_DLL_PUBLIC void
nbdkit_debug (const char *fs, ...)
{
  int err = errno;
  va_list args;

  va_start (args, fs);
  debug_common (false, fs, args);
  va_end (args);

  errno = err;
}

/* This variant of debug is used when debug is called from the server
 * code, via the debug() macro.
 *
 * Note: preserves the previous value of errno.
 */
void
debug_in_server (const char *fs, ...)
{
  int err = errno;
  va_list args;

  va_start (args, fs);
  debug_common (true, fs, args);
  va_end (args);

  errno = err;
}
