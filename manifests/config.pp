class tesk::config {
  if $tesk::installceph {
     file{'/etc/ceph/ceph.conf':
        ensure  => file,
        content => "[global]\nfsid = ${tesk::cephfsid}\nmon host = ${tesk::cephmonhost}\n",
        require => Package['ceph-common'],
     }
     $_keys = $tesk::cephkeys.map |$_it| {
        "[client.${_it['user']}]\n\tkey = ${_it['key']}\n"
     }
     file{'/etc/ceph/ceph.keyring':
        ensure    => file,
        mode      => '0600',
        show_diff => false,
        content   => join($_keys, "\n"),
     }
  }
}
