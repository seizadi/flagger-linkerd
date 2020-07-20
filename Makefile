export GIT_REPO	= flagger-linkerd
export FLAGGER_NS = linkerd

.id:
	git config user.email | awk -F@ '{print $$1}' > .id

cluster:
	minikube stop; minikube delete;
	minikube start --cpus=3
	minikube addons enable ingress
	minikube addons enable metrics-server
	@echo 'Built minikube cluster'

metric-server: cluster
	kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
	@echo 'Done with deploy Metrics Server'

linkerd:
	linkerd check --pre                     # validate that Linkerd can be installed
	linkerd install | kubectl apply -f -    # install the control plane into the 'linkerd' namespace
	linkerd check                           # validate everything worked!
	@echo 'Done with deploy Linkerd'

dashboard:
	linkerd dashboard                      # launch the Linkerd dashboard

flagger: cluster linkerd
	kubectl apply -k github.com/weaveworks/flagger//kustomize/linkerd
	@echo 'Done with deploy Flagger'

flux: .id
	kubectl create ns flux
	fluxctl install \
	--git-user=$(shell cat .id) \
	--git-email=$(shell cat .id)@users.noreply.github.com \
	--git-url=git@github.com:$(shell cat .id)/flagger-linkerd \
	--manifest-generation=true \
	--namespace=flux | kubectl apply -f -
	sleep 10; fluxctl  --k8s-fwd-ns flux identity
	@echo 'Done with deploy Flux'

test:
	kubectl apply -k workloads
	@echo 'Done with deploy test application'


status:
	# kubectl get --watch helmreleases --all-namespaces
	kubectl -n test get ev --watch

logs:
	 kubectl logs -n $(FLAGGER_NS) -f --since 10s $(shell kubectl get pods -n $(FLAGGER_NS) -o name | grep flagger)

clean:
	minikube stop; minikube delete
