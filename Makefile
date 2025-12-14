.PHONY: build run debug clean test

build:
	nimble build

run:
	nimble run

debug:
	nimble run --debugger:native

clean:
	nimble clean
	rm -f tide
	find . -name "*.o" -delete
	find . -name "*.exe" -delete

test:
	echo "Tests not implemented yet."
