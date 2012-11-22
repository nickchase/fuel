
class firewall (
	$ssh_port = 22,
	$http_port = 80,
	$https_port = 443,
	$mysql_port = 3306,
	$mysql_backend_port = 3307,
    $mysql_gcomm_port = 4567,
        $galera_ist_port = 4568,
	$keystone_public_port =  5000,
	$swift_proxy_port =  8080,
	$swift_object_port =  6000,
	$swift_container_port =  6001,
	$swift_account_port =  6002,
  $keystone_admin_port = 35357,
	$glance_api_port = 9292,
	$glance_reg_port = 9191,
	$glance_nova_api_ec2_port = 8773,
	$nova_api_compute_port =   8774,
	$nova_api_metadata_port =  8775,
	$nova_api_volume_port =  8776,
	$nova_vncproxy_port =  6080,
	$erlang_epmd_port  =   4369,
	$erlang_rabbitmq_port =  5672,
    $erlang_inet_dist_port = 41055,
	$memcached_port =  11211,
  $rsync_port = 873,
  $iscsi_port = 3260,
) {

  case $::osfamily {
    'RedHat': {
      firewall::allow {[
		$ssh_port,
		$http_port,
		$https_port,
		$mysql_port,
		$mysql_backend_port,
		$galera_ist_port,
        $mysql_gcomm_port,
		$keystone_public_port,
		$keystone_admin_port, 
		$glance_api_port,
		$glance_reg_port,
		$glance_nova_api_ec2_port,
		$nova_api_compute_port,
		$nova_api_metadata_port,
		$nova_api_volume_port,
		$nova_vncproxy_port,
		$erlang_epmd_port,
		$erlang_rabbitmq_port,
		$erlang_inet_dist_port,
		$memcached_port,
    $rsync_port,
	$swift_proxy_port,
	$swift_object_port,
	$swift_container_port,
	$swift_account_port,
  $iscsi_port,
      ]: }
     }
     default: {
       warning("Unsupported platform: ${::operatingsystem}")
     }
  }

}