#!/bin/bash

P_K8S="../k8s"
P_SUBST_BROKER_TOKEN="./broker-info.subm"

set -x

RET=0

export KUBECONFIG_PATHES=$( realpath ~/.kube/config )

# === functions

# Function that will get executed when the user presses Ctrl+C
function handler () {
    echo "Processing the Ctrl+C"
    echo "PAUSE"
    read PAUSE
}

# Assign the handler function to the SIGINT signal
trap handler SIGINT

setup_cni_calico () {
	set -x

	local RET=0

	local IN_CTX="${1}"

	[ "${IN_CTX}." = "." ] && echo "error: missing parameter <ctx>" && return 1

	# install calico cni latest stable version
	kubectl --context ${IN_CTX} apply -f https://docs.projectcalico.org/manifests/calico.yaml

	# install operator
	kubectl --context ${IN_CTX} create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
	RET=$?

	# Trigger the operator to start a migration by creating an Installation resource. The operator will auto-detect your existing Calico settings and fill out the spec section.
	kubectl --context ${IN_CTX} create -f - <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec: {}
EOF
	RET=$?

	echo "pause"
	read PAUSE

	# monitor: Monitor the migration status with the following command:
	kubectl --context ${IN_CTX} describe tigerastatus calico
	RET=$?

	# result
	kubectl --context ${IN_CTX} get pods -n calico-system
	RET=$?

	return ${RET}
}

# ssh fschulte@n01.harryboing.de
# sudo su -

# cd /root/_prj

# git clone https://github.com/amhambra/sample-istio-services.git

# cd /root/_prj/sample-istio-services

DO="Y"

if [ "${DO}." = "Y." ]; then
	# create clusters: kind-cr1
	kind create cluster --config ${P_K8S}/kind-cluster-cr1.yaml

	# create clusters: kind-cr2
	kind create cluster --config ${P_K8S}/kind-cluster-cr2.yaml

	# list custers
	kind get clusters

	# init cni calico to cluster
	setup_cni_calico "kind-cr1";
	setup_cni_calico "kind-cr2";


	# apply tigera crd for needed network

	kubectl --context kind-cr1 apply -f ${P_K8S}/tigera-c1.yaml

	echo "PAUSE: waiting for tigera ip pool settlement"
	read PAUSE;

	kubectl --context kind-cr1 get -A pods

	kubectl --context kind-cr2 apply -f ${P_K8S}/tigera-c2.yaml

	echo "PAUSE: waiting for tigera ip pool settlement"
	read PAUSE;

	kubectl --context kind-cr2 get -A pods

	echo "subctl deploy-broker into kind-cr1 cluster ..."
	read PAUSE;


	subctl deploy-broker --kubeconfig ${KUBECONFIG_PATHES} --kubecontext kind-cr1 --operator-debug

	kubectl --context kind-cr1 get -A pods

	echo "PAUSE: waiting for broker settlement"
	read PAUSE;

	kubectl --context kind-cr1 label node cr1-worker submariner.io/gateway=true
	kubectl --context kind-cr1 label node cr1-worker2 submariner.io/gateway=true
	kubectl --context kind-cr1 label node cr1-worker3 submariner.io/gateway=true

	kubectl --context kind-cr2 label node cr2-worker submariner.io/gateway=true
	kubectl --context kind-cr2 label node cr2-worker2 submariner.io/gateway=true
	kubectl --context kind-cr2 label node cr2-worker3 submariner.io/gateway=true

	subctl deploy-broker --kubeconfig ${KUBECONFIG_PATHES} --kubecontext kind-cr1 --operator-debug

	subctl join ${P_SUBST_BROKER_TOKEN} --pod-debug --kubeconfig ${KUBECONFIG_PATHES} --natt=false --clusterid kind-cr2 --kubecontext kind-cr2
	RET=$?

	subctl join ${P_SUBST_BROKER_TOKEN} --pod-debug --kubeconfig ${KUBECONFIG_PATHES} --natt=false --clusterid kind-cr1 --kubecontext kind-cr1
	RET=$?

	subctl show gateways
	RET=$?

	subctl show connections
	RET=$?

fi

subctl verify --kubeconfig ${KUBECONFIG_PATHES} --kubecontexts kind-cr1,kind-cr2 --only service-discovery,connectivity --verbose
RET=$?


exit ${RET}


# cleanup: remove clusters

kind delete clusters cr2
RET=$?

kind delete clusters cr1
RET=$?


