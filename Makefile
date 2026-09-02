install:
	killall convey || true
	meson setup build-release --prefix=/usr/local
	sudo ninja -C build-release install

clear-cache:
	rm -rf ~/.cache/convey
	rm -rf ~/.local/share/convey
	rm -rf ~/.config/convey
