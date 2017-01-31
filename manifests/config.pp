# == Class: oldelasticsearch::config
#
# This class exists to coordinate all configuration related actions,
# functionality and logical units in a central place.
#
#
# === Parameters
#
# This class does not provide any parameters.
#
#
# === Examples
#
# This class may be imported by other classes to use its functionality:
#   class { 'oldelasticsearch::config': }
#
# It is not intended to be used directly by external resources like node
# definitions or other modules.
#
#
# === Authors
#
# * Richard Pijnenburg <mailto:richard.pijnenburg@elasticsearch.com>
#
class oldelasticsearch::config {

  #### Configuration

  File {
    owner => $oldelasticsearch::elasticsearch_user,
    group => $oldelasticsearch::elasticsearch_group,
  }

  Exec {
    path => [ '/bin', '/usr/bin', '/usr/local/bin' ],
    cwd  => '/',
  }

  if ( $oldelasticsearch::ensure == 'present' ) {

    $notify_service = $oldelasticsearch::restart_on_change ? {
      true  => Class['oldelasticsearch::service'],
      false => undef,
    }

    file { $oldelasticsearch::configdir:
      ensure => directory,
      mode   => '0644',
    }

    file { $oldelasticsearch::params::logdir:
      ensure  => 'directory',
      group   => undef,
      mode    => '0644',
      recurse => true,
    }

    file { $oldelasticsearch::params::homedir:
      ensure  => 'directory',
    }

    file { "${oldelasticsearch::params::homedir}/bin":
      ensure  => 'directory',
      recurse => true,
      mode    => '0755',
    }

    file { $oldelasticsearch::plugindir:
      ensure  => 'directory',
      recurse => true,
    }

    file { $oldelasticsearch::datadir:
      ensure  => 'directory',
    }

    file { "${oldelasticsearch::homedir}/lib":
      ensure  => 'directory',
      recurse => true,
    }

    if $oldelasticsearch::params::pid_dir {
      file { $oldelasticsearch::params::pid_dir:
        ensure  => 'directory',
        group   => undef,
        recurse => true,
      }

      if ($oldelasticsearch::service_providers == 'systemd') {
        $user = $oldelasticsearch::elasticsearch_user
        $group = $oldelasticsearch::elasticsearch_group
        $pid_dir = $oldelasticsearch::params::pid_dir

        file { '/usr/lib/tmpfiles.d/elasticsearch.conf':
          ensure  => 'file',
          content => template("${module_name}/usr/lib/tmpfiles.d/elasticsearch.conf.erb"),
          owner   => 'root',
          group   => 'root',
        }
      }
    }

    file { "${oldelasticsearch::params::homedir}/templates_import":
      ensure => 'directory',
      mode   => '0644',
    }

    file { "${oldelasticsearch::params::homedir}/scripts":
      ensure => 'directory',
      mode   => '0644',
    }

    # Removal of files that are provided with the package which we don't use
    file { '/etc/init.d/elasticsearch':
      ensure => 'absent',
    }
    file { '/lib/systemd/system/elasticsearch.service':
      ensure => 'absent',
    }

    $new_init_defaults = { 'CONF_DIR' => $oldelasticsearch::configdir }
    augeas { "${oldelasticsearch::params::defaults_location}/elasticsearch":
      incl    => "${oldelasticsearch::params::defaults_location}/elasticsearch",
      lens    => 'Shellvars.lns',
      changes => template("${module_name}/etc/sysconfig/defaults.erb"),
    }

    file { '/etc/elasticsearch/elasticsearch.yml':
      ensure => 'absent',
    }
    file { '/etc/elasticsearch/logging.yml':
      ensure => 'absent',
    }

  } elsif ( $oldelasticsearch::ensure == 'absent' ) {
    # don't remove anything for now
  }

}
