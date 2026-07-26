### System Administration — IAM (Users, Groups, Permissions)

Two separate systems are covered here:

- **Layer 1 — Proxmox host IAM**: who can log into the Proxmox web UI / API, and what they're allowed to do
- **Layer 2 — OS-level IAM**: Linux users inside each VM/LXC, handled by Ansible (Phase 3) — referenced, not repeated, at the end of this doc

---

## 0. Node / Hostname Configuration

```bash
# Change the hostname for Proxmox VE
# Proceed with caution — not advisable on a clustered setup
ssh root@192.168.x.x
nano /etc/hosts
nano /etc/hostname
reboot
```

---

## 1. Understanding Realms: PVE vs PAM

Proxmox authenticates users against a **realm**. The two that matter here behave very differently:

| Realm   | What it is               | SSH access? | Where the account lives                        |
| ------- | ------------------------ | ----------- | ---------------------------------------------- |
| **pve** | Proxmox-only account     | No          | Proxmox's internal user database only          |
| **pam** | Linux PAM authentication | Yes         | An actual Linux system account (`/etc/passwd`) |

A `pam`-realm user, by contrast, **is** a real Linux account. If you want someone to both log into the Proxmox UI _and_ SSH into the host itself, you need a matching Linux user — and the two must share the exact same username, since Proxmox just points at the existing system account rather than storing its own copy of the password.

**Recommended order:** create the Linux user first via CLI, _then_ add the matching entry in the Proxmox GUI under Realm → `Linux PAM standard authentication`. Doing it in the reverse order (as commonly seen in quick guides) also works, but creating the real account first avoids a dangling GUI entry with no matching login if you get interrupted partway through.

---

## 2. Layer 1 — Proxmox Host IAM via CLI or Shell as Root

Goal: stop using `root@pam` for day-to-day work, and give Terraform/Packer their own scoped credentials.

- [ ] **Create a dedicated admin user**
      `pveum user add username@pve -comment "Daily User Account"` — _or_ follow the PAM steps in section 3 below if you also want SSH access on this account

- [ ] **Create an admin group**
      `pveum group add coreadmin -comment "System Administrators"`

- [ ] **Add yourself to the group**
      `pveum user modify username@pve -group coreadmin`

- [ ] **Assign the Administrator role to the group, not the individual user**
      `pveum acl modify / -group coreadmin -role Administrator`
      _(Assigning roles to groups instead of users scales better as you add more accounts later.)_

- [ ] **Enable 2FA (TOTP) on your admin user**
      Datacenter → Permissions → Users → select user → TFA → Add a TOTP app

- [ ] **Create a separate, scoped API token for Terraform/Packer**
      Datacenter → Permissions → API Tokens → Add
      User: `yourname` — give it only the roles it actually needs (e.g. `PVEVMAdmin`), not full `Administrator`
      _(This token will live on your Workstation(MAC) — scoping it limits the blast radius of any mistake in your `.tf` files.)_

- [ ] **Stop using `root@pam` for routine logins**
      Keep root for emergency/shell-level access only — use your new admin account for daily work

---

## 3. Creating a Matching PAM User (CLI + SSH Access)

Use this when you want an account that can both log into the Proxmox UI **and** SSH into the host directly.

```bash
# 1. Create the actual Linux user
adduser <user>

# 2. Give it sudo rights
apt update && apt install sudo -y
usermod -aG sudo <user>

# 3. Test SSH access as the new user
ssh <user>@192.168.1.150

# 4. Confirm it can reach Proxmox's own tooling
sudo pvesm status
# (alternatively, sudo -i to drop into a root shell if needed)
```

After this, go add the matching entry in the Proxmox GUI (Datacenter → Permissions → Users → Add, Realm: `Linux PAM standard authentication`, same username) and assign it to the `admins` group from section 2 if it should have admin rights in the UI too.
