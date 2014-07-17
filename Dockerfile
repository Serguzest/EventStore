FROM ubuntu:14.04

# Install required system packages
RUN apt-get -q update
RUN apt-get install -yq git mono-devel subversion build-essential

# Adding sources
ADD . /usr/src/EventStore

WORKDIR /usr/src/EventStore

RUN ./build.sh full
