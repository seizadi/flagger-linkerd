export GIT_REPO	= flagger-linkerd
export FLAGGER_NS = linkerd

.id:
	git config user.email | awk -F@ '{print $$1}' > .id

cluster:
	minikube stop; minikube delete; minikube start; minikube addons enable metrics-server
	@echo 'Built minikube cluster'

metric-server: cluster
	kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
	@echo 'Done with deploy Metrics Server'

linkerd: cluster
	linkerd check --pre                     # validate that Linkerd can be installed
	linkerd install | kubectl apply -f -    # install the control plane into the 'linkerd' namespace
	linkerd check                           # validate everything worked!
	@echo 'Done with deploy Linkerd'

dashboard:
	linkerd dashboard                      # launch the Linkerd dashboard

flagger: linkerd
	kubectl apply -k github.com/weaveworks/flagger//kustomize/linkerd
	@echo 'Done with deploy Flagger'

test:
	kubectl apply -k .
	@echo 'Done with deploy test application'


status:
	# kubectl get --watch helmreleases --all-namespaces
	kubectl -n test get ev --watch

logs:
	 kubectl logs -n $(FLAGGER_NS) -f --since 10s $(shell kubectl get pods -n $(FLAGGER_NS) -o name | grep flagger)

clean:
	minikube stop; minikube delete
