.PHONY: build test deb clean

build:
	meson setup build -Dprofile=development -Dlibunwind=disabled
	meson compile -C build

test:
	python3 debian/run-tests.py build

deb:
	dpkg-buildpackage -b -us -uc

clean:
	dh_clean
