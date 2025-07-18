<p align="center">
  <img src="assets/docs/readme/TuringPiCluster.png" width="200%" alt="<code>❯ REPLACE-ME</code>-logo">
</p>
<p align="center">
    <h3 align="center"><code>❯ Turing Pi 2 Home cluster
</code></h3>

<p align="center">
	<!-- local repository, no metadata badges. --></p>

<p align="center">
  <img src="https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/tomassirio/54521673e7feb0e657d92ec385be3851/raw/turing-pi-services.json" alt="Services">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/Kubernetes-326CE5?logo=kubernetes&logoColor=white" alt="Kubernetes">
  <img src="https://img.shields.io/badge/Helm-0F1689?logo=helm&logoColor=white" alt="Helm">
  <img src="https://img.shields.io/badge/Raspberry%20Pi-A22846?logo=raspberry-pi&logoColor=white" alt="Raspberry Pi">
</p>
<p align="center">
  <img src="https://img.shields.io/github/repo-size/tomassirio/turing-pi-server" alt="GitHub repo size">
  <img src="https://img.shields.io/github/last-commit/tomassirio/turing-pi-server" alt="GitHub last commit">
  <img src="https://img.shields.io/github/issues/tomassirio/turing-pi-server" alt="GitHub issues">
  <img src="https://img.shields.io/github/stars/tomassirio/turing-pi-server" alt="GitHub stars">
</p>

## Set-Up

This cluster depends on:

- MetalLB
- Nginx
- CoreDns

Also, the current Storage uses an NFS shared drive (will change soon). Thus, install the `PersistentVolumes` and `PersistentVolumeClaims` in /storage:

- storage/nfs-config-pv.yaml
- storage/nfs-config-pvc.yaml
- storage/nfs-pv.yaml
- storage/nfs-pvc.yaml