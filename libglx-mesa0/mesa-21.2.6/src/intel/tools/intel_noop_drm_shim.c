/*
 * Copyright © 2020 Intel Corporation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <sys/un.h>

#include "common/intel_gem.h"
#include "dev/intel_device_info.h"
#include "drm-uapi/i915_drm.h"
#include "drm-shim/drm_shim.h"
#include "util/macros.h"
#include "util/vma.h"

struct i915_device {
   struct intel_device_info devinfo;
   uint32_t device_id;
};

struct i915_bo {
   struct shim_bo base;
};

static struct i915_device i915 = {};

bool drm_shim_driver_prefers_first_render_node = true;

static int
i915_ioctl_noop(int fd, unsigned long request, void *arg)
{
   return 0;
}

static int
i915_ioctl_gem_create(int fd, unsigned long request, void *arg)
{
   struct shim_fd *shim_fd = drm_shim_fd_lookup(fd);
   struct drm_i915_gem_create *create = arg;
   struct i915_bo *bo = calloc(1, sizeof(*bo));

   drm_shim_bo_init(&bo->base, create->size);

   create->handle = drm_shim_bo_get_handle(shim_fd, &bo->base);

   drm_shim_bo_put(&bo->base);

   return 0;
}

static int
i915_ioctl_gem_mmap(int fd, unsigned long request, void *arg)
{
   struct shim_fd *shim_fd = drm_shim_fd_lookup(fd);
   struct drm_i915_gem_mmap *mmap_arg = arg;
   struct shim_bo *bo = drm_shim_bo_lookup(shim_fd, mmap_arg->handle);

   if (!bo)
      return -1;

   if (!bo->map)
      bo->map = drm_shim_mmap(shim_fd, bo->size, PROT_READ | PROT_WRITE, MAP_SHARED, -1, (uintptr_t)bo);

   mmap_arg->addr_ptr = (uint64_t) (bo->map + mmap_arg->offset);

   return 0;
}

static int
i915_ioctl_gem_userptr(int fd, unsigned long request, void *arg)
{
   struct shim_fd *shim_fd = drm_shim_fd_lookup(fd);
   struct drm_i915_gem_userptr *userptr = arg;
   struct i915_bo *bo = calloc(1, sizeof(*bo));

   drm_shim_bo_init(&bo->base, userptr->user_size);

   userptr->handle = drm_shim_bo_get_handle(shim_fd, &bo->base);

   drm_shim_bo_put(&bo->base);

   return 0;
}

static int
i915_ioctl_gem_context_create(int fd, unsigned long request, void *arg)
{
   struct drm_i915_gem_context_create *create = arg;

   create->ctx_id = 1; /* Just return a fake non zero ID. */

   return 0;
}

static int
i915_ioctl_gem_context_getparam(int fd, unsigned long request, void *arg)
{
   struct drm_i915_gem_context_param *param = arg;

   if (param->param ==  I915_CONTEXT_PARAM_GTT_SIZE) {
      if (i915.devinfo.ver >= 8 && !i915.devinfo.is_cherryview)
         param->value = 1ull << 48;
      else
         param->value = 1ull << 31;
   } else {
      param->value = 0;
   }

   return 0;
}

static int
i915_ioctl_get_param(int fd, unsigned long request, void *arg)
{
   drm_i915_getparam_t *gp = arg;

   switch (gp->param) {
   case I915_PARAM_CHIPSET_ID:
      *gp->value = i915.device_id;
      return 0;
   case I915_PARAM_REVISION:
      *gp->value = 0;
      return 0;
   case I915_PARAM_CS_TIMESTAMP_FREQUENCY:
      *gp->value = i915.devinfo.timestamp_frequency;
      return 0;
   case I915_PARAM_HAS_ALIASING_PPGTT:
      if (i915.devinfo.ver < 6)
         *gp->value = I915_GEM_PPGTT_NONE;
      else if (i915.devinfo.ver <= 7)
         *gp->value = I915_GEM_PPGTT_ALIASING;
      else
         *gp->value = I915_GEM_PPGTT_FULL;
      return 0;

   case I915_PARAM_NUM_FENCES_AVAIL:
      *gp->value = 8; /* gfx2/3 value, unused in brw/iris */
      return 0;

   case I915_PARAM_HAS_BLT:
      *gp->value = 1; /* gfx2/3 value, unused in brw/iris */
      return 0;

   case I915_PARAM_HAS_BSD:
   case I915_PARAM_HAS_LLC:
   case I915_PARAM_HAS_VEBOX:
      *gp->value = 0; /* gfx2/3 value, unused in brw/iris */
      return 0;

   case I915_PARAM_HAS_GEM:
   case I915_PARAM_HAS_RELAXED_DELTA:
   case I915_PARAM_HAS_RELAXED_FENCING:
   case I915_PARAM_HAS_WAIT_TIMEOUT:
   case I915_PARAM_HAS_EXECBUF2:
   case I915_PARAM_HAS_EXEC_SOFTPIN:
   case I915_PARAM_HAS_EXEC_CAPTURE:
   case I915_PARAM_HAS_EXEC_FENCE:
   case I915_PARAM_HAS_EXEC_FENCE_ARRAY:
   case I915_PARAM_HAS_CONTEXT_ISOLATION:
   case I915_PARAM_HAS_EXEC_ASYNC:
   case I915_PARAM_HAS_EXEC_NO_RELOC:
   case I915_PARAM_HAS_EXEC_BATCH_FIRST:
      *gp->value = true;
      return 0;
   case I915_PARAM_HAS_EXEC_TIMELINE_FENCES:
      *gp->value = false;
      return 0;
   case I915_PARAM_CMD_PARSER_VERSION:
      /* Most recent version in drivers/gpu/drm/i915/i915_cmd_parser.c */
      *gp->value = 10;
      return 0;
   case I915_PARAM_MMAP_VERSION:
   case I915_PARAM_MMAP_GTT_VERSION:
      *gp->value = 1;
      return 0;
   case I915_PARAM_SUBSLICE_TOTAL:
      *gp->value = 0;
      for (uint32_t s = 0; s < i915.devinfo.num_slices; s++)
         *gp->value += i915.devinfo.num_subslices[s];
      return 0;
   case I915_PARAM_EU_TOTAL:
      *gp->value = 0;
      for (uint32_t s = 0; s < i915.devinfo.num_slices; s++)
         *gp->value += i915.devinfo.num_subslices[s] * i915.devinfo.num_eu_per_subslice;
      return 0;
   case I915_PARAM_PERF_REVISION:
      *gp->value = 3;
      return 0;
   default:
      break;
   }

   fprintf(stderr, "Unknown DRM_IOCTL_I915_GET_PARAM %d\n", gp->param);
   return -1;
}

