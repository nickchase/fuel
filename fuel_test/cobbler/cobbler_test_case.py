import unittest
from devops.helpers import ssh
from fuel_test.base_test_case import BaseTestCase
from fuel_test.ci.ci_cobbler import CiCobbler
from fuel_test.helpers import safety_revert_nodes, sync_time
from fuel_test.root import root

class CobblerTestCase(BaseTestCase):
    def ci(self):
        if not hasattr(self, '_ci'):
            self._ci = CiCobbler()
        return self._ci

    def setUp(self):
        super(CobblerTestCase, self).setUp()
        self.write_cobbler_manifest()

    def revert_snapshots(self):
        safety_revert_nodes(self.environment.nodes, 'empty')
        for node in [self.environment.node['master']] + self.nodes.cobblers:
            remote = ssh(node.ip_address, username='root', password='r00tme')
            sync_time(remote.sudo.ssh)
            remote.sudo.ssh.execute('yum makecache')

    def write_cobbler_manifest(self):
        cobbler = self.nodes.cobblers[0]
        cobbler_address = cobbler.ip_address_by_network['internal']
        self.write_site_pp_manifest(
            root('fuel', 'deployment', 'puppet', 'cobbler', 'examples',
                'server_site.pp'),
            server="'%s'" % cobbler_address,
            name_server="'%s'" % cobbler_address,
            next_server="'%s'" % cobbler_address,
            dhcp_start_address="'%s'" % self.environment.network[
                                        'internal'].ip_addresses[10],
            dhcp_end_address="'%s'" %
                             self.environment.network['internal'].ip_addresses[
                             -5],
            dhcp_netmask="'%s'" % '255.255.255.0',
            dhcp_gateway="'%s'" %
                         self.environment.network['internal'].ip_addresses[1]
        )


if __name__ == '__main__':
    unittest.main()



