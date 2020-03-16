require 'spec_helper'

describe 'simp_nfs' do
  shared_examples_for 'a structured module' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('simp_nfs') }
  end

  on_supported_os.each do |os, os_facts|
    let(:nfs_server_ip) { '1.2.3.4' }
    context "on #{os}" do
      let(:facts) do
        os_facts
      end

      context 'with default parameters' do
        let(:params) {{ }}

        it_behaves_like 'a structured module'

        it { is_expected.to contain_class('nfs').with_is_server(false) }
        it { is_expected.to_not contain_class('simp_nfs::export::home') }
        it { is_expected.to contain_class('nfs').with_is_client(true) }
        it { is_expected.to_not contain_class('simp_nfs::mount::home') }
      end

      context 'when exporting home directories only' do
        let(:params) {{
          :export_home_dirs => true
        }}

        it_behaves_like 'a structured module'

        it { is_expected.to contain_class('nfs').with_is_server(true) }
        it { is_expected.to contain_class('simp_nfs::export::home') }
        it { is_expected.to_not contain_class('simp_nfs::mount::home') }
      end

      context 'when exporting and mounting home directories' do
        context 'with autodetect_remote and use_autofs defaults' do
          let(:params) {{
            :export_home_dirs => true,
            :home_dir_server  => nfs_server_ip
          }}

          it_behaves_like 'a structured module'

          it { is_expected.to contain_class('nfs').with_is_server(true) }
          it { is_expected.to contain_class('simp_nfs::export::home') }
          it { is_expected.to contain_class('simp_nfs::mount::home').with({
            :nfs_server        => '127.0.0.1',
            :autodetect_remote => true,
            :use_autofs        => true
          } ) }
        end

        context 'with autodetect_remote=false' do
          let(:params) {{
            :export_home_dirs  => true,
            :home_dir_server   => nfs_server_ip,
            :autodetect_remote => false
          }}

          it_behaves_like 'a structured module'
          it { is_expected.to contain_class('simp_nfs::mount::home').with({
            :nfs_server        => '127.0.0.1',
            :autodetect_remote => false,
            :use_autofs        => true
          } ) }
        end

        context 'with use_autofs=false' do
          let(:params) {{
            :export_home_dirs => true,
            :home_dir_server  => nfs_server_ip,
            :use_autofs       => false
          }}

          it_behaves_like 'a structured module'
          it { is_expected.to contain_class('simp_nfs::mount::home').with({
            :nfs_server        => '127.0.0.1',
            :autodetect_remote => true,
            :use_autofs        => false
          } ) }
        end
      end

      context 'when mounting home directories only' do
        context 'with autodetect_remote and use_autofs defaults' do
          let(:params) {{
            :home_dir_server => nfs_server_ip
          }}

          it_behaves_like 'a structured module'

          it { is_expected.to contain_class('nfs').with_is_server(false) }
          it { is_expected.to_not contain_class('simp_nfs::export::home') }
          it { is_expected.to contain_class('simp_nfs::mount::home').with({
            :nfs_server        => nfs_server_ip,
            :autodetect_remote => true,
            :use_autofs        => true
          } ) }

        end

        context 'with autodetect_remote=false' do
          let(:params) {{
            :home_dir_server   => nfs_server_ip,
            :autodetect_remote => false
          }}

          it_behaves_like 'a structured module'

          it { is_expected.to contain_class('simp_nfs::mount::home').with({
            :nfs_server        => nfs_server_ip,
            :autodetect_remote => false,
            :use_autofs        => true
          } ) }
        end

        context 'with use_autofs=false' do
          let(:params) {{
            :home_dir_server => nfs_server_ip,
            :use_autofs     => false
          }}

          it_behaves_like 'a structured module'

          it { is_expected.to contain_class('simp_nfs::mount::home').with({
            :nfs_server        => nfs_server_ip,
            :autodetect_remote => true,
            :use_autofs        => false
          } ) }
        end
      end
    end
  end
end
