# these parameters need to be accessed from several locations and
# should be considered to be constant
class horizon::params {

  $logdir = '/var/log/horizon'

  case $::osfamily {
    'RedHat': {
      $http_service                = 'httpd'
      $http_modwsgi                = 'mod_wsgi'
      $http_config_file            = '/etc/httpd/conf/httpd.conf'
      $package_name                = 'openstack-dashboard'
      $dashboard_config_file       = '/etc/httpd/conf.d/openstack-dashboard.conf'
      $httpd_listen_config_file       = '/etc/httpd/conf/httpd.conf'
      $local_settings_path         = '/etc/openstack-dashboard/local_settings'
    }
    'Debian': {
      $http_service                = 'apache2'
      $http_modwsgi                = 'libapache2-mod-wsgi'
      $httpd_listen_config_file    = '/etc/apache2/ports.conf'
      case $::operatingsystem {
        'Debian': {
            $package_name          = 'openstack-dashboard-apache'
        }
        default: {
            $package_name          = 'openstack-dashboard'
        }
      }
      $dashboard_config_file       = '/etc/apache2/conf.d/openstack-dashboard.conf'
      $local_settings_path         = '/etc/openstack-dashboard/local_settings.py'
    }
    default: {
      fail("Unsupported osfamily: ${::osfamily} operatingsystem: ${::operatingsystem}, module ${module_name} only support osfamily RedHat and Debian")
    }
  }
}