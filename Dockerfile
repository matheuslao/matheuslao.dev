FROM ruby:3.4.8

WORKDIR /srv/blog
COPY . .
RUN gem update bundler && bundle install