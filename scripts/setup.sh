!#/bin/sh

P_K8S="../k8s"

set -x

RET=0

# ssh fschulte@n01.harryboing.de
# sudo su -

# cd /root/_prj

# git clone https://github.com/amhambra/sample-istio-services.git

# cd /root/_prj/sample-istio-services

kind create cluster --config ${P_K8S}/kind-cluster-cr1.yaml
kind create cluster --config ${P_K8S}/kind-cluster-cr2.yaml

# create custers
kind 

exit ${RET}


# cleanup: remove clusters

kind delete clusters cr2
Deleted clusters: ["cr2"]

kind delete clusters cr1
Deleted clusters: ["cr1"]
