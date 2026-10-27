# Downstream modification: 2026-10-27 — install the owner-selected closed-envelope artwork.
system_icons_dir = join_paths(data_dir, 'icons', 'hicolor')

icon_files = files(
  'mail-archive-symbolic.svg',
  'close-symbolic.svg',
  'detach-symbolic.svg',
  'text-x-generic-symbolic.svg',
  'edit-symbolic.svg',
  'font-size-symbolic.svg',
  'font-color-symbolic.svg',
  'format-ordered-list-symbolic.svg',
  'format-ordered-list-symbolic-rtl.svg',
  'format-text-remove-symbolic.svg',
  'format-toolbar-toggle-symbolic.svg',
  'format-unordered-list-symbolic.svg',
  'format-unordered-list-symbolic-rtl.svg',
  'mail-drafts-symbolic.svg',
  'mail-drafts-symbolic-rtl.svg',
  'mail-inbox-symbolic.svg',
  'mail-outbox-symbolic.svg',
  'mail-reply-list-symbolic.svg',
  'mail-reply-list-symbolic-rtl.svg',
  'mail-sent-symbolic.svg',
  'mail-sent-symbolic-rtl.svg',
  'tag-symbolic.svg',
  'tag-symbolic-rtl.svg',
)

install_data(icon_files,
  install_dir: join_paths(system_icons_dir, 'scalable', 'actions'),
)

scalable_dir = join_paths('hicolor', 'scalable', 'apps')

brand_dir = meson.project_source_root() / 'brand'
app_icon = 'griabuntu-mail-app-icon'
if get_option('nightly')
  app_icon = 'griabuntu-mail-app-icon-nightly'
endif

install_data(
  brand_dir / (app_icon + '.svg'),
  install_dir: join_paths(data_dir, 'icons', scalable_dir),
  rename: '@0@.svg'.format(griabuntu_mail_id),
)

foreach size : [16, 24, 32, 48, 64, 128, 256, 512]
  install_data(
    brand_dir / '@0@-@1@.png'.format(app_icon, size),
    install_dir: system_icons_dir / '@0@x@0@'.format(size) / 'apps',
    rename: '@0@.png'.format(griabuntu_mail_id),
  )
endforeach

symbolic_dir = join_paths('hicolor', 'symbolic', 'apps')

install_data(
  brand_dir / 'griabuntu-mail-tray.svg',
  install_dir: join_paths(data_dir, 'icons', scalable_dir),
  rename: '@0@-tray.svg'.format(griabuntu_mail_id),
)

install_data(
  brand_dir / 'griabuntu-mail-symbolic.svg',
  install_dir: join_paths(data_dir, 'icons', symbolic_dir),
  rename: '@0@-symbolic.svg'.format(griabuntu_mail_id)
)

install_data(brand_dir / 'README.md',
  install_dir: license_dir,
  rename: 'Griabuntu-Mail-Artwork.md',
)
