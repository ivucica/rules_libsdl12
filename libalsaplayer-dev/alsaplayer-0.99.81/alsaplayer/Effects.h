/*  Effects.h
 *  Copyright (C) 1998-2002 Andy Lo A Foe <andy@alsaplayer.org>
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
 *  $Id: Effects.h 1250 2007-07-08 14:17:12Z dominique_libre $
 *
*/ 

#ifndef __Effects_h__
#define __Effects_h__

#define DELAY_BUF_SIZE        ((44100 * 2 * 2) * 2)
#define MAX_CHUNK      (32768 * 2)

extern "C" {

void clear_buffer(void);

void init_effects(void);
void echo_effect32(void *buf, int size, int delay, int vol);
void volume_effect32(void *buf, int size, float left, float right=-100.0);
void buffer_effect(void *buf, int size);
char *delay_feed(int delay, int max_size);

}

#endif
