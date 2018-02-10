FROM ruby:2.4-alpine
LABEL maintainer="rodrigo.fernandes@tecnico.ulisboa.pt"
LABEL version="1.0.0-alpha.1"

ENV LANG C.UTF-8
ENV RACK_ENV production
ENV APP_HOME /opt/bitwarden-ruby
ENV APP_PORT 80
ENV DB_ROOT /bitwarden/db

WORKDIR $APP_HOME

ADD . $APP_HOME

RUN apk add --update --no-cache ruby ruby-dev openssl sqlite-dev \
  && apk add --update --no-cache --virtual .build-deps build-base linux-headers \
  && gem install bundler --no-ri --no-rdoc \
  && bundle install --without dev development test \
  && apk del .build-deps \
  && rm -rf /var/cache/apk/*

EXPOSE $APP_PORT
VOLUME $DB_ROOT

ENTRYPOINT ["bundle", "exec"]
CMD rackup -p $APP_PORT config.ru
