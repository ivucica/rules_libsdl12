/*  AlsaNode.h
 *  Copyright (C) 1998-2002 Andy Lo A Foe <andy@alsaplayer.org>
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
 *
 *  $Id: AlsaNode.h 1319 2007-11-04 07:27:40Z peter_lemenkov $
 * 
*/ 

#ifndef __AlsaNode_h__
#define __AlsaNode_h__

#ifdef __linux__
#define USE_REALTIME
#endif

#define OUTPUT_RATE 44100

#include <stdio.h>
#include <string.h>
#include <pthread.h>

#include "output_plugin.h"

#define MAX_OUTPUT_PLUGINS	32
#define MAX_SUB	32

#define POS_BEGIN		0x0
#define POS_MIDDLE	0x1
#define POS_END			0x2

typedef bool(*streamer_type)(void *arg, void *buf, int size);

typedef struct _subscriber
{
	int ID;
	streamer_type streamer;
	bool active;
	void *arg;
} subscriber;

class AlsaNode
{
 private:
	output_plugin plugins[MAX_OUTPUT_PLUGINS];
	output_plugin *plugin;
	int plugin_count;
	subscriber subs[MAX_SUB]; 
	pthread_mutex_t queue_mutex; 
	pthread_mutex_t thread_mutex;
	void *handle;
	int count;
	int follow_id; 
	int fragment_size;
	int nr_fragments;
	int sample_freq;
	int external_latency;
	char *driver_name;
	char *driver_args;
	char client_name[32];
	bool realtime_sched;
	bool thread_running;
	bool init;
	bool looping;
	static void looper(void *);
	pthread_t looper_thread;
 public:		
	AlsaNode(const char *name, const char *args, int realtime=0);
	~AlsaNode();
	int SetSamplingRate(int freq);
	int SamplingRate() { return sample_freq; }
	int SetStreamBuffers(int frag_size, int count, int channels);
	int RegisterPlugin(output_plugin *the_plugin);
	int RegisterPlugin(const char *plugin = NULL);
	int GetLatency();
	int GetFragmentSize() { return fragment_size; }
	void StartStreaming();
	void StopStreaming();
	bool IsInStream(int);
	int AddStreamer(streamer_type str, void *arg, int);
	bool RemoveStreamer(int);
	bool ReadyToRun();
};


#endif
