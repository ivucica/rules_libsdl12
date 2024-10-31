-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA512

Format: 3.0 (quilt)
Source: libdrm
Binary: libdrm-dev, libdrm2, libdrm-common, libdrm-tests, libdrm2-udeb, libdrm-intel1, libdrm-nouveau2, libdrm-radeon1, libdrm-omap1, libdrm-freedreno1, libdrm-exynos1, libdrm-tegra0, libdrm-amdgpu1, libdrm-etnaviv1
Architecture: any all
Version: 2.4.107-8ubuntu1~20.04.2
Maintainer: Ubuntu Developers <ubuntu-devel-discuss@lists.ubuntu.com>
Uploaders: Andreas Boll <aboll@debian.org>
Homepage: https://cgit.freedesktop.org/mesa/drm/
Standards-Version: 4.5.0
Vcs-Browser: https://salsa.debian.org/xorg-team/lib/libdrm
Vcs-Git: https://salsa.debian.org/xorg-team/lib/libdrm
Build-Depends: debhelper-compat (= 12), meson, quilt, xsltproc, libx11-dev, pkg-config, python3-setuptools, xutils-dev (>= 1:7.6+2), libudev-dev [linux-any], libpciaccess-dev, python3-docutils
Package-List:
 libdrm-amdgpu1 deb libs optional arch=linux-any,kfreebsd-any,hurd-any
 libdrm-common deb libs optional arch=all
 libdrm-dev deb libdevel optional arch=linux-any,kfreebsd-any,hurd-any
 libdrm-etnaviv1 deb libs optional arch=armhf,arm64
 libdrm-exynos1 deb libs optional arch=any-arm
 libdrm-freedreno1 deb libs optional arch=any-arm,arm64
 libdrm-intel1 deb libs optional arch=amd64,i386,kfreebsd-amd64,kfreebsd-i386,hurd-i386,x32
 libdrm-nouveau2 deb libs optional arch=linux-any
 libdrm-omap1 deb libs optional arch=any-arm
 libdrm-radeon1 deb libs optional arch=linux-any,kfreebsd-any,hurd-any
 libdrm-tegra0 deb libs optional arch=any-arm,arm64
 libdrm-tests deb libs optional arch=any
 libdrm2 deb libs optional arch=linux-any,kfreebsd-any,hurd-any
 libdrm2-udeb udeb debian-installer optional arch=linux-any,kfreebsd-any,hurd-any
Checksums-Sha1:
 372eb85849d1858a892dc5569edfa278640a9732 425612 libdrm_2.4.107.orig.tar.xz
 bc14137852a2260fd4228e7d04459667a1b65754 59064 libdrm_2.4.107-8ubuntu1~20.04.2.debian.tar.xz
Checksums-Sha256:
 c554cef03b033636a975543eab363cc19081cb464595d3da1ec129f87370f888 425612 libdrm_2.4.107.orig.tar.xz
 9b60b0e919a9f7aed30016d46e4545820b0f8b948120b95f3a1364663023a4fe 59064 libdrm_2.4.107-8ubuntu1~20.04.2.debian.tar.xz
Files:
 252175d363e3dbc4ffe32faaa8e93494 425612 libdrm_2.4.107.orig.tar.xz
 1c8961f0a421236db2577735fbb5b34e 59064 libdrm_2.4.107-8ubuntu1~20.04.2.debian.tar.xz
Original-Maintainer: Debian X Strike Force <debian-x@lists.debian.org>

-----BEGIN PGP SIGNATURE-----

iQIzBAEBCgAdFiEEUMSg3c8x5FLOsZtRZWnYVadEvpMFAmIn9Q8ACgkQZWnYVadE
vpOx6RAAui/iergtSWSAeNjzO8q+nx1cw/rlPYu9/Wx+nbU+SuqXteoTy/uN1siR
PicP5J/YqT5k/cy8aTSXlmAeMnz1mk7HAuMFq4LbXTLMdnJFCWDEg2FIGpHo/peN
/Uzlj5WXTwZENCr4jLtaX4uCHZgHolaKzRbVVLPOtLUWg7P3uYW0xS82o5nHDc8W
FscfZ4xvz6ubxjsRqRPSrbXXswqjnNWPq6DP2mt+YsfGK8WxdRBOb59zXo3MtaeO
JCdjW5YOpGAPfjYYySvBMRMk9nXPgmY8KTuIHLZ2BifLoLO9XrjPm+aqWiaxl9r/
Vi8owDqkH4ADApQdCXpMOUBw3N6WdMVErvFg6lUCvWRIasZiPeAuV8EDYW36c+Cd
Z4JdtJsrMuuXBFtVk6mZwgSas0qUuCDVPW2mcuuxVMd+e8LM2Ak1H/NgraqDsFja
tTDDpxTOu7j2PfAcqDu2TdOmVmPE2wHyKzg+BF+AOzse74uZ2XwEZfEcB3pOeyAT
UU+DvZLmn7hB5dJJHSfCFLXmslABQQEwdkbp/g+q8MaFkLao0ccD6Jq81c5CqovV
lVYPQC9fEtpejRwJnFlv8pZpSm6QLUxoNjPokMiTxcKHzo1LkLVpE6T9RPpbZyhw
MvRoqoet0NdMcXVUMZ/2hlcOnVXLna/0QTHCgxHXVWvuXkIQIA4=
=Pq6U
-----END PGP SIGNATURE-----
