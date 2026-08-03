#!/bin/bash

SOURCE=$1
SCTE35_PID=${2:-96}
PCR_PID=${3:-48}
CSV_OUT_FILE=${4:-scte35-events.csv}

# Initialize CSV with headers if it doesn't exist
if [ ! -f "$CSV_OUT_FILE" ]; then
    echo "TIME,COMMAND_TYPE,PAYLOAD" > "$CSV_OUT_FILE"
fi

# Check if SOURCE is provided
if [ -z "$SOURCE" ]; then
    echo "Error: SOURCE URL is required"
    echo "Usage: $0 <source_url> [SCTE35_PID] [PCR_PID] [CSV_OUTPUT_FILE]"
    echo "Example: $0 10.0.0.1:5001 96 48 scte35-events.csv"
    exit 1
fi

# Run tsduck and parse JSON output
TSP_CMD="tsp -I srt ${SOURCE} -P splicemonitor --time-pid ${PCR_PID} --time-stamp --meta-sections --splice-pid ${SCTE35_PID} --no-adjustment --select-commands 0-255 --display-commands --json-line -O drop"
echo "Running following tsp command:"
echo "$TSP_CMD"
echo "Saving the results to ${CSV_OUT_FILE}"
eval "$TSP_CMD" 2>&1 | sed -n 's/^\* splicemonitor: //p' | \
jq -r --unbuffered '
# Function to get command type from splice_information_table or event
def get_command_type:
  if .["#name"] == "splice_information_table" then
    # Get command type from second node in splice_information_table
    .["#nodes"][1]["#name"] // "unknown"
  elif .["#name"] == "event" then
    "event"
  else
    .["#name"] // "unknown"
  end;

# Function to get time - check multiple fields
def get_time:
  if .time then .time
  elif .["event-time"] then .["event-time"]
  elif .["#nodes"] then
    (.["#nodes"][0].time // .["#nodes"][0]["event-time"] // "unknown")
  else "unknown"
  end;

# Function to extract hex payload from metadata section
def get_payload:
  if .["#nodes"] then
    (.["#nodes"][0]["#nodes"][] | select(.["#name"] == "section") | .["#nodes"][0]) // "unknown"
  else
    "unknown"
  end;

# Main processing logic
if .["#name"] == "splice_information_table" then
  if .["#nodes"][1]["#name"] == "time_signal" then
    # For time_signal, we only process paired events (skip pending, only get occurred)
    # This will be handled by checking if there is corresponding event with progress="occurred"
    # For now, we output if we have metadata
    if .["#nodes"][0].time then
      {
        time: .["#nodes"][0].time,
        type: "time_signal",
        payload: (.["#nodes"][0]["#nodes"][] | select(.["#name"] == "section") | .["#nodes"][0])
      }
    else empty
    end
  else
    # For other splice commands (splice_null, splice_schedule, etc.)
    if .["#nodes"][0].time then
      {
        time: .["#nodes"][0].time,
        type: (.["#nodes"][1]["#name"] // "unknown"),
        payload: (.["#nodes"][0]["#nodes"][] | select(.["#name"] == "section") | .["#nodes"][0])
      }
    else empty
    end
  end
elif .["#name"] == "event" and (.progress == "occurred" or .progress == null) then
  # Only include occurred events, skip pending
  {
    time: .time,
    type: "event",
    payload: "N/A"
  }
else
  empty
end |
"\(.time // "unknown"),\(.type // "unknown"),\(.payload // "unknown")"
' >> "$CSV_OUT_FILE"