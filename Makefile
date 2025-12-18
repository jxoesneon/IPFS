# Makefile for dart_ipfs
# Centralized development task automation

.PHONY: all analyze test doc clean format protos pub-get

# Proto path configurations
PROTO_PATH = lib/src/proto
DART_OUT = lib/src/proto/dht
PROTOC_CMD = protoc

all: pub-get analyze test

# Install dependencies
pub-get:
	dart pub get

# Static analysis
analyze:
	dart analyze lib/ test/

# Run tests
test:
	dart test test/ --reporter=compact

# Generate documentation
doc:
	dart doc

# Format code
format:
	dart format .

# Compile Protocol Buffers
protos: clean-protos
	@echo "Compiling Protocol Buffers..."
	find $(PROTO_PATH) -name "*.proto" -print0 | xargs -0 -I {} $(PROTOC_CMD) \
		--proto_path=$(PROTO_PATH) \
		--dart_out=$(DART_OUT) \
		-I=$(PROTO_PATH) {}
	@echo "Protocol Buffer compilation complete."

# Cleanup generated and runtime data
clean:
	@echo "Cleaning up build artifacts and local data..."
	rm -rf doc/api/
	rm -rf coverage/
	rm -rf blog_data/
	rm -rf ipfs_data/
	rm -rf online_data/
	rm -rf gateway_data/
	rm -rf p2p_data/
	rm -rf chat_data*/
	rm -rf fileshare_data/
	rm -rf cdn_data/
	rm -rf ipfs.log
	rm -rf .dart_tool/
	rm -rf example/ipfs_dashboard/build/
	@echo "Cleanup complete."

# Helper to remove stranded .pb.dart files if .proto is missing
clean-protos:
	@echo "Cleaning stranded Protocol Buffer artifacts..."
	find $(DART_OUT) \( -name "*.pb.dart" -o -name "*.pbenum.dart" -o -name "*.pbjson.dart" -o -name "*.pbserver.dart" \) -print0 | while IFS= read -r -d $$'\0' dart_file; do \
		filename=$$(basename "$$dart_file"); \
		filename_no_ext=$${filename%%.*}; \
		proto_file="$(PROTO_PATH)/$$filename_no_ext.proto"; \
		if [ ! -f "$$proto_file" ]; then \
			echo "Deleting stranded file: $$dart_file"; \
			rm "$$dart_file"; \
		fi; \
	done
	@echo "Protocol Buffer cleanup complete."
