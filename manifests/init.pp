# @summary A SIMP Profile for common NFS configurations
#
# @param export_home_dirs
#   Set up home directory exports for this system
#
#   * The `simp_options::trusted_nets` parameter will govern what clients may
#     connect to the share by default.
#   * Further configuration for home directory exports can be tweaked via the
#     parameters in `simp_nfs::export::home`
#
# @param home_dir_server
#   If set, specifies the IP address of the server from which you want to mount
#   NFS home directories for your users
#
#   * If `$export_home_dirs` is also set, this class will assume that you
#     want to mount on the local server if this is set at all.
#
#     * If the home directories other than the ones this server exports
#       should be mounted, do *not* set this parameter, and instead,
#       include and configure `simp_nfs::mount::home` in this server's manifest.
#   * Further configuration for the home directory mounts can be tweaked via
#     the parameters in `simp_nfs::mount::home`
#
# @param autodetect_remote
#   Attempts to figure out if this host is also the NFS server and adjust
#   the connection to the local IP address, `127.0.0.1`, in lieu of the
#   IP address specified in `$nfs_server`.
#
#   * When you know this host is also the NFS server, setting `$nfs_server`
#     to `127.0.0.1` is best.
#   * Auto-detect logic only works with IPv4 addresses.
#
# @param use_autofs
#   Use `autofs` for home directory mounts
#
# @author https://github.com/simp/pupmod-simp-simp_nfs/graphs/contributors
#
class simp_nfs (
  Boolean               $export_home_dirs  = false,
  Optional[Simplib::Ip] $home_dir_server   = undef,
  Boolean               $autodetect_remote = true,
  Boolean               $use_autofs        = true
) {
  if $export_home_dirs {
    class { 'nfs': * => { 'is_server' => true } }

    include 'simp_nfs::export::home'

    if $home_dir_server {
      class { 'simp_nfs::mount::home':
        nfs_server        => '127.0.0.1',
        autodetect_remote => $autodetect_remote,
        use_autofs        => $use_autofs
      }
    }
  }
  else {
    class { 'nfs': * => { 'is_client' => true } }

    if $home_dir_server {
      class { 'simp_nfs::mount::home':
        nfs_server        => $home_dir_server,
        autodetect_remote => $autodetect_remote,
        use_autofs        => $use_autofs
      }
    }
  }
}
