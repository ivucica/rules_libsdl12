/*
 * AlsaPlayer MAD plugin.
 *
 * Copyright (C) 2001-2003 Andy Lo A Foe <andy@alsaplayer.org>
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
 *  $Id: mad_engine.c 1344 2010-11-07 20:38:05Z dominique_libre $
 */ 

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#ifdef HAVE_GLIB2
#include <glib.h>
#endif

#include <stdio.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include "input_plugin.h"
#include "alsaplayer_error.h"
#include "reader.h"
#include "prefs.h"

#define MAD_BUFSIZE (32 * 1024)

#ifdef __cplusplus
extern "C" { 	/* Make sure MAD symbols are not mangled
		 * since we compile them with regular gcc */
#endif

#ifndef HAVE_LIBMAD /* Needed if we use our own (outdated) copy */
#include "frame.h"
#include "synth.h"
#endif	
#include <mad.h>

#ifdef __cplusplus
}
#endif

#include "xing.h"

#define BLOCK_SIZE 4096
#define MAX_NUM_SAMPLES 8192
#define STREAM_BUFFER_SIZE	(32 * 1024)
#define FRAME_RESERVE	2000

# if !defined(O_BINARY)
#  define O_BINARY  0
# endif

struct mad_local_data {
	void *mad_fd;
	uint8_t mad_map[MAD_BUFSIZE];
	long map_offset;
	int bytes_avail;
	struct stat stat;
	ssize_t	*frames;
	int highest_frame;
	int current_frame;
	char path[FILENAME_MAX+1];
	char filename[FILENAME_MAX+1];
	struct mad_synth  synth; 
	struct mad_stream stream;
	struct mad_frame  frame;
	struct xing xing;
	stream_info sinfo;
	int mad_init;
	ssize_t offset;
	ssize_t filesize;
	unsigned int samplerate;
	int bitrate;
	int seekable;
	int seeking;
	int eof;
	int parse_id3;
	int parsed_id3;
	char str[17];
};		


/*
 * NAME:	error_str()
 * DESCRIPTION:	return a string describing a MAD error
 */
	static
char const *error_str(enum mad_error error, char *str)
{

	switch (error) {
		case MAD_ERROR_BUFLEN:
		case MAD_ERROR_BUFPTR:
			/* these errors are handled specially and/or should not occur */
			break;

		case MAD_ERROR_NOMEM:		 return ("not enough memory");
		case MAD_ERROR_LOSTSYNC:	 return ("lost synchronization");
		case MAD_ERROR_BADLAYER:	 return ("reserved header layer value");
		case MAD_ERROR_BADBITRATE:	 return ("forbidden bitrate value");
		case MAD_ERROR_BADSAMPLERATE:	 return ("reserved sample frequency value");
		case MAD_ERROR_BADEMPHASIS:	 return ("reserved emphasis value");
		case MAD_ERROR_BADCRC:		 return ("CRC check failed");
		case MAD_ERROR_BADBITALLOC:	 return ("forbidden bit allocation value");
		case MAD_ERROR_BADSCALEFACTOR:	 return ("bad scalefactor index");
		case MAD_ERROR_BADFRAMELEN:	 return ("bad frame length");
		case MAD_ERROR_BADBIGVALUES:	 return ("bad big_values count");
		case MAD_ERROR_BADBLOCKTYPE:	 return ("reserved block_type");
		case MAD_ERROR_BADSCFSI:	 return ("bad scalefactor selection info");
		case MAD_ERROR_BADDATAPTR:	 return ("bad main_data_begin pointer");
		case MAD_ERROR_BADPART3LEN:	 return ("bad audio data length");
		case MAD_ERROR_BADHUFFTABLE:	 return ("bad Huffman table select");
		case MAD_ERROR_BADHUFFDATA:	 return ("Huffman data overrun");
		case MAD_ERROR_BADSTEREO:	 return ("incompatible block_type for JS");
		default:;
	}

	sprintf(str, "error 0x%04x", error);
	return str;
}


/* utility to scale and round samples to 16 bits */

static inline signed int my_scale(mad_fixed_t sample)
{
	/* round */
	sample += (1L << (MAD_F_FRACBITS - 16));

	/* clip */
	if (sample >= MAD_F_ONE)
		sample = MAD_F_ONE - 1;
	else if (sample < -MAD_F_ONE)
		sample = -MAD_F_ONE;

	/* quantize */
	return sample >> (MAD_F_FRACBITS + 1 - 16);
}


static void fill_buffer(struct mad_local_data *data, long offset)
{
	size_t bytes_read;
	if (data->seekable && offset >= 0) {
		reader_seek(data->mad_fd, data->offset + offset, SEEK_SET);
		bytes_read = reader_read(data->mad_map, MAD_BUFSIZE, data->mad_fd);
		data->bytes_avail = bytes_read;
		data->map_offset = offset;
	} else {	
		memmove(data->mad_map, data->mad_map + MAD_BUFSIZE - data->bytes_avail, data->bytes_avail);
		bytes_read = reader_read(data->mad_map + data->bytes_avail, MAD_BUFSIZE - data->bytes_avail, data->mad_fd);
		data->map_offset += (MAD_BUFSIZE - data->bytes_avail);
		data->bytes_avail += bytes_read;
	}
}

