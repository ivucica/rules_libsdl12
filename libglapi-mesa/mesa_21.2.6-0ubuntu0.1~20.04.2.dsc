-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA512

Format: 1.0
Source: mesa
Binary: libxatracker2, libxatracker-dev, libd3dadapter9-mesa, libd3dadapter9-mesa-dev, libgbm1, libgbm-dev, libegl-mesa0, libegl1-mesa, libegl1-mesa-dev, libwayland-egl1-mesa, libgles2-mesa, libgles2-mesa-dev, libglapi-mesa, libglx-mesa0, libgl1-mesa-glx, libgl1-mesa-dri, libgl1-mesa-dev, mesa-common-dev, libosmesa6, libosmesa6-dev, mesa-va-drivers, mesa-vdpau-drivers, mesa-vulkan-drivers, mesa-opencl-icd
Architecture: any
Version: 21.2.6-0ubuntu0.1~20.04.2
Maintainer: Ubuntu Developers <ubuntu-devel-discuss@lists.ubuntu.com>
Uploaders: Andreas Boll <aboll@debian.org>
Homepage: https://mesa3d.org/
Standards-Version: 4.1.4
Vcs-Browser: https://salsa.debian.org/xorg-team/lib/mesa
Vcs-Git: https://salsa.debian.org/xorg-team/lib/mesa.git
Build-Depends: debhelper-compat (= 12), directx-headers-dev [linux-amd64 linux-arm64], glslang-tools [amd64 arm64 armel armhf i386 mips64el mipsel powerpc ppc64 ppc64el riscv64 s390x sparc64 x32], meson (>= 0.45), quilt (>= 0.63-8.2~), pkg-config, libdrm-dev (>= 2.4.107-4), libx11-dev, libxxf86vm-dev, libexpat1-dev, libsensors-dev [!hurd-any], libxfixes-dev, libxext-dev, libva-dev (>= 1.6.0) [linux-any kfreebsd-any] <!pkg.mesa.nolibva>, libvdpau-dev (>= 1.1.1) [linux-any kfreebsd-any], libvulkan-dev [amd64 arm64 armel armhf i386 mips64el mipsel powerpc ppc64 ppc64el riscv64 s390x sparc64 x32], x11proto-dev, linux-libc-dev (>= 2.6.31) [linux-any], libx11-xcb-dev, libxcb-dri2-0-dev (>= 1.8), libxcb-glx0-dev (>= 1.8.1), libxcb-xfixes0-dev, libxcb-dri3-dev, libxcb-present-dev, libxcb-randr0-dev, libxcb-shm0-dev, libxcb-sync-dev, libxrandr-dev, libxshmfence-dev (>= 1.1), libzstd-dev, python3, python3-mako, python3-setuptools, flex, bison, libelf-dev [amd64 arm64 armel armhf i386 kfreebsd-amd64 kfreebsd-i386 mips64el mipsel powerpc ppc64 ppc64el riscv64 s390x sparc64], libwayland-dev (>= 1.15.0) [linux-any], libwayland-egl-backend-dev (>= 1.15.0) [linux-any], llvm-12-dev [amd64 arm64 armel armhf i386 mips64el mipsel powerpc ppc64 ppc64el riscv64 s390x sparc64], libclang-12-dev [amd64 arm64 armel armhf i386 mips64el mipsel powerpc ppc64 ppc64el riscv64 s390x sparc64], libclang-cpp12-dev [amd64 arm64 armel armhf i386 mips64el mipsel powerpc ppc64 ppc64el riscv64 s390x sparc64], libclc-12-dev [amd64 arm64 armel armhf i386 mips64el mipsel powerpc ppc64 ppc64el riscv64 s390x sparc64], wayland-protocols (>= 1.9), zlib1g-dev, libglvnd-dev (>= 1.3.2), valgrind [amd64 arm64 armhf i386 mips64el mipsel powerpc ppc64 ppc64el s390x], gcc-10 [ppc64el], cpp-10 [ppc64el], g++-10 [ppc64el]
Package-List:
 libd3dadapter9-mesa deb libs optional arch=amd64,arm64,armel,armhf,i386,powerpc
 libd3dadapter9-mesa-dev deb libdevel optional arch=amd64,arm64,armel,armhf,i386,powerpc
 libegl-mesa0 deb libs optional arch=any
 libegl1-mesa deb oldlibs optional arch=any
 libegl1-mesa-dev deb libdevel optional arch=any
 libgbm-dev deb libdevel optional arch=linux-any,kfreebsd-any
 libgbm1 deb libs optional arch=linux-any,kfreebsd-any
 libgl1-mesa-dev deb oldlibs optional arch=any
 libgl1-mesa-dri deb libs optional arch=any
 libgl1-mesa-glx deb oldlibs optional arch=any
 libglapi-mesa deb libs optional arch=any
 libgles2-mesa deb oldlibs optional arch=any
 libgles2-mesa-dev deb oldlibs optional arch=any
 libglx-mesa0 deb libs optional arch=any
 libosmesa6 deb libs optional arch=any
 libosmesa6-dev deb libdevel optional arch=any
 libwayland-egl1-mesa deb oldlibs optional arch=linux-any
 libxatracker-dev deb libdevel optional arch=amd64,i386,x32
 libxatracker2 deb libs optional arch=amd64,i386,x32
 mesa-common-dev deb libdevel optional arch=any
 mesa-opencl-icd deb libs optional arch=amd64,arm64,armel,armhf,i386,mips64el,mipsel,powerpc,ppc64,ppc64el,s390x,sparc64
 mesa-va-drivers deb libs optional arch=linux-any,kfreebsd-any profile=!pkg.mesa.nolibva
 mesa-vdpau-drivers deb libs optional arch=linux-any,kfreebsd-any
 mesa-vulkan-drivers deb libs optional arch=amd64,arm64,armel,armhf,i386,mips64el,mipsel,powerpc,ppc64,ppc64el,s390x,sparc64,x32
