
Create service account with rights to provision VMs, use key in JSON format. Create k8s secret from it:
```
kubectl create secret generic satoken --from-file=satoken=awesome-project-113111-18913905538b.json -n test-pods
```
Create ssh keypair:
```
ssh-keygen -t rsa -f ~/.ssh/gce_prow_lab -C ubuntu -b 2048
```
And make k8s secret out of it:
```
kubectl create secret generic ssh-key-e2e --from-file=id_rsa=/home/your_user/.ssh/gce_prow_lab --from-file=id_rsa.pub=/home/your_user/.ssh/gce_prow_lab.pub -n test-pods
```

Populate nephio.yaml with your settings, create dockerhub read-only token and place it in prow.yaml, then make secret out of it. It will be mounted and copied over to destination machine under one-summit-22-workshop/nephio-ansible-install/inventory/
```
kubectl create secret generic nephio-e2e-yaml --from-file=nephio.yaml=/Users/user/dev/nephio/repos_fork/nephio.yaml -n test-pods
```