static void mad_init_decoder(struct mad_local_data *data)
{
	if (!data)
		return;

	mad_synth_init  (&data->synth);
	mad_stream_init (&data->stream);
	mad_frame_init  (&data->frame);
}


static int mad_frame_seek(input_object *obj, int frame)
{
	struct mad_local_data *data;
	struct mad_header header;
	int skip;
	ssize_t byte_offset;

	if (!obj)
		return 0;
	data = (struct mad_local_data *)obj->local_data;

	if (!data || !data->seekable)
		return 0;

	//alsaplayer_error("frame_seek(..., %d)", frame);
	mad_header_init(&header);

	data->bytes_avail = 0;
	if (frame <= data->highest_frame) {
		skip = 0;

		if (frame > 4) {
			skip = 3;
		}
		byte_offset = data->frames[frame-skip];

		/* Prepare the buffer for a read */
		fill_buffer(data, byte_offset);
		mad_stream_buffer(&data->stream, data->mad_map, data->bytes_avail);
		skip++;
		while (skip != 0) {
			skip--;

			mad_frame_decode(&data->frame, &data->stream);
			if (skip == 0)
				mad_synth_frame (&data->synth, &data->frame);
		}
		data->bytes_avail = data->stream.bufend - 
			data->stream.next_frame;
		data->current_frame = frame;
		data->seeking = 0;
		return data->current_frame;
	}

	data->seeking = 1;
	fill_buffer(data, data->frames[data->highest_frame]);
	mad_stream_buffer(&data->stream, data->mad_map, data->bytes_avail);
	while (data->highest_frame < frame) {
		if (data->bytes_avail < 3072) {
			fill_buffer(data, data->map_offset + MAD_BUFSIZE - data->bytes_avail);
			mad_stream_buffer(&data->stream, data->mad_map, data->bytes_avail);
		}	
		if (mad_header_decode(&header, &data->stream) == -1) {
			if (!MAD_RECOVERABLE(data->stream.error)) {
				fill_buffer(data, 0);
				mad_stream_buffer(&data->stream, data->mad_map, data->bytes_avail);
				data->seeking = 0;
				return 0;
			}				
		}
		data->frames[++data->highest_frame] =
			data->map_offset + data->stream.this_frame - data->mad_map;
		data->bytes_avail = data->stream.bufend - data->stream.next_frame;
	}

	data->current_frame = data->highest_frame;
	if (data->current_frame > 4) {
		skip = 3;
		fill_buffer(data, data->frames[data->current_frame-skip]);
		mad_stream_buffer(&data->stream, data->mad_map, data->bytes_avail);
		skip++;
		while (skip != 0) { 
			skip--;
			mad_frame_decode(&data->frame, &data->stream);
			if (skip == 0) 
				mad_synth_frame (&data->synth, &data->frame);
			data->bytes_avail = data->stream.bufend -
				data->stream.next_frame;
		}
	}

	data->seeking = 0;
	return data->current_frame;

	return 0;
}

static int mad_frame_size(input_object *obj)
{
	if (!obj || !obj->frame_size) {
		puts("No frame size!");
		return 0;
	}
	return obj->frame_size;
}


/* #define MAD_DEBUG */

