define tesk::k8resource::namespace {
   exec {"create_k8s_namespace_${title}":
     command => "kubectl create namespace ${title}",
     unless  => "kubectl get namespace | grep -q ${title}",
   }
}
