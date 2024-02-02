/*  utilities.h
 *  Copyright (C) 1999 Richard Boulton <richard@tartarus.org>
 *
 *  This file is part of AlsaPlayer
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
 *  $Id: utilities.h 1250 2007-07-08 14:17:12Z dominique_libre $
 * 
 */ 

#ifndef __utilities_h__
#define __utilities_h__
#ifdef __cplusplus
extern "C" {
#endif

// Magic macros for stringizing
#define STRINGISE(a) _STRINGISE(a)	// Not sure why this is needed, but
					// sometimes fails without it.
#define _STRINGISE(a) #a		// Now do the stringising

// Sleep for specified number of micro-seconds
// Used by scopes and things, so use C-style linkage
void dosleep(unsigned int);
void parse_file_uri_free(char *);
void parse_percent_free(char *);
char *get_homedir(void);
char *get_prefsdir(void);
char *parse_file_uri(const char *);
char *parse_percent(const char *);
int is_playlist(const char *);
int is_uri(const char *);

#ifdef __cplusplus
}
#endif
#endif