static int
query_write_topology(struct drm_i915_query_item *item)
{
   struct drm_i915_query_topology_info *info =
      (void *) (uintptr_t) item->data_ptr;
   int32_t length =
      sizeof(*info) +
      DIV_ROUND_UP(i915.devinfo.num_slices, 8) +
      i915.devinfo.num_slices * DIV_ROUND_UP(i915.devinfo.num_subslices[0], 8) +
      i915.devinfo.num_slices * i915.devinfo.num_subslices[0] *
      DIV_ROUND_UP(i915.devinfo.num_eu_per_subslice, 8);

   if (item->length == 0) {
      item->length = length;
      return 0;
   }

   if (item->length < length) {
      fprintf(stderr, "size too small\n");
      return -EINVAL;
   }

   if (info->flags) {
      fprintf(stderr, "invalid topology flags\n");
      return -EINVAL;
   }

   info->max_slices = i915.devinfo.num_slices;
   info->max_subslices = i915.devinfo.num_subslices[0];
   info->max_eus_per_subslice = i915.devinfo.num_eu_per_subslice;

   info->subslice_offset = DIV_ROUND_UP(i915.devinfo.num_slices, 8);
   info->subslice_stride = DIV_ROUND_UP(i915.devinfo.num_subslices[0], 8);
   info->eu_offset = info->subslice_offset + info->max_slices * info->subslice_stride;

   uint32_t slice_mask = (1u << i915.devinfo.num_slices) - 1;
   for (uint32_t i = 0; i < info->subslice_offset; i++)
      info->data[i] = (slice_mask >> (8 * i)) & 0xff;

   for (uint32_t s = 0; s < i915.devinfo.num_slices; s++) {
      uint32_t subslice_mask = (1u << i915.devinfo.num_subslices[s]) - 1;
      for (uint32_t i = 0; i < info->subslice_stride; i++) {
         info->data[info->subslice_offset + s * info->subslice_stride + i] =
            (subslice_mask >> (8 * i)) & 0xff;
      }
   }

   for (uint32_t s = 0; s < i915.devinfo.num_slices; s++) {
      for (uint32_t ss = 0; ss < i915.devinfo.num_subslices[s]; ss++) {
         uint32_t eu_mask = (1u << info->max_eus_per_subslice) - 1;
         for (uint32_t i = 0; i < DIV_ROUND_UP(info->max_eus_per_subslice, 8); i++) {
            info->data[info->eu_offset +
                       (s * info->max_subslices + ss) * DIV_ROUND_UP(info->max_eus_per_subslice, 8) + i] =
               (eu_mask >> (8 * i)) & 0xff;
         }
      }
   }

   return 0;
}

static int
i915_ioctl_query(int fd, unsigned long request, void *arg)
{
   struct drm_i915_query *query = arg;
   struct drm_i915_query_item *items = (void *) (uintptr_t) query->items_ptr;

   if (query->flags) {
      fprintf(stderr, "invalid query flags\n");
      return -EINVAL;
   }

   for (uint32_t i = 0; i < query->num_items; i++) {
      struct drm_i915_query_item *item = &items[i];

      switch (item->query_id) {
      case DRM_I915_QUERY_TOPOLOGY_INFO: {
         int ret = query_write_topology(item);
         if (ret)
            item->length = ret;
         break;
      }

      default:
         fprintf(stderr, "Unknown drm_i915_query_item id=%lli\n", item->query_id);
         item->length = -EINVAL;
         break;
      }
   }

   return 0;
}

