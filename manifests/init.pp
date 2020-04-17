class tesk (
  Boolean          $managerepo           = true,
  Boolean          $installdocker        = true,
  Boolean          $installceph          = true,
  Optional[Array]  $workernodes          = undef,
  Optional[String] $cephfsid             = undef,
  Optional[String] $cephmonhost          = undef,
  Optional[Array]  $cephkeys             = undef,
  String           $dockeruser           = 'centos',
  String           $kubemtu              = '1400',
  String           $rancherhostname      = 'elixir-rancher.cerit-sc.cz',
  Optional[String] $cephmonitors         = '78.128.244.33:6789,78.128.244.37:6789,78.128.244.41:6789',
  Optional[String] $cephadminid          = 'rbd_vo_cerit-elixir_replicated-cerit-elixir-ceph-adm',
  Optional[String] $cephadminsecret      = 'ceph-adm-secret',
  Optional[String] $cephpool             = 'rbd_vo_cerit-elixir_replicated',
  Optional[String] $cephuserid           = 'rbd_vo_cerit-elixir_replicated-cerit-elixir-ceph-user',
  Optional[String] $cephusersecret       = 'ceph-user-secret',
  Optional[String] $lemail               = 'root@cerit-sc.cz',
  Optional[String] $ftpusername          = undef,
  Optional[String] $ftppassword          = undef,
) inherits tesk::params {

    contain tesk::install
    contain tesk::config

}
