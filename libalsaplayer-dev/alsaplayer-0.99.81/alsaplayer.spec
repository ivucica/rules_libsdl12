Summary: A advanced, graphical PCM audio player
Name: alsaplayer
Version: 0.99.81
Release: 1
URL: http://www.alsaplayer.org/
Source0: http://www.alsaplayer.org/%{name}-%{version}.tar.bz2
License: GPL
Group: Applications/Multimedia
BuildRoot: %{_tmppath}/%{name}-root
# FIXME: check out what packages are available in different
# distributions.

# These are correct for both redhat and mandrake
BuildRequires: gtk+-devel, libvorbis-devel, mikmod

# These are redhat only
#BuildRequires: libmad, esound-devel, audiofile-devel

%description
AlsaPlayer is a new PCM player developed on the Linux Operating
System. AlsaPlayer was written in the first place to excercise the new
ALSA (Advanced Linux Sound Architecture) driver and library system.

It has now developed into a versitile audio player with rich plugin system.
The  Input Plugins plugins include: OGG, MPEG, MAD, CDDA, MikMod, FLAC and
Audiofile. The Output Plugins include: ALSA, OSS and OSS/Lite, Esound,
Sparc (tested on UltraSparc), SGI, and JACK. There are also a few scope
plugins included.

%package devel
Group: Development/Libraries
Requires: %{name} = %{version}-%{release}
Summary: Files needed for building applications with libalsaplayer

%description devel
The functionality of the alsaplayer is also exposed via a c programming
library. This package is neede to compile programs that uses the library.

%prep
%setup -q

%build
automake
./configure --prefix=%{_prefix} --mandir=%{_datadir}/man --enable-audiofile
make

%install
rm -rf $RPM_BUILD_ROOT
make DESTDIR=%{buildroot} install

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root)
%doc README INSTALL AUTHORS COPYING TODO docs/wishlist.txt
%{_libdir}/pkgconfig/*
%{_libdir}/*.so.*
%{_libdir}/alsaplayer/*
%{_bindir}/*
%{_datadir}/man/man*/*

%files devel
%{_includedir}/alsaplayer/*
%doc docs/reference/html
%{_libdir}/*.so
%{_libdir}/*.la

%changelog
* Mon Jul 29 2002 Daniel Resare <noa@resare.com>
- Initial build.
* Sun Jul 06 2007 Dominique Michel <dominique@tuxfamily.rog>
- Added FLAC input plugin in description.
