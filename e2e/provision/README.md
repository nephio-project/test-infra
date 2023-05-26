# Quick Start for GCE

1. Create a VM:

```bash
$ gcloud compute instances create --machine-type e2-standard-8 --boot-disk-size 60GB nephio-r1-e2e
```

2. SSH to the VM:

Googlers (you also need to run `gcert`):
```bash
$ gcloud compute ssh nephio-r1-e2e -- -o ProxyCommand='corp-ssh-helper %h %p' -L 7007:localhost:7007
```

Everyone else:
```bash
$ gcloud compute ssh nephio-r1-e2e -- -L 7007:localhost:7007
```

3. On the machine, run this:

```bash
$ sudo apt-get install -y git
$ git clone https://github.com/nephio-project/test-infra.git
$ sed -e "s/vagrant/$USER/" < test-infra/e2e/provision/nephio.yaml > ~/nephio.yaml
$ cd test-infra/e2e/provision/
$ ./gce_run.sh
$ kubectl --kubeconfig ~/.kube/mgmt-config port-forward --namespace=nephio-webui svc/nephio-webui 7007
```

You can now navigate to
[http://localhost:7007/config-as-data](http://localhost:7007/config-as-data) to
browse the UI.

You probably want a second ssh window open to run `kubectl` commands, etc.,
without the port forwarding (which would fail if you try to open a second ssh
connection with that setting).

Googlers:
```bash
$ gcloud compute ssh nephio-r1-e2e -- -o ProxyCommand='corp-ssh-helper %h %p'
```

Everyone else:
```bash
$ gcloud compute ssh nephio-r1-e2e
```

