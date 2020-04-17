# Requirements

* control node role has ssh keys to other nodes to $dockeruser account (needed for rke)
* control node is setup so that rke and helm binaries are available as rpm packages
* currently only Centos 7 is tested and only Centos is supported
* at least rancher hostname has to exist in DNS prior to deployment

# Rancher let's encrypt:

 cluster -> system -> load balancing -> rancher -> edit
 labels & annotations:
 add annotation
 cert-manager.io/cluster-issuer: letsencrypt-prod
 kubernetes.io/ingress.class: nginx
 kubernetes.io/tls-acme: true

 save & reload

 ssl certificates: select serving cert(hostname)

# usage

* control node from hiera: include classes tesk and tesk::role::controlnode
* define tesk::workernodes as a list of ip of k8s worker nodes
* workernodes: include class tesk only
