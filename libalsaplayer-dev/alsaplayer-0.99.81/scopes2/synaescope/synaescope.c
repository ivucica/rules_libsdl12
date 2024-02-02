/*  synaescope.c
 *  Copyright (C) 1999 Richard Boulton <richard@tartarus.org>
 *  Further support (C) 2002 Andy Lo A Foe <andy@alsaplayer.org>
 *
 *  Much code copied from Synaesthesia - a program to display sound
 *  graphically, by Paul Francis Harrison <pfh@yoyo.cc.monash.edu.au>
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
*/ 
#include <pthread.h>
#include <dirent.h>
#include <sys/stat.h>
#include <gtk/gtk.h>
#include <sys/time.h>
#include <time.h>   
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "scope_config.h"
#include "prefs.h"

#define FFT_BUFFER_SIZE_LOG 8 
#define FFT_BUFFER_SIZE (1 << FFT_BUFFER_SIZE_LOG)
typedef short int sound_sample;

#define syn_width 320
#define syn_height 200
#define brightMin 200
#define brightMax 2000
#define brightDec 10 
#define brightInc 6
#define brTotTargetLow 5000
#define brTotTargetHigh 15000

static int autobrightness = 1;  /* Whether to use automatic brightness adjust */
static unsigned int brightFactor = 400;
static unsigned char output[syn_width * syn_height * 2];
static sound_sample pcmt_l[FFT_BUFFER_SIZE];
static sound_sample pcmt_r[FFT_BUFFER_SIZE];
static sound_sample pcm_l[FFT_BUFFER_SIZE];
static sound_sample pcm_r[FFT_BUFFER_SIZE];
static double fftout_l[FFT_BUFFER_SIZE];
static double fftout_r[FFT_BUFFER_SIZE];
static double fftmult[FFT_BUFFER_SIZE / 2 + 1];
static double corr_l[FFT_BUFFER_SIZE];
static double corr_r[FFT_BUFFER_SIZE];
static int clarity[FFT_BUFFER_SIZE]; /* Surround sound */
static double cosTable[FFT_BUFFER_SIZE];
static double negSinTable[FFT_BUFFER_SIZE];
static int bitReverse[FFT_BUFFER_SIZE];
static int scaleDown[256];
static GdkImage *image = NULL;
static GtkWidget *scope_win = NULL;
static int ready_state = 0;
static pthread_t synaescope_thread;
static pthread_mutex_t synaescope_mutex;
static int is_init = 0;
static int running = 0;

static void synaescope_hide(void);
static void synaes_fft(double *x, double *y);
static void synaescope_coreGo(void);
static int synaescope_running(void);

static const int default_colors[] = {
    10, 20, 30,
    230, 220, 210
};


static void synaescope_set_data(void *audio_buffer, int size)
{
	short *sound = (short *)audio_buffer;
	if (!sound) {
			memset(&pcm_l, 0, sizeof(pcm_l));
			memset(&pcm_r, 0, sizeof(pcm_r));
			return;
	}	
	if (running && size > FFT_BUFFER_SIZE * 2) {
		int i;
		sound_sample *newset_l = pcmt_l;
		sound_sample *newset_r = pcmt_r;
		sound += (size / 2 - FFT_BUFFER_SIZE) * 2; /* Use the very latest data */
		for (i=0; i < FFT_BUFFER_SIZE; i++) {
			*(newset_l++) = (sound_sample)(*(sound++));
			*(newset_r++) = (sound_sample)(*(sound++));
		}
	}
}

#define SYNAESCOPE_DOLOOP() \
while (running) { \
    unsigned char *outptr = output; \
    int w; \
\
    synaescope_coreGo(); \
\
    outptr = output; \
    for (w=0; w < syn_width * syn_height; w++) { \
	bits[w] = colEq[(outptr[0] >> 4) + (outptr[1] & 0xf0)]; \
	outptr += 2; \
    } \
\
    GDK_THREADS_ENTER(); \
    gdk_draw_image(win,gc,image,0,0,0,0,-1,-1); \
    gdk_flush(); \
    GDK_THREADS_LEAVE(); \
    dosleep(SCOPE_SLEEP); \
}

static inline void addPixel(unsigned char *output, int x,int y,int br1,int br2) {
  unsigned char *p;
  if (x < 0 || x >= syn_width || y < 0 || y >= syn_height) return;
  
  p = output + x * 2 + y * syn_width * 2;
  if (p[0] < 255 - br1) p[0] += br1; else p[0] = 255;
  if (p[1] < 255 - br2) p[1] += br2; else p[1] = 255;
}

