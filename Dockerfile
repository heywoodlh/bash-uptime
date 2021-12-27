FROM alpine:latest
LABEL maintainer=heywoodlh

RUN apk --no-cache add bash coreutils grep sed iputils curl

RUN mkdir -p /app
COPY uptime.sh /app/uptime.sh
WORKDIR /app

ENTRYPOINT "/app/uptime.sh" 
