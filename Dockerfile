FROM ruby:2.3

RUN apt-get update \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

ENV RAILS_ENV production
ENV RAILS_SERVE_STATIC_FILES 1

ADD Gemfile /rails/bonnie/Gemfile
ADD Gemfile.lock /rails/bonnie/Gemfile.lock

WORKDIR /rails/bonnie

RUN bundle install --without development test

ADD . /rails/bonnie

RUN bundle exec rake assets:precompile

EXPOSE 3000
