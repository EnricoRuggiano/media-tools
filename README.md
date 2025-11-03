# Media-Tools

Docker image with basic media-tools
* ffmpeg
* tsduck
* srt-live-transmit

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

To build the image locally - only if you want to load specific script under scripts directory
```
make build 
```
