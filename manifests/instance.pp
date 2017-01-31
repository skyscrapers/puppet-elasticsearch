# == Define: oldelasticsearch::instance
#
#  This define allows you to create or remove an elasticsearch instance
#
# === Parameters
#
# [*ensure*]
#   String. Controls if the managed resources shall be <tt>present</tt> or
#   <tt>absent</tt>. If set to <tt>absent</tt>:
#   * The managed software packages are being uninstalled.
#   * Any traces of the packages will be purged as good as possible. This may
#     include existing configuration files. The exact behavior is provider
#     dependent. Q.v.:
#     * Puppet type reference: {package, "purgeable"}[http://j.mp/xbxmNP]
#     * {Puppet's package provider source code}[http://j.mp/wtVCaL]
#   * System modifications (if any) will be reverted as good as possible
#     (e.g. removal of created users, services, changed log settings, ...).
#   * This is thus destructive and should be used with care.
#   Defaults to <tt>present</tt>.
#
# [*status*]
#   String to define the status of the service. Possible values:
#   * <tt>enabled</tt>: Service is running and will be started at boot time.
#   * <tt>disabled</tt>: Service is stopped and will not be started at boot
#     time.
#   * <tt>running</tt>: Service is running but will not be started at boot time.
#     You can use this to start a service on the first Puppet run instead of
#     the system startup.
#   * <tt>unmanaged</tt>: Service will not be started at boot time and Puppet
#     does not care whether the service is running or not. For example, this may
#     be useful if a cluster management software is used to decide when to start
#     the service plus assuring it is running on the desired node.
#   Defaults to <tt>enabled</tt>. The singular form ("service") is used for the
#   sake of convenience. Of course, the defined status affects all services if
#   more than one is managed (see <tt>service.pp</tt> to check if this is the
#   case).
#
# [*config*]
#   Elasticsearch configuration hash
#
# [*configdir*]
#   Path to directory containing the elasticsearch configuration.
#   Use this setting if your packages deviate from the norm (/etc/elasticsearch)
#
# [*datadir*]
#   Allows you to set the data directory of Elasticsearch
#
# [*logging_file*]
#   Instead of a hash you can supply a puppet:// file source for the logging.yml file
#
# [*logging_config*]
#   Hash representation of information you want in the logging.yml file
#
# [*logging_template*]
#  Use a custom logging template - just supply the reative path ie ${module}/elasticsearch/logging.yml.erb
#
# [*logging_level*]
#   Default logging level for Elasticsearch.
#   Defaults to: INFO
#
# [*init_defaults*]
#   Defaults file content in hash representation
#
# [*init_defaults_file*]
#   Defaults file as puppet resource
#
# === Authors
#
# * Richard Pijnenburg <mailto:richard.pijnenburg@elasticsearch.com>
#
define oldelasticsearch::instance(
  $ensure             = $oldelasticsearch::ensure,
  $status             = $oldelasticsearch::status,
  $config             = undef,
  $configdir          = undef,
  $datadir            = undef,
  $logging_file       = undef,
  $logging_config     = undef,
  $logging_template   = undef,
  $logging_level      = $oldelasticsearch::default_logging_level,
  $init_defaults      = undef,
  $init_defaults_file = undef
) {

  require oldelasticsearch::params

  File {
    owner => $oldelasticsearch::elasticsearch_user,
    group => $oldelasticsearch::elasticsearch_group,
  }

  Exec {
    path => [ '/bin', '/usr/bin', '/usr/local/bin' ],
    cwd  => '/',
  }

  # ensure
  if ! ($ensure in [ 'present', 'absent' ]) {
    fail("\"${ensure}\" is not a valid ensure parameter value")
  }

  $notify_service = $oldelasticsearch::restart_on_change ? {
    true  => Oldelasticsearch::Service[$name],
    false => undef,
  }

  # Instance config directory
  if ($configdir == undef) {
    $instance_configdir = "${oldelasticsearch::configdir}/${name}"
  } else {
    $instance_configdir = $configdir
  }

  if ($ensure == 'present') {

    # Configuration hash
    if ($config == undef) {
      $instance_config = {}
    } else {
      validate_hash($config)
      $instance_config = $config
    }

    if(has_key($instance_config, 'node.name')) {
      $instance_node_name = {}
    } elsif(has_key($instance_config,'node')) {
      if(has_key($instance_config['node'], 'name')) {
        $instance_node_name = {}
      } else {
        $instance_node_name = { 'node.name' => "${::hostname}-${name}" }
      }
    } else {
      $instance_node_name = { 'node.name' => "${::hostname}-${name}" }
    }

    # String or array for data dir(s)
    if ($datadir == undef) {
      if (is_array($oldelasticsearch::datadir)) {
        $instance_datadir = array_suffix($oldelasticsearch::datadir, "/${name}")
      } else {
        $instance_datadir = "${oldelasticsearch::datadir}/${name}"
      }
    } else {
      $instance_datadir = $datadir
    }

    # Logging file or hash
    if ($logging_file != undef) {
      $logging_source = $logging_file
      $logging_content = undef
    } elsif ($oldelasticsearch::logging_file != undef) {
      $logging_source = $oldelasticsearch::logging_file
      $logging_content = undef
    } else {

      if(is_hash($oldelasticsearch::logging_config)) {
        $main_logging_config = $oldelasticsearch::logging_config
      } else {
        $main_logging_config = { }
      }

      if(is_hash($logging_config)) {
        $instance_logging_config = $logging_config
      } else {
        $instance_logging_config = { }
      }
      $logging_hash = merge($oldelasticsearch::params::logging_defaults, $main_logging_config, $instance_logging_config)
      if ($logging_template != undef ) {
        $logging_content = template($logging_template)
      } elsif ($oldelasticsearch::logging_template != undef) {
        $logging_content = template($oldelasticsearch::logging_template)
      } else {
        $logging_content = template("${module_name}/etc/elasticsearch/logging.yml.erb")
      }
      $logging_source = undef
    }

    if ($oldelasticsearch::config != undef) {
      $main_config = $oldelasticsearch::config
    } else {
      $main_config = { }
    }

    if(has_key($instance_config, 'path.data')) {
      $instance_datadir_config = { 'path.data' => $instance_datadir }
    } elsif(has_key($instance_config, 'path')) {
      if(has_key($instance_config['path'], 'data')) {
        $instance_datadir_config = { 'path' => { 'data' => $instance_datadir } }
      } else {
        $instance_datadir_config = { 'path.data' => $instance_datadir }
      }
    } else {
      $instance_datadir_config = { 'path.data' => $instance_datadir }
    }

    if(is_array($instance_datadir)) {
      $dirs = join($instance_datadir, ' ')
    } else {
      $dirs = $instance_datadir
    }

    exec { "mkdir_datadir_elasticsearch_${name}":
      command => "mkdir -p ${dirs}",
      creates => $instance_datadir,
      require => Class['oldelasticsearch::package'],
      before  => Oldelasticsearch::Service[$name],
    }

    file { $instance_datadir:
      ensure  => 'directory',
      owner   => $oldelasticsearch::elasticsearch_user,
      group   => undef,
      mode    => '0644',
      require => [ Exec["mkdir_datadir_elasticsearch_${name}"], Class['oldelasticsearch::package'] ],
      before  => Oldelasticsearch::Service[$name],
    }

    exec { "mkdir_configdir_elasticsearch_${name}":
      command => "mkdir -p ${instance_configdir}",
      creates => $oldelasticsearch::configdir,
      require => Class['oldelasticsearch::package'],
      before  => Oldelasticsearch::Service[$name],
    }

    file { $instance_configdir:
      ensure  => 'directory',
      mode    => '0644',
      purge   => $oldelasticsearch::purge_configdir,
      force   => $oldelasticsearch::purge_configdir,
      require => [ Exec["mkdir_configdir_elasticsearch_${name}"], Class['oldelasticsearch::package'] ],
      before  => Oldelasticsearch::Service[$name],
    }

    file { "${instance_configdir}/logging.yml":
      ensure  => file,
      content => $logging_content,
      source  => $logging_source,
      mode    => '0644',
      notify  => $notify_service,
      require => Class['oldelasticsearch::package'],
      before  => Oldelasticsearch::Service[$name],
    }

    file { "${instance_configdir}/scripts":
      ensure => 'link',
      target => "${oldelasticsearch::params::homedir}/scripts",
    }

    # build up new config
    $instance_conf = merge($main_config, $instance_node_name, $instance_config, $instance_datadir_config)

    # defaults file content
    # ensure user did not provide both init_defaults and init_defaults_file
    if (($init_defaults != undef) and ($init_defaults_file != undef)) {
      fail ('Only one of $init_defaults and $init_defaults_file should be defined')
    }

    if (is_hash($oldelasticsearch::init_defaults)) {
      $global_init_defaults = $oldelasticsearch::init_defaults
    } else {
      $global_init_defaults = { }
    }

    $instance_init_defaults_main = { 'CONF_DIR' => $instance_configdir, 'CONF_FILE' => "${instance_configdir}/elasticsearch.yml", 'LOG_DIR' => "/var/log/elasticsearch/${name}", 'ES_HOME' => '/usr/share/elasticsearch' }

    if (is_hash($init_defaults)) {
      $instance_init_defaults = $init_defaults
    } else {
      $instance_init_defaults = { }
    }
    $init_defaults_new = merge($global_init_defaults, $instance_init_defaults_main, $instance_init_defaults )

    $user = $oldelasticsearch::elasticsearch_user
    $group = $oldelasticsearch::elasticsearch_group

    datacat_fragment { "main_config_${name}":
      target => "${instance_configdir}/elasticsearch.yml",
      data   => $instance_conf,
    }

    datacat { "${instance_configdir}/elasticsearch.yml":
      template => "${module_name}/etc/elasticsearch/elasticsearch.yml.erb",
      notify   => $notify_service,
      require  => Class['oldelasticsearch::package'],
      owner    => $oldelasticsearch::elasticsearch_user,
      group    => $oldelasticsearch::elasticsearch_group,
    }

    $require_service = Class['oldelasticsearch::package']
    $before_service  = undef

  } else {

    file { $instance_configdir:
      ensure  => 'absent',
      recurse => true,
      force   => true,
    }

    $require_service = undef
    $before_service  = File[$instance_configdir]

    $init_defaults_new = {}
  }

  oldelasticsearch::service { $name:
    ensure             => $ensure,
    status             => $status,
    init_defaults      => $init_defaults_new,
    init_defaults_file => $init_defaults_file,
    init_template      => "${module_name}/etc/init.d/${oldelasticsearch::params::init_template}",
    require            => $require_service,
    before             => $before_service,
  }

}