Checksums-Sha1:
 b5ac5bc88d515802c23679b64265516629214c18 24561701 mesa_21.2.6.orig.tar.gz
 b1c8071405e7f6a8609c29853917f47e56d7c3a0 110576 mesa_21.2.6-0ubuntu0.1~20.04.2.diff.gz
Checksums-Sha256:
 3285f83e0215ce8b4129b228c02efea7d20645f03869f4fa973815c0af2851bd 24561701 mesa_21.2.6.orig.tar.gz
 64f006104b615950cc50011110f577624aed9cf1c50f60a02046a9bef2a1655f 110576 mesa_21.2.6-0ubuntu0.1~20.04.2.diff.gz
Files:
 d47f4a69a2f1baff93613c47a375ed64 24561701 mesa_21.2.6.orig.tar.gz
 bb2c3797a7ee2c159ff8ab7bb24e5617 110576 mesa_21.2.6-0ubuntu0.1~20.04.2.diff.gz
Original-Maintainer: Debian X Strike Force <debian-x@lists.debian.org>

-----BEGIN PGP SIGNATURE-----

iQIzBAEBCgAdFiEEUMSg3c8x5FLOsZtRZWnYVadEvpMFAmIolCUACgkQZWnYVadE
vpMHuQ/+KLzcR0lZX4eN4l0w0n3zAQJBQZBd6vPPhcGY1BKQUkwDjlDsBBvwHxw9
VjkdkB7CAvZ2Qhk+9oC92Es9Oc0dg2jo6OqdGaDPeqVcJfCqcocUmE5G2vn1E0uV
7HlBCASmQ1vShB0q3oJrHcE071OTpkNIZT+gU5VD1L2v0Nr3v49jEerK0l6IY90E
DKP+ZJCVvCm9rufWZac5TICsTzdcKI0hcIa9QiebJW4gESibuc5ojEn8PjcLhjIC
q4f3LY+LcJUJrZOoPwUJ3yrVRTTOgzWw8JqrE7C46wKshwmZrS5ufWRCJ+4FS5bm
s5wOwzbrT7hVG25WOJM7zo/8HYiiGtzuez1oStNGH3OYthHqb3MSfkF6rjNQlwyh
/p+aHS+55HiWyRx3O4bwcM8wX7Kxptv0bVn8zEbunTv4N2r1sSlQZKNba016iV9c
BH0x60TenPdrJ11QtBeZI6Zv9jIKe6rAm+T0D6vzGm+d02MrUdsUhcBtdLATo3Ed
OrGZaXA5KWPvAt2MBhNwQj7s/aRKNAGNPTZZB7/s16VtkitNfzWYJHf59I9KEhc5
geFWgntkKWIosF37fgu9GcYjtY1J7/9m/Xmqp9RqVZVhbBZrtimGk9pLt3uOFeHp
JHKFoY4Vb8QF7qEzEX0Fka/SQj6c8Yw1dYzYGvwwXLnfZp6ZxEM=
=K27f
-----END PGP SIGNATURE-----
