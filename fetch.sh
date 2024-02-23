#!/bin/bash

PACKAGES_X11="libx11-dev libxext-dev libxrandr-dev libxrender-dev x11proto-dev xorg-sgml-doctools"
PACKAGES_EXTRA="libgl-dev libglu1-mesa-dev libasound2-dev libalsaplayer-dev"

PACKAGES="${PACKAGES_X11} ${PACKAGES_EXTRA}"

for pkg in ${PACKAGES} ; do
(
  tput bold
  tput rev
  tput setaf 1  # red
  echo Updating $pkg
  tput setaf 9  # default color
  tput sgr0  # default attributes
  rm -rf $pkg/
  mkdir -p $pkg/
  cd $pkg/
  apt-get download $pkg
  apt-get source $pkg
)
done

tput bold
tput rev
tput setaf 2
echo "Before committing, run 'git add .' or similar to stage all changes."
echo
echo "Update '.gitignore' if necessary."
tput setaf 9
tput sgr0
