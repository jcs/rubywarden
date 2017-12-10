FROM ruby:alpine

ENV APP_HOME=/opt/bitwarden-ruby RACK_ENV=production PORT=4567
WORKDIR $APP_HOME

# Needed for build but can be discarded.
RUN apk add --no-cache --virtual .build-deps build-base gcc abuild binutils linux-headers git 
RUN apk add --no-cache sqlite-dev 
RUN git clone https://github.com/jcs/bitwarden-ruby.git ${APP_HOME} 
RUN bundle install 
RUN apk del .build-deps

ARG UID=1001
ARG GID=1001

RUN addgroup -g ${GID} abc 
RUN adduser -D -u ${UID} -G abc abc 
RUN chown -R ${UID}:${GID} ${APP_HOME}/db

EXPOSE ${PORT}
VOLUME ["${APP_HOME}/db"]
USER abc

ENTRYPOINT ["bundle","exec"]
CMD rackup -p ${PORT} config.ru