static int mad_play_frame(input_object *obj, char *buf)
{
	struct mad_local_data *data;
	struct mad_pcm *pcm;
	mad_fixed_t const *left_ch;
	mad_fixed_t const *right_ch;
	int16_t	*output;
	int nsamples;
	int nchannels;

	if (!obj)
		return 0;
	data = (struct mad_local_data *)obj->local_data;
	if (!data)
		return 0;
	if (data->bytes_avail < 3072) {
		/*
		   alsaplayer_error("Filling buffer = %d,%d",
		   data->bytes_avail,
		   data->map_offset + MAD_BUFSIZE - data->bytes_avail);
		   */
		fill_buffer(data, -1); /* data->map_offset + MAD_BUFSIZE - data->bytes_avail); */
		mad_stream_buffer(&data->stream, data->mad_map, data->bytes_avail);
	} else {
		/* alsaplayer_error("bytes_avail = %d", data->bytes_avail); */
	}
	if (mad_frame_decode(&data->frame, &data->stream) == -1) {
		if (!MAD_RECOVERABLE(data->stream.error)) {
			/*
			   alsaplayer_error("MAD error: %s (%d). fatal", 
			   error_str(data->stream.error, data->str),
			   data->bytes_avail);
			   */	
			mad_frame_mute(&data->frame);
			return 0;
		} else {
			if (reader_eof(data->mad_fd)) {
				return 0;
			}	
			//alsaplayer_error("MAD error: %s (not fatal)", error_str(data->stream.error, data->str)); 
			memset(buf, 0, obj->frame_size);
			return 1;
		}
	}
	data->current_frame++;
	if (data->seekable && data->current_frame < (obj->nr_frames + FRAME_RESERVE)) {
		data->frames[data->current_frame] = 
			data->map_offset + data->stream.this_frame - data->mad_map;
		if (data->current_frame > 3 && 
				(data->frames[data->current_frame] -
				 data->frames[data->current_frame-3]) < 6) {
			return 0;
		}		
		if (data->highest_frame < data->current_frame)
			data->highest_frame = data->current_frame;
	}				

	mad_synth_frame (&data->synth, &data->frame);

	{
		pcm = &data->synth.pcm;
		output = (int16_t *)buf;
		nsamples = pcm->length;
		nchannels = pcm->channels;
		if (nchannels != obj->nr_channels) {
			alsaplayer_error("ERROR: bad data stream! (channels: %d != %d, frame %d)",
					nchannels, 
					obj->nr_channels,
					data->current_frame);
			mad_frame_mute(&data->frame);
			memset(buf, 0, obj->frame_size);
			return 1;
		}	
		obj->nr_channels = nchannels;
		if (data->samplerate != data->frame.header.samplerate) {
			alsaplayer_error("ERROR: bad data stream! (samplerate: %d != %d, frame %d)",
					data->samplerate, 
					data->frame.header.samplerate,
					data->current_frame);
			mad_frame_mute(&data->frame);
			memset(buf, 0, obj->frame_size);
			return 1;
		}	
		data->samplerate = data->frame.header.samplerate;
		left_ch = pcm->samples[0];
		right_ch = pcm->samples[1];
		while (nsamples--) {
			*output++ = my_scale(*(left_ch++));
			if (nchannels == 1) {
				*output++ = my_scale(*(left_ch-1));
			} else { /* nchannels == 2 */
				*output++ = my_scale(*(right_ch++));
			}	

		}
	}
	data->bytes_avail = data->stream.bufend - data->stream.next_frame;
	return 1;
}


static  long mad_frame_to_sec(input_object *obj, int frame)
{
	struct mad_local_data *data;
	unsigned long sec = 0;

	if (!obj)
		return 0;
	data = (struct mad_local_data *)obj->local_data;
	if (data) {
		sec = data->samplerate ? frame * (obj->frame_size >> 2) /
			(data->samplerate / 100) : 0;
	}			
	return sec;
}


static int mad_nr_frames(input_object *obj)
{
	if (!obj)
		return 0;
	return obj->nr_frames;
}

/* TODO: Move all id3 code into the separated file. */

/* Strip spaces from right to left */
static void rstrip (char *s) {
	int len = strlen (s);

	while (len && s[len-1] == ' ') {
		len --;
		s[len] = '\0';
	}
}

/* Convert from synchsafe integer */
static unsigned int from_synchsafe4 (const char *buf)
{
	return (buf [3]) + (buf [2] << 7) + (buf [1] << 14) + (buf [0] << 21);
}

static unsigned int from_synchsafe3 (const char *buf)
{
	return (buf [2]) + (buf [1] << 7) + (buf [0] << 14);
}

/* Fill filed */
static void fill_from_id3v2 (char *dst, const char *src, int max, int size)
{
	// it can be iso8851-1==0 utf16==1 utf16be==2 and utf8==3
	if ((*src < 0) || (*src > 3))
		return;

	char *conv = NULL;
	
#ifdef HAVE_GLIB2
	if (*src == 0)
		conv = g_convert(src+1, (gssize) size-1, "UTF-8", "ISO-8859-1", NULL, NULL, NULL); // gsti: size -1
	else if (*src == 1)
		conv = g_convert(src+1, (gssize) size-1, "UTF-8", "UTF-16", NULL, NULL, NULL);
	else if (*src == 2)
		conv = g_convert(src+1, (gssize) size-1, "UTF-8", "UTF-16BE", NULL, NULL, NULL);
 	else
		conv = g_strndup(src+1, size);
#else
	alsaplayer_error ("Warning: Without glib2 you get different encodings.");
	conv = strndup(src+1, size);
#endif
	
	if (!conv)	// convert error
		return;
	
	int min = strlen(conv) > max ? max : strlen(conv);	// gsti
	strncpy (dst, conv, min);
	
	if (min == max)	// gsti
		dst[min-1] = 0;
		
	if (conv)
		free(conv);
	
}

