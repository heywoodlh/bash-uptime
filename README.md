## Uptime Monitoring BASH Script:

This is a ridiculously simple BASH script that relies on common GNU tools to do ICMP or HTTP monitoring. All this script reports is if a website or host is unresponsive.

## Quickstart:

Create an example config file in `/tmp/uptime.yaml`:

```
ping:
  hosts:
    - 1.1.1.1
    - google.com
    - bad-garbage-site.net
  options: "-c 1 -W 1"
  silent: "true"
curl:
  urls:
    - "http://google.com"
    - "http://bad-garbage-site.net"
  options: "-LI --silent"
  silent: "true"
```

Then run the Docker container using the new config file:

```
docker run -it -v /tmp/uptime.yaml:/app/uptime.yaml heywoodlh/bash-uptime
```

## Example usage:

Create a cron that runs every hour that will send a notification via Gotify's CLI when one of your monitored hosts is down. 

```
0 * * * * gotify push $(docker run -it -v /tmp/uptime.yaml:/app/uptime.yaml heywoodlh/bash-uptime | grep DOWN)
```
