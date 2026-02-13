ARGS ?= -prod -d dynamic_boehm
BIN_DIR ?= /usr/local/bin
BIN_NAME ?= spotv
LAUNCHAGENT_NAME ?= xyz.leodev.spotv.app
LAUNCHAGENTS ?= $(HOME)/Library/LaunchAgents
LAUNCHAGENT_PATH ?= $(LAUNCHAGENTS)/$(LAUNCHAGENT_NAME).plist

.PHONY: build update install fmt

build:
	v $(ARGS) -o $(BIN_NAME) .

update: build
	cp $(BIN_NAME) $(BIN_DIR)/$(BIN_NAME)

install: update
	cp assets/launchagent.plist $(LAUNCHAGENT_PATH)
	sed -i '' 's|{BIN}|$(BIN_DIR)/$(BIN_NAME)|g' $(LAUNCHAGENT_PATH)
	sed -i '' 's|{NAME}|$(LAUNCHAGENT_NAME)|g' $(LAUNCHAGENT_PATH)

	@echo "Please grant the application Accessibility permissions in System Preferences > Security & Privacy > Accessibility."
	@echo "Drag the application into the list (it won't be displayed in the settings!)"
	@open -R $(BIN_DIR)/$(BIN_NAME)
	@open /System/Library/PreferencePanes/Security.prefPane

fmt:
	v fmt -w .
