DART_LIB_FILES_ALL := $(shell find lib -name *.dart)
DART_TEST_FILES_ALL := $(shell find test -name *.dart)
DART_TEST_FILES := $(shell find test -name *.dart ! -name *.part.dart)

# This section is used to setup the environment for running with mojo_shell.
ETHER_DIR := $(JIRI_ROOT)/release/mojo/syncbase
CROUPIER_DIR := $(shell pwd)
SHELL := /bin/bash -euo pipefail

# Flags for Syncbase service running as Mojo service.
ETHER_FLAGS := --v=1

ifdef ANDROID
	MOJO_ANDROID_FLAGS := --android
	ETHER_BUILD_DIR := $(ETHER_DIR)/gen/mojo/android
	export SYNCBASE_SERVER_URL := "https://mojo.v.io/syncbase_server.mojo"

	# Location of mounttable on syncslides-alpha network.
	MOUNTTABLE := /192.168.86.254:8101
	# Name to mount under.
	NAME := croupier/sb1

	APP_HOME_DIR = /data/data/org.chromium.mojo.shell/app_home
	ANDROID_CREDS_DIR := /sdcard/v23creds

	ETHER_FLAGS += --logtostderr=true \
		--name=$(NAME) \
		--root-dir=$(APP_HOME_DIR)/syncbase_data \
		--v23.credentials=$(ANDROID_CREDS_DIR) \
		--v23.namespace.root=$(MOUNTTABLE)
else
	ETHER_BUILD_DIR := $(ETHER_DIR)/gen/mojo/linux_amd64
	export SYNCBASE_SERVER_URL := file://$(ETHER_BUILD_DIR)/syncbase_server.mojo

	ETHER_FLAGS += --root-dir=$(PWD)/tmp/syncbase_data --v23.credentials=$(PWD)/creds
endif

MOJO_SHELL_FLAGS := --enable-multiprocess --args-for="$(SYNCBASE_SERVER_URL) $(ETHER_FLAGS)"

ifdef ANDROID
	MOJO_SHELL_FLAGS += --map-origin="https://mojo.v.io/=$(ETHER_BUILD_DIR)"
endif

# Runs a sky app.
# $1 is location of flx file.
define RUN_SKY_APP
	pub run sky_tools -v --very-verbose run_mojo \
	--app $1 \
	$(MOJO_ANDROID_FLAGS) \
	--mojo-path $(MOJO_DIR)/src \
	--checked \
	--mojo-debug \
	-- $(MOJO_SHELL_FLAGS)
endef

.DELETE_ON_ERROR:

# Get the packages used by the dart project, according to pubspec.yaml
# Can also use `pub get`, but Sublime occasionally reverts me to an ealier version.
# Only `pub upgrade` can escape such a thing.
packages: pubspec.yaml
	pub upgrade

# Builds mounttabled and principal.
bin: | env-check
	jiri go build -a -o $@/mounttabled v.io/x/ref/services/mounttable/mounttabled
	jiri go build -a -o $@/principal v.io/x/ref/cmd/principal
	touch $@

.PHONY: creds
creds: | bin
	./bin/principal seekblessings --v23.credentials creds
	touch $@

.PHONY: dartfmt
dartfmt:
	dartfmt -w $(DART_LIB_FILES_ALL) $(DART_TEST_FILES_ALL)

.PHONY: lint
lint: packages
	dartanalyzer lib/main.dart | grep -v "\[warning\] The imported libraries"
	dartanalyzer $(DART_TEST_FILES) | grep -v "\[warning\] The imported libraries"

.PHONY: build
build: croupier.flx

croupier.flx: packages $(DART_LIB_FILES_ALL)
	pub run sky_tools -v build --manifest manifest.yaml --output-file $@

.PHONY: start
start: croupier.flx env-check packages
ifdef ANDROID
	# Make creds dir if it does not exist.
	mkdir -p creds
	adb push -p $(PWD)/creds $(ANDROID_CREDS_DIR)
endif
	$(call RUN_SKY_APP,$<)

.PHONY: mock
mock:
	mv lib/src/syncbase/log_writer.dart lib/src/syncbase/log_writer.dart.backup
	mv lib/src/syncbase/settings_manager.dart lib/src/syncbase/settings_manager.dart.backup
	cp lib/src/mocks/log_writer.dart lib/src/syncbase/
	cp lib/src/mocks/settings_manager.dart lib/src/syncbase/

.PHONY: unmock
unmock:
	mv lib/src/syncbase/log_writer.dart.backup lib/src/syncbase/log_writer.dart
	mv lib/src/syncbase/settings_manager.dart.backup lib/src/syncbase/settings_manager.dart

.PHONY: env-check
env-check:
ifndef MOJO_DIR
	$(error MOJO_DIR is not set)
endif
ifndef JIRI_ROOT
	$(error JIRI_ROOT is not set)
endif

# TODO(alexfandrianto): I split off the syncbase logic from game.dart because it
# would not run in a stand-alone VM. We will need to add mojo_test eventually.
.PHONY: test
test: packages
	# Protect src/syncbase/log_writer.dart
	mv lib/src/syncbase/log_writer.dart lib/src/syncbase/log_writer.dart.backup
	mv lib/src/syncbase/settings_manager.dart lib/src/syncbase/settings_manager.dart.backup
	cp lib/src/mocks/log_writer.dart lib/src/syncbase/
	cp lib/src/mocks/settings_manager.dart lib/src/syncbase/
	pub run test -r expanded $(DART_TEST_FILES) || (mv lib/src/syncbase/log_writer.dart.backup lib/src/syncbase/log_writer.dart && exit 1)
	mv lib/src/syncbase/log_writer.dart.backup lib/src/syncbase/log_writer.dart
	mv lib/src/syncbase/settings_manager.dart.backup lib/src/syncbase/settings_manager.dart

.PHONY: clean
clean:
ifdef ANDROID
	# Clean syncbase creds and data dir.
	adb shell rm -rf $(ANDROID_CREDS_DIR) $(APP_HOME_DIR)/syncbase_data
endif
	rm -f croupier.flx snapshot_blob.bin
	rm -rf bin creds tmp

.PHONY: veryclean
veryclean: clean
	rm -rf .packages .pub packages pubspec.lock
