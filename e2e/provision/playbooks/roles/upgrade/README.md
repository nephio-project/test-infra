# Upgrade

This role upgrades Nephio services on a target cluster.

## Requirements

* [Docker Container Engine](https://docs.docker.com/engine/install/). Recommended Ansible role: `andrewrothstein.docker_engine`
* [KinD CLI](https://kind.sigs.k8s.io/docs/user/quick-start/#installation). Recommended Ansible role: `andrewrothstein.kind`
* [kpt CLI](https://kpt.dev/installation/kpt-cli). Recommended Ansible role: `andrewrothstein.kpt`

## Role Variables

Available variables are listed below, along with default values (see defaults/main.yml):

| Variable                   | Required | Default       | Choices | Comments                                                               |
|----------------------------|----------|---------------|---------|------------------------------------------------------------------------|
| k8s.context                | no       | kind-kind     |         | Kubernetes context to create resources                                 |
| nephio_pkg_version         | no       | v1.0.1        |         | Default version for all kpt packages                                   |
| nephio.k8s.namespaces      | no       |               |         | List of Kubernetes namespaces to watch for Nephio deployment resources |
| nephio.kpt.packages        | no       |               |         | List of Nephio kpt packages to be upgraded                             |

## Dependencies

None

## Example Playbook

```yaml
- hosts: all
  pre_tasks:
    - name: Update Apt cache
      ansible.builtin.raw: apt-get update --allow-releaseinfo-change
      become: true
      changed_when: false
    - name: Install pip package
      become: true
      ansible.builtin.package:
        name: python3-pip
        state: present
      when: ansible_distribution == 'Ubuntu'
    - name: Install kubernetes python package
      become: true
      ansible.builtin.pip:
        name: kubernetes==26.1.0
    - name: Unarchive /tmp/kpt.tgz into /usr/local/bin/
      become: true
      become_user: root
      ansible.builtin.unarchive:
        remote_src: true
        src: https://github.com/GoogleContainerTools/kpt/releases/download/v1.0.0-beta.49/kpt_linux_amd64-1.0.0-beta.49.tar.gz
        dest: /usr/local/bin/
        creates: /usr/local/bin/kpt
    - name: Install Docker Engine
      become: true
      ansible.builtin.include_role:
        name: andrewrothstein.docker_engine
    - name: Install KinD command-line
      ansible.builtin.include_role:
        name: andrewrothstein.kind
    - name: Get k8s clusters
      become: true
      ansible.builtin.command: kind get clusters
      register: kind_get_cluster
      failed_when: (kind_get_cluster.rc not in [0, 1])
    - name: Create k8s cluster
      become: true
      ansible.builtin.command: kind create cluster --image kindest/node:v1.27.1
      when: not 'kind' in kind_get_cluster.stdout
  roles:
    - role: install
      nephio_pkg_version: v1.0.0
    - role: upgrade
      nephio_pkg_version: v1.0.1
```

## Workflow

```mermaid
flowchart TD
    A[main.yml] --> |Upgrade Nephio packages| B(Define working directory)
    B --> C(Create base directory if it does not exist)
    C --> D(Init job ids array)
    D --> E(Update package)
    E --> F(Export job ids array)
    F --> G(Wait for packages to be updated)
    G --> |Wait for deployments| H(Get deployment resources)
    H --> I(Wait for deployments)
```
