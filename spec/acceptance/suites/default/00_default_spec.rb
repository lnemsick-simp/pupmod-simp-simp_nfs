require 'spec_helper_acceptance'

test_name 'SIMP NFS profile'

describe 'simp_nfs stock classes' do
  nfs_servers = hosts_with_role(hosts, 'nfs_server')
  clients = hosts_with_role(hosts, 'client')
  el7_server = only_host_with_role(nfs_servers, 'el7')
  el8_server = only_host_with_role(nfs_servers, 'el8')

  # TODO revert behavior
  # The test originally had each NFS server also be an LDAP server. However,
  # at the time this test was updated to EL8, a working LDAP server on EL8
  # was not yet available.  So, this test must restrict the LDAP server to
  # be on an EL7 node.
  ldap_server = el7_server
  ldap_server_fqdn = fact_on(ldap_server, 'fqdn')

  trusted_nets = host_networks(hosts[0])
puts "trusted_nets=#{trusted_nets}"

  context 'with exported home directories' do
    hosts.each do |node|

      # Determine who your nfs server is
      nfs_server = nil
      os_release = fact_on(node, 'operatingsystemmajrelease')
      if os_release == '7'
        nfs_server = el7_server
      elsif os_release == '8'
        nfs_server = el8_server
      else
        STDERR.puts "#{os_release} not a supported OS release"
        next
      end

      nfs_server_fqdn = fact_on(nfs_server, 'fqdn')
      nfs_server_ip = internal_network_info(nfs_server)[:ip]

      # Determine what your domain is, in dn form
      _domains = fact_on(node, 'domain').split('.')
      _domains.map! { |d|
        "dc=#{d}"
      }
      domains = _domains.join(',')

      manifest = <<~EOM
        include 'simp_options'
        include 'pam::access'
        include 'sudo'
        include 'ssh'
        include 'simp::nsswitch'
        include 'simp_openldap::client'
        include 'simp::sssd::client'
        include 'simp_nfs'
      EOM

      hieradata = <<~EOM
        ---

        simp_nfs::home_dir_server: #{nfs_server_ip}
        simp_nfs::mount::home::local_home: /mnt

        # Options
        simp_options::clamav: false
        simp_options::dns::servers: ['8.8.8.8']
        simp_options::puppet::server: #{ldap_server_fqdn}
        simp_options::puppet::ca: #{ldap_server_fqdn}
        simp::yum::servers: ['#{nfs_server_fqdn}']
        simp_options::ntpd::servers: ['time.nist.gov']
        simp_options::sssd: true
        simp_options::stunnel: true
        simp_options::tcpwrappers: true
        simp_options::pam: true
        simp_options::firewall: true
        simp_options::pki: true
        simp_options::pki::source: '/etc/pki/simp-testing/pki'
        simp_options::trusted_nets: ['ALL']
        simp_options::ldap: true
        simp_options::ldap::bind_pw: 'foobarbaz'
        simp_options::ldap::bind_hash: '{SSHA}BNPDR0qqE6HyLTSlg13T0e/+yZnSgYQz'
        simp_options::ldap::sync_pw: 'foobarbaz'
        simp_options::ldap::sync_hash: '{SSHA}BNPDR0qqE6HyLTSlg13T0e/+yZnSgYQz'
        # suP3rP@ssw0r!
        simp_openldap::server::conf::rootpw: "{SSHA}TghZyHW6r8/NL4fo0Q8BnihxVb7A7af5"
        sssd::domains:
          - LDAP
        simp::mail_server: false
        pam::wheel_group: 'administrators'

        # Settings to make beaker happy
        pam::access::users:
          defaults:
            origins:
              - ALL
            permission: '+'
          vagrant:
          test.user:
        sudo::user_specifications:
          vagrant_all:
            user_list: ['vagrant']
            cmnd: ['ALL']
            passwd: false
        ssh::server::conf::permitrootlogin: true
        ssh::server::conf::authorizedkeysfile: .ssh/authorized_keys
      EOM

      test_user_ldif = <<~EOM
        dn: cn=test.user,ou=Group,#{domains}
        objectClass: posixGroup
        objectClass: top
        cn: test.user
        gidNumber: 10000
        description: 'Test user'

        dn: uid=test.user,ou=People,#{domains}
        uid: test.user
        cn: test.user
        givenName: Test
        sn: User
        mail: test.user@funurl.net
        objectClass: inetOrgPerson
        objectClass: posixAccount
        objectClass: top
        objectClass: shadowAccount
        objectClass: ldapPublicKey
        shadowMax: 180
        shadowMin: 1
        shadowWarning: 7
        shadowLastChange: #{Time.now.to_i/60/60/24 - 4}
        loginShell: /bin/bash
        uidNumber: 10000
        gidNumber: 10000
        homeDirectory: /mnt/test.user
        # suP3rP@ssw0r!
        userPassword: {SSHA}yOdnVOQYXOEc0Gjv4RRY5BnnFfIKLI3/
        pwdReset: TRUE
      EOM

      test_group_ldif = <<~EOM
        dn: cn=administrators,ou=Group,#{domains}
        changetype: modify
        add: memberUid
        memberUid: test.user
      EOM

      if os_release == '8'
        # this is a workaround until an official, signed package is available
        it 'should install locally-built rubygem-net-ldap RPM' do
          files_dir = File.join(File.dirname(__FILE__), 'files')
          rpm = File.join(files_dir, 'rubygem-net-ldap-0.16.1-5.el8.noarch.rpm')
          scp_to(node, rpm, '/tmp')
          on(node, 'yum install -y /tmp/rubygem-net-ldap-0.16.1-5.el8.noarch.rpm')
        end
      end

      if nfs_servers.include?(node)
        it 'should export home directories' do
          # Construct server hieradata; export home directories.
          server_hieradata = hieradata + <<~EOM
            nfs::is_server: true
            simp_nfs::export_home::create_home_dirs: true
          EOM

          server_manifest = manifest + <<~EOM
            include 'simp_nfs::export::home'
            # Don't try to run create_home_directories.rb before the LDAP client
            # is set up and accessible or will get a manifest error
            # when the script fails
            Class['simp_openldap::client'] -> Class['simp_nfs::export::home']
            Pki::Copy['openldap'] -> Class['simp_nfs::export::home']
            Class['sssd::service'] -> Class['simp_nfs::export::home']
          EOM

          if node == ldap_server
            server_manifest += "include 'simp::server::ldap'\n"
          end

          # Apply
          set_hieradata_on(node, server_hieradata, 'default')
          on(node, 'mkdir -p /usr/local/sbin/simp')
          apply_manifest_on(node, server_manifest, catch_failures: true)
          apply_manifest_on(node, server_manifest, catch_failures: true)
          apply_manifest_on(node, server_manifest, catch_changes: true)
        end

        if node == ldap_server
          it "should create LDAP user 'test.user'" do
            # Create test.user
            create_remote_file(node, '/root/user_ldif.ldif', test_user_ldif)
            create_remote_file(node, '/root/group_ldif.ldif', test_group_ldif)

            # Create test.user and add to administrators
            on(node, "ldapadd -D cn=LDAPAdmin,ou=People,#{domains} -H ldap://#{nfs_server_fqdn} -w suP3rP@ssw0r! -x -Z -f /root/user_ldif.ldif")
            on(node, "ldapmodify -D cn=LDAPAdmin,ou=People,#{domains} -H ldap://#{nfs_server_fqdn} -w suP3rP@ssw0r! -x -Z -f /root/group_ldif.ldif")

            # Ensure the cache is built, don't wait for enum timeout
            on(node, 'service sssd restart')

            user_info = on(node, 'id test.user', :acceptable_exit_codes => [0])
            expect(user_info.stdout).to match(/.*uid=10000\(test.user\).*gid=10000\(test.user\)/)
          end
        end
      else
        it "should set up NFS client on #{node}" do
          set_hieradata_on(node, hieradata, 'default')
          on(node, 'mkdir -p /usr/local/sbin/simp')
          client_manifest = manifest +
            "Class['sssd::service'] -> Class['simp_nfs::mount::home']\n"

          apply_manifest_on(node, client_manifest, catch_failures: true)
          apply_manifest_on(node, client_manifest, catch_failures: true)
          apply_manifest_on(node, client_manifest, catch_changes: true)
        end
      end
    end

    it 'should create the test.user home directory mount on the servers using the cron job' do
      nfs_servers.each do |node|
        # Create test.user's homedir via cron, and ensure it gets mounted
        on(node, '/etc/cron.hourly/create_home_directories.rb')
        on(node, 'ls /var/nfs/home/test.user')
        on(node, "runuser -l test.user -c 'touch ~/testfile'")
        mount = on(node, 'mount')
        expect(mount.stdout).to match(/127.0.0.1:\/home\/test.user.*nfs/)
      end
    end

    it 'should have file propagation to the clients' do
      clients.each do |node|
        retry_on(node, 'cd /mnt/test.user; ls testfile', :verbose => true.to_s) #beaker bug requires string
      end
    end
  end
end
