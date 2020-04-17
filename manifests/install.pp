class tesk::install {
   if $tesk::managerepo {
      case $facts['osfamily'] {
         'RedHat': {
            yumrepo {'kubernetes':
              enabled       => true,
              descr         => 'kubernetes',
              baseurl       => "https://packages.cloud.google.com/yum/repos/kubernetes-el${::operatingsystemmajrelease}-x86_64",
              repo_gpgcheck => true,
              gpgkey        => "https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg",
              gpgcheck      => true,
            }
           
            if $tesk::installceph {
              yumrepo {'ceph':
                enabled       => true,
                descr         => 'ceph',
                baseurl       => "https://download.ceph.com/rpm-nautilus/el${::operatingsystemmajrelease}/\$basearch",
                gpgcheck      => true,
                gpgkey        => 'https://download.ceph.com/keys/release.asc',
              }
            }
          }
          default: {
            fail("Unsupported osfamily")
          }
      }
   }
   if $tesk::installdocker {
      class { 'docker':
         mtu          => $tesk::kubemtu,
         docker_users => [$tesk::dockeruser],
      }
      package{'docker-compose':
         ensure => present,
      }      
   }
   if $tesk::installceph {
      package{'ceph-common':
         ensure => present,
      }
      exec{'modprobe_rbd':
         command => 'modprobe rbd',
         unless  => 'lsmod | grep -q rbd',
         require => Package['ceph-common'],
      }
   }

   file {'/etc/tesk-deploy':
     ensure => 'directory',
     mode   => '0700',
   }
}
