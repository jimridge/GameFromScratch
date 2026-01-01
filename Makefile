# ==============================
# GameFromScratch Makefile
# ==============================
APP_NAME := GameFromScratch
SRC_DIR := src
BUILD_DIR := build
APP_DIR := $(BUILD_DIR)/$(APP_NAME).app
BIN := $(APP_DIR)/Contents/MacOS/$(APP_NAME)

# # Sources and objects
# SRC := $(wildcard $(SRC_DIR)/*.m)
# OBJ := $(SRC:.m=.o)
# -----------------------------
# Sources and objects
# -----------------------------
# Find all .m and .c files
SRC := $(wildcard $(SRC_DIR)/*.m) $(wildcard $(SRC_DIR)/*.c)

# Place object files in build/ matching source structure
OBJ := $(patsubst $(SRC_DIR)/%, $(BUILD_DIR)/%, $(SRC:.m=.o))
OBJ := $(patsubst $(BUILD_DIR)/%, $(BUILD_DIR)/%, $(OBJ:.c=.o))

# Dependency files
DEP := $(OBJ:.o=.d)


# Compiler flags
CFLAGS := -O0 -Wall -Wextra -g
LDFLAGS := -framework Cocoa

# ------------------------------
# Default target
# ------------------------------
all: $(BIN)

# ------------------------------
# Build the app bundle
# ------------------------------
$(BIN): $(OBJ) $(APP_DIR)/Contents/Info.plist
	@mkdir -p $(APP_DIR)/Contents/MacOS
# 	@mkdir -p $(APP_DIR)/Contents
	clang $(OBJ) -o $@ $(LDFLAGS)

# ------------------------------
# Auto-generate Info.plist
# ------------------------------
$(APP_DIR)/Contents/Info.plist:
	@mkdir -p $(APP_DIR)/Contents
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $@
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $@
	@echo '<plist version="1.0">' >> $@
	@echo '<dict>' >> $@
	@echo '    <key>CFBundleName</key><string>$(APP_NAME)</string>' >> $@
	@echo '    <key>CFBundleExecutable</key><string>$(APP_NAME)</string>' >> $@
	@echo '    <key>CFBundleIdentifier</key><string>com.example.$(APP_NAME)</string>' >> $@
	@echo '    <key>CFBundlePackageType</key><string>APPL</string>' >> $@
	@echo '    <key>LSMinimumSystemVersion</key><string>11.0</string>' >> $@
	@echo '</dict></plist>' >> $@

# -----------------------------
# Compile .m files into .o in build/
# -----------------------------
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.m
	@mkdir -p $(dir $@)
	clang $(CFLAGS) -c $< -o $@

# Compile .c files into .o in build/
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	clang $(CFLAGS) -c $< -o $@
# ------------------------------
# Include dependency files if they exist
# ------------------------------
-include $(DEP)

# ------------------------------
# Run the app
# ------------------------------
run: all
	open $(APP_DIR)

# ------------------------------
# Clean build artifacts
# ------------------------------
clean:
	rm -rf $(BUILD_DIR) $(OBJ) $(DEP)