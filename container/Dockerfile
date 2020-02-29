FROM ruby:2.4
WORKDIR /app

COPY Gemfile .
RUN bundle install 

COPY . .
EXPOSE 4567

CMD ["./container/entrypoint.sh"]
