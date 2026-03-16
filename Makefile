.PHONY: generate build clean run

generate:
	xcodegen generate

build: generate
	xcodebuild build -project OneOnOne.xcodeproj -scheme OneOnOne -configuration Debug

clean:
	rm -rf DerivedData build
	xcodebuild clean -project OneOnOne.xcodeproj -scheme OneOnOne 2>/dev/null || true

run: build
	open DerivedData/Build/Products/Debug/OneOnOne.app 2>/dev/null || \
	open build/Debug/OneOnOne.app 2>/dev/null || \
	echo "Build the app first with 'make build'"
