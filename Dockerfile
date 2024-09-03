FROM ruby:3.2

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /usr/src/app

# COPY Gemfile Gemfile.lock ./
# RUN bundle install

COPY . .
RUN bundle install

CMD ["tail", "-f", "/dev/null"]
