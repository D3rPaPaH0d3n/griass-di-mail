#
# Desktop files
#

desktop_output = []
desktop_conf = configuration_data()
desktop_conf.set('appid', griabuntu_mail_id)

desktop_file = i18n.merge_file(
  input: configure_file(
    input: 'io.github.d3rpapah0d3n.GriabuntuMail.desktop.in.in',
    output: 'io.github.d3rpapah0d3n.GriabuntuMail.desktop.in',
    configuration: desktop_conf
  ),
  output: '@0@.desktop'.format(griabuntu_mail_id),
  type: 'desktop',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(data_dir, 'applications')
)
desktop_output += desktop_file

autostart_file = i18n.merge_file(
  input: configure_file(
    input: 'griabuntu-mail-autostart.desktop.in.in',
    output: 'griabuntu-mail-autostart.desktop.in',
    configuration: desktop_conf
  ),
  output: 'griabuntu-mail-autostart.desktop',
  type: 'desktop',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(data_dir, 'applications')
)
desktop_output += autostart_file

foreach desktop_file: desktop_output
  if desktop_file_validate.found()
    test(
      'desktop-file-validate',
      desktop_file_validate,
      args: [ desktop_file.full_path() ],
      depends: [
        desktop_file,
      ]
    )
  endif
endforeach

#
# Metainfo file
#

metainfo_file = 'io.github.d3rpapah0d3n.GriabuntuMail.metainfo.xml'

metainfo_merged = i18n.merge_file(
  input: configure_file(
    input: metainfo_file + '.in.in',
    output: metainfo_file + '.in',
    configuration: desktop_conf
  ),
  output: '@0@.metainfo.xml'.format(griabuntu_mail_id),
  type: 'xml',
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(data_dir, 'metainfo')
)

if appstreamcli.found()
  test(
    metainfo_file + '-validate',
    appstreamcli,
    args: [
      'validate', '--no-net', '--explain', metainfo_merged.full_path()
    ],
    depends: [
      metainfo_merged,
    ]
  )
endif

#
# Contractor file (Elementary OS)
#

if get_option('contractor').enabled()
  # Call msgfmt manually since gettext won't otherwise translate the
  # Description field. See merge req !50.
  msgfmt = find_program('msgfmt')

  custom_target('griabuntu-mail-attach-contract',
    input: 'griabuntu-mail-attach.contract.desktop.in',
    output: 'griabuntu-mail-attach.contract',
    command: [msgfmt, '--desktop', '--keyword=Description', '--template', '@INPUT@', '-d', po_dir, '-o', '@OUTPUT@'],
    install: true,
    install_dir: join_paths(data_dir, 'contractor')
  )

  install_data('griabuntu-mail-attach',
    install_dir: bin_dir,
  )
endif

# GSettings schemas.
#
# Compile since it makes sure the schema is valid and is used for both
# running the client locally and for tests.
#
# Note the use of depend_files here is a kludge to ensure that the
# schema is re-compiled if the source changes. This is not supported
# by Meson but it works, so request for official support has been
# added, see: https://github.com/mesonbuild/meson/issues/2770
griabuntu_mail_compiled_schema = gnome.compile_schemas(
  depend_files: files('io.github.d3rpapah0d3n.GriabuntuMail.gschema.xml'),
)
install_data('io.github.d3rpapah0d3n.GriabuntuMail.gschema.xml',
  install_dir: join_paths(data_dir, 'glib-2.0', 'schemas'),
)

#
# DBus services
#

service_conf = configuration_data()
service_conf.set('bindir', bin_dir)
service_conf.set('appid', griabuntu_mail_id)

configure_file(
  input: 'io.github.d3rpapah0d3n.GriabuntuMail.service.in',
  output: '@0@.service'.format(griabuntu_mail_id),
  configuration: service_conf,
  install: true,
  install_dir: dbus_services_dir
)
