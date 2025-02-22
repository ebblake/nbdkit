/* nbdkit
 * Copyright (C) 2014-2023 Red Hat Inc.
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

/* Header and cookie scripts. */

#include <config.h>

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <assert.h>
#include <pthread.h>

#include <curl/curl.h>

#include <nbdkit-plugin.h>

#include "ascii-ctype.h"
#include "cleanup.h"
#include "utils.h"

#include "curldefs.h"

#ifndef WIN32

/* This lock protects internal state in this file. */
static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

/* Last time header-script or cookie-script was run. */
static time_t header_last = 0;
static time_t cookie_last = 0;
static bool header_script_has_run = false;
static bool cookie_script_has_run = false;
static unsigned header_iteration = 0;
static unsigned cookie_iteration = 0;

/* Last set of headers and cookies generated by the scripts. */
static struct curl_slist *headers_from_script = NULL;
static char *cookies_from_script = NULL;

/* Debug scripts by setting -D curl.scripts=1 */
NBDKIT_DLL_PUBLIC int curl_debug_scripts;

void
scripts_unload (void)
{
  curl_slist_free_all (headers_from_script);
  free (cookies_from_script);
}

static int run_header_script (struct curl_handle *);
static int run_cookie_script (struct curl_handle *);
static void error_from_tmpfile (const char *what, const char *tmpfile);

/* This is called from any thread just before we make a curl request.
 *
 * Because the curl handle must be obtained through get_handle() we
 * can be assured of exclusive access here.
 */
int
do_scripts (struct curl_handle *ch)
{
  time_t now;
  struct curl_slist *p;

  /* Return quickly without acquiring the lock if this feature is not
   * being used.
   */
  if (!header_script && !cookie_script)
    return 0;

  ACQUIRE_LOCK_FOR_CURRENT_SCOPE (&lock);

  /* Run or re-run header-script if we need to. */
  if (header_script) {
    time (&now);
    if (!header_script_has_run ||
        (header_script_renew > 0 && now - header_last >= header_script_renew)) {
      if (run_header_script (ch) == -1)
        return -1;
      header_last = now;
      header_script_has_run = true;
    }
  }

  /* Run or re-run cookie-script if we need to. */
  if (cookie_script) {
    time (&now);
    if (!cookie_script_has_run ||
        (cookie_script_renew > 0 && now - cookie_last >= cookie_script_renew)) {
      if (run_cookie_script (ch) == -1)
        return -1;
      cookie_last = now;
      cookie_script_has_run = true;
    }
  }

  /* Set headers and cookies in the handle.
   *
   * When calling CURLOPT_HTTPHEADER we have to keep the list around
   * because unfortunately curl doesn't take a copy.  Since we don't
   * know which other threads might be using it, we must make a copy
   * of the global list (headers_from_script) per handle
   * (ch->headers_copy).  For CURLOPT_COOKIE, curl internally takes a
   * copy so we don't need to do this.
   */
  if (ch->headers_copy) {
    curl_easy_setopt (ch->c, CURLOPT_HTTPHEADER, NULL);
    curl_slist_free_all (ch->headers_copy);
    ch->headers_copy = NULL;
  }
  for (p = headers_from_script; p != NULL; p = p->next) {
    if (curl_debug_scripts)
      nbdkit_debug ("header-script: setting header %s", p->data);
    ch->headers_copy = curl_slist_append (ch->headers_copy, p->data);
    if (ch->headers_copy == NULL) {
      nbdkit_error ("curl_slist_append: %m");
      return -1;
    }
  }
  curl_easy_setopt (ch->c, CURLOPT_HTTPHEADER, ch->headers_copy);

  if (curl_debug_scripts && cookies_from_script)
    nbdkit_debug ("cookie-script: setting cookie %s", cookies_from_script);
  curl_easy_setopt (ch->c, CURLOPT_COOKIE, cookies_from_script);

  return 0;
}

/* This is called with the lock held when we must run or re-run the
 * header-script.
 */