static int
i915_gem_get_aperture(int fd, unsigned long request, void *arg)
{
   struct drm_i915_gem_get_aperture *aperture = arg;

   if (i915.devinfo.ver >= 8 &&
       !i915.devinfo.is_cherryview) {
      aperture->aper_size = 1ull << 48;
      aperture->aper_available_size = 1ull << 48;
   } else {
      aperture->aper_size = 1ull << 31;
      aperture->aper_size = 1ull << 31;
   }

   return 0;
}

static ioctl_fn_t driver_ioctls[] = {
   [DRM_I915_GETPARAM] = i915_ioctl_get_param,
   [DRM_I915_QUERY] = i915_ioctl_query,

   [DRM_I915_GET_RESET_STATS] = i915_ioctl_noop,

   [DRM_I915_GEM_CREATE] = i915_ioctl_gem_create,
   [DRM_I915_GEM_MMAP] = i915_ioctl_gem_mmap,
   [DRM_I915_GEM_SET_TILING] = i915_ioctl_noop,
   [DRM_I915_GEM_CONTEXT_CREATE] = i915_ioctl_gem_context_create,
   [DRM_I915_GEM_CONTEXT_DESTROY] = i915_ioctl_noop,
   [DRM_I915_GEM_CONTEXT_GETPARAM] = i915_ioctl_gem_context_getparam,
   [DRM_I915_GEM_CONTEXT_SETPARAM] = i915_ioctl_noop,
   [DRM_I915_GEM_EXECBUFFER2] = i915_ioctl_noop,
   [DRM_I915_GEM_EXECBUFFER2_WR] = i915_ioctl_noop,

   [DRM_I915_GEM_USERPTR] = i915_ioctl_gem_userptr,

   [DRM_I915_GEM_GET_APERTURE] = i915_gem_get_aperture,

   [DRM_I915_REG_READ] = i915_ioctl_noop,

   [DRM_I915_GEM_SET_DOMAIN] = i915_ioctl_noop,
   [DRM_I915_GEM_GET_CACHING] = i915_ioctl_noop,
   [DRM_I915_GEM_SET_CACHING] = i915_ioctl_noop,
   [DRM_I915_GEM_GET_TILING] = i915_ioctl_noop,
   [DRM_I915_GEM_MADVISE] = i915_ioctl_noop,
   [DRM_I915_GEM_WAIT] = i915_ioctl_noop,
   [DRM_I915_GEM_BUSY] = i915_ioctl_noop,
};

void
drm_shim_driver_init(void)
{
   const char *user_platform = getenv("INTEL_STUB_GPU_PLATFORM");

   /* Use SKL if nothing is specified. */
   i915.device_id = intel_device_name_to_pci_device_id(user_platform ?: "skl");
   if (!intel_get_device_info_from_pci_id(i915.device_id, &i915.devinfo))
      return;

   shim_device.bus_type = DRM_BUS_PCI;
   shim_device.driver_name = "i915";
   shim_device.driver_ioctls = driver_ioctls;
   shim_device.driver_ioctl_count = ARRAY_SIZE(driver_ioctls);

   char uevent_content[1024];
   snprintf(uevent_content, sizeof(uevent_content),
            "DRIVER=i915\n"
            "PCI_CLASS=30000\n"
            "PCI_ID=8086:%x\n"
            "PCI_SUBSYS_ID=1028:075B\n"
            "PCI_SLOT_NAME=0000:00:02.0\n"
            "MODALIAS=pci:v00008086d00005916sv00001028sd0000075Bbc03sc00i00\n",
            i915.device_id);
   drm_shim_override_file(uevent_content,
                          "/sys/dev/char/%d:%d/device/uevent",
                          DRM_MAJOR, render_node_minor);
   drm_shim_override_file("0x0\n",
                          "/sys/dev/char/%d:%d/device/revision",
                          DRM_MAJOR, render_node_minor);
   char device_content[10];
   snprintf(device_content, sizeof(device_content),
            "0x%x\n", i915.device_id);
   drm_shim_override_file("0x8086",
                          "/sys/dev/char/%d:%d/device/vendor",
                          DRM_MAJOR, render_node_minor);
   drm_shim_override_file("0x8086",
                          "/sys/devices/pci0000:00/0000:00:02.0/vendor");
   drm_shim_override_file(device_content,
                          "/sys/dev/char/%d:%d/device/device",
                          DRM_MAJOR, render_node_minor);
   drm_shim_override_file(device_content,
                          "/sys/devices/pci0000:00/0000:00:02.0/device");
   drm_shim_override_file("0x1234",
                          "/sys/dev/char/%d:%d/device/subsystem_vendor",
                          DRM_MAJOR, render_node_minor);
   drm_shim_override_file("0x1234",
                          "/sys/devices/pci0000:00/0000:00:02.0/subsystem_vendor");
   drm_shim_override_file("0x1234",
                          "/sys/dev/char/%d:%d/device/subsystem_device",
                          DRM_MAJOR, render_node_minor);
   drm_shim_override_file("0x1234",
                          "/sys/devices/pci0000:00/0000:00:02.0/subsystem_device");
}
