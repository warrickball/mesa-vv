BUILD_DIR := build

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)%/:
	mkdir -p $@