static int
run_header_script (struct curl_handle *ch)
{
  int fd;
  char tmpfile[] = "/tmp/errorsXXXXXX";
  FILE *fp;
  CLEANUP_FREE char *cmd = NULL, *line = NULL;
  ssize_t n;
  size_t len = 0, linelen = 0, nr_headers = 0;

  assert (header_script != NULL); /* checked by caller */

  /* Reset the list of headers. */
  curl_slist_free_all (headers_from_script);
  headers_from_script = NULL;

  /* Create a temporary file for the errors so we can redirect them
   * into nbdkit_error.
   */
  fd = mkstemp (tmpfile);
  if (fd == -1) {
    nbdkit_error ("mkstemp");
    return -1;
  }
  close (fd);

  /* Generate the full script with the local $url variable. */
  fp = open_memstream (&cmd, &len);
  if (fp == NULL) {
    nbdkit_error ("open_memstream: %m");
    return -1;
  }
  fprintf (fp, "exec </dev/null\n");    /* Avoid stdin leaking (nbdkit -s). */
  fprintf (fp, "exec 2>%s\n", tmpfile); /* Catch errors to a temporary file. */
  fprintf (fp, "url=");                 /* Set the shell variables. */
  shell_quote (url, fp);
  putc ('\n', fp);
  fprintf (fp, "iteration=%u\n", header_iteration++);
  putc ('\n', fp);
  fprintf (fp, "%s", header_script);    /* The script or command. */
  if (fclose (fp) == EOF) {
    nbdkit_error ("memstream failed");
    return -1;
  }

  /* Run the script and read the headers. */
  nbdkit_debug ("curl: running header-script");
  fp = popen (cmd, "r");
  if (fp == NULL) {
    nbdkit_error ("popen: %m");
    return -1;
  }
  while ((n = getline (&line, &linelen, fp)) != -1) {
    /* Remove trailing \n and whitespace. */
    while (n > 0 && ascii_isspace (line[n-1]))
      line[--n] = '\0';
    if (n == 0)
      continue;

    headers_from_script = curl_slist_append (headers_from_script, line);
    if (headers_from_script == NULL) {
      nbdkit_error ("curl_slist_append: %m");
      pclose (fp);
      return -1;
    }
    nr_headers++;
  }

  if (pclose (fp) != 0) {
    error_from_tmpfile ("header-script", tmpfile);
    return -1;
  }

  nbdkit_debug ("header-script returned %zu header(s)", nr_headers);
  return 0;
}

/* This is called with the lock held when we must run or re-run the
 * cookie-script.
 */
static int
run_cookie_script (struct curl_handle *ch)
{
  int fd;
  char tmpfile[] = "/tmp/errorsXXXXXX";
  FILE *fp;
  CLEANUP_FREE char *cmd = NULL, *line = NULL;
  ssize_t n;
  size_t len = 0, linelen = 0;

  assert (cookie_script != NULL); /* checked by caller */

  /* Reset the cookies. */
  free (cookies_from_script);
  cookies_from_script = NULL;

  /* Create a temporary file for the errors so we can redirect them
   * into nbdkit_error.
   */
  fd = mkstemp (tmpfile);
  if (fd == -1) {
    nbdkit_error ("mkstemp");
    return -1;
  }
  close (fd);

  /* Generate the full script with the local $url variable. */
  fp = open_memstream (&cmd, &len);
  if (fp == NULL) {
    nbdkit_error ("open_memstream: %m");
    return -1;
  }
  fprintf (fp, "exec </dev/null\n");    /* Avoid stdin leaking (nbdkit -s). */
  fprintf (fp, "exec 2>%s\n", tmpfile); /* Catch errors to a temporary file. */
  fprintf (fp, "url=");                 /* Set the shell variable. */
  shell_quote (url, fp);
  putc ('\n', fp);
  fprintf (fp, "iteration=%u\n", cookie_iteration++);
  putc ('\n', fp);
  fprintf (fp, "%s", cookie_script);    /* The script or command. */
  if (fclose (fp) == EOF) {
    nbdkit_error ("memstream failed");
    return -1;
  }

  /* Run the script and read the cookies. */
  nbdkit_debug ("curl: running cookie-script");
  fp = popen (cmd, "r");
  if (fp == NULL) {
    nbdkit_error ("popen: %m");
    return -1;
  }
  n = getline (&line, &linelen, fp);
  if (n > 0) {
    /* Remove trailing \n and whitespace. */
    while (n > 0 && ascii_isspace (line[n-1]))
      line[--n] = '\0';
    if (n > 0) {
      cookies_from_script = strdup (line);
      if (cookies_from_script == NULL) {
        nbdkit_error ("strdup");
        pclose (fp);
        return -1;
      }
    }
  }

  if (pclose (fp) != 0) {
    error_from_tmpfile ("cookie-script", tmpfile);
    return -1;
  }

  nbdkit_debug ("cookie-script returned %scookies",
                cookies_from_script ? "" : "no ");
  return 0;
}

/* If the command failed, the error message should be in the temporary
 * file to which we redirected the script's stderr.  We only read the
 * first line.
 */
static void
error_from_tmpfile (const char *what, const char *tmpfile)
{
  FILE *fp;
  CLEANUP_FREE char *line = NULL;
  ssize_t n;
  size_t linelen = 0;

  fp = fopen (tmpfile, "r");

  if (fp && (n = getline (&line, &linelen, fp)) >= 0) {
    if (n > 0 && line[n-1] == '\n')
      line[n-1] = '\0';
    nbdkit_error ("%s failed: %s", what, line);
  }
  else
    nbdkit_error ("%s failed", what);

  if (fp) fclose (fp);
}

#else /* WIN32 */

void
scripts_unload (void)
{
}

int
do_scripts (struct curl_handle *ch)
{
  if (!header_script && !cookie_script)
    return 0;

  NOT_IMPLEMENTED_ON_WINDOWS ("header-script or cookie-script");
}

#endif /* WIN32 */
