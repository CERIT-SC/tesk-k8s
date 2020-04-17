class tesk::role::controlnode (
  Array $installpkgs = ['kubectl', 'rke', 'helm'],
) {
   package{$installpkgs:
      ensure => present,
   }

   class{'nginx':
      worker_processes     => 4,
      worker_rlimit_nofile => 40000,
      worker_connections   => 8192,
      stream               => true,
      confd_purge          => true,
      server_purge         => true,
   }

   nginx::resource::upstream {'rancher_servers_http':
     context    => 'stream',
     least_conn => true,
   }
   nginx::resource::upstream {'rancher_servers_https':
     context    => 'stream',
     least_conn => true,
   }

   $tesk::workernodes.each |$_node| {
      nginx::resource::upstream::member{"${_node}_80":
         upstream     => 'rancher_servers_http',
         context      => 'stream',
         server       => $_node,
         max_fails    => 3,
         fail_timeout => '5s',
      }
      nginx::resource::upstream::member{"${_node}_443":
         upstream     => 'rancher_servers_https',
         context      => 'stream',
         server       => $_node,
         port         => 443,
         max_fails    => 3,
         fail_timeout => '5s',
      } 
   }

   nginx::resource::streamhost { 'http_proxy':
     listen_port => 80,
     proxy       => 'rancher_servers_http',
   }
   nginx::resource::streamhost { 'https_proxy':
     listen_port => 443,
     proxy       => 'rancher_servers_https',
   }

   $_nodes = $tesk::workernodes.map |$_node| {
      {'address' => $_node, 'user' => $tesk::dockeruser, 'role' => '[controlplane, worker, etcd]'}
   }

   file{'/etc/tesk-deploy/rancher-cluster.yml':
     ensure  => 'file',
     content => epp('tesk/rancher-cluster.yml', {'nodes' => $_nodes}),
     require => [Package['rke'], File['/etc/tesk-deploy']],
   } ~> exec{'rke up --config':
      command     => "rke up --config /etc/tesk-deploy/rancher-cluster.yml",
      refreshonly => true,
      timeout     => '1200',
   }

   file_line{'/etc/environment':
     path  => '/etc/environment',
     line  => 'KUBECONFIG=/etc/tesk-deploy/kube_config_rancher-cluster.yml',
     match => 'KUBECONFIG',
   }

   exec{'get_canal_configmaps':
     command => 'kubectl get configmaps -n kube-system canal-config -o yaml > /etc/tesk-deploy/canal_configmaps.yaml',
     unless  => 'test -f /etc/tesk-deploy/canal_configmaps.yaml',
     require => Package['kubectl'],
   }

   exec{'set_canal_mtu':
     command => "sed -i '/\"type\": \"calico\",/a \\ \\ \\ \\ \\ \\ \\ \\ \\ \\ \"mtu\": ${tesk::kubemtu},' /etc/tesk-deploy/canal_configmaps.yaml",
     unless  => 'grep -q mtu /etc/tesk-deploy/canal_configmaps.yaml',
     require => Exec['get_canal_configmaps'],
   } ~> exec{'update_canal_maps':
     command     => 'kubectl apply -f /etc/tesk-deploy/canal_configmaps.yaml',
     refreshonly => true,
   } ~> exec{'reload_canal':
     command     => "kubectl get pod -n kube-system |grep canal |awk '{print \$1}' | xargs kubectl delete -n kube-system pod",
     refreshonly => true
   }

   exec{'add_helm_repos':
     command     => 'helm repo add rancher-latest https://releases.rancher.com/server-charts/latest && helm repo add jetstack https://charts.jetstack.io && helm repo update',
     unless      => 'helm repo list | grep jetstack',
   }

   tesk::k8resource::namespace{'cattle-system':} 
   tesk::k8resource::namespace{'cert-manager':} 
   exec{'pre_install_cert_manager':
      command => "kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.14/deploy/manifests/00-crds.yaml",
      unless  => "kubectl get CustomResourceDefinition certificaterequests.cert-manager.io | grep -q certificaterequests.cert-manager.io",
      require => Tesk::K8resource::Namespace['cert-manager'],
      before  => Tesk::Helm::Install['cert-manager'],
   }
   tesk::helm::install{'cert-manager':
      repo      => 'jetstack/cert-manager',
      namespace => 'cert-manager',
      version   => 'v0.14.0',
      before    => Tesk::Helm::Install['rancher'],
   }
   tesk::helm::install{'rancher':
      repo      => 'rancher-latest/rancher',
      namespace => 'cattle-system',
      args      => "--set hostname=${tesk::rancherhostname}",
   } ~> exec{'start_rancher': 
      command     => "kubectl -n cattle-system rollout status deploy/rancher",
      refreshonly => true,
   }

   if $tesk::installceph {
      $_admkey = $tesk::cephkeys.filter |$_key| {
         $_key['user'] == $tesk::cephadminid
      }
   
      file{'/etc/tesk-deploy/ceph-adm-secret.yaml':
         ensure  => 'file',
         content =>  epp('tesk/ceph-secret.yaml', {'name' => $tesk::cephadminsecret, 'key' => base64('encode', $_admkey[0]['key']), 'namespace' => 'kube-system'}),
      } ~> exec{'reload-adm-secret':
         command     => 'kubectl delete -f /etc/tesk-deploy/ceph-adm-secret.yaml; kubectl create -f /etc/tesk-deploy/ceph-adm-secret.yaml',
         refreshonly => true,
      }
   
      $_userkey = $tesk::cephkeys.filter |$_key| {
         $_key['user'] == $tesk::cephuserid
      }
   
      file{'/etc/tesk-deploy/ceph-user-secret.yaml':
         ensure  => 'file',
         content =>  epp('tesk/ceph-secret.yaml', {'name' => $tesk::cephusersecret, 'key' => base64('encode',$_userkey[0]['key']), 'namespace' => 'default'}),
      } ~> exec{'reload-user-secret':
         command     => 'kubectl delete -f /etc/tesk-deploy/ceph-user-secret.yaml; kubectl create -f /etc/tesk-deploy/ceph-user-secret.yaml',
         refreshonly => true,
      }
     
      file{'/etc/tesk-deploy/ceph-storage.yaml':
         ensure  => 'file',
         content => epp('tesk/ceph-storage.yaml',
                        {'monitors'    => $tesk::cephmonitors,
                         'adminid'     => $tesk::cephadminid,
                         'adminsecret' => $tesk::cephadminsecret,
                         'pool'        => $tesk::cephpool,
                         'userid'      => $tesk::cephuserid,
                         'usersecret'  => $tesk::cephusersecret,
                        }),
      } ~> exec{'reload-ceph-storage':
         command     => 'kubectl delete -f /etc/tesk-deploy/ceph-storage.yaml; kubectl create -f /etc/tesk-deploy/ceph-storage.yaml',
         refreshonly => true,
      }
   }

   file{'/etc/tesk-deploy/le-server-secret.yaml':
      ensure  => 'file',
      content => epp('tesk/le-server-secret.yaml', {'email' => $tesk::lemail}),
   } ~> exec{'reload-le-server-secret':
      command     => 'kubectl delete -f /etc/tesk-deploy/le-server-secret.yaml; kubectl create -f /etc/tesk-deploy/le-server-secret.yaml',
      refreshonly => true,
   }

## already created in heml chart
#
#   file{'/etc/tesk-deploy/ftp-secret.yaml':
#      ensure => 'file',
#      content => epp('tesk/ftp-secret.yaml', {'username' => $tesk::ftpusername, 'password' => $tesk::ftppassword}),
#   } ~> exec{'reload-ftp-secret':
#      command     => 'kubectl delete -f /etc/tesk-deploy/ftp-secret.yaml; kubectl create -f /etc/tesk-deploy/ftp-secret.yaml',
#      refreshonly => true,
#   }
}
