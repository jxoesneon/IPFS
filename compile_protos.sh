#!/bin/bash

# Set the protoc command (adjust if needed)
PROTOC_CMD="protoc"

# Set the proto path
PROTO_PATH="lib/src/proto"

# Set the output directory for Dart code
DART_OUT="lib/src/proto/dht"

# Compile all .proto files in lib/src/proto
find "$PROTO_PATH" -name "*.proto" -print0 | while IFS= read -r -d $'\0' proto_file; do
  # Extract the filename without extension
  filename=$(basename "$proto_file" .proto)

  # Construct the package name
  package_name="ipfs.dht.$filename"

  # Execute protoc command
  $PROTOC_CMD \
    --proto_path="$PROTO_PATH" \
    --dart_out="$DART_OUT" \
    -I="$PROTO_PATH" \
    "$proto_file"
    # in proto file we should have 
    # option dart_package = "package:your_package_name/proto/dht/$filename.pb.dart"; 
    # and we should change -I

done

echo "Protocol Buffer compilation complete."