static inline void addPixelFast(unsigned char *p,int br1,int br2) {
  if (p[0] < 255 - br1) p[0] += br1; else p[0] = 255;
  if (p[1] < 255 - br2) p[1] += br2; else p[1] = 255;
}

static void synaescope_coreGo(void) {
  int i,j;
  register unsigned long *ptr;
  register unsigned long *end;
  int heightFactor;
  int actualHeight;
  int heightAdd;
  double brightFactor2;
  long int brtot;

  GDK_THREADS_ENTER();
  memcpy(pcm_l, pcmt_l, sizeof(pcm_l));
  memcpy(pcm_r, pcmt_r, sizeof(pcm_r));
  GDK_THREADS_LEAVE();

  for(i = 0; i < FFT_BUFFER_SIZE; i++) {
    fftout_l[i] = pcm_l[i];
    fftout_r[i] = pcm_r[i];
  }

  synaes_fft(fftout_l,fftout_r);

  for(i=0 +1;i<FFT_BUFFER_SIZE;i++) {
    double x1 = fftout_l[bitReverse[i]];
    double y1 = fftout_r[bitReverse[i]];
    double x2 = fftout_l[bitReverse[FFT_BUFFER_SIZE-i]];
    double y2 = fftout_r[bitReverse[FFT_BUFFER_SIZE-i]];
    double aa,bb;
    corr_l[i] = sqrt(aa= (x1+x2)*(x1+x2) + (y1-y2)*(y1-y2) );
    corr_r[i] = sqrt(bb= (x1-x2)*(x1-x2) + (y1+y2)*(y1+y2) );
    clarity[i] = (int)(
      ( (x1+x2) * (x1-x2) + (y1+y2) * (y1-y2) )/(aa+bb) * 256 );
  }

  /* Asger Alstrupt's optimized 32 bit fade */
  /* (alstrup@diku.dk) */
  ptr = (unsigned long*)output;
  end = (unsigned long*)(output + syn_width * syn_height * 2);
  do {
    /* Bytewize version was: *(ptr++) -= *ptr+(*ptr>>1)>>4; */
    if (*ptr) {

      if (*ptr & 0xf0f0f0f0) {
        *ptr = *ptr - ((*ptr & 0xf0f0f0f0) >> 4) - ((*ptr & 0xe0e0e0e0) >> 5);
      } else {
        *ptr = (*ptr * 14 >> 4) & 0x0f0f0f0f;
            /* Should be 29/32 to be consistent. Who cares. This is totally */
            /* hacked anyway.  */
/*
	unsigned char *subptr = (unsigned char*)(ptr++);
        subptr[0] = (int)subptr[0] * 29 / 32;
        subptr[1] = (int)subptr[0] * 29 / 32;
        subptr[2] = (int)subptr[0] * 29 / 32;
        subptr[3] = (int)subptr[0] * 29 / 32;
*/
      }
    } 
    ptr++;
  } while(ptr < end);

  heightFactor = FFT_BUFFER_SIZE/2 / syn_height + 1;
  actualHeight = FFT_BUFFER_SIZE/2 / heightFactor;
  heightAdd = (syn_height + actualHeight) >> 1;

  /* Correct for window size */
  brightFactor2 = (brightFactor/65536.0/FFT_BUFFER_SIZE)*
      sqrt(actualHeight * syn_width / (320.0*200.0));

  brtot = 0;
  for(i=1;i<FFT_BUFFER_SIZE/2;i++) {
    /* int h = (int)( corr_r[i]*280 / (corr_l[i]+corr_r[i]+0.0001)+20 ); */
    if (corr_l[i] > 0 || corr_r[i] > 0) {
      int h = (int)( corr_r[i] * syn_width / (corr_l[i]+corr_r[i]) );
      /* int h = (int)( syn_width - 1 ); */
      int br1, br2, br = (int)( 
          (corr_l[i]+corr_r[i])*i*brightFactor2 );
      int px = h, 
          py = heightAdd - i / heightFactor;
	  brtot += br;
      br1 = br*(clarity[i]+128)>>8;
      br2 = br*(128-clarity[i])>>8;
      if (br1 < 0) br1 = 0; else if (br1 > 255) br1 = 255;
      if (br2 < 0) br2 = 0; else if (br2 > 255) br2 = 255;
      /* unsigned char *p = output+ h*2+(164-((i<<8)>>FFT_BUFFER_SIZE_LOG))*(syn_width*2);  */

      if (px < 30 || py < 30 || px > syn_width-30 || py > syn_height-30) {
        addPixel(output, px,py,br1,br2);
        for(j=1;br1>0||br2>0;j++,br1=scaleDown[br1],br2=scaleDown[br2]) {
          addPixel(output, px+j,py,br1,br2);
          addPixel(output, px,py+j,br1,br2);
          addPixel(output, px-j,py,br1,br2);
          addPixel(output, px,py-j,br1,br2);
        }
      } else {
        unsigned char *p = output+px*2+py*syn_width*2, *p1=p, *p2=p, *p3=p, *p4=p;
        addPixelFast(p,br1,br2);
        for(;br1>0||br2>0;br1=scaleDown[br1],br2=scaleDown[br2]) {
          p1 += 2;
          addPixelFast(p1,br1,br2);
          p2 -= 2;
          addPixelFast(p2,br1,br2);
          p3 += syn_width * 2;
          addPixelFast(p3,br1,br2);
          p4 -= syn_width * 2;
          addPixelFast(p4,br1,br2);
        }
      }
    }
  }

	/* Apply autoscaling: makes quiet bits brighter, and loud bits
	 * darker, but still keeps loud bits brighter than quiet bits. */
	if(brtot != 0 && autobrightness) {
		long int brTotTarget = brTotTargetHigh;
		if(brightMax != brightMin) {
			brTotTarget -= ((brTotTargetHigh - brTotTargetLow) *
							(brightFactor - brightMin)) /
					       (brightMax - brightMin);
		}
		if(brtot < brTotTarget) {
			brightFactor += brightInc;
			if(brightFactor > brightMax) brightFactor = brightMax;
		} else {
			brightFactor -= brightDec;
			if(brightFactor < brightMin) brightFactor = brightMin;
		}
		/* printf("brtot: %ld\tbrightFactor: %d\tbrTotTarget: %d\n",
			   brtot, brightFactor, brTotTarget); */
	}
}

