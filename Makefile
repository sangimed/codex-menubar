.PHONY: check build test run icon app package clean

check:
	./scripts/check-environment.sh

build:
	swift build

test:
	swift test

run:
	swift run CodexMenuBar

icon:
	bash scripts/generate-app-icon.sh

app:
	bash scripts/build-app.sh

package:
	bash scripts/package-app.sh

clean:
	swift package clean
	rm -rf dist
