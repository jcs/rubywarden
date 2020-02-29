#!/usr/bin/env bash

bundle exec rake db:migrate && bundle exec rackup -p 4567 config.ru
