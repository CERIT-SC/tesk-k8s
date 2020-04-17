define tesk::helm::install (
  String           $repo,
  String           $namespace, 
  Optional[String] $version = undef,
  Optional[String] $args = undef,
) {
  if $version != undef {
    $_version = "--version ${version}"
  } else {
    $_version = ''
  }
  
  exec{"helm_install_$title":
    command => "helm install ${title} ${repo} --namespace ${namespace} ${_version} ${args}",
    unless  => "helm list -n ${namespace} | grep -q ${title}",
  }
}