#define BOUND(x) ((x) > 255 ? 255 : (x))
#define PEAKIFY(x) BOUND((x) - (x)*(255-(x))/255/2)

static void synaescope32(void *data)
{
	guint32 *bits;
	guint32 colEq[256];
	int i;
	GdkWindow *win;
	GdkColormap *c;
	GdkVisual *v;
	GdkGC *gc;
	GdkColor bg_color;
	
	win = (GdkWindow *)data;
	GDK_THREADS_ENTER();
	c = gdk_colormap_get_system();
	gc = gdk_gc_new(win);
	v = gdk_window_get_visual(win);

	for (i = 0; i < 256; i++) {
		GdkColor color;
		color.red = PEAKIFY((i&15*16)) << 8;
		color.green = PEAKIFY((i&15)*16+(i&15*16)/4) << 8;
		color.blue = PEAKIFY((i&15)*16) << 8;
	        gdk_color_alloc(c, &color);
		colEq[i] = color.pixel; 
  	}

	/* Create render image */
	if (image) {
		gdk_image_destroy(image);
		image = NULL;
	}
	image = gdk_image_new(GDK_IMAGE_FASTEST, v, syn_width, syn_height);
	bg_color.red = SCOPE_BG_RED << 8;
	bg_color.green = SCOPE_BG_GREEN << 8;
	bg_color.blue = SCOPE_BG_BLUE << 8;
	gdk_color_alloc(c, &bg_color); 
	GDK_THREADS_LEAVE();
	
	assert(image);
	assert(image->bpp > 2);
	
	bits = (guint32 *)image->mem;	

	running = 1;

	SYNAESCOPE_DOLOOP();

	GDK_THREADS_ENTER();
	synaescope_hide();
	GDK_THREADS_LEAVE();
}



