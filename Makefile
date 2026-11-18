# Standalone dylib for a sideloaded IPA. Requires Xcode.
.PHONY: all verify
all:
	bash scripts/build.sh
verify:
	python3 scripts/verify_macho.py out/RiseInsta.dylib
