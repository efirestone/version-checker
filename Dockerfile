FROM alpine:3.10
MAINTAINER Eric Firestone <@firetweet>

VOLUME ["/data"]

RUN mkdir /app
WORKDIR /app

COPY ./Gemfile /app
COPY ./Gemfile.lock /app
COPY ./docker/startup.sh /
COPY ./app /app

# Packages only needed during image setup
ENV BUILDTIME_PACKAGES build-base ruby-bundler ruby-dev

# Packages needed to run the application
ENV RUNTIME_PACKAGES libxslt-dev openssh-client ruby

# Update and install all of the required packages.
# At the end, remove the apk cache
RUN apk update && \
    apk upgrade && \
    apk add --no-cache $BUILDTIME_PACKAGES && \
    apk add --update $RUNTIME_PACKAGES && \
    bundle config --global silence_root_warning 1 && \
    bundle config build.nokogiri --use-system-libraries && \
    bundle install --no-cache --clean --force && \
    apk del $BUILDTIME_PACKAGES && \
    rm -rf /var/cache/apk/* && \
    rm /app/Gemfile*

ENTRYPOINT ["/startup.sh"]
