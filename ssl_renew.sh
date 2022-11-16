#!/bin/bash

dc="$(command -v docker-compose)"
d="$(command -v docker)"
g="$(command -v grep)"

cd project_path && \
"$dc" -f docker-compose.yml run certbot renew --dry-run && \
"$dc" -f docker-compose.yml kill -s SIGHUP webserver && \
"$d" rm $("$d" ps -qa --no-trunc --filter "ancestor=certbot/certbot" | "$g" -v $("$d" ps -qa --no-trunc --filter "name=^certbot"))