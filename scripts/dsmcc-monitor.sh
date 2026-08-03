#!/bin/bash

SOURCE=$1
DSMCC_PID=${2:-810}

# Check if SOURCE is provided
if [ -z "$SOURCE" ]; then
    echo "Error: SOURCE URL is required"
    echo "Usage: $0 <source_url> [DSMCC_PID]"
    echo "Example: $0 10.0.0.1:5001 810"
    exit 1
fi

TSP_CMD="tsp -I srt ${SOURCE} -P tables --pid ${DSMCC_PID} --log-hexa-line=200 -O drop  2>&1 | python3 /app/scripts/dsmcc-extractor.py"
echo "Running following tsp command:"
echo "$TSP_CMD"
eval "$TSP_CMD" 