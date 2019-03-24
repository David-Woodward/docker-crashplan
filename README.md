# Headless CrashPlan for Small Business Docker Image

(Yes, this still works for CrashPlan 6.9.2)

# Disclaimers
**IMPORTANT: DO NOT CONTACT CODE42 FOR SUPPORT USING CRASHPLAN WITH THIS DOCKER IMAGE**

This docker image is provided for educational purposes only to aid in development of lightweight docker images with minimal dependencies.  Downloading and creating Docker containers from this image implies use of [CrashPlan for Small Business](https://www.crashplan.com/en-us/) and agreement with the [Code42 service agreement and terms and conditions](https://support.code42.com/Terms_and_conditions/Legal_terms_and_conditions/CrashPlan_for_Small_Business_Master_services_agreement).  Interpretation of the Code42 service agreement, terms, and conditions is an exercise left for the reader to determine if use of this Docker image constitutes a breach of the aforementioned agreement which could have repercussions including cancelation of your service and/or loss of your backups.

The developers of CrashPlan, [Code42](https://code42.com), have explicitly stated that use of CrashPlan in a headless environment (or on a NAS) is [not supported](https://support.code42.com/CrashPlan/4/Configuring/Use_CrashPlan_on_a_headless_computer) and have recently gone a step further making [changes in version 6.6.0](https://support.code42.com/Release_Notes/CrashPlan_for_Small_Business_version_6.6) to ~~remove~~ hide the headless functionality.  This Docker image demonstrates that these changes were not likely to have been made due to any technical limitation of the CrashPlan software since restoring the headless functionality can be achieved using simple command line networking tools - no modification to the CrashPlan software is necessary.  It's more probable that hiding headless functionality was a business decision made in an effort to eliminate the overhead of headless/NAS users (too much data?  too many support calls?).  So, although this image could be used to allow continued use of CrashPlan on a NAS or in another headless environment, it would be wise to consider this a temporary measure at best.  Recognizing Code42's growing intollerance for headless/NAS installations, it may be time to look at other *supported* solutions for backing up your data.

---

# Description
A lightweight (251MB) Crashplan Docker image supporting headless operations from a CrashPlan client running on a remote system.  For example, using this Docker image, CrashPlan services can run directly on a Synology NAS and then can be configured/controlled from a standard CrashPlan installation on a Windows laptop.

This Docker image is an amalgamation of two other well known Docker images: [JrCs/crashplan](https://github.com/JrCs/docker-crashplan) and [jlesage/crashplan-pro](https://github.com/jlesage/docker-crashplan-pro).  The image has the lightweight/headless operation of the older JrCs image, but uses the volume/directory structure used by the more recent jlesage image.  This allows for easy migration to a jlesage container if needed (for example if future CrashPlan releases include changes that prevent the techniques used by this image to allow headless operations).  The image does support running under the old JrCs volume/directory structure to allow for initial testing by users who are currently using a JrCs based container, but it is recommended that containers based on this image be run with the new jlesage volume (/config) as support and the JrCs volume (/var/crashplan) may be dropped from future versions.

Since this image is based off of the JrCs image and is intended to mimic the jlesage image as closely as possible, it is likely that it can be used in many of the same environments as those images.  However, it has currently only been tested on a Synology NAS.

---

# Educational Use
The minimalist design concepts used in this Docker image make it well suited for demonstrating how easy it is to create your own Docker images.  Containing only roughly 650 lines of shell script, an official Alpine Linux base image, and a handful of Alpine pkg installs, you could easily perform your own code review of this image in an afternoon (unless you want to review through the Apline/pkg sources also ... good luck).

**NOTE:** The build script/process is tailored for use directly on a Synology NAS which does not natively include some of the more common development tools like [make](https://www.gnu.org/software/make/).  This does slightly reduce the value of the Docker image as a teaching aid, but it also lowers the barrier to entry for building and testing on a Synology NAS since it will only require SSH access to the NAS to get started. 

---

# Usage

### Quick Start

**NOTE**: The Docker command below is only an example and will need to be modified for your environment.

Create/Launch the CrashPlan Headless docker container with the following command:
```
docker run --detach \
    --name CrashPlan-Headless \
    --volume /volume1/docker/crashplan-headless:/config \
    --volume /volume1/critical_data:/storage:ro \
    --volume /volume1/Temp/CrashPlan-Restores:/restores \
    --volume /etc/localtime:/etc/localtime:ro \
    --env PUBLIC_IP=192.168.1.20 \
    --env PUBLIC_PORT=4244 \
    --publish 4244:4244 \
    --hostname $(hostname) \
    woodwarden/crashplan-headless:latest
```

Where:
  - `/volume1/docker/crashplan-headless`: **[CRITICAL]** The path on the Docker host where the CrashPlan container stores its configuration, logs, and any files needing persistency.  The container will run without this volume being specified, but upgrading to a new version of the image may not be possible without starting over from scratch with a new CrashPlan configuration and using the [adoption process](https://support.code42.com/CrashPlan/6/Configuring/Replace_your_device).
  - `/volume1/critical_data`: A path on the Docker host that needs to be backed up by CrashPlan.  This line can be duplicated to add additional paths from the host as needed.  ***[Recommended to be mounted as `ro` - readonly - as shown for additional security]***
  - `/storage`: The path within the Docker container that will be used to expose the host file system to CrashPlan for backup.  This can be changed as desired to allow for multiple volumes (ie. /storage/pictures, /storage/work, ...) or to allow consistency with a previous CrashPlan installation/system that is be replaced by the CrashPlan installation in the docker container (See the [instructions for the replacement/adoption process](https://support.code42.com/CrashPlan/6/Configuring/Replace_your_device) on the CrashPlan website).  For example, if a previous CrashPlan installation on the host was backing up /volume1, then to stay consistent `--volume /volume1:/volume1:ro"` would be used in the Docker statement to recreate the same "/volume1" path within the Docker container.  This would allow the CrashPlan instance in the Docker container to see the same path for file versioning/retention purposes rather than showing the old path as being deleted and an entireley new path as being created - as would be the case if you were to use `--volume /volume1:/storage:ro`.
  - `/volume1/Temp/CrashPlan-Restores`: Optional writable path on the host file system for CrashPlan to use for data restores when `/volume1/critical_data` is mounted to `/storage` as read only (`ro`).
  - `/etc/localtime`: Optional volume/mount for using the same timezone in the docker container and the host.

### Access the headless CrashPlan service from a locally installed CrashPlan client
- Install CrashPlan on the system that will be used to manage the headless CrashPlan installation and then immediately kill all CrashPlan processes if any were started
- Start the CrashPlan container on the headless system and wait at least 1 minute before proceeding to the next step to allow for the files below to be generated and modified (an entry in the Docker container logs that says *"Updating .ui_info to direct clients to 192.168.1.20:4244 ..."* indicates file modifications are complete and it's safe to proceed)
- Make a backup of the current `.ui_info` and `service.pem` files on the client machine (located in the paths below):
    * On Linux: `/var/crashplan/data/id/`
    * On OSX: `/Library/Application Support/CrashPlan/`
    * On Windows: `C:\ProgramData\CrashPlan\`
    * On Windows 10 installed per user: `C:\Users\<username>\AppData\Local\CrashPlan\`
- Copy the `.ui_info` and `service.pem` files from the `var` subdirectory under the host directory mapped to the `/config` volume in the Docker container to the client machine at the location above (replacing any existing files which should have been backed up elsewhere).
    For example, copying from the host directory used in the [Quck Start](#quick-start) example to a standard Windows 10 client installation would look like:
    ```
    /volume1/docker/crashplan-headless/var/.ui_info --> C:\ProgramData\CrashPlan
    /volume1/docker/crashplan-headless/var/service.pem --> C:\ProgramData\CrashPlan
    ```
- Start the local CrashPlan GUI (if the CrashPlan GUI fales to connect to the headless instance after a minute or so, you may need to kill all CrashPlan instances on your client system or reboot and then start the GUI again).

## Basic Docker Command Syntax

```
docker run [--detach] \
    --name=CrashPlan-Headless \
    [--env <VARIABLE_NAME>=<VALUE>]... \
    [--volume <HOST_DIR>:<CONTAINER_DIR>[:PERMISSIONS]]... \
    [--publish <HOST_PORT>:<CONTAINER_PORT>]... \
    woodwarden/crashplan-headless
```
| Parameter | Description |
|-----------------|-------------|
| &#x2011;&#x2011;detach, &#x2011;d    | Run the container in background.  If not set, the container runs in foreground - which is generally not the desired state for a service such as CrashPlan that should run continuously. |
| &#x2011;&#x2011;env, &#x2011;e       | Set environmental variables used by the Docker container to modify default behaviors.  See the [Environment Variables](#environment-variables) section for more details. |
| &#x2011;&#x2011;volume, &#x2011;v    | Bind mount a volume in the container.  Makes `HOST_DIR` appear as `CONTAINER_DIR` to CrashPlan.  See the [Data Volumes](#data-volumes) section for more details. |
| &#x2011;&#x2011;publish, &#x2011;p   | Sends network traffic destined for `HOST_PORT` to the `CONTAINER_PORT` that CrashPlan is listening on (both ports should be the same).  See the [Ports](#ports) section for more details. |
| &#x2011;&#x2011;hostname, &#x2011;h | The hostname of the Docker container that CrashPlan will use. |

### Environment Variables

The following variables can be set to modify the default behavior of the container (passed to the docker run/create commands as `-env <VARIABLE_NAME>=<VALUE>`).

| Variable       | Description                                  | Default |
|----------------|----------------------------------------------|---------|
|`PUBLIC_IP`| **[RECOMMENDED]** The public IP address of the host machine running the Docker container.  Setting this variable will allow the container to rewrite the appropriate IP address in the `.ui_info` file allowing it to be copied to the client system with no further modification.  **NOTE:** Unless the container is running on the host network (`--network=host`), setting this variable will generate an error in the docker container logs that says, *"socat[###] E bind(5, {AF=2 192.168.1.20:4244}, 16): Address not available"*.  This error is benign and can be ignored. | (unset) |
|`PUBLIC_PORT`| **[RECOMMENDED]** The TCP port that the Docker container/host machine will be listening on for CrashPlan client/UI connections.  Setting this variable will allow the container to rewrite the appropriate TCP port in the `.ui_info` file allowing it to be copied to the client system with no further modification.  See the [Ports](#ports) section for more information. | `4244` |
|`PUBLIC_INTERFACE`| When set (generally to `eth0`), the Docker container will use the IP address assigned to the container interface designated by the value of this variable as the public IP address to use when creating port proxies and updating the `.ui_info` file.  This is primarily used when the container is on the host network (`--network=host`) to avoid setting the IP information in the container configuration. | (unset) |
|`STOP_CONTAINER_WITH_APP` | When set to `1`, the container will stop when the CrashPlan service is detected in a stopped state | `0` |
|`KEEP_APP_RUNNING`| When set to `1`, the application will be automatically restarted if it crashes or if user stops it. | `1` |
|`CRASH_RESPONSE_DELAY`| The number of seconds the container will pause before taking any action when the CrashPlan service is detected to be in a stopped state.  This delay allows for the user to intervene if need be.  **NOTE:** Low values (ie. < 5) can increase overhead of the container as this also dictates how frequently it will check the state of the CrashPlan service when either `KEEP_APP_RUNNING` or `STOP_CONTAINER_WITH_APP` are set to 1. | `30` |
|`BLOCK_UPGRADES`| When set to `1`, CrashPlan will not be able to automatically upgrade the newer versions.  **WARNING:** Setting this to `0` runs the risk that new versions of CrashPlan may introduce incompatibilites with the Docker image/container (such as headless operations no longer working). | `1` |
|`CLEAN_UPGRADES`| When set to `1`, the same cleanup steps used to keep storage requirements to a minimum during the inital image build will be used after any CrashPlan upgrades are detected (only applicable when `BLOCK_UPGRADES=0`). | `0` |
|`LOG_FILES`| A space/comma delimited list of log files that should be captured in the Docker container logs.  Possible log files at the time of this documentation are: `app.log`, `backup_files.log.0`, `engine_error.log`, `engine_output.log`, `history.log.0`, `restore_files.log.0`, and `service.log.0`.  For more information on log files, see the [CrashPlan documentation](https://support.code42.com/CrashPlan/6/Troubleshooting/Read_Code42_app_log_files). | `history.log.0` |
|`USER_ID`| ID of the user CrashPlan will runs as.  See [User/Group IDs](#usergroup-ids) to better understand when this should be set. | `0` |
|`GROUP_ID`| ID of the group CrashPlan will runs as.  See [User/Group IDs](#usergroup-ids) to better understand when this should be set. | `0` |
|`SUP_GROUP_IDS`| A comma-separated list of supplementary group IDs CrashPlan will run with. | (unset) |
|`TZ`| [TimeZone](http://en.wikipedia.org/wiki/List_of_tz_database_time_zones) of the container.  Timezone can also be set by mapping `/etc/localtime` between the host and the container as demonstrated in the [Quick Start](#quick-start) example. | (unset) |

### Data Volumes

The following table describes the data volumes that should be mapped to the container (passed to the docker run/create commands as `--volume <HOST_DIR>:<CONTAINER_DIR>[:PERMISSIONS]`).

| Container path  | Permissions | Description |
|-----------------|-------------|-------------|
|`/config`| rw | This volume should be mapped to the directory on your host where the CrashPlan container will store its configuration, logs, and any files needing persistency. |
|`/storage` (or any path not otherwise used in a standard linux/CrashPlan installation)| ro/rw (user preference) | Data directories on the host system that need to be backed up should be mapped to the container using ro - readonly - for best security.  However, they can be mapped as rw - read/write - if restoring directly to the original path is desired over tighter security. |
|`/restores` (or any path not otherwise used in a standard linux/CrashPlan installation)| rw | If the `/storage` or other chosen host data volumes were mapped as readonly, then it may be beneficial to map another volume to a directory on the host where CrashPlan will be able to restore data. |

### Ports

Communications between CrashPlan clients and the CrashPlan service running in the container will be relayed through three ports.  For the sake of simplicity it is recommended that all the ports be set to 4244.  The ports can be changed as needed, but they must all be set to the same port number in order to evade CrashPlan's "unsupported configuration" detection.  The three ports traffic is relayed through in order from client to server are:

**(1)** Docker HOST port -> **(2)** Docker CONTAINER port / socat port proxy listening port -> **(3)** CrashPlan service listening port

Port **1** is dictated by the Docker container creation/configuration (`--publish <port>:<port>`).  Ports **2** and **3** are are both controlled by the value provided to the `PUBLIC_PORT` environmental variable during container creation (port 4244 by default).  If all of these ports do not match, commincation between the CrashPlan service and the remote CrashPlan client will likely fail either by timing out, or by producing an "Unsupported Configuration" error from the CrashPlan client..

**NOTE:** If the container is created with the `--network=host` parameter, the `--publish ####:####` parameter should not be used and the `--env PUBLIC_PORT=####` parameter alone will be used to specify the ports used by the container.


## Docker Image Updates

If the system running this image does not provide an easy way to update to a new version of the image, the following commands can be used from a command prompt (`sudo` may be required depending on your system configuration):

1. Pull the latest image:
```
docker pull woodwarden/crashplan-headless
```
2. Stop the current container:
```
docker stop CrashPlan-Headless
```
3. Remove the current container (**IMPORTANT** - If the `/config` volume was not manually mapped to a host directory during creation of the current container you will likely need to reconfigure CrashPlan and [adopt the previous installation](https://support.code42.com/CrashPlan/6/Configuring/Replace_your_device) after step 4):
```
docker rm CrashPlan-Headless
```
4. Start the container using the same `docker run` command just as you did with the previous image version making sure to use the same host directory mapping for the `/config` volume (refer to the [Quick Start](#quick-start) section above).

### Synology

If the Docker image is running on a Synology NAS, the following steps can be use to update a container image.

1.  Open the *Docker* application.
2.  Click on *Registry* in the left pane.
3.  In the search bar, type the name of the container: *woodwarden/crashplan-headless*.
4.  Select the image, click *Download* and then choose the `latest` tag.
5.  Wait for the download to complete.
6.  Click on *Container* in the left pane.
7.  Select your CrashPlan Headless container.
8.  Stop it by clicking *Action*->*Stop*.
9.  Clear the container by clicking *Action*->*Clear*.  This removes the container while keeping its configuration **WARNING:** Any configuration options provided by creating the container on the command line (through SSH) which are not supported by Synology (such as volume mounts for system directories) will be lost.  These changes are also lost anytime the container is edited through the Synology Docker interface.  To prevent this, avoid using the Synology Docker interface and use the manual steps in the [previous section](#docker-image-updates) to upgrade your image.
10. Start the container again by clicking *Action*->*Start*. **NOTE:**  The container may temporarily disappear from the list while it is re-created.

## User/Group IDs

To reduce complexity and allow for unimpeeded backups, containers based on this image will have root access (`USER_ID=0`) to all data in the HOST directories mapped to the container via `--volume` parameters during container creation.  For the more security concious among us, this can be a little troubling - especially if the volumes are mounted as rw - read/write.  For such security concious individuals, the `USER_ID`, `GROUP_ID`, and `SUP_GROUP_IDS` environmental variables can be used to control the actual user the CrashPlan service runs under and therefore restricting the access it has to the data.

To determine the IDs associated with a specific user on a system, first gain command line access on the system the data is being backed up from, and then run `id <username>` which will generate an output like:
```
uid=1000(myuser) gid=1000(mygroup) groups=1000(mygroup),100(users)
```

The number next to `uid` (user ID) and `gid` (group ID) should be assigned to the `USER_ID` and `GROUP_ID` variables respectively to limit CrashPlan's access to only the directories that the designated user would have access to.

## Troubleshooting

### Shell Access

To troubleshoot a running Docker container, it may be beneficial to gain shell access to the container by executing the following command from the host machine running the Docker container (`sudo` may be required depending on your system configuration):

```
docker exec -ti Container-Name sh
```

Where `Container-Name` is the ID or the name of the running container (ie. `CrashPlan-Headless`).

### Crashes backing up large data sets (greater than 1TB or 1 million files)

When backing up large data sets the following two issues often arise:

1. Running out of memory - Increase the maximum allowed memory using the [instructions on the CrashPlan support site](https://support.code42.com/CrashPlan/6/Troubleshooting/Adjust_Code42_app_settings_for_memory_usage_with_large_backups).

2. File changes are not detected - Update the **host** system with the *inotify* changes recommended by CrashPlan's [Linux real-time file watching errors](https://support.code42.com/CrashPlan/6/Troubleshooting/Linux_real-time_file_watching_errors) aticle.  (On a Synology NAS the inotify's max watch limit must be set in `/etc.defaults/sysctl.conf` instead of `/etc/sysctl.conf` to make the setting permanent - recheck after DSM updates).

### Upgrades Fail

Upgrades are intentionally disabled by default to prevent problems created by new CrashPlan versions that may be difficult to recover from.  The recommended upgrade process is to wait for the new version of CrashPlan to be tested and implemented in a new version of the Docker image and then use the steps documented in the [Docker Image Updates](#docker-image-updates) section to upgrade to the new Docker image.  Alternately, automatic upgrades can be enabled by setting the `BLOCK_UPGRADES` variable to `0` with the understanding that this convenience comes at the risk of rendering the container unusable or incompatible with future image updates.

## Support

Please [create a new issue](https://github.com/David-Woodward/docker-crashplan-headless/issues) if you believe you've identified a bug or area for improvement.  Or if you're feeling really generous, feel free to fork the image repository, fix the bug, and create a pull request.
