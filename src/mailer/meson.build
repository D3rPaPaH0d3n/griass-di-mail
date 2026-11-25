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

mailer = executable('griabuntu-mail-mailer',
  mailer_sources,
  dependencies: mailer_dependencies,
  vala_args: griabuntu_mail_vala_args,
  c_args: griabuntu_mail_c_args,
)
