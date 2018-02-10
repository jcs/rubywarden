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

OUTPUT_DIR="../."
if [ $# -gt 0 ]
then
  OUTPUT_DIR=$1
fi

CORE_VERSION="latest"
if [ $# -gt 1 ]
then
  CORE_VERSION=$2
fi

WEB_VERSION="latest"
if [ $# -gt 2 ]
then
  WEB_VERSION=$3
fi

RUBY_API_VERSION="latest"
if [ $# -gt 3 ]
then
  RUBY_API_VERSION=$4
fi

mkdir -p ${OUTPUT_DIR}

LETS_ENCRYPT="n"
read -p "(!) Enter the domain name for your bitwarden instance (ex. bitwarden.company.com): " DOMAIN

if [ "$DOMAIN" == "" ]
then
  DOMAIN="localhost"
fi

if [ "$DOMAIN" != "localhost" ]
then
  read -p "(!) Do you want to use Let's Encrypt to generate a free SSL certificate? (y/n): " LETS_ENCRYPT
  
  if [ "$LETS_ENCRYPT" == "y" ]
  then
    read -p "(!) Enter your email address (Let's Encrypt will send you certificate expiration reminders): " EMAIL
    mkdir -p ${OUTPUT_DIR}/letsencrypt
    docker pull certbot/certbot
    docker run -it --rm --name certbot -p 80:80 -v ${OUTPUT_DIR}/letsencrypt:/etc/letsencrypt/ certbot/certbot \
    certonly --standalone --noninteractive  --agree-tos --preferred-challenges http --email ${EMAIL} -d ${DOMAIN} \
    --logs-dir /etc/letsencrypt/logs
  fi
fi

docker pull rtfpessoa/bitwarden-ruby:${RUBY_API_VERSION}
docker run -it --rm --name setup -v ${OUTPUT_DIR}:/bitwarden rtfpessoa/bitwarden-ruby:${RUBY_API_VERSION} \
ruby docker/setup.rb -o /bitwarden -d ${DOMAIN} -l ${LETS_ENCRYPT} -c ${CORE_VERSION} -w ${WEB_VERSION}  -r ${RUBY_API_VERSION}

echo ""
echo "Setup complete"
