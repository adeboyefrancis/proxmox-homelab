## Proxmox Resource Organization Standard

This system uses a **4-Resource-Pool Model** aligned with network boundaries, complemented by **Color-Coded Tags** for UI visualization and metadata.

---

### 1. Resource Pools & Network Mapping

| Resource Pool | Subnet Scope   | Role & Purpose                                                      | Lifecycle           |
| :------------ | :------------- | :------------------------------------------------------------------ | :------------------ |
| `Management`  | `10.10.0.0/24` | Core infrastructure services (Vault, Harbor Registry, Internal DNS) | Long-lived / Static |
| `Automation`  | `10.10.0.0/24` | CI/CD engines, Ansible Controllers, Packer build nodes              | Ephemeral / Dynamic |
| `Platform`    | `10.20.0.0/24` | Platform control planes (K3s Control Plane, ArgoCD, Observability)  | Long-lived / Static |
| `Workload`    | `10.20.0.0/24` | Application runtime nodes, Docker hosts, dev/test VMs               | Ephemeral / Dynamic |

---

### 2. Tagging & Color Standard

Tags must be configured in **Datacenter Options** -> **Tag Style Override** before assignment to maintain visual consistency.

| Tag             | Background Hex     | Recommended Shape | Usage                            |
| :-------------- | :----------------- | :---------------- | :------------------------------- |
| `management`    | `#6f42c1` (Purple) | Dense             | Core infrastructure (Vault, DNS) |
| `automation`    | `#e83e8c` (Pink)   | Dense             | Ansible, Packer, CI Runners      |
| `platform`      | `#007bff` (Blue)   | Dense             | K3s, ArgoCD, Ingress             |
| `workload`      | `#17a2b8` (Cyan)   | Dense             | Docker apps, runtime workers     |
| `observability` | `#28a745` (Green)  | Dense             | Prometheus, Grafana, Loki        |

---

### 3. Management via Proxmox CLI (`pvesh` & `qm`)

#### A. Initialize Resource Pools

```bash
# Tier 1 Pools (Management & Automation - 10.10.0.0/24)
pvesh create /pools --poolid Management --comment "Core Services (Vault, Registry, DNS)"
pvesh create /pools --poolid Automation --comment "CI/CD & Provisioning (Ansible, Packer, Runners)"

# Tier 2 Pools (Platform & Workloads - 10.20.0.0/24)
pvesh create /pools --poolid Platform   --comment "Platform Controllers (K3s, ArgoCD, Observability)"
pvesh create /pools --poolid Workload   --comment "Application Runtimes & Docker Hosts"
```

#### B. Assign Guest to Pool and Apply Tags

```bash
# Example: Automation VM (10.10.0.10)
qm set 100 --pool Automation --tags "automation;ansible;packer"

# Example: K3s Master Node (10.20.0.20)
qm set 102 --pool Platform --tags "platform;k3s;control-plane"
```

#### 4. Infrastructure as Code via Terraform (bpg/proxmox)

When provisioning via IaC, manage pools directly using the proxmox_virtual_environment_pool resource and map VMs using pool_id and tags.

```hcl
# --- Resource Pools Definition ---
resource "proxmox_virtual_environment_pool" "management" {
  pool_id = "Management"
  comment = "Core Services (Vault, Registry, DNS)"
}

resource "proxmox_virtual_environment_pool" "automation" {
  pool_id = "Automation"
  comment = "CI/CD & Provisioning (Ansible, Packer, Runners)"
}

resource "proxmox_virtual_environment_pool" "platform" {
  pool_id = "Platform"
  comment = "Platform Controllers (K3s, ArgoCD, Observability)"
}

resource "proxmox_virtual_environment_pool" "workload" {
  pool_id = "Workload"
  comment = "Application Runtimes & Docker Hosts"
}

# --- Example VM Provisioning inside Pool ---
resource "proxmox_virtual_environment_vm" "k3s_control_plane" {
  name      = "k3s-master-01"
  vmid      = 102
  node_name = "pve"

  # Resource Pool Association
  pool_id   = proxmox_virtual_environment_pool.platform.pool_id

  # Tags (Matches UI predefined colors)
  tags      = ["platform", "k3s", "control-plane"]

  network_device {
    bridge = "vmbr2" # 10.20.0.0/24 Workloads/Platform Bridge
  }
}
```
