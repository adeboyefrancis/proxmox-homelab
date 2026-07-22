# Proxmox DevOps Home Lab

Welcome to the documentation and configuration repository for my devops/platform engineering Home Lab. This project tracks the build, deployment, and maintenance of a Proxmox VE hypervisor running on a mini PC.

---

## 🛠️ Hardware Specifications

- **Host Machine:** HP ProDesk 400 G6 Mini PC
- **CPU:** Intel Core 10th Generation
- **Memory:** 32 GB RAM
- **Storage:** 512 GB NVMe SSD
- **Primary Hypervisor:** Proxmox VE (PVE)

---

## Implementation Phases & Documentation

The steps for this project is broken down into structured phases. Follow the links below for the step-by-step guides located in the `/docs` directory:

[Proxmox Documentation Reference](https://pve.proxmox.com/pve-docs/)

### 📍 Phase 1: Bare Metal Installation

Getting the physical machine ready, configuring the host BIOS, and running the initial PVE setup using a temporary bootstrap network.

- 👉 **[Phase 1 Guide](./docs/01-Initial-Setup.md)**

### 📍 Phase 2: Post-Install & Home Network Transition

Moving the server from mobile tethering to the permanent home network, assigning static local IPs, upgrading PVE repositories, and configuring local storage pools.

- 👉 **[Phase 2 Guide](./docs/02-Post-Installation.md)**

### 📍 Phase 3: Baseline Network Setup

Network Segmentation step-by-step creation of isolated, scalable private NAT networks with automatic DHCP IP allocation on Proxmox VE.

- 👉 **[Phase 3 Guide](./docs/03-Base-Network.md)**