static char *genres[] = {
	"Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge",
	"Hip-Hop", "Jazz", "Metal", "New Age", "Oldies", "Other", "Pop", "R&B",
	"Rap", "Reggae", "Rock", "Techno", "Industrial", "Alternative", "Ska",
	"Death Metal", "Pranks", "Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop",
	"Vocal", "Jazz+Funk", "Fusion", "Trance", "Classical", "Instrumental",
	"Acid", "House", "Game", "Sound Clip", "Gospel", "Noise", "AlternRock",
	"Bass", "Soul", "Punk", "Space", "Meditative", "Instrumental Pop",
	"Instrumental Rock", "Ethnic", "Gothic", "Darkwave", "Techno-industrial",
	"Electronic", "Pop-Folk", "Eurodance", "Dream", "Southern Rock", "Comedy",
	"Cult", "Gangsta", "Top 40", "Christian Rap", "Pop/Funk", "Jungle",
	"Native American", "Cabaret", "New Wave", "Psychadelic", "Rave",
	"Showtunes", "Trailer", "Lo-Fi", "Tribal", "Acid Punk", "Acid Jazz",
	"Polka", "Retro", "Musical", "Rock & Roll", "Hard Rock", "Folk",
	"Folk/Rock", "National Folk", "Swing", "Fast-Fusion", "Bebob", "Latin",
	"Revival", "Celtic", "Bluegrass", "Avantegarde", "Gothic Rock",
	"Progressive Rock", "Psychedelic Rock", "Symphonic Rock", "Slow Rock",
	"Big Band", "Chorus", "Easy Listening", "Acoustic", "Humour", "Speech",
	"Chanson", "Opera", "Chamber Music", "Sonata", "Symphony", "Booty Bass",
	"Primus", "Porn Groove", "Satire", "Slow Jam", "Club", "Tango", "Samba",
	"Folklore", "Ballad", "Power Ballad", "Rythmic Soul", "Freestyle", "Duet",
	"Punk Rock", "Drum Solo", "A capella", "Euro-House", "Dance Hall", "Goa",
	"Drum & Bass", "Club House", "Hardcore", "Terror", "Indie", "BritPop",
	"NegerPunk", "Polsk Punk", "Beat", "Christian Gangsta", "Heavy Metal",
	"Black Metal", "Crossover", "Contemporary C", "Christian Rock", "Merengue",
	"Salsa", "Thrash Metal", "Anime", "JPop", "SynthPop"};

