mailer_sources = files(
  'main.vala',
)

mailer_dependencies = [
  config_dep,
  gee,
  gmime,
  webkitgtk,
  engine_dep,
]

mailer = executable('convey-mailer',
  mailer_sources,
  dependencies: mailer_dependencies,
  vala_args: convey_vala_args,
  c_args: convey_c_args,
)
