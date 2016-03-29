# VERSION:		  1.0
# DESCRIPTION:	  Create chromium container with its dependencies on Arch Linux
# AUTHOR:		  Captain Wishaw <captainwishaw@gmail.com>
# COMMENTS:
#	This file describes how to build a Chromium container with all
#	dependencies installed. It uses native X11 unix socket.
#	Based on https://github.com/jfrazelle
# USAGE:
#	# Download Chromium Dockerfile
#	wget https://github.com/captainwishaw/docker
#
#	# Build chromium image
#	docker build -t chromium .

# Base Docker Image
FROM captainwishaw/archlinux:archlinux
MAINTAINER Captain Wishaw <captainwishaw@gmail.com>
RUN pacman -Syu --noconfirm && pacman -S chromium --noconfirm

# Install Chromium
ENTRYPOINT [ "/usr/bin/chromium" ]
CMD [ "--user-data-dir=/data" ]
