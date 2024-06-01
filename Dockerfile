FROM ruby:3.3.2

WORKDIR /srv/blog
COPY . .
RUN gem update bundler && bundle install