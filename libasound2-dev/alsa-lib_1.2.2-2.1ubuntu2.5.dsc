-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA1

Format: 3.0 (quilt)
Source: alsa-lib
Binary: libasound2, libasound2-dev, libasound2-data, libasound2-udeb, libasound2-doc, libasound2-plugin-smixer, libatopology2, libatopology-dev
Architecture: linux-any all
Version: 1.2.2-2.1ubuntu2.5
Maintainer: Debian ALSA Maintainers <pkg-alsa-devel@lists.alioth.debian.org>
Uploaders: Jordi Mallach <jordi@debian.org>, Elimar Riesebieter <riesebie@lxtec.de>, Luke Yelavich <themuso@ubuntu.com>
Homepage: https://www.alsa-project.org/
Standards-Version: 4.5.0
Vcs-Browser: https://salsa.debian.org/alsa-team/alsa-lib
Vcs-Git: https://salsa.debian.org/alsa-team/alsa-lib.git
Testsuite: autopkgtest
Testsuite-Triggers: build-essential
Build-Depends: debhelper-compat (= 12), python3-dev:native, libpython3-dev
Build-Depends-Indep: doxygen, graphviz
Package-List:
 libasound2 deb libs optional arch=linux-any
 libasound2-data deb libs optional arch=all
 libasound2-dev deb libdevel optional arch=linux-any
 libasound2-doc deb doc optional arch=all
 libasound2-plugin-smixer deb libs optional arch=linux-any
 libasound2-udeb udeb debian-installer optional arch=linux-any
 libatopology-dev deb libdevel optional arch=linux-any
 libatopology2 deb libs optional arch=linux-any
Checksums-Sha1:
 f0eee7ff8b37a40c104cee6fd7b2f4c645b1b1a1 1030747 alsa-lib_1.2.2.orig.tar.bz2
 986bb76bddbef1749c8af43630212c0a92340f84 59256 alsa-lib_1.2.2-2.1ubuntu2.5.debian.tar.xz
Checksums-Sha256:
 d8e853d8805574777bbe40937812ad1419c9ea7210e176f0def3e6ed255ab3ec 1030747 alsa-lib_1.2.2.orig.tar.bz2
 4d7538f8d1a3c4fc4200840d7587477ceef76d993229419f9754f653e4f8a09e 59256 alsa-lib_1.2.2-2.1ubuntu2.5.debian.tar.xz
Files:
 82cdc23a5233d5ed319d2cbc89af5ca5 1030747 alsa-lib_1.2.2.orig.tar.bz2
 9edd4404c11e4100456317895a95a50b 59256 alsa-lib_1.2.2-2.1ubuntu2.5.debian.tar.xz

-----BEGIN PGP SIGNATURE-----

iF0EARECAB0WIQTgLv71TsYonmdA1hxDGjztotfSkgUCYX+0+AAKCRBDGjztotfS
kiZEAJ4/bzf9QEFq/q8gT/vStWw3LBJ1EACg4EEvjmcUKxG53pbBksLtMHOZ7Pw=
=vwNq
-----END PGP SIGNATURE-----