/* Trying to fill info from id3 tagged file */
static void parse_id3 (const char *path, stream_info *info)
{
	void *fd;
	char buf [2024];
	unsigned char g;

	/* Open stream */
	fd = reader_open (path, NULL, NULL);
	if (!fd)  return;

	/* --------------------------------------------------- */
	/* Trying to load id3v2 tags                           */
	if (reader_read (buf, 10, fd) != 10) {
		reader_close (fd);
		return;
	}

	if (memcmp(buf, "ID3", 3) == 0) {
		/* Parse id3v2 tags */

		/* Header */
		unsigned char major_version = buf [3];
		int f_unsynchronization = buf [5] & (1<<7);
		int f_extended_header = buf [5] & (1<<6);
		int f_experimental = buf [5] & (1<<5);
		int header_size = from_synchsafe4 (buf + 6);
		int name_size = buf [3] == 2 ? 3 : 4;
		int ext_size = 0;
		
		if (f_extended_header) {
//			alsaplayer_error ("FIXME: Extended header found in mp3."
//					"Please contact alsaplayer team.\n"
//					"Filename: %s", path);
	//		reader_close (fd);
	//		return;
			ext_size = 1;	//stupid but should do
		}

		if (f_unsynchronization) {
			alsaplayer_error ("FIXME: f_unsynchronization is set."
					"Please contact alsaplayer team.\n"
					"Filename: %s", path);
			reader_close (fd);
			return;
		}

		if (f_experimental) {
			alsaplayer_error ("FIXME: f_experimental is set."
					"Please contact alsaplayer team.\n"
					"Filename: %s", path);
			reader_close (fd);
			return;
		}

			if (ext_size) {
				char b[4];
				if (reader_read (b, 4, fd) != 4) {
						reader_close(fd);
						return;
				}
				if (major_version == 2)
					ext_size = from_synchsafe3 (b);
				else
					ext_size = from_synchsafe4 (b);
				
				if (reader_seek (fd, ext_size - 4, SEEK_CUR) < 0) {
					reader_close (fd);
					return;
				}
			
			}
			
		/* -- -- read frames -- -- */
		while (reader_tell (fd) <= header_size + 10) {
			unsigned int size = 0;
			
			
			/* Get name of this frame */
			if (reader_read (buf, name_size, fd) != (unsigned)name_size) {
				reader_close (fd);
				return;
			}

			if (buf [0] == '\0')  break;
			if (buf [0] < 'A')  break;
			if (buf [0] > 'Z')  break;

			/* Get size */
			if (major_version == 2) {
				char sb [3];

				if (reader_read (sb, 3, fd) != 3) {
					reader_close (fd);
					return;
				}

				size = from_synchsafe3 (sb);
			} else {
				char sb [4];

				if (reader_read (sb, 4, fd) != 4) {
					reader_close (fd);
					return;
				}

				size = from_synchsafe4 (sb);
			}

			/* skip frame flags */
//			if (reader_seek (fd, 1, SEEK_CUR) == -1) {
//				reader_close (fd);
//				return;
//			}

			int start = 0;		
			// read them
			char b[2];
			if (reader_read (b, 2, fd) != 2) {
				reader_close (fd);
				return;
			} else {
			
				if (b[1] & (1 << 6)) {
//					printf ("Grouping added\n");
					start++;
				}
				if (b[1] & (1 << 3)) {
//					printf ("Compression added\n");
				}
				if (b[1] & (1 << 2)) {
//					printf ("Encryption added\n");
				}
				if (b[1] & (1 << 1)) {
//					printf ("Unsynch added\n");
				}
				if (b[1] & (1 << 0)) {
//					printf ("Length added\n");
					start+=4;
				}	
			}
				
				
				
			if (size>=1024) {
				/* I will not support such long tags...
				 * Only if someone ask for it...
				 * not now... */

				if (reader_seek (fd, size, SEEK_CUR) == -1) {
					reader_close (fd);
					return;
				}

				continue;
			}


			/* read info */
			if (reader_read (buf + name_size, size, fd) != size) {
				reader_close (fd);
				return;
			}
			/* make sure buffer is zero-terminated for sscanf */
			buf[name_size + size] = 0;

			/* !!! Ok. There we have frame name and data. */
			/* Lets use it. */
			if (name_size == 4) {
				if (memcmp (buf, "TIT2", 4)==0)
					fill_from_id3v2 (info->title, buf + name_size + start,
							sizeof (info->title), size - start);
				else if (memcmp (buf, "TPE1", 4)==0)
					fill_from_id3v2 (info->artist, buf + name_size + start,
							sizeof (info->artist), size - start);
				else if (memcmp (buf, "TALB", 4)==0)
					fill_from_id3v2 (info->album, buf + name_size + start,
							sizeof (info->album), size - start);
				else if (memcmp (buf, "TYER", 4)==0)
					fill_from_id3v2 (info->year, buf + name_size + start,
							sizeof (info->year), size - start);
				else if (memcmp (buf, "COMM", 4)==0)
					fill_from_id3v2 (info->comment, buf + name_size + start,
							sizeof (info->comment), size - start);
				else if (memcmp (buf, "TRCK", 4)==0)
					fill_from_id3v2 (info->track, buf + name_size + start,
							sizeof (info->track), size - start);
				else if (memcmp (buf, "TCON", 4)==0) {
					/* Genre */
					/* TODO: Optimize duplicated code */
					unsigned int gindex;

					if (sscanf (buf + name_size + start +1, "(%u)", &gindex)==1) {
						if (gindex==255)
							*info->genre = '\0';
						else if (sizeof (genres)/sizeof(char*) <= gindex)
							snprintf (info->genre, sizeof (info->genre), "(%u)", gindex);
						else
							snprintf (info->genre, sizeof (info->genre), "%s", genres[gindex]);
					} else
						fill_from_id3v2 (info->genre, buf + name_size + start,
								sizeof (info->genre), size - start);
				}
			} /* end of 'if name_size == 4' */

		} /* end of frames read */

		/* end parsing */
		reader_close (fd);
		return;
	} /* end of id3v2 parsing */

	/* --------------------------------------------------- */
	/* Trying to load id3v1 tags                           */
	if (reader_seek (fd, -128, SEEK_END) == -1) {
		reader_close (fd);
		return;
	}

	if (reader_read (buf, 128, fd) != 128) {
		reader_close (fd);
		return;
	}

	if (memcmp(buf, "TAG", 3) == 0) {
		/* ID3v1 frame found */

		/* title */
		strncpy (info->title, buf + 3, 30);
		rstrip (info->title);

		/* artist */
		strncpy (info->artist, buf + 33, 30);
		rstrip (info->artist);

		/* album */
		strncpy (info->album, buf + 63, 30);
		rstrip (info->album);

		/* year */
		strncpy (info->year, buf + 93, 4);
		rstrip (info->year);

		/* comment */
		strncpy (info->comment, buf + 97, 28);
		rstrip (info->comment);

		/* track number */
		if (buf [125] == '\0')
			snprintf (info->track, sizeof (info->track), "%u", buf [126]);

		/* genre */
		g = buf [127];
		if (g==255)
			*info->genre = '\0';
		else if (sizeof (genres)/sizeof(char*) <= g)
			snprintf (info->genre, sizeof (info->genre), "(%u)", g);
		else
			snprintf (info->genre, sizeof (info->genre), "%s", genres[g]);
	} /* end of id3v1 parsing */

	reader_close (fd);
}

