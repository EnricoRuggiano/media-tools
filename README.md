# Media-Tools
Docker `Alpine` image with preinstalled video tools:
* `FFmpeg`
* `TSduck`
* `Vmaf`
* `srt-live-transmit`

## Versions
```sh
FFMPEG_version=n8.0
TSDUCK_version=v3.44-4676
SRT_version=v1.5.5
VMAF_version=3.0.0
easyVmaf_hash=31c59a444445125265044789d0754db8f39f71be
```
## Scripts
The image provides a script directory where you can push some `Python` scripts.

Examples:
- `scte35-monitor.sh`: monitor incoming SCTE-35 packets 
- `dsmcc-monitor.py`: monitor incoming DSMCC packets
- `easyvmaf.sh`: entrypoint to run `easyVmaf.py` library

## DockerHub
The docker image is public on [DockerHub](https://hub.docker.com/r/lalalaciccio/media-tools)

## Usage

Run the container locally
```
make start
```

Deploy a Pod in Kubernetes using the image
```
make deploy
```

## Building

To build the image locally
```
make build 
```
