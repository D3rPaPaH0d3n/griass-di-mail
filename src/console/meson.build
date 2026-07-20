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

console_resources = gnome.compile_resources('net.donnybeelo.ConveyConsole',
  files('net.donnybeelo.ConveyConsole.gresource.xml'),
)

console = executable('convey-console',
  [ console_sources, console_resources ],
  dependencies: console_dependencies,
  vala_args: convey_vala_args,
  c_args: convey_c_args,
)
