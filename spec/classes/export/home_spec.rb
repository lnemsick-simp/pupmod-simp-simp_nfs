require 'spec_helper'

describe 'simp_nfs::export::home' do
  shared_examples_for 'a structured module' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('simp_nfs::export::home') }
  end

  on_supported_os.each do |os, os_facts|
    let(:nfs_server_ip) { '1.2.3.4' }
    context "on #{os}" do
      let(:facts) do
        os_facts
      end

      context 'with default parameters' do
        let(:pre_condition) { "class { 'nfs': is_server => true }" }
        let(:params) {{ }}

        it_behaves_like 'a structured module'

        it { is_expected.to_not contain_class('simp_nfs::create_home_dirs') }
        it { is_expected.to contain_nfs__server__export('nfs4_root').with( {
          :clients     => [ '127.0.0.1' ],
          :export_path => '/var/nfs/exports',
          :sec         => ['sys'],
          :fsid        => '0',
          :crossmnt    => true
        } ) }

        it { is_expected.to_not contain_nfs__server__export('nfs4_root').with_insecure(true) }

        it { is_expected.to contain_nfs__server__export('home_dirs').with( {
          :clients     => [ '127.0.0.1' ],
          :export_path => '/var/nfs/exports/home',
          :rw          => true,
          :sec         => ['sys']
        } ) }

        it { is_expected.to_not contain_nfs__server__export('home_dirs').with_insecure(true) }

        [ "/var/nfs",
          "/var/nfs/exports",
          "/var/nfs/exports/home",
          "/var/nfs/home"
        ].each do |dir|
          it { is_expected.to contain_file(dir).with( {
            :ensure => 'directory',
            :owner  => 'root',
            :group  => 'root',
            :mode   => '0755'
          } ) }
        end

        it { is_expected.to contain_mount('/var/nfs/exports/home').with( {
          :ensure   => 'mounted',
          :fstype   => 'none',
          :device   => '/var/nfs/home',
          :remounts => true,
          :options  => 'rw,bind'
        } ) }
      end

      context 'with trusted_nets not in CIDR format' do
        let(:pre_condition) { "class { 'nfs': is_server => true }" }
        let(:params) {{
          :trusted_nets => [ '1.2.3.0/255.255.255.0', '1.3.1.1' ]
        }}

        it_behaves_like 'a structured module'

        it { is_expected.to contain_nfs__server__export('nfs4_root').with_clients( [
          '1.2.3.0/24', '1.3.1.1'
        ] ) }

        it { is_expected.to contain_nfs__server__export('home_dirs').with_clients( [
          '1.2.3.0/24', '1.3.1.1'
        ] ) }

      end

      context 'with create_home_dirs=true' do
        let(:pre_condition) { "class { 'nfs': is_server => true }" }
        let(:hieradata) { 'simp_options_ldap_params' }
        let(:params) {{ }}

        it_behaves_like 'a structured module'

        it { is_expected.to contain_class('simp_nfs::create_home_dirs') }
      end

      context 'when nfs::server::stunnel=true' do
        # setting nfs::stunnel to true will also set nfs::server::stunnel to
        # true by default
        let(:pre_condition) { <<~EOM
            class { 'nfs':
              is_server => true,
              stunnel => true
            }
          EOM
        }

        let(:params) {{ :trusted_nets => [ '1.2.3.0/255.255.255.0' ] }}

        it_behaves_like 'a structured module'

        it { is_expected.to contain_nfs__server__export('nfs4_root').with( {
          :clients     => [ '127.0.0.1' ],
          :export_path => '/var/nfs/exports',
          :sec         => ['sys'],
          :fsid        => '0',
          :crossmnt    => true,
          :insecure    => true
        } ) }

        it { is_expected.to contain_nfs__server__export('home_dirs').with( {
          :clients     => [ '127.0.0.1' ],
          :export_path => '/var/nfs/exports/home',
          :rw          => true,
          :sec         => ['sys'],
          :insecure    => true
        } ) }
      end

      context 'when nfs::is_server is not true' do
        # default value of nfs::is_server is false
        it { is_expected.to_not compile.with_all_deps }
      end
    end
  end
end
