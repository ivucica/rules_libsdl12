/*   file.c
 *   Copyright (C) 2002 Evgeny Chukreev <codedj@echo.ru>
 *
 *  This file is part of AlsaPlayer.
 *
 *  AlsaPlayer is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  AlsaPlayer is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, see <http://www.gnu.org/licenses/>.
 *
 *   $Id: file.c 1331 2007-12-19 20:27:43Z dominique_libre $
 *
 */

#include <stdlib.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>

#include "reader.h"
#include "string.h"
#include "utilities.h"
#include "alsaplayer_error.h"

static void decode_uri(const char *src, char *dst, int len)
{
    int j;
   
    if (!is_uri(src)) {
	    strncpy(dst, src, len);
	    return;
    }	    
    for (j=0; j<len && *src; j++, src++) {
	if (*src == '%') {
	    int c;
	    char *pos;
	    char buf [3] = {src[1], src[2], '\0'};
	    
	    if (src[1] == '%') {
		dst [j] = '%';
		src++;
		continue;
	    }
	    
	    c = strtoul (buf, &pos, 16);
	    if (*pos == '\0') {
		dst [j] = c;
		src+=2;
		continue;
	    }
	}
	dst [j] = *src;
    }
    dst [j] = '\0';
}

/* open stream, may return NULL */
static void *file_open(const char *uri, reader_status_type status, void *data)
{
    char decoded_uri[1024];
    int offset = 0;
    
    decode_uri (uri, decoded_uri, 1020);
    if (strncmp(decoded_uri, "file:", 5) == 0) {
	    offset = 5;
    }	    
    
    return fopen (&decoded_uri[offset], "r");
}

/* close stream */
static void file_close(void *d)
{
    fclose ((FILE*)d);
}

/* test function */
static float file_can_handle(const char *uri)
{
    struct stat buf;
    char decoded_uri[1024];
    int offset = 0;

    decode_uri (uri, decoded_uri, 1020);

    /* Check for prefix */
    if (strncmp (decoded_uri, "file:", 5) == 0)
	  offset = 5;
    
    if (stat(&decoded_uri[offset], &buf))   return 0.0;
    
    /* Is it a type we might have a chance of reading?
     * (Some plugins may cope with playing special devices, eg, a /dev/scd) */
    if (!(S_ISREG(buf.st_mode) ||
	  S_ISCHR(buf.st_mode) ||
	  S_ISBLK(buf.st_mode) ||
	  S_ISFIFO(buf.st_mode) ||
	  S_ISSOCK(buf.st_mode))) return 0.0;
    
    return 1.0;
}

/* init plugin */
static int file_init(void)
{
    return 1;
}

/* shutdown plugin */
static void file_shutdown(void)
{
    return;
}

static size_t file_metadata (void *ptr, size_t size, void *d)
{
	/* Not implemented */
	return 0;
}


/* read from stream */
static size_t file_read (void *ptr, size_t size, void *d)
{
    return fread (ptr, 1, size, (FILE*)d) ;
}

/* seek in stream */
static int file_seek (void *d, long offset, int whence)
{
    return fseek ((FILE*)d, offset, whence);
}

/*
 * Return current position in stream.
*/
static long file_tell (void *d)
{
    return ftell ((FILE*)d);
}

/* directory test */
static float file_can_expand (const char *uri)
{
    const char *path;
    struct stat buf;   
    char decoded_uri[1024];
    
    decode_uri (uri, decoded_uri, 1020);
    
    /* Check for prefix */
    if (strncmp (decoded_uri, "file:", 5))  return 0.0;
 
    /* Real path */
    path = &decoded_uri[5];
    if (!*path)  return 0.0;

    // Stat file, and don't follow symlinks
    if (lstat(path, &buf))  return 0.0;
    if (!S_ISDIR(buf.st_mode))  return 0.0;
    
    return 1.0;
}


/* expand directory */
static char **file_expand (const char *uri)
{
    struct dirent *entry;
    DIR *dir;
    char **expanded = NULL;
    int count = 0;
    char *s;
    char decoded_uri[1024];
    
    decode_uri (uri, decoded_uri, 1020);
    dir = opendir (&decoded_uri[5]);
    
    /* Allocate memory for empty list */
    expanded = malloc (sizeof(char*));
    *expanded = NULL;
   
    /* return empty list on error */
    if (!dir)  return expanded;
       
    /* iterate over a dir */
    while ((entry = readdir(dir)) != NULL) {
	/* don't include . and .. entries */
	if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)  continue;

	/* compose */
	s = malloc (sizeof(char) * (2 + strlen(&uri[5]) + strlen(entry->d_name)));
	strcpy (s, &decoded_uri[5]);
	strcat (s, "/");
	strcat (s, entry->d_name);
	expanded [count++] = s;

	/* grow up our list */
	expanded = realloc (expanded, (count+1)*sizeof(char*));
    }
    
    /* set the end mark */
    expanded [count] = NULL;
    
    closedir(dir);  

    return expanded;
}

/* feof wrapper */
static int file_eof (void *d)
{
    return feof ((FILE*)d);
}

/* stream is seekable */
static int file_seekable (void *d)
{
    return 1;
}

static long file_length (void *d)
{    
    long len, old=ftell ((FILE*)d);

    len = fseek ((FILE*)d, 0, SEEK_END);
    fseek ((FILE*)d, old, SEEK_SET);

    return len;
}

/* info about this plugin */
reader_plugin file_plugin = {
	READER_PLUGIN_VERSION,
	"File reader v1.1",
	"Evgeny Chukreev",
	NULL,
	file_init,
	file_shutdown,
	file_can_handle,
	file_open,
	file_close,
	file_read,
	file_metadata,
	file_seek,
	file_tell,
	file_can_expand,
	file_expand,
	file_length,
	file_eof,
	file_seekable
};

/* return info about this plugin */
reader_plugin *reader_plugin_info(void)
{
	return &file_plugin;
}