static void synaescope16(void *data)
{
	guint16 *bits;
	guint16 colEq[256];
	int i;
	GdkWindow *win;
	GdkColormap *c;
	GdkVisual *v;
	GdkGC *gc;
	GdkColor bg_color;
	
	win = (GdkWindow *)data;
	GDK_THREADS_ENTER();
	c = gdk_colormap_get_system();
	gc = gdk_gc_new(win);
	v = gdk_window_get_visual(win);

	for (i = 0; i < 256; i++) {
		GdkColor color;
		color.red = PEAKIFY((i&15*16)) << 8;
		color.green = PEAKIFY((i&15)*16+(i&15*16)/4) << 8;
		color.blue = PEAKIFY((i&15)*16) << 8;
		gdk_color_alloc(c, &color);
		colEq[i] = color.pixel; 
	}

	/* Create render image */
	if (image) {
		gdk_image_destroy(image);	
		image = NULL;
	}
	image = gdk_image_new(GDK_IMAGE_FASTEST, v, syn_width, syn_height);
	bg_color.red = SCOPE_BG_RED << 8;
	bg_color.green = SCOPE_BG_GREEN << 8;
	bg_color.blue = SCOPE_BG_BLUE << 8;        
	gdk_color_alloc(c, &bg_color); 
	GDK_THREADS_LEAVE();

	assert(image);
	assert(image->bpp == 2);

	bits = (guint16 *)image->mem;	

	running = 1;

	SYNAESCOPE_DOLOOP();

	GDK_THREADS_ENTER();
	synaescope_hide();
	GDK_THREADS_LEAVE();
}


static void synaescope8(void *data)
{
	guint8 *bits;
	guint8 colEq[256];
	int i;
	GdkWindow *win;
	GdkColormap *c;
	GdkVisual *v;
	GdkGC *gc;
	GdkColor bg_color;
	
	win = (GdkWindow *)data;
	GDK_THREADS_ENTER();
	c = gdk_colormap_get_system();
	gc = gdk_gc_new(win);
	v = gdk_window_get_visual(win);

	for (i = 0; i < 64; i++) {
		GdkColor color;
		color.red = PEAKIFY((i&7*8)*4) << 8;
		color.green = PEAKIFY((i&7)*32+(i&7*8)*2) << 8;
		color.blue = PEAKIFY((i&7)*32) << 8;
	        gdk_color_alloc(c, &color);
		colEq[i * 4] = color.pixel; 
		colEq[i * 4 + 1] = color.pixel; 
		colEq[i * 4 + 2] = color.pixel; 
		colEq[i * 4 + 3] = color.pixel; 
  	}

	/* Create render image */
	if (image) {
		gdk_image_destroy(image);
		image = NULL;
	}	
	image = gdk_image_new(GDK_IMAGE_FASTEST, v, syn_width, syn_height);
	bg_color.red = SCOPE_BG_RED << 8;
	bg_color.green = SCOPE_BG_GREEN << 8;
	bg_color.blue = SCOPE_BG_BLUE << 8;        
	gdk_color_alloc(c, &bg_color); 
	GDK_THREADS_LEAVE();
	
	assert(image);
	assert(image->bpp == 1);
	
	bits = (guint8 *)image->mem;	

	running = 1;

	SYNAESCOPE_DOLOOP();

	GDK_THREADS_ENTER();
	synaescope_hide();
	GDK_THREADS_LEAVE();
}

static GdkVisual *visual;
static GdkWindow *win;

static void stop_synaescope(void);

static gboolean close_synaescope_window(GtkWidget *widget, GdkEvent *event, gpointer data)
{
	GDK_THREADS_LEAVE();
        stop_synaescope();
	GDK_THREADS_ENTER();

	return TRUE;
}

static GtkWidget *init_synaescope_window(void)
{
	GtkWidget *synaescope_win;
	GtkStyle *style;
	GdkColor *color;

	pthread_mutex_init(&synaescope_mutex, NULL);

	style = gtk_style_new();
	synaescope_win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
	gtk_window_set_title(GTK_WINDOW(synaescope_win), "Synaescope");
	gtk_widget_set_usize(synaescope_win, syn_width, syn_height);
	gtk_window_set_policy (GTK_WINDOW (synaescope_win), FALSE, FALSE, FALSE);
	style = gtk_style_copy(gtk_widget_get_style(GTK_WIDGET(synaescope_win)));
	
	color = &style->bg[GTK_STATE_NORMAL];
	color->red = SCOPE_BG_RED << 8;
	color->blue = SCOPE_BG_BLUE << 8;
	color->green = SCOPE_BG_GREEN << 8;
	gdk_color_alloc(gdk_colormap_get_system(), color);
	gtk_widget_set_style(GTK_WIDGET(synaescope_win), style);
	
	gtk_widget_show(synaescope_win);
	
	win = synaescope_win->window;

	/* Signals */
		
	gtk_signal_connect(GTK_OBJECT(synaescope_win), "delete_event",
                GTK_SIGNAL_FUNC(close_synaescope_window), synaescope_win);


	/* Clear and show the window */
	gdk_window_clear(win);
	gdk_window_show(win);
	gdk_flush(); 

	ready_state = 1;

	return synaescope_win;
}


