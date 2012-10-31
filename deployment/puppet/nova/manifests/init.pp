# This class is used to specify configuration parameters that are common
# across all nova services.
#
# ==Parameters
#
# [sql_connection] Connection url to use to connect to nova sql database.
#  If specified as false, then it tries to collect the exported resource
#   Nova_config <<| title == 'sql_connection' |>>. Optional. Defaults to false.
# [image_service] Service used to search for and retrieve images. Optional.
#   Defaults to 'nova.image.local.LocalImageService'
# [glance_api_servers] List of addresses for api servers. Optional.
#   Defaults to localhost:9292.
# [rabbit_nodes] RabbitMQ nodes. Optional. Defaults to localhost.
# [rabbit_host] Location of rabbitmq installation. Optional. Defaults to localhost.
# [rabbit_password] Password used to connect to rabbitmq. Optional. Defaults to guest.
# [rabbit_port] Port for rabbitmq instance. Optional. Defaults to 5672.
# [rabbit_userid] User used to connect to rabbitmq. Optional. Defaults to guest.
# [rabbit_virtual_host] The RabbitMQ virtual host. Optional. Defaults to /.
# [auth_strategy]
# [service_down_time] maximum time since last check-in for up service. Optional.
#  Defaults to 60
# [logdir] Directory where logs should be stored. Optional. Defaults to '/var/log/nova'.
# [state_path] Directory for storing state. Optional. Defaults to '/var/lib/nova'.
# [lock_path] Directory for lock files. Optional. Distro specific default.
# [verbose] Rather to print more verbose output. Optional. Defaults to false.
# [periodic_interval] Seconds between running periodic tasks. Optional.
#   Defaults to '60'.
# [report_interval] Interval at which nodes report to data store. Optional.
#    Defaults to '10'.
# [root_helper] Command used for roothelper. Optional. Distro specific.
# [monitoring_notifications] A boolean specifying whether or not to send system usage data notifications out on the message queue. Optional, false by default. Only valid for stable/essex.
#
# $rabbit_nodes = ['node001', 'node002', 'node003']
# add rabbit nodes hostname
#
class nova(
  $ensure_package = 'present',
  # this is how to query all resources from our clutser
  $nova_cluster_id='localcluster',
  $sql_connection = false,
  $image_service = 'nova.image.glance.GlanceImageService',
  # these glance params should be optional
  # this should probably just be configured as a glance client
  $glance_api_servers = 'localhost:9292',
  # for use rabbitmq in HA mode
  $rabbit_nodes = false,
  $rabbit_host = 'localhost',
  $rabbit_password='guest',
  $rabbit_port='5672',
  $rabbit_userid='guest',
  $rabbit_virtual_host='/',
  $auth_strategy = 'keystone',
  $service_down_time = 60,
  $logdir = '/var/log/nova',
  $state_path = '/var/lib/nova',
  $lock_path = $::nova::params::lock_path,
  $verbose = false,
  $periodic_interval = '60',
  $report_interval = '10',
  $root_wrap_config = '/etc/nova/rootwrap.conf',
  # deprecated in folsom
  #$root_helper = $::nova::params::root_helper,
  $monitoring_notifications = false,
  $api_bind_address = '0.0.0.0',
) inherits nova::params {

  # all nova_config resources should be applied
  # after the nova common package
  # before the file resource for nova.conf is managed
  # and before the post config resource
  Package['nova-common'] -> Nova_config<| |> -> File['/etc/nova/nova.conf']
  Nova_config<| |> ~> Exec['post-nova_config']

  # TODO - see if these packages can be removed
  # they should be handled as package deps by the OS
  package { 'python':
    ensure => present,
  }
  package { 'python-greenlet':
    ensure => present,
    require => Package['python'],
  }

  class { 'nova::utilities': }

  # this anchor is used to simplify the graph between nova components by
  # allowing a resource to serve as a point where the configuration of nova begins
  anchor { 'nova-start': }

  package { 'python-nova':
    ensure  => $ensure_package,
    require => Package['python-greenlet']
  }

  # turn on rabbitmq ha/cluster mode
  if $rabbit_nodes {
    package { "patch":
      ensure => present
    }

    file { "/tmp/rmq-ha.patch":
      ensure => present,
      source => 'puppet:///modules/nova/rmq-ha.patch'
    }

    exec { 'patch-nova':
      unless  => "/bin/grep x-ha-policy /usr/lib/${::nova::params::python_path}/nova/openstack/common/rpc/impl_kombu.py",
      command => "/usr/bin/patch -p1 -d /usr/lib/${::nova::params::python_path}/nova </tmp/rmq-ha.patch",
      require => [ [File['/tmp/rmq-ha.patch']],[Package['patch', 'python-nova']]], 
    } ->
    exec { 'update-kombu':
      command => "/usr/bin/easy_install pip; /usr/bin/pip uninstall -y kombu; /usr/bin/pip uninstall -y anyjson; /usr/bin/pip install kombu==2.4.7; /usr/bin/pip install anyjson==0.3.3; /usr/bin/pip install amqp"
    }

    nova_config { 'DEFAULT/rabbit_ha_queues': value => 'True' }
  }

  package { 'nova-common':
    name    => $::nova::params::common_package_name,
    ensure  => $ensure_package,
    require => [Package["python-nova"], Anchor['nova-start']]
  } 

  group { 'nova':
    ensure  => present,
    system  => true,
    require => Package['nova-common'],
  }

  user { 'nova':
    ensure  => present,
    gid     => 'nova',
    system  => true,
    require => Package['nova-common'],
  }

  file { $logdir:
    ensure  => directory,
    mode    => '0751',
    require => Package['nova-common'],
    owner   => 'nova',
    group   => 'nova',
  }
  file { '/etc/nova/nova.conf':
    mode  => '0640',
    require => Package['nova-common'],
    owner   => 'nova',
    group   => 'nova',
  }

  # used by debian/ubuntu in nova::network_bridge to refresh
  # interfaces based on /etc/network/interfaces
  exec { "networking-refresh":
    command     => "/sbin/ifdown -a ; /sbin/ifup -a",
    refreshonly => "true",
  }


  # both the sql_connection and rabbit_host are things
  # that may need to be collected from a remote host
  if $sql_connection {
    if($sql_connection =~ /mysql:\/\/\S+:\S+@\S+\/\S+/) {
      require 'mysql::python'
    } elsif($sql_connection =~ /postgresql:\/\/\S+:\S+@\S+\/\S+/) {

    } elsif($sql_connection =~ /sqlite:\/\//) {

    } else {
      fail("Invalid db connection ${sql_connection}")
    }
    nova_config { 'DEFAULT/sql_connection': value => $sql_connection }
  } else {
    Nova_config <<| title == 'sql_connection' |>>
  }

  nova_config { 'DEFAULT/image_service': value => $image_service }
 
  if $image_service == 'nova.image.glance.GlanceImageService' {
    if $glance_api_servers {
      nova_config { 'DEFAULT/glance_api_servers': value => $glance_api_servers }
    } else {
      # TODO this only supports setting a single address for the api server
      Nova_config <<| title == glance_api_servers |>>
    }
  }

  nova_config { 'DEFAULT/auth_strategy': value => $auth_strategy }

#  if $rabbit_host {
#    nova_config { 'DEFAULT/rabbit_host': value => $rabbit_host }
#  }
#  else {
#     Nova_config <<| title == 'rabbit_host' |>>
#  }


  if $rabbit_nodes {
    nova_config { 'DEFAULT/rabbit_hosts': value => inline_template("<%= @rabbit_nodes.map {|x| x+':5672'}.join ',' %>") }
  } else {
    Nova_config <<| title == 'rabbit_hosts' |>>
  }
  # I may want to support exporting and collecting these
  nova_config {
    'DEFAULT/rabbit_password':     value => $rabbit_password;
    'DEFAULT/rabbit_port':         value => $rabbit_port;
    'DEFAULT/rabbit_userid':       value => $rabbit_userid;
    'DEFAULT/rabbit_virtual_host': value => $rabbit_virtual_host;
    'DEFAULT/rpc_backend': value => 'nova.rpc.impl_kombu';
  }

  nova_config {
    'DEFAULT/verbose':           value => $verbose;
    'DEFAULT/logdir':            value => $logdir;
    # Following may need to be broken out to different nova services
    'DEFAULT/state_path':        value => $state_path;
    'DEFAULT/lock_path':         value => $lock_path;
    'DEFAULT/service_down_time': value => $service_down_time;
    'DEFAULT/rootwrap_config':  value => $root_wrap_config;
  }

  nova_config {
    'DEFAULT/ec2_listen':           value => $api_bind_address;
    'DEFAULT/osapi_compute_listen': value => $api_bind_address;
    'DEFAULT/metadata_listen':      value => $api_bind_address;
    'DEFAULT/osapi_volume_listen':  value => $api_bind_address;
  }

  if $monitoring_notifications {
    nova_config {
      'DEFAULT/notification_driver': value => 'nova.notifier.rabbit_notifier'
    }
  }


  exec { 'post-nova_config':
    command => '/bin/echo "Nova config has changed"',
    refreshonly => true,
  }

}
