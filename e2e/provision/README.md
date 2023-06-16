# Quick Start for GCE and VMs running in other environments

## Table of Contents

- [Installing on GCE](#installing-on-gce)
  - [GCE Prerequisites](#gce-prerequisites)
  - [Create a Virtual Machine on GCE](#create-a-virtual-machine-on-gce)
  - [Follow installation on GCE](#follow-installation-on-gce)
- [Installing on a pre-provisioned VM](#installing-on-a-pre-provisioned-vm)
  - [VM Prerequisites](#vm-prerequisites)
  - [Kick off the installation on VM](#kick-off-installation-on-vm)
  - [Follow installation on VM](#follow-installation-on-vm)
- [Access to the User Interfaces](#access-to-the-user-interfaces)
- [Open terminal](#open-terminal)
- [Excercise](#excercise)
  - [Create regional cluster](#step-1-create-regional-cluster)
  - [Check Regional cluster installation](#step-2-check-regional-cluster-installation)
  - [Deploy 2 edge clusters](#step-3-deploy-2-edge-clusters)
  - [Deploy Free5GC control plane functions](#step-4-deploy-free5Gc-control-plane-functions)
  - [Deploy Free5GC operator in the workload clusters](#step-5-deploy-free5GC-operator-in-the-workload-clusters)
  - [Check Free5GC operator deployment](#step-6-check-free5GC-operator-deployment)
  - [Deploy AMF, SMF and UPF](#step-7-deploy-amf-smf-and-upf)

## Installing on GCE

### GCE Prerequisites

You need a account in GCP and `gcloud` available on your local environment.

### Create a Virtual Machine on GCE

```bash
gcloud compute instances create --machine-type e2-standard-8 \
                                    --boot-disk-size 200GB \
                                    --image-family=ubuntu-2004-lts \
                                    --image-project=ubuntu-os-cloud \
                                    --metadata=startup-script-url=https://raw.githubusercontent.com/nephio-project/test-infra/main/e2e/provision/init.sh \
                                    nephio-r1-e2e
```

There are some optional metadata values you can pass (add them as
comma-delimited key=value pairs in the `--metadata` flag).

- `nephio-run-e2e` defaults to `false` but you can set it to `true` to run
    the full e2e suite, instead of just setting up the sandbox.
- `nephio-setup-type` defaults to `r1` but `one-summit` will use the workshop
    code instead of the R1 code. Results are not guaranteed with that.
- `nephio-setup-debug` defaults to `false` but `true` will turn on verbose
    debugging.
- `nephio-test-infra-repo` defaults to
    `https://github.com/nephio-project/test-infra.git` but you can set it to
    your repository when testing changes to these scripts, and your repo will
    then be pulled by the `init.sh` instead.
- `nephio-test-infra-branch` defaults to `main` but you can use it along with
    the repo value to choose a branch in the repo for testing.

### Follow installation on GCE

If you want to watch the progress of the installation, give it about 30
seconds to reach a network accessible state, and then ssh in and tail the
startup script execution:

Googlers (you also need to run `gcert`):
```bash
gcloud compute ssh ubuntu@nephio-r1-e2e -- \
                -o ProxyCommand='corp-ssh-helper %h %p' \
                sudo journalctl -u google-startup-scripts.service --follow
```

Everyone else:
```bash
gcloud compute ssh ubuntu@nephio-r1-e2e -- \
                sudo journalctl -u google-startup-scripts.service --follow
```

## Installing on a pre-provisioned VM

This install has been verified on VMs running on Openstack, AWS, and Azure. 

### VM Prerequisites

Order or create a VM with the following specification:

- Linux Flavour: Ubuntu-20.04-focal
- 8 cores
- 32 GB memory
- 200 GB disk size
- default user with sudo passwordless permissions

**Configure a route for Kubernetes**

In some installations, the IP range used by Kubernetes in the sandbox can clash with the
IP address used by your VPN. In such cases, the VM will become unreachable during the
sandbox installation. If you have this situation, add the route below on your VM.

Log onto your VM and run the following commands,
replacing **\<interface-name\>** and **\<interface-gateway-ip\>** with your VMs values: 

```bash
sudo bash -c 'cat << EOF > /etc/netplan/99-cloud-init-network.yaml
network:
  ethernets:
    <interface-name>:
      routes:
        - to: 172.18.2.6/32
          via: <interface-gateway-ip>
          metric: 100
  version: 2
EOF'

sudo netplan apply
```

### Kick off installation on VM

Log onto your VM and run the following command:

```bash
wget -O - https://raw.githubusercontent.com/nephio-project/test-infra/main/e2e/provision/init.sh |  \
sudo NEPHIO_DEBUG=false   \
     NEPHIO_USER=ubuntu  \
     bash
```

The following environment variables can be used to configure the installation:

| Variable               | Values           | Default Value | Description                                            |
| ---------------------- | ---------------- | ------------- | ------------------------------------------------------ |
| NEPHIO_USER            | userid           | ubuntu        | The user to install the sandbox on (must have sudo passwordless permissions) |
| NEPHIO_DEBUG           | false or true    | false         | Controls debug output from the install                 |
| NEPHIO_DEPLOYMENT_TYPE | r1 or one-summit | r1            | Controls the type of installation to be carried out    |
| RUN_E2E                | false or true    | false         | Specifies whether end to end tests should be executed or not |
| NEPHIO_REPO            | URL              | https://github.com/nephio-project/test-infra.git |URL of the repository to be used for installation |

### Follow installation on VM

Monitor the installation on your terminal.

Log onto your VM using ssh on another terminal and use commands *docker* and *kubectl* to monitor the installation.

## Access to the User Interfaces

Once it's done, ssh in and port forward the port to the UI (7007) and to
Gitea's HTTP interface, if you want to have that (3000):

Googlers (you also need to run `gcert`):

```bash
gcloud compute ssh ubuntu@nephio-r1-e2e -- \
                -o ProxyCommand='corp-ssh-helper %h %p' \
                -L 7007:localhost:7007 \
                -L 3000:172.18.0.200:3000 \
                kubectl port-forward --namespace=nephio-webui svc/nephio-webui 7007
```

Others using GCE:

```bash
gcloud compute ssh ubuntu@nephio-r1-e2e -- \
                -L 7007:localhost:7007 \
                -L 3000:172.18.0.200:3000 \
                kubectl port-forward --namespace=nephio-webui svc/nephio-webui 7007
```

Others on VMs:

```bash
ssh <user>@<vm-address> \
                -L 7007:localhost:7007 \
                -L 3000:172.18.0.200:3000 \
                kubectl port-forward --namespace=nephio-webui svc/nephio-webui 7007
```

You can now navigate to:
- [http://localhost:7007/config-as-data](http://localhost:7007/config-as-data) to
browse the Nephio Web UI
- [http://localhost:3000/nephio](http://localhost:3000/nephio) to browse the Gitea UI

## Open terminal

You probably want a second ssh window open to run `kubectl` commands, etc.,
without the port forwarding (which would fail if you try to open a second ssh
connection with that setting).

Googlers:

```bash
gcloud compute ssh ubuntu@nephio-r1-e2e -- -o ProxyCommand='corp-ssh-helper %h %p'
```

Others on GCE:

```bash
gcloud compute ssh ubuntu@nephio-r1-e2e
```
Others on VMs:

```bash
ssh <user>@<vm-address>
```

## Exercise

### Step 1: Create regional cluster

Our e2e topology consists of one regional cluster, and two edge clusters.
Let's start by deploying the regional cluster. In this case, you will use
manual kpt commands to deploy a single cluster. First, check to make sure
that both the mgmt and mgmt-staging repositories are in the Ready state.
The mgmt repository is used to manage the contents of the management
cluster via Nephio; the mgmt-staging repository is just used internally
during the cluster bootstrapping process.

Use the session just started on the VM to run these commands:

```bash
kubectl get repositories
```

<details>
<summary>The output is similar to:</summary>

```console
NAME                      TYPE   CONTENT   DEPLOYMENT   READY   ADDRESS
free5gc-packages          git    Package   false        True    https://github.com/nephio-project/free5gc-packages.git
mgmt                      git    Package   true         True    http://172.18.0.200:3000/nephio/mgmt.git
mgmt-staging              git    Package   false        True    http://172.18.0.200:3000/nephio/mgmt-staging.git
nephio-example-packages   git    Package   false        True    https://github.com/nephio-project/nephio-example-packages.git
```
</details>

Since those are Ready, you can deploy a package from the
nephio-example-packages repository into the mgmt repository. To do this, you
retrieve the Package Revision name using `kpt alpha rpkg get`, and then clone
that specific Package Revision via the `kpt alpha rpkg clone` command,
propose and approve the resulting package revision. You want to use the latest
revision of the nephio-workload-cluster package, which you can get with the
command below (your latest revision may be different):

```bash
kpt alpha rpkg get --name nephio-workload-cluster
```

<details>
<summary>The output is similar to:</summary>

```console
NAME                                                               PACKAGE                   WORKSPACENAME   REVISION   LATEST   LIFECYCLE   REPOSITORY
nephio-example-packages-05707c7acfb59988daaefd85e3f5c299504c2da1   nephio-workload-cluster   main            main       false    Published   nephio-example-packages
nephio-example-packages-781e1c17d63eed5634db7b93307e1dad75a92bce   nephio-workload-cluster   v1              v1         false    Published   nephio-example-packages
nephio-example-packages-5929727104f2c62a2cb7ad805dabd95d92bf727e   nephio-workload-cluster   v2              v2         false    Published   nephio-example-packages
nephio-example-packages-cdc6d453ae3e1bd0b64234d51d575e4a30980a77   nephio-workload-cluster   v3              v3         false    Published   nephio-example-packages
nephio-example-packages-c78ecc6bedc8bf68185f28a998718eed8432dc3b   nephio-workload-cluster   v4              v4         false    Published   nephio-example-packages
nephio-example-packages-46b923a6bbd09c2ab7aa86c9853a96cbd38d1ed7   nephio-workload-cluster   v5              v5         false    Published   nephio-example-packages
nephio-example-packages-17bffe318ac068f5f9ef22d44f08053e948a3683   nephio-workload-cluster   v6              v6         false    Published   nephio-example-packages
nephio-example-packages-0fbaccf6c5e75a3eff7976a523bb4f42bb0118ce   nephio-workload-cluster   v7              v7         false    Published   nephio-example-packages
nephio-example-packages-7895e28d847c0296a204007ed577cd2a4222d1ea   nephio-workload-cluster   v8              v8         true     Published   nephio-example-packages
```
</details>

Then, use the NAME from that in the `clone` operation, and the resulting
PackageRevision name to perform the `propose` and `approve` operations:

```bash
kpt alpha rpkg clone -n default nephio-example-packages-7895e28d847c0296a204007ed577cd2a4222d1ea --repository mgmt regional
```

<details>
<summary>The output is similar to:</summary>

```console
mgmt-08c26219f9879acdefed3469f8c3cf89d5db3868 created
```
</details>

You want to make sure that our new regional cluster is labeled as regional.
Since you are using the CLI, you need to pull the package out, modify it, and
then push the updates back to the Draft revision. You will use `kpt` and the
`set-labels` function to do this.

To pull the package to a local directory, you use the `rpkg pull` command:

```bash
kpt alpha rpkg pull -n default mgmt-08c26219f9879acdefed3469f8c3cf89d5db3868 regional
```

The package is now in the `regional` directory. So, you can execute the
`set-labels` function against the package imperatively, using `kpt fn eval`:

```bash
kpt fn eval --image gcr.io/kpt-fn/set-labels:v0.2.0 regional -- "nephio.org/site-type=regional" "nephio.org/region=us-west1"
```

<details>
<summary>The output is similar to:</summary>

```console
[RUNNING] "gcr.io/kpt-fn/set-labels:v0.2.0"
[PASS] "gcr.io/kpt-fn/set-labels:v0.2.0" in 5.5s
    Results:
    [info]: set 7 labels in total
```
</details>

If you wanted to, you could have used the `--save` option to add the
`set-labels` call to the package pipeline. This would mean that function gets
called whenever the server saves the package; if you added new resources
later, they would also get labeled.

In any case, you now can push the package with the labels applied back to the
repository:

```bash
kpt alpha rpkg push -n default mgmt-08c26219f9879acdefed3469f8c3cf89d5db3868 regional
```

<details>
<summary>The output is similar to:</summary>

```console
[RUNNING] "gcr.io/kpt-fn/apply-replacements:v0.1.1" 
[PASS] "gcr.io/kpt-fn/apply-replacements:v0.1.1"
```
</details>

Finally, you propose and approve the package.

```bash
kpt alpha rpkg propose -n default mgmt-08c26219f9879acdefed3469f8c3cf89d5db3868
```

<details>
<summary>The output is similar to:</summary>

```console
mgmt-08c26219f9879acdefed3469f8c3cf89d5db3868 proposed
```
</details>

```bash
kpt alpha rpkg approve -n default mgmt-08c26219f9879acdefed3469f8c3cf89d5db3868
```

<details>
<summary>The output is similar to:</summary>

```console
mgmt-08c26219f9879acdefed3469f8c3cf89d5db3868 approved
```
</details>

ConfigSync running in the management cluster will now pull out this new
package, creating all the resources necessary to provision a Kind cluster and
register it with Nephio. This will take about five minutes or so.

### Step 2: Check Regional cluster installation

You can check if the cluster has been added to the management cluster:

```bash
kubectl get clusters
```

<details>
<summary>The output is similar to:</summary>

```console
NAME       PHASE         AGE     VERSION
regional   Provisioned   52m     v1.26.3
```
</details>

To access the API server of that cluster as well, you
need to get the `kubeconfig` file for it. To retrieve the file, you
pull it from the Kubernetes Secret, and decode the Base64 encoding:

```bash
kubectl get secret regional-kubeconfig -o jsonpath='{.data.value}' | base64 -d > $HOME/.kube/regional-kubeconfig
export KUBECONFIG=$HOME/.kube/config:$HOME/.kube/regional-kubeconfig
```

You can then use it to access the workload cluster directly:

```bash
kubectl get ns --context regional-admin@regional
```

<details>
<summary>The output is similar to:</summary>

```console
NAME                           STATUS   AGE
config-management-monitoring   Active   3h35m
config-management-system       Active   3h35m
default                        Active   3h39m
kube-node-lease                Active   3h39m
kube-public                    Active   3h39m
kube-system                    Active   3h39m
```
</details>

You should also check that the Kind cluster came up fully with `kubectl get
machinesets`. You should see READY and AVAILABLE replicas.

```bash
kubectl get machinesets
```

<details>
<summary>The output is similar to:</summary>

```console
NAME                                   CLUSTER    REPLICAS   READY   AVAILABLE   AGE     VERSION
regional-md-0-zhw2j-58d497c498xkz96z   regional   1          1       1           3h58m   v1.26.3
```
</details>

### Step 3: Deploy 2 edge clusters

Next, you can deploy a fleet of two edge clusters by applying the
PackageVariantSet that can be found in the `tests` directory:

```bash
kubectl apply -f test-infra/e2e/tests/002-edge-clusters.yaml
```

<details>
<summary>The output is similar to:</summary>

```console
packagevariantset.config.porch.kpt.dev/edge-clusters created
```
</details>

This is equivalent to doing the same `kpt` commands you did for the regional
cluster, except that it uses the PackageVariantSet controller, which is
running in the Nephio management cluster to do them automatically. It will
clone the package for each entry in the field `packageNames` in the
PackageVariantSet. You can observe the progress by looking at the UI, or by
using `kubectl` to monitor the various package variants, package revisions,
and kind clusters that get created.

To access the API server of these clusters, you
need to get the `kubeconfig` file. To retrieve the file, you
pull it from the Kubernetes Secret, and decode the Base64 encoding:

```bash
kubectl get secret edge01-kubeconfig -o jsonpath='{.data.value}' | base64 -d > $HOME/.kube/edge01-kubeconfig
kubectl get secret edge02-kubeconfig -o jsonpath='{.data.value}' | base64 -d > $HOME/.kube/edge02-kubeconfig
export KUBECONFIG=$HOME/.kube/config:$HOME/.kube/regional-kubeconfig:$HOME/.kube/edge01-kubeconfig:$HOME/.kube/edge02-kubeconfig
```

Once the edge clusters are ready it's necessary to inter-connect them. This time
we are going to use the [containerlab tool](https://containerlab.dev/) for that
operation. Eventually inter-cluster networking will be automated as well, but it
is not yet in this release.

```bash
workers=""
for context in $(kubectl config get-contexts --no-headers --output name); do
    workers+=$(kubectl get nodes -l node-role.kubernetes.io/control-plane!= -o jsonpath='{range .items[*]}"{.metadata.name}",{"\n"}{end}' --context "$context")
done
echo "{\"workers\":[${workers::-1}]}" | tee /tmp/vars.json
sudo containerlab deploy --topo test-infra/e2e/tests/002-topo.gotmpl --vars /tmp/vars.json --skip-post-deploy
```

<details>
<summary>The output is similar to:</summary>

```console
{"workers":["edge01-md-0-5xpjv-d578b7b8bxwph6d-6sv2n","edge02-md-0-fvpvh-99498794cxhfzsn-q5xvl","regional-md-0-p6zbf-586d7b54d8xw6b5x-qv77v"]}
INFO[0000] Containerlab v0.41.2 started
INFO[0000] Parsing & checking topology file: 002-topo.gotmpl
INFO[0000] Could not read docker config: open /root/.docker/config.json: no such file or directory
INFO[0000] Pulling ghcr.io/nokia/srlinux:latest Docker image
INFO[0266] Done pulling ghcr.io/nokia/srlinux:latest
INFO[0266] Creating lab directory: /tmp/test-infra/e2e/clab-free5gc-net
INFO[0268] Creating docker network: Name="clab", IPv4Subnet="172.20.20.0/24", IPv6Subnet="2001:172:20:20::/64", MTU="1500"
INFO[0271] Creating container: "N6"
INFO[0276] Creating virtual wire: N6:e1-1 <--> edge02-md-0-fvpvh-99498794cxhfzsn-q5xvl:eth1
INFO[0276] Creating virtual wire: N6:e1-2 <--> regional-md-0-p6zbf-586d7b54d8xw6b5x-qv77v:eth1
INFO[0276] Creating virtual wire: N6:e1-0 <--> edge01-md-0-5xpjv-d578b7b8bxwph6d-6sv2n:eth1
INFO[0277] Adding containerlab host entries to /etc/hosts file
+---+--------------------------------------------+--------------+-----------------------+---------------+---------+----------------+--------------------------+
| # |                    Name                    | Container ID |         Image         |     Kind      |  State  |  IPv4 Address  |       IPv6 Address       |
+---+--------------------------------------------+--------------+-----------------------+---------------+---------+----------------+--------------------------+
| 1 | edge01-md-0-5xpjv-d578b7b8bxwph6d-6sv2n    | 44e78769fc1e | kindest/node:v1.26.3  | ext-container | running | 172.18.0.11/16 | fc00:f853:ccd:e793::b/64 |
| 2 | edge02-md-0-fvpvh-99498794cxhfzsn-q5xvl    | 38eb76c0323b | kindest/node:v1.26.3  | ext-container | running | 172.18.0.8/16  | fc00:f853:ccd:e793::8/64 |
| 3 | regional-md-0-p6zbf-586d7b54d8xw6b5x-qv77v | 142a4f0cff7e | kindest/node:v1.26.3  | ext-container | running | 172.18.0.5/16  | fc00:f853:ccd:e793::5/64 |
| 4 | net-free5gc-net-N6                         | 1581d603e174 | ghcr.io/nokia/srlinux | srl           | running | 172.20.20.2/24 | 2001:172:20:20::2/64     |
+---+--------------------------------------------+--------------+-----------------------+---------------+---------+----------------+--------------------------+
```
</details>

Finally, we want to configure the resource backend to know about these clusters.
The resource backend is an IP address and VLAN index management system. It is
included for demonstration purposes, to show how Nephio package specialization
can interact with external systems to fully configure packages. But it needs to
be configured to match our topology.

First, we apply a package that defines the high-level networks to which our
workloads will attach. Part of the Nephio package specialization pipeline will
determine the exact VLAN tags and IP addresses for those attachments, based on
the specific clusters. There is a pre-defined PackageVariant in the tests
directory for this:

```bash
kubectl apply -f test-infra/e2e/tests/003-network.yaml
```

<details>
<summary>The output is similar to:</summary>

```console
packagevariant.config.porch.kpt.dev/network created
```
</details>

That package defines certain resources that exist for the entire topology.
However, we also need to configure the resource backend for our particular
topology. This will likely be automated in the future, but for now you can
just directly apply the configuration we have created that matches this test
topology.

```bash
kubectl apply -f test-infra/e2e/tests/003-network-topo.yaml
```

<details>
<summary>The output is similar to:</summary>

```console
rawtopology.topo.nephio.org/nephio created
```
</details>

### Step 4: Deploy Free5GC control plane functions

While the edge clusters are deploying (which will take 5-10 minutes), you can
install the free5gc functions other than SMF, AMF, and UPF. For this,
you use the regional cluster. Since these are all installed with a single
package, you can use the UI to pick the `free5gc-cp` package from the
`free5gc-packages` repository, and clone it to the `regional` repository (you
could have also used the CLI).

![Install free5gc - Step 1](free5gc-cp-1.png)

![Install free5gc - Step 2](free5gc-cp-2.png)

![Install free5gc - Step 3](free5gc-cp-3.png)

Click through the "Next" button until you are through all the steps, then
click "Add Deployment". On the next screen, click "Propose", and then
"Approve".

![Install free5gc - Step 4](free5gc-cp-4.png)

![Install free5gc - Step 5](free5gc-cp-5.png)

![Install free5gc - Step 6](free5gc-cp-6.png)

Shortly thereafter, you should see free5gc-cp in the cluster namespace:

```bash
kubectl get ns --context regional-admin@regional
```

<details>
<summary>The output is similar to:</summary>

```console
NAME                           STATUS   AGE
config-management-monitoring   Active   28m
config-management-system       Active   28m
default                        Active   28m
free5gc-cp                     Active   3m16s
kube-node-lease                Active   28m
kube-public                    Active   28m
kube-system                    Active   28m
local-path-storage             Active   28m
resource-group-system          Active   27m
```
</details>

And the actual workload resources:

```bash
kubectl -n free5gc-cp get all --context regional-admin@regional
```

<details>
<summary>The output is similar to:</summary>

```console
NAME                                 READY   STATUS    RESTARTS   AGE
pod/free5gc-ausf-7d494d668d-k55kb    1/1     Running   0          3m31s
pod/free5gc-nrf-66cc98cfc5-9mxqm     1/1     Running   0          3m31s
pod/free5gc-nssf-668db85d54-gsnqw    1/1     Running   0          3m31s
pod/free5gc-pcf-55d4bfd648-tk9fs     1/1     Running   0          3m31s
pod/free5gc-udm-845db6c9c8-54tfb     1/1     Running   0          3m31s
pod/free5gc-udr-79466f7f86-wh5bt     1/1     Running   0          3m31s
pod/free5gc-webui-84ff8c456c-g7q44   1/1     Running   0          3m31s
pod/mongodb-0                        1/1     Running   0          3m31s

NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
service/ausf-nausf      ClusterIP   10.131.151.99    <none>        80/TCP           3m32s
service/mongodb         ClusterIP   10.139.208.189   <none>        27017/TCP        3m32s
service/nrf-nnrf        ClusterIP   10.143.64.94     <none>        8000/TCP         3m32s
service/nssf-nnssf      ClusterIP   10.130.139.231   <none>        80/TCP           3m31s
service/pcf-npcf        ClusterIP   10.131.19.224    <none>        80/TCP           3m31s
service/udm-nudm        ClusterIP   10.128.13.118    <none>        80/TCP           3m31s
service/udr-nudr        ClusterIP   10.137.211.80    <none>        80/TCP           3m31s
service/webui-service   NodePort    10.140.177.70    <none>        5000:30500/TCP   3m31s

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/free5gc-ausf    1/1     1            1           3m31s
deployment.apps/free5gc-nrf     1/1     1            1           3m31s
deployment.apps/free5gc-nssf    1/1     1            1           3m31s
deployment.apps/free5gc-pcf     1/1     1            1           3m31s
deployment.apps/free5gc-udm     1/1     1            1           3m31s
deployment.apps/free5gc-udr     1/1     1            1           3m31s
deployment.apps/free5gc-webui   1/1     1            1           3m31s

NAME                                       DESIRED   CURRENT   READY   AGE
replicaset.apps/free5gc-ausf-7d494d668d    1         1         1       3m31s
replicaset.apps/free5gc-nrf-66cc98cfc5     1         1         1       3m31s
replicaset.apps/free5gc-nssf-668db85d54    1         1         1       3m31s
replicaset.apps/free5gc-pcf-55d4bfd648     1         1         1       3m31s
replicaset.apps/free5gc-udm-845db6c9c8     1         1         1       3m31s
replicaset.apps/free5gc-udr-79466f7f86     1         1         1       3m31s
replicaset.apps/free5gc-webui-84ff8c456c   1         1         1       3m31s

NAME                       READY   AGE
statefulset.apps/mongodb   1/1     3m31s
```
</details>

### Step 5: Deploy Free5GC operator in the workload clusters

Now you need to deploy the free5gc operator across all of the workload
clusters (regional and edge). To do this, you use another PackageVariantSet.
This one uses an objectSelector, and selects the WorkloadCluster resources
that were added to the management cluster when you deployed the
nephio-workload-cluster packages (manually as well as via
PackageVariantSet).

```bash
kubectl apply -f test-infra/e2e/tests/004-free5gc-operator.yaml
```

<details>
<summary>The output is similar to:</summary>

```console
packagevariantset.config.porch.kpt.dev/free5gc-operator created
```
</details>

### Step 6: Check Free5GC operator deployment

Within five minutes of applying that, you should see `free5gc` namespaces on
your regional and edge clusters:

```bash
kubectl get ns --context edge01-admin@edge01
```

<details>
<summary>The output is similar to:</summary>

```console
NAME                           STATUS   AGE
config-management-monitoring   Active   3h46m
config-management-system       Active   3h46m
default                        Active   3h47m
free5gc                        Active   159m
kube-node-lease                Active   3h47m
kube-public                    Active   3h47m
kube-system                    Active   3h47m
resource-group-system          Active   3h45m
```
</details>

```bash
kubectl -n free5gc get all --context edge01-admin@edge01
```

<details>
<summary>The output is similar to:</summary>

```console
NAME                                                          READY   STATUS    RESTARTS   AGE
pod/free5gc-operator-controller-controller-58df9975f4-sglj6   2/2     Running   0          164m

NAME                                                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/free5gc-operator-controller-controller   1/1     1            1           164m

NAME                                                                DESIRED   CURRENT   READY   AGE
replicaset.apps/free5gc-operator-controller-controller-58df9975f4   1         1         1       164m
```
</details>

### Step 7: Deploy AMF, SMF and UPF

Finally, you can deploy individual network functions which the operator will
instantiate. For now, you will use individual PackageVariants targeting the regional
cluster for each of the AMF and SMF, and a PackageVariantSet targeting the
edge clusters for the UPFs. In the future, you could put all of these
resources into yet-another-package - a "topology" package - and deploy them all as a
unit. Or you can use a topology controller to create them. But for now, let's do each
manually.

```bash
kubectl apply -f test-infra/e2e/tests/005-regional-free5gc-amf.yaml
kubectl apply -f test-infra/e2e/tests/005-regional-free5gc-smf.yaml
kubectl apply -f test-infra/e2e/tests/006-edge-free5gc-upf.yaml
```