static int mad_stream_info(input_object *obj, stream_info *info)
{
	struct mad_local_data *data;	
	unsigned len;
	char metadata[256];
	char *s, *p;

	if (!obj || !info)
		return 0;

	data = (struct mad_local_data *)obj->local_data;

	if (data) {
		if (!data->parse_id3) {
			sprintf(data->sinfo.title, "%s", data->filename);
		} else if (!data->parsed_id3) {
			if (reader_seekable(data->mad_fd)) {
				parse_id3 (data->path, &data->sinfo);
				if ((len = strlen(data->sinfo.title))) {
					s = data->sinfo.title + (len - 1);
					while (s != data->sinfo.title && *s == ' ')
						*(s--) = '\0';
				}
				if ((len = strlen(data->sinfo.artist))) {
					s = data->sinfo.artist + (len - 1);
					while (s != data->sinfo.artist && *s == ' ')
						*(s--) = '\0';
				}
			}
			strncpy (data->sinfo.path, data->path, sizeof(data->sinfo.path));
			data->parsed_id3 = 1;
		}
		memset(metadata, 0, sizeof(metadata));
		if ((len = reader_metadata(data->mad_fd, sizeof(metadata), metadata))) {
			//alsaplayer_error("Metadata: %s", metadata);
			if ((s = strstr(metadata, "StreamTitle='"))) {
				s += 13;
				if ((p = strstr(s, "'"))) {
					*p = '\0';
					snprintf(data->sinfo.title, 128, "%s", s);
				} else {
					alsaplayer_error("Malformed metadata: \"%s\"", metadata);
				}
			}
		}	
		/* Restore permanently filled info */
		memcpy (info, &data->sinfo, sizeof (data->sinfo));

		/* Compose path, stream_type and status fields */
		sprintf(info->stream_type, "MP3 %dKHz %s %-3ldkbit",
				data->frame.header.samplerate / 1000,
				obj->nr_channels == 2 ? "stereo" : "mono",
				data->frame.header.bitrate / 1000);

		if (data->seeking)
			sprintf(info->status, "Seeking...");
	}				
	return 1;
}


static int mad_sample_rate(input_object *obj)
{
	struct mad_local_data *data;

	if (!obj)
		return 44100;
	data = (struct mad_local_data *)obj->local_data;
	if (data)	
		return data->samplerate;
	return 44100;
}

static int mad_init(void) 
{
	return 1;
}		


static int mad_channels(input_object *obj)
{
	struct mad_local_data *data;

	if (!obj)
		return 2; /* Default to 2, this is flaky at best! */
	data = (struct mad_local_data *)obj->local_data;

	return obj->nr_channels;
}


static float mad_can_handle(const char *path)
{
	char *ext;      
	ext = strrchr(path, '.');

	if (strncmp(path, "http://", 7) == 0)
		return 0.5;
	if (!ext)
		return 0.0;
	ext++;
	if (!strcasecmp(ext, "mp3") ||
			!strcasecmp(ext, "mp2")) {
		return 0.9;
	} else {
		return 0.0;
	}
}


static ssize_t find_initial_frame(uint8_t *buf, int size)
{
	uint8_t *data = buf;			
	int ext_header = 0;
	int pos = 0;
	ssize_t header_size = 0;
	while (pos < (size - 10)) {
		if (pos == 0 && data[pos] == 0x0d && data[pos+1] == 0x0a)
			pos += 2;
		if (data[pos] == 0xff && (data[pos+1] == 0xfb
					|| data[pos+1] == 0xfa
					|| data[pos+1] == 0xf3 
					|| data[pos+1] == 0xf2
					|| data[pos+1] == 0xe2
					|| data[pos+1] == 0xe3)) {
			return pos;
		}	
		if (pos == 0 && data[pos] == 0x0d && data[pos+1] == 0x0a) {
			return -1; /* Let MAD figure this out */
		}	
		if (pos == 0 && (data[pos] == 'I' && data[pos+1] == 'D' && data[pos+2] == '3')) {
			header_size = (data[pos + 6] << 21) + 
				(data[pos + 7] << 14) +
				(data[pos + 8] << 7) +
				data[pos + 9]; /* syncsafe integer */
			if (data[pos + 5] & 0x10) {
				ext_header = 1;
				header_size += 10; /* 10 byte extended header */
			}
			/* printf("ID3v2.%c detected with header size %d (at pos %d)\n",  0x30 + data[pos + 3], header_size, pos); */
			if (ext_header) {
				/* printf("Extended header detected\n"); */
			}
			header_size += 10;

			if (header_size > STREAM_BUFFER_SIZE) {
				//alsaplayer_error("Header larger than 32K (%d)", header_size);
				return header_size;
			}	
			return header_size;
		} else if (data[pos] == 'R' && data[pos+1] == 'I' &&
				data[pos+2] == 'F' && data[pos+3] == 'F') {
			pos+=4;
			/* alsaplayer_error("Found a RIFF header"); */
			while (pos < size) {
				if (data[pos] == 'd' && data[pos+1] == 'a' &&
						data[pos+2] == 't' && data[pos+3] == 'a') {
					pos += 8; /* skip 'data' and ignore size */
					return pos;
				} else
					pos++;
			}
			puts("MAD debug: invalid header");
			return -1;
		} else if (pos == 0 && data[pos] == 'T' && data[pos+1] == 'A' && 
				data[pos+2] == 'G') {
			return 128;	/* TAG is fixed 128 bytes, we assume! */
		}  else {
			pos++;
		}				
	}
	alsaplayer_error(
			"MAD debug: potential problem file or unhandled info block\n"
			"next 4 bytes =  %x %x %x %x (index = %d, size = %d)\n",
			data[header_size], data[header_size+1],
			data[header_size+2], data[header_size+3],
			(int)header_size, size);
	return -1;
}


