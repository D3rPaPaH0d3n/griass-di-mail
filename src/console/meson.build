console_sources = files(
  'main.vala',
)

console_dependencies = [
  config_dep,
  gtk,
  gee,
  gmime,
  libadwaita,
  webkitgtk,
  engine_dep,
]

console_resources = gnome.compile_resources('io.github.d3rpapah0d3n.GriabuntuMailConsole',
  files('io.github.d3rpapah0d3n.GriabuntuMailConsole.gresource.xml'),
)

console = executable('griabuntu-mail-console',
  [ console_sources, console_resources ],
  dependencies: console_dependencies,
  vala_args: griabuntu_mail_vala_args,
  c_args: griabuntu_mail_c_args,
)
