FROM docker:latest

WORKDIR /endtoend

ARG VITESS_VERSION=""
ENV VITESS_VERSION=$VITESS_VERSION

# Install necessary dependencies
RUN apk add --no-cache curl bash make mysql-client
