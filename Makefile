.PHONY: build run clean test

build:
	nimble build

run:
	nim c -r src/nexus.nim

debug:
	nim c -r --debugger:native src/nexus.nim

clean:
	rm -f nexus
	find . -name "*.o" -delete
	find . -name "*.exe" -delete

test:
	echo "Tests coming soon"
