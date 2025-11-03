.PHONY: build run publish

build:
	docker build -t lalalaciccio/media-tools:latest .
	docker image prune -f --filter label=stage=builder

run:
	docker run -it -w /app -v ./scripts:/app/scripts lalalaciccio/media-tools:latest 

start:
	make run

publish:
	docker push lalalaciccio/media-tools:latest	