static void reader_status(void *ptr, const char *str)
{
	input_object *obj = (input_object *)ptr;
	struct mad_local_data *data;

	if (!obj)
		return;
	data = (struct mad_local_data *)obj->local_data;

	if (data) {
		//fprintf(stdout, "%s     \r", str);
		//fflush(stdout);
		strcpy(data->sinfo.status, str);
	}	
}


static int mad_open(input_object *obj, const char *path)
{
	struct mad_local_data *data;
	char *p;
	int mode;

	if (!obj)
		return 0;

	obj->local_data = malloc(sizeof(struct mad_local_data));
	if (!obj->local_data) {
		puts("failed to allocate local data");
		return 0;
	}
	data = (struct mad_local_data *)obj->local_data;
	memset(data, 0, sizeof(struct mad_local_data));

	if ((data->mad_fd = reader_open(path, &reader_status, obj)) == NULL) {
		fprintf(stderr, "mad_open(obj, %s) failed\n", path);
		free(obj->local_data);
		obj->local_data = NULL;
		return 0;
	}
	obj->flags = 0;

	if (strncasecmp(path, "http://", 7) == 0) {
		obj->flags |= P_STREAMBASED;
		strcpy(data->sinfo.status, "Prebuffering");
	} else {
		obj->flags |= P_FILEBASED;
	}
	if (!reader_seekable(data->mad_fd)) {
		data->seekable = 0;
	} else {
		obj->flags |= P_SEEK;
		obj->flags |= P_PERFECTSEEK;
		data->seekable = 1;
	}
	obj->flags |= P_REENTRANT;

	mad_init_decoder(data);
	memset(&data->xing, 0, sizeof(struct xing));
	xing_init (&data->xing);
	data->mad_init = 1;
	fill_buffer(data, -1);
	//alsaplayer_error("initial bytes_avail = %d", data->bytes_avail);
	if (obj->flags & P_PERFECTSEEK) {
		data->offset = find_initial_frame(data->mad_map, 
				data->bytes_avail < STREAM_BUFFER_SIZE ? data->bytes_avail :
				STREAM_BUFFER_SIZE);
	} else {
		data->offset = 0;
	}	
	data->highest_frame = 0;
	if (data->offset < 0) {
		//fprintf(stderr, "mad_open() couldn't find valid MPEG header\n");
		data->offset = 0;
	}
	//alsaplayer_error("data->offset = %d", data->offset);
	if (data->offset > data->bytes_avail) {
		data->seekable = 1;
		//alsaplayer_error("Need to refill buffer (data->offset = %d)", data->offset);
		fill_buffer(data, 0);
		mad_stream_buffer(&data->stream, data->mad_map, data->bytes_avail);
	} else {
		mad_stream_buffer(&data->stream, data->mad_map + data->offset,
				data->bytes_avail - data->offset);
		data->bytes_avail -= data->offset;
	}	
first_frame:

	if ((mad_header_decode(&data->frame.header, &data->stream) == -1)) {
		switch (data->stream.error) {
			case MAD_ERROR_BUFLEN:
				return 0;
			case MAD_ERROR_LOSTSYNC:
			case MAD_ERROR_BADEMPHASIS:
			case MAD_ERROR_BADBITRATE:
			case MAD_ERROR_BADLAYER:	
			case MAD_ERROR_BADSAMPLERATE:	
				//alsaplayer_error("Error %x (frame %d)", data->stream.error, data->current_frame);
				data->bytes_avail-=(data->stream.next_frame - data->stream.this_frame);
				goto first_frame;
				break;
			case MAD_ERROR_BADBITALLOC:
				return 0;
			case MAD_ERROR_BADCRC:
				alsaplayer_error("MAD_ERROR_BADCRC: %s", error_str(data->stream.error, data->str));
			case MAD_ERROR_BADBIGVALUES:
			case MAD_ERROR_BADDATAPTR:
				break;
			default:
				alsaplayer_error("ERROR: %s", error_str(data->stream.error, data->str));
				alsaplayer_error("No valid frame found at start (pos: %d, error: 0x%x --> %x %x %x %x) (%s)", data->offset, data->stream.error, 
						data->stream.this_frame[0],
						data->stream.this_frame[1],
						data->stream.this_frame[2],
						data->stream.this_frame[3],path);
				return 0;
		}
	}

	mad_frame_decode(&data->frame, &data->stream);
	/*	
		alsaplayer_error("xing parsing...%x %x %x %x (%x %d)", 
		data->stream.this_frame[0], data->stream.this_frame[1],
		data->stream.this_frame[2], data->stream.this_frame[3],
		data->stream.anc_ptr, data->stream.anc_bitlen);
		*/		
	if (xing_parse(&data->xing, data->stream.anc_ptr, data->stream.anc_bitlen) == 0) {
		// We use the xing data later on
	}

	mode = (data->frame.header.mode == MAD_MODE_SINGLE_CHANNEL) ?
		1 : 2;
	data->samplerate = data->frame.header.samplerate;
	data->bitrate	= data->frame.header.bitrate;
	mad_synth_frame (&data->synth, &data->frame);
	{
		struct mad_pcm *pcm = &data->synth.pcm;			

		obj->nr_channels = pcm->channels;
		//alsaplayer_error("nr_channels = %d", obj->nr_channels);
	}
	//alsaplayer_error("Initial: %d, %d, %d", data->samplerate, data->bitrate, obj->nr_channels);
	/* Calculate some values */
	data->bytes_avail = data->stream.bufend - data->stream.next_frame;
	{
		int64_t time;
		int64_t samples;
		int64_t frames;

		long oldpos = reader_tell(data->mad_fd);
		reader_seek(data->mad_fd, 0, SEEK_END);

		data->filesize = reader_tell(data->mad_fd);
		data->filesize -= data->offset;

		reader_seek(data->mad_fd, oldpos, SEEK_SET);
		if (data->bitrate)
			time = (data->filesize * 8) / (data->bitrate);
		else
			time = 0;

		samples = 32 * MAD_NSBSAMPLES(&data->frame.header);

		obj->frame_size = (int) samples << 2; /* Assume 16-bit stereo */
		frames = data->samplerate * (time+1) / samples;
		if (data->xing.flags & XING_FRAMES) {
			obj->nr_frames = data->xing.frames;
		} else {	
			obj->nr_frames = (int) frames;
		}	
		obj->nr_tracks = 1;
	}
	/* Determine if nr_frames makes sense */
	if (!(obj->flags & P_SEEK) && (obj->flags & P_STREAMBASED)) {
		obj->nr_frames = -1;
	}	

	/* Allocate frame index */
	if (!data->seekable  || obj->nr_frames > 1000000 ||
			(data->frames = (ssize_t *)malloc((obj->nr_frames + FRAME_RESERVE) * sizeof(ssize_t))) == NULL) {
		data->seekable = 0; // Given really
	}	else {
		data->seekable = 1;
		data->frames[0] = 0;
	}	
	data->mad_init = 1;

	p = strrchr(path, '/');
	if (p) {
		strcpy(data->filename, ++p);
	} else {
		strcpy(data->filename, path);
	}
	strcpy(data->path, path);

	data->parse_id3 = prefs_get_bool(ap_prefs, "mad", "parse_id3", 1);

	return 1;
}


