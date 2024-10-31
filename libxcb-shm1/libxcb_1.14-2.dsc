-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA512

Format: 1.0
Source: libxcb
Binary: libxcb1, libxcb1-udeb, libxcb1-dev, libxcb-doc, libxcb-composite0, libxcb-composite0-dev, libxcb-damage0, libxcb-damage0-dev, libxcb-dpms0, libxcb-dpms0-dev, libxcb-glx0, libxcb-glx0-dev, libxcb-randr0, libxcb-randr0-dev, libxcb-record0, libxcb-record0-dev, libxcb-render0, libxcb-render0-dev, libxcb-res0, libxcb-res0-dev, libxcb-screensaver0, libxcb-screensaver0-dev, libxcb-shape0, libxcb-shape0-dev, libxcb-shm0, libxcb-shm0-dev, libxcb-sync1, libxcb-sync-dev, libxcb-xf86dri0, libxcb-xf86dri0-dev, libxcb-xfixes0, libxcb-xfixes0-dev, libxcb-xinerama0, libxcb-xinerama0-dev, libxcb-xinput0, libxcb-xinput-dev, libxcb-xtest0, libxcb-xtest0-dev, libxcb-xv0, libxcb-xv0-dev, libxcb-xvmc0, libxcb-xvmc0-dev, libxcb-dri2-0, libxcb-dri2-0-dev, libxcb-present0, libxcb-present-dev, libxcb-dri3-0, libxcb-dri3-dev, libxcb-xkb1, libxcb-xkb-dev
Architecture: any all
Version: 1.14-2
Maintainer: Debian X Strike Force <debian-x@lists.debian.org>
Uploaders:  Julien Cristau <jcristau@debian.org>,
Homepage: https://xcb.freedesktop.org
Standards-Version: 4.5.0
Vcs-Browser: https://salsa.debian.org/xorg-team/lib/libxcb
Vcs-Git: https://salsa.debian.org/xorg-team/lib/libxcb.git
Testsuite: autopkgtest
Testsuite-Triggers: build-essential, pkg-config, xauth, xvfb
Build-Depends: libxau-dev (>= 1:1.0.5-2), libxdmcp-dev (>= 1:1.0.3-2), xcb-proto (>= 1.14), xcb-proto (<< 2.0), libpthread-stubs0-dev (>= 0.1), debhelper-compat (= 12), pkg-config, xutils-dev, xsltproc (>= 1.1.19), check (>= 0.9.4-2) <!nocheck>, python3-xcbgen (>= 1.14), libtool, automake, python3:native, dctrl-tools
Build-Depends-Indep: doxygen, graphviz
Package-List:
 libxcb-composite0 deb libs optional arch=any
 libxcb-composite0-dev deb libdevel optional arch=any
 libxcb-damage0 deb libs optional arch=any
 libxcb-damage0-dev deb libdevel optional arch=any
 libxcb-doc deb doc optional arch=all
 libxcb-dpms0 deb libs optional arch=any
 libxcb-dpms0-dev deb libdevel optional arch=any
 libxcb-dri2-0 deb libs optional arch=any
 libxcb-dri2-0-dev deb libdevel optional arch=any
 libxcb-dri3-0 deb libs optional arch=any
 libxcb-dri3-dev deb libdevel optional arch=any
 libxcb-glx0 deb libs optional arch=any
 libxcb-glx0-dev deb libdevel optional arch=any
 libxcb-present-dev deb libdevel optional arch=any
 libxcb-present0 deb libs optional arch=any
 libxcb-randr0 deb libs optional arch=any
 libxcb-randr0-dev deb libdevel optional arch=any
 libxcb-record0 deb libs optional arch=any
 libxcb-record0-dev deb libdevel optional arch=any
 libxcb-render0 deb libs optional arch=any
 libxcb-render0-dev deb libdevel optional arch=any
 libxcb-res0 deb libs optional arch=any
 libxcb-res0-dev deb libdevel optional arch=any
 libxcb-screensaver0 deb libs optional arch=any
 libxcb-screensaver0-dev deb libdevel optional arch=any
 libxcb-shape0 deb libs optional arch=any
 libxcb-shape0-dev deb libdevel optional arch=any
 libxcb-shm0 deb libs optional arch=any
 libxcb-shm0-dev deb libdevel optional arch=any
 libxcb-sync-dev deb libdevel optional arch=any
 libxcb-sync1 deb libs optional arch=any
 libxcb-xf86dri0 deb libs optional arch=any
 libxcb-xf86dri0-dev deb libdevel optional arch=any
 libxcb-xfixes0 deb libs optional arch=any
 libxcb-xfixes0-dev deb libdevel optional arch=any
 libxcb-xinerama0 deb libs optional arch=any
 libxcb-xinerama0-dev deb libdevel optional arch=any
 libxcb-xinput-dev deb libdevel optional arch=any
 libxcb-xinput0 deb libs optional arch=any
 libxcb-xkb-dev deb libdevel optional arch=any
 libxcb-xkb1 deb libs optional arch=any
 libxcb-xtest0 deb libs optional arch=any
 libxcb-xtest0-dev deb libdevel optional arch=any
 libxcb-xv0 deb libs optional arch=any
 libxcb-xv0-dev deb libdevel optional arch=any
 libxcb-xvmc0 deb libs optional arch=any
 libxcb-xvmc0-dev deb libdevel optional arch=any
 libxcb1 deb libs optional arch=any
 libxcb1-dev deb libdevel optional arch=any
 libxcb1-udeb udeb debian-installer optional arch=any
