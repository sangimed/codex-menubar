.PHONY: check build test run clean

check:
	./scripts/check-environment.sh

build:
	swift build

test:
	swift test

run:
	swift run CodexMenuBar

clean:
	swift package clean
