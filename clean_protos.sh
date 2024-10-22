#!/bin/bash

# Set the proto path
PROTO_PATH="lib/src/proto"

# Set the output directory for Dart code
DART_OUT="lib/src/proto/dht"

# File extensions to clean up
FILE_EXTENSIONS=("pb.dart" "pbenum.dart" "pbjson.dart" "pbserver.dart")

# Find all generated files in the output directory
find "$DART_OUT" \( -name "*.pb.dart" -o -name "*.pbenum.dart" -o -name "*.pbjson.dart" -o -name "*.pbserver.dart" \) -print0 | while IFS= read -r -d $'\0' dart_file; do
  # Extract the filename without extension
  filename=$(basename "$dart_file")
  filename_no_ext="${filename%.*}"
  filename_no_ext="${filename_no_ext%.*}"
  filename_no_ext="${filename_no_ext%.*}"
  filename_no_ext="${filename_no_ext%.*}"


  # Construct the expected .proto file path
  proto_file="$PROTO_PATH/$filename_no_ext.proto"

  # Check if the corresponding .proto file exists
  if [[ ! -f "$proto_file" ]]; then
    # If .proto file doesn't exist, delete the generated file
    echo "Deleting stranded file: $dart_file"
    rm "$dart_file"
  fi
done

echo "Protocol Buffer cleanup complete."
