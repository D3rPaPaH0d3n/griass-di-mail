install:
	killall convey || true
	meson setup build-release --prefix=/usr/local
	sudo ninja -C build-release install

uninstall:
	killall convey || true
	sudo ninja -C build-release uninstall

clear-cache:
	rm -rf ~/.cache/convey
	rm -rf ~/.local/share/convey
	rm -rf ~/.config/convey
