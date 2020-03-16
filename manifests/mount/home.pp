# @summary Set up an `NFSv4` client to point to mount your remote home directories
#
# If this system is also the NFS server, you need to set
# `nfs::client::is_server` to `true` or set
# `simp_nfs::mount::home::nfs_server` to `127.0.0.1`.
#
# @param nfs_server
#   The IP address of the NFS server to which you will be connecting
#
#   * If you are the server, please make sure that this is `127.0.0.1`
#
# @param remote_path
#   The NFS share that you want to mount
#
# @param local_home
#   The local base for home directories
#
#   * Most sites will want this to be `/home` but some may opt for something
#     like `/exports/home` or the like.
#
#   * Top level directories will **not** be automatically managed
#
# @param port
#   The NFS port to which to connect
#
# @param sec
#   The sec mode for the mount
#
# @param options
#   The mount options string that should be used
#
#   * fstype and port will already be set for you
#   * If using stunnel, `proto` will be set to `tcp` for you
#
# @param at_boot
#   Ensure that this mount is mounted at boot time
#
#   * Has no effect if `$use_autofs` is set
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
#   Enable automounting with Autofs
#
# @param stunnel
#   Controls enabling `stunnel` to encrypt NFSv4 connection to the NFS server
#
#   * If left unset, the value will be taken from `$nfs::client::stunnel`
#   * May be set to `false` to ensure that `stunnel` will not be used for
#     this connection
#   * May be set to `true` to force the use of `stunnel` on this connection
#   * Will *attempt* to determine if the host is trying to connect to itself
#     and use a direct, local connection in lieu of a stunnel in this case.
#
#     * When you know this host is also the NFS server, setting this to
#       `false` and `$nfs_server` to `127.0.0.1` is best.
#     * Auto-detect logic only works with IPv4 addresses.
#
# @param stunnel_nfsd_port
#   Listening port on the NFS server for the tunneled connection to
#   the NFS server daemon
#
#   * Decrypted traffic will be forwarded to `$port` on the NFS server
#   * If left unset, the value will be taken from `$nfs::stunnel_nfsd_port`
#   * Unused when `$stunnel` is `false`
#
# @param stunnel_socket_options
#   Additional stunnel socket options to be applied to the stunnel to the NFS
#   server
#
#   * If left unset, the value will be taken from
#     `$nfs::client::stunnel_socket_options`
#   * Unused when `$stunnel` is `false`
#
# @param stunnel_verify
#   The level at which to verify TLS connections
#
#   * Levels:
#
#       * level 0 - Request and ignore peer certificate.
#       * level 1 - Verify peer certificate if present.
#       * level 2 - Verify peer certificate.
#       * level 3 - Verify peer with locally installed certificate.
#       * level 4 - Ignore CA chain and only verify peer certificate.
#
#   * If left unset, the value will be taken from
#     `$nfs::client::stunnel_socket_verify`
#   * Unused when `$stunnel` is `false`
#
# @param stunnel_wantedby
#   The `systemd` targets that need `stunnel` to be active prior to being
#   activated
#
#   * If left unset, the value will be taken from `$nfs::client::stunnel_wantedby`
#   * Unused when `$stunnel` is `false`
#
# @author https://github.com/simp/pupmod-simp-simp_nfs/graphs/contributors
#
class simp_nfs::mount::home (
  Simplib::Ip                        $nfs_server,
  Stdlib::Absolutepath               $remote_path            = '/home',
  Stdlib::Absolutepath               $local_home             = '/home',
  Optional[Simplib::Port]            $port                   = undef,
  Enum['sys','krb5','krb5i','krb5p'] $sec                    = 'sys',
  Optional[String]                   $options                = undef,
  Boolean                            $at_boot                = true,
  Boolean                            $autodetect_remote      = true,
  Boolean                            $use_autofs             = true,
  Optional[Boolean]                  $stunnel                = undef,
  Optional[Simplib::Port]            $stunnel_nfsd_port      = undef,
  Optional[Array[String]]            $stunnel_socket_options = undef,
  Optional[Integer]                  $stunnel_verify         = undef,
  Optional[Array[String]]            $stunnel_wantedby       = undef

) {

  include 'nfs'

  unless $nfs::is_client {
    fail('This host is not configured to be a NFS client. Set nfs::is_client to true to fix.')
  }

  if $facts['selinux_current_mode'] and ($facts['selinux_current_mode'] != 'disabled') {
    selboolean { 'use_nfs_home_dirs':
      persistent => true,
      value      => 'on'
    }
  }

  if $use_autofs {
    $_autofs_indirect_map_key = '*'
    $_autofs_add_key_subst    = true
  }
  else {
    $_autofs_indirect_map_key = undef
    $_autofs_add_key_subst    = false
  }

  nfs::client::mount { $local_home:
    nfs_server              => $nfs_server,
    remote_path             => $remote_path,
    autodetect_remote       => $autodetect_remote,
    nfs_version             => 4,
    sec                     => $sec,
    options                 => $options,
    at_boot                 => $at_boot,
    autofs                  => $use_autofs,
    autofs_add_key_subst    => $_autofs_add_key_subst,
    autofs_indirect_map_key => $_autofs_indirect_map_key,
    nfsd_port               => $port,
    stunnel                 => $stunnel,
    stunnel_nfsd_port       => $stunnel_nfsd_port,
    stunnel_socket_options  => $stunnel_socket_options,
    stunnel_verify          => $stunnel_verify,
    stunnel_wantedby        => $stunnel_wantedby
  }
}
