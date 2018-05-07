FROM ruby:2.3

ENV RACK_ENV production
RUN mkdir /app
WORKDIR /app

COPY Gemfile .
COPY Gemfile.lock .
RUN bundle install

COPY . .

EXPOSE $PORT
