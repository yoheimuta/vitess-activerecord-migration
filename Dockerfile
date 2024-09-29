ARG RUBY_VERSION=""

FROM ruby:$RUBY_VERSION

WORKDIR /migration

CMD ["tail", "-f", "/dev/null"]
