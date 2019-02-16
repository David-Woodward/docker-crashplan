[![](https://img.shields.io/docker/stars/jrcs/crashplan.svg)](https://hub.docker.com/r/jrcs/crashplan 'DockerHub') [![](https://img.shields.io/docker/pulls/jrcs/crashplan.svg)](https://hub.docker.com/r/jrcs/crashplan 'DockerHub')
[![](https://badge.imagelayers.io/jrcs/crashplan:latest.svg)](https://imagelayers.io/?images=jrcs/crashplan:latest 'Get your own badge on imagelayers.io')
# docker-crashplan
Lightweight (243MB) [Crashplan](http://www.crashplan.com) docker container.

## Features:
* Headless CrashPlan for Small Business (6.9.0 - yes it can be managed remotely from your locally installed CrashPlan client just like the old v4.x.x days)
* Automatic version upgrade
* Access to all configuration files
* Access to log files

# Quick Start

- Launch the crashplan container

```bash
docker run -d \
  --name crashplan \
  -h $HOSTNAME \
  -e TZ="${TZ:-$(cat /etc/timezone 2>/dev/null)}" \
  --publish 4244:4244 \
  --volume /srv/crashplan/data:/var/crashplan \
  jrcs/crashplan:latest
```

## Access the GUI from your desktop crashplan application
- Make a backup of the current `.ui_info` and `service.pem` files of your desktop machine locate:
  * On Linux: `/var/crashplan/data/id/.ui_info|service.pem`
  * On OSX: `/Library/Application Support/CrashPlan/.ui_info|service.pem`
  * On Windows: `C:\ProgramData\CrashPlan\.ui_info|service.pem`
  * On Windows 10 installed per user: `C:\Users\<username>\AppData\Local\CrashPlan\.ui_info|service.pem`
- Replace the `.ui_info` and `service.pem` files of your desktop machine with the ones from the host machine directory that you shared with the crashplan docker container: `/srv/crashplan/data/id/.ui_info|service.pem`.
- In the `.ui_info` file of your desktop machine, replace the IP (should be `0.0.0.0` or `127.0.0.1`) with the IP of your docker host (the port documented in `.ui_info` is always one port down from the actual port being used; 4243 by default and 4244 is actually used for communication with your client).
- Make sure you can connect to port 4244 on your docker host.
- Start your local CrashPlan GUI.

# Configuration  

## Volumes:
* `/var/crashplan`: where the configuration files and logs are stored

## Optional environment variables:
* `PUBLIC_IP`and `PUBLIC_PORT`: force the public ip address and port to use.
* `TZ`: time zone to use in the crashplan logs. Use /etc/timezone string values, e.g. "Europe/Paris"
