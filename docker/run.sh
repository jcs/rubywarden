#!/usr/bin/env bash

# Open source password management solutions
# Copyright 2015 8bit Solutions LLC
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e

# Setup

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

OUTPUT_DIR="../."
if [ $# -gt 1 ]
then
  OUTPUT_DIR=$2
fi

CORE_VERSION="latest"
if [ $# -gt 2 ]
then
  CORE_VERSION=$3
fi

WEB_VERSION="latest"
if [ $# -gt 3 ]
then
  WEB_VERSION=$4
fi

RUBY_API_VERSION="latest"
if [ $# -gt 4 ]
then
  RUBY_API_VERSION=$5
fi

DOCKER_DIR="$OUTPUT_DIR/docker"

# Functions

function dockerComposeUp() {
  docker-compose -f ${DOCKER_DIR}/docker-compose.yml up -d
}

function dockerComposeDown() {
  docker-compose -f ${DOCKER_DIR}/docker-compose.yml down
}

function dockerComposePull() {
  docker-compose -f ${DOCKER_DIR}/docker-compose.yml pull
}

function dockerPrune() {
  docker image prune -f
}

function updateLetsEncrypt() {
  if [ -d "${OUTPUT_DIR}/letsencrypt/live" ]
  then
    docker pull certbot/certbot
    docker run -it --rm --name certbot -p 443:443 -p 80:80 -v ${OUTPUT_DIR}/letsencrypt:/etc/letsencrypt/ certbot/certbot \
    renew --logs-dir /etc/letsencrypt/logs
  fi
}

function restart() {
  dockerComposeDown
  dockerComposePull
  updateLetsEncrypt
  dockerComposeUp
  dockerPrune
}

function pullSetup() {
  docker pull rtfpessoa/bitwarden-ruby:${RUBY_API_VERSION}
}

# Commands

if [ "$1" == "start" -o "$1" == "restart" ]
then
  restart
elif [ "$1" == "pull" ]
then
  dockerComposePull
elif [ "$1" == "stop" ]
then
  dockerComposeDown
elif [ "$1" == "update" ]
then
  dockerComposeDown
  pullSetup
  restart
fi
