# == Class: elasticsearch::snapshot
#
# This class is able to activate snapshots for elasticsearch
#
#
# === Parameters
#
# [*name*]
#   Name of snapshot repository.
#
# [*location]
#   Where to save the snapshots on the filesystem.
#
# [*script_path*]
#   Where to place the backup script.
#
# === Examples
#
# * Configuration of elasticsearch backup
#     class {'bacula::elasticsearch':
#       name        => 'my_backup',
#       location    => '/var/backup/elasticsearch',
#       script_path => '/root'
#     }
#
# * Configuration of elasticsearch backup with s3
#     class {'bacula::elasticsearch':
#       name        => 'my_backup',
#       bucket      => 'my_bucket_name',
#       region      => 'us-west',
#       script_path => '/root'
#     }
#
class elasticsearch::snapshot(
  $name             = undef,
  $type             = $elasticsearch::params::snapshot_type,
  $location         = undef,
  $bucket           = undef,
  $region           = undef,
  $base_path        = undef,
  $script_path      = $elasticsearch::params::snapshot_script_path,
  $cronjob          = false,
  $cron_starthour   = $elasticsearch::params::cron_starthour,
  $cron_startminute = $elasticsearch::params::cron_startminute,
  $snapshot_age     = $elasticsearch::params::snapshot_age,
  ){

  require elasticsearch::params

  if ($type == 'fs') {
    $settings = "{\"location\": \"${location}\",\"compress\": true}"
  } elsif ($type == 's3') {
    if ($base_path) {
      $settings = "{\"bucket\": \"${bucket}\",\"region\": \"${region}\",\"base_path\": \"${base_path}\"}"
    } else {
      $settings = "{\"bucket\": \"${bucket}\",\"region\": \"${region}\"}"
    }
    }
  }

  exec { 'Add snapshot to elasticsearch':
    command   => "curl -XPUT \'http://localhost:9200/_snapshot/${name}\' -d \'{\"type\": \"${type}\",\"settings\": ${settings}}\'",
    unless    => "curl -XGET \'http://localhost:9200/_snapshot/_all\' | grep ${name}",
    path      => '/usr/bin/:/bin/',
    logoutput => true,
  }

  file {
    "${script_path}/elasticsearch_backup.py":
      ensure => file,
      source => 'puppet:///modules/elasticsearch/usr/local/bin/elasticsearch_backup.py',
      owner => root,
      group => root,
      mode => '0775';
  }

  if ( $type == 'fs' ) {
    file {
      $location:
        ensure => directory,
        mode   => '0755',
        owner  => elasticsearch,
        group  => elasticsearch;
    }
  }

  if ( $cronjob == true ) {
    file {
      '/etc/cron.d/elasticsearch':
        ensure  => file,
        content => template('elasticsearch/etc/cron.d/elasticsearch.erb'),
        owner   => root,
        group   => root,
        mode    => '0644';
    }
  }
}