Checksums-Sha1:
 f0d7b99c8ae1fbe8a6ec9c8cf3faa21090b11b12 640322 libxcb_1.14.orig.tar.gz
 666ba4d699a85f45831673106c061c274964eb75 25716 libxcb_1.14-2.diff.gz
Checksums-Sha256:
 2c7fcddd1da34d9b238c9caeda20d3bd7486456fc50b3cc6567185dbd5b0ad02 640322 libxcb_1.14.orig.tar.gz
 92d7e0a80c3c7f2a5b5afd0c0702183f1c483338d678d67d8d0e61fd8989ba85 25716 libxcb_1.14-2.diff.gz
Files:
 8d1285dec5a474236f67f899f99bc147 640322 libxcb_1.14.orig.tar.gz
 fc7794383a48ba14537a4df1ca90e4ad 25716 libxcb_1.14-2.diff.gz

-----BEGIN PGP SIGNATURE-----

iQIzBAEBCgAdFiEEdS3ifE3rFwGbS2Yjy3AxZaiJhNwFAl5+BOsACgkQy3AxZaiJ
hNzqxBAAiDWAqBPMGlFxtjpQ5ttPw5xYErzlaIPiuC054vBRofs08XiEdh7mF/0g
teGRPYs9enL19VEcm8CXT7Ob12ywm4veLUSUOk9OnGBjCIlq73ONV1VqDdecgRfL
t8NYBB4ZFYH3KO/s0ZrQ034+jgh/VQ2dKMZyxip51YsLOV6L+RDwD5ICvYqSXBpw
hzyEc+hJ7wJZvkMUTb1YRB6TeuVQM/xyNTMlOE4ECtChZulFopA42DlgbQF1iOmO
kgUtroq+RO6KoP+DC/NTbGmQgwobhD5cf3Q+X8ZkWJapfF93Tc/mOIkoDKZ1CrSa
MJEf7DrxnlX+6hR/k2GJQ5NghDEDGcoWoanS4kt1iUIxc7+zeYVcgTgL+zEcJtwZ
F48cQuqhvqqH3b0nSpsnF15xcPiYVtQSh/tE3GQeXoibxBw3CkVECHAk70uRy4G3
GzV2LuGePnpL89JHSQupOYFisbAqPn0KSnUWQpCxLZsvTHZAbFerrKFF85DiyTyO
DRmL/LTjqJk9NxAv9WMjGNEnU1BhwtUw5LM+04vc6XBfGU2jzAVG9HSGtrF68x/A
Te8roouoP1AQzk9bmZRYnJcetAv5wh06LLe1zAWuuvvMtig8YmHjrMukAeGznse2
TerMxPjcR3OWBuxeCjmi2JKkjcHAaabShejK+IaR5b31btCpHjM=
=AJqj
-----END PGP SIGNATURE-----
