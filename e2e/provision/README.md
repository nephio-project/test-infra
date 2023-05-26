# Quick Start for GCE

1. Create a VM:

   ```bash
   $ gcloud compute instances create --machine-type e2-standard-8 \
                                     --boot-disk-size 200GB \
                                     --image-family=ubuntu-2004-lts \
                                     --image-project=ubuntu-os-cloud \
                                     --metadata=startup-script-url=https://raw.githubusercontent.com/nephio-project/test-infra/main/e2e/provision/gce_init.sh \
                                     nephio-r1-e2e
   ```

2. If you want to watch the progress of the installation, give it about 30
   seconds to reach a network accessible state, and then ssh in and tail the
   startup script exection:

   Googlers (you also need to run `gcert`):
   ```bash
   $ gcloud compute ssh nephio-r1-e2e -- \
                    -o ProxyCommand='corp-ssh-helper %h %p' \
                    sudo journalctl -u google-startup-scripts.service --follow
   ```
   
   Everyone else:
   ```bash
   $ gcloud compute ssh nephio-r1-e2e -- \
                    sudo journalctl -u google-startup-scripts.service --follow
   ```

4. Once it's done, ssh in and port forward the port to the UI:

   Googlers (you also need to run `gcert`):
   ```bash
   $ gcloud compute ssh nephio-r1-e2e -- \
                    -o ProxyCommand='corp-ssh-helper %h %p' \
                    -L 7007:localhost:7007 \
                    kubectl --kubeconfig /home/ubuntu/.kube/mgmt-config port-forward --namespace=nephio-webui svc/nephio-webui 7007
   ```
   
   Everyone else:
   ```bash
   $ gcloud compute ssh nephio-r1-e2e -- \
                    -L 7007:localhost:7007 \
                    kubectl --kubeconfig /home/ubuntu/.kube/mgmt-config port-forward --namespace=nephio-webui svc/nephio-webui 7007
   ```
   
   You can now navigate to
   [http://localhost:7007/config-as-data](http://localhost:7007/config-as-data) to
   browse the UI.

5. You probably want a second ssh window open to run `kubectl` commands, etc.,
without the port forwarding (which would fail if you try to open a second ssh
connection with that setting).

   Googlers:
   ```bash
   $ gcloud compute ssh nephio-r1-e2e -- -o ProxyCommand='corp-ssh-helper %h %p'
   $ sudo su - ubuntu
   ```
   
   Everyone else:
   ```bash
   $ gcloud compute ssh nephio-r1-e2e
   $ sudo su - ubuntu
   ```
