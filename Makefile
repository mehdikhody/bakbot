NAME = bakbot
VERSION = $(shell git describe --tags --abbrev=0 2>/dev/null || echo "0.0.1")
BUILD_COMMIT = $(shell git rev-parse HEAD)
BUILD_DATE = $(shell date -u +%Y-%m-%dT%H:%M:%SZ)

LDFLAGS := -s -w \
	-X github.com/mehdikhody/bakbot/internal/version.Version=$(VERSION) \
	-X github.com/mehdikhody/bakbot/internal/version.Commit=$(BUILD_COMMIT) \
	-X github.com/mehdikhody/bakbot/internal/version.Date=$(BUILD_DATE)

BUILD_DIR = build
OUTPUT = $(BUILD_DIR)/$(NAME)

ifeq ($(OS),Windows_NT)
	OUTPUT := $(OUTPUT).exe
endif

all: build

clean:
	rm -rf $(BUILD_DIR)

build: clean
	mkdir -p $(BUILD_DIR)
	go build -ldflags "$(LDFLAGS)" -o $(OUTPUT) cmd/$(NAME)/main.go