static void mad_close(input_object *obj)
{
	struct mad_local_data *data;
	if (!obj)
		return;
	data = (struct mad_local_data *)obj->local_data;

	if (data) {
		if (data->mad_fd)
			reader_close(data->mad_fd);
		if (data->mad_init) {
			mad_synth_finish (&data->synth);
			mad_frame_finish (&data->frame);
			mad_stream_finish(&data->stream);
			data->mad_init = 0;
		}
		if (data->frames) {
			free(data->frames);
		}				
		free(obj->local_data);
		obj->local_data = NULL;
	}				
}


static void mad_shutdown(void)
{
	return;
}


static input_plugin mad_plugin;

#ifdef __cplusplus
extern "C" {
#endif

input_plugin *input_plugin_info (void)
{
	memset(&mad_plugin, 0, sizeof(input_plugin));
	mad_plugin.version = INPUT_PLUGIN_VERSION;
	mad_plugin.name = "MAD MPEG audio plugin v1.01";
	mad_plugin.author = "Andy Lo A Foe";
	mad_plugin.init = mad_init;
	mad_plugin.shutdown = mad_shutdown;
	mad_plugin.can_handle = mad_can_handle;
	mad_plugin.open = mad_open;
	mad_plugin.close = mad_close;
	mad_plugin.play_frame = mad_play_frame;
	mad_plugin.frame_seek = mad_frame_seek;
	mad_plugin.frame_size = mad_frame_size;
	mad_plugin.nr_frames = mad_nr_frames;
	mad_plugin.frame_to_sec = mad_frame_to_sec;
	mad_plugin.sample_rate = mad_sample_rate;
	mad_plugin.channels = mad_channels;
	mad_plugin.stream_info = mad_stream_info;
	return &mad_plugin;
}

#ifdef __cplusplus
}
#endif
