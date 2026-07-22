install:
	killall convey || true
	meson setup build-release -Dprofile=release --prefix=/usr/local
	sudo ninja -C build-release install

clear-cache:
	rm -rf ~/.cache/geary
	rm -rf ~/.local/share/geary
	rm -rf ~/.config/geary