static void synaescope_hide(void)
{
	gint x, y;
	
	if (scope_win) {
		gdk_window_get_root_origin(scope_win->window, &x, &y);
		gtk_widget_hide(scope_win);
		gtk_widget_set_uposition(scope_win, x, y);
	}
}


static void stop_synaescope(void)
{
	if (running) {
		running = 0;
		pthread_join(synaescope_thread, NULL);
	}	
}


static void run_synaescope(void *data)
{
	nice(SCOPE_NICE); /* Be nice to most processes */

	GDK_THREADS_ENTER();	
	visual = gdk_window_get_visual(win); 
	GDK_THREADS_LEAVE();

	switch (visual->depth) {
	 case 8:
		synaescope8(win);
		break;
	 case 16:
		synaescope16(win);
		break;
	 case 24:
	 case 32:
		synaescope32(win);
		break;
		
	}
	pthread_mutex_unlock(&synaescope_mutex);
	pthread_exit(NULL);
}


static void start_synaescope(void)
{
	if (pthread_mutex_trylock(&synaescope_mutex) != 0) {
		printf("synaescope already running\n");
		return;
	}
	if (!is_init) {
		is_init = 1;
		scope_win = init_synaescope_window();
	}
	gtk_widget_show(scope_win);
	pthread_create(&synaescope_thread, NULL, (void * (*)(void *))run_synaescope, NULL);
}


static int bitReverser(int i) {
    int sum = 0;
    int j;

    for(j = 0; j < FFT_BUFFER_SIZE_LOG; j++) {
	sum = (i & 1) + sum * 2;
	i >>= 1;
    }

    return sum;
}

static int init_synaescope(void *arg)
{
    int i;

    for(i = 0; i <= FFT_BUFFER_SIZE / 2 + 1; i++) {
	double mult = (double)128 / ((FFT_BUFFER_SIZE * 16384) ^ 2);
	/* Result now guaranteed (well, almost) to be in range 0..128 */

	/* Low values represent more frequencies, and thus get more */
	/* intensity - this helps correct for that. */
	mult *= log(i + 1) / log(2);

	mult *= 3; /* Adhoc parameter, looks about right for me. */

	fftmult[i] = mult;
    }

	for(i = 0; i < FFT_BUFFER_SIZE; i++) {
		negSinTable[i] = -sin(M_PI * 2 / FFT_BUFFER_SIZE*i);
		cosTable[i] = cos(M_PI * 2 / FFT_BUFFER_SIZE*i);
		bitReverse[i] = bitReverser(i);
	}

	for(i=0;i<256;i++)
		scaleDown[i] = i*200>>8;

	memset(output, 0, syn_width * syn_height * 2);

	if (prefs_get_bool(ap_prefs, "synaescope", "active", 0))
		start_synaescope();
		
	return 1;
}

static void synaes_fft(double *x, double *y) {
	int n2 = FFT_BUFFER_SIZE;
	int n1;
	int twoToTheK;
	int j;
	for(twoToTheK = 1; twoToTheK < FFT_BUFFER_SIZE; twoToTheK *= 2) {
		n1 = n2;
		n2 /= 2;
		for(j = 0; j < n2; j++) {
			double c = cosTable[j * twoToTheK & (FFT_BUFFER_SIZE - 1)];
			double s = negSinTable[j * twoToTheK & (FFT_BUFFER_SIZE - 1)];
			int i;
			for(i = j; i < FFT_BUFFER_SIZE; i += n1) {
				int l = i + n2;
				double xt = x[i] - x[l];
				double yt = y[i] - y[l];
				x[i] = (x[i] + x[l]);
				y[i] = (y[i] + y[l]);
				x[l] = xt * c - yt * s;
				y[l] = xt * s + yt * c;
			}
		}
	}
}


static void shutdown_synaescope(void)
{
	prefs_set_bool(ap_prefs, "synaescope", "active", synaescope_running());
	
	if (synaescope_running())
		stop_synaescope();
}


static int synaescope_running(void)
{
	return running;
}

scope_plugin synaescope_plugin = {
	SCOPE_PLUGIN_VERSION,
	"Synaescope",
	"Richard Boulton",
	NULL,
	init_synaescope,
	start_synaescope,
	synaescope_running,
	stop_synaescope,
	shutdown_synaescope,
	synaescope_set_data,
	NULL
};


scope_plugin *scope_plugin_info(void)
{
	return &synaescope_plugin;
}
