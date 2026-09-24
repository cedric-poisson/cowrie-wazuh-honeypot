# Cowrie + Wazuh Honeypot

Déploiement automatisé d'un honeypot SSH (Cowrie) surveillé par un SIEM (Wazuh), sur Azure, entièrement en Infrastructure as Code.

## Contexte

Projet personnel réalisé en autoformation, dans une logique d'apprentissage pratique de l'infrastructure sécurisée et de l'analyse de menaces. L'objectif : déployer un piège volontairement exposé sur internet pour observer, en conditions réelles, comment les attaquants (bots et scripts automatisés) tentent de compromettre un serveur SSH, tout en centralisant et analysant cette activité via un SIEM.

## Architecture

```
Internet
   │
   ▼
┌─────────────────────────────────────────┐
│  Azure VNet (10.10.0.0/24)               │
│  Resource Group: rg-cowrie-honeypot      │
│                                           │
│  ┌──────────────┐      ┌──────────────┐ │
│  │  VM Cowrie    │      │  VM Wazuh    │ │
│  │  (honeypot)   │─────▶│  (manager)   │ │
│  │  port 2222    │      │  dashboard   │ │
│  │  (SSH exposé) │      │  port 443    │ │
│  └──────────────┘      └──────────────┘ │
│                                           │
│  NSG : 2222 (public), 22 (admin only),   │
│  443 (dashboard, admin only),            │
│  1514/1515 (agent-manager, subnet only)  │
└─────────────────────────────────────────┘
```

- **Cowrie** : honeypot SSH/Telnet d'émulation (medium-interaction). Simule un shell Debian sans exécuter réellement les commandes de l'attaquant, capture toute l'activité en JSON structuré (connexions, credentials tentés, commandes tapées, fichiers téléchargés).
- **Wazuh** : SIEM open source. Un agent installé sur la VM Cowrie lit les logs JSON et les transmet au manager, qui applique des règles de détection et génère des alertes visibles dans un dashboard.

## Stack technique

| Couche | Outil |
|---|---|
| Provisioning infra | OpenTofu (Azure provider) |
| Configuration | Ansible |
| Honeypot | Cowrie |
| SIEM | Wazuh 4.14 (manager + indexer + dashboard, agent) |
| Cloud | Microsoft Azure |

## Structure du repo

```
cowrie-wazuh-honeypot/
├── terraform/          # provisioning Azure (réseau, VM)
│   ├── main.tf          # resource group
│   ├── network.tf       # VNet, subnet, NSG, IP publiques, NIC
│   ├── vm.tf             # VM Cowrie et VM Wazuh
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
├── ansible/
│   ├── inventory/        # généré dynamiquement (non versionné)
│   ├── roles/
│   │   ├── cowrie/         # installation et config du honeypot
│   │   ├── wazuh_manager/  # installation manager + règles custom
│   │   └── wazuh_agent/    # agent sur la VM Cowrie
│   └── playbook.yml
├── scripts/
│   ├── update_inventory.sh  # génère l'inventaire Ansible depuis les outputs OpenTofu
│   └── enrich_ip.sh          # enrichissement IP via AbuseIPDB
└── docs/
    └── analysis-report.md    # analyse détaillée des attaques capturées
```

## Déploiement

### Prérequis

- Azure CLI connecté (`az login`)
- OpenTofu installé
- Ansible installé
- Une clé SSH RSA (Azure ne supporte pas ed25519 pour l'admin des VM)
- Un `terraform/terraform.tfvars` (non versionné) avec ton IP publique admin :
  ```hcl
  admin_ip_cidr = "x.x.x.x/32"
  ```
- Un mot de passe d'enrollment Wazuh chiffré avec `ansible-vault` :
  ```bash
  cp ansible/group_vars/all/vault.yml.example ansible/group_vars/all/vault.yml
  # éditer wazuh_registration_password avec un mot de passe fort
  ansible-vault encrypt ansible/group_vars/all/vault.yml
  echo "ton_mot_de_passe_vault" > vault_pass.txt   # déjà dans .gitignore
  ```

### Étapes

```bash
# 1. Provisionner l'infrastructure
cd terraform/
tofu init
tofu apply

# 2. Générer l'inventaire Ansible à partir des IP déployées
cd ..
./scripts/update_inventory.sh

# 3. Configurer les VM (Cowrie + Wazuh + agent)
cd ansible/
ansible-playbook -i inventory/hosts.yml playbook.yml --vault-password-file ../vault_pass.txt
```

### Accès

- **Honeypot** (pour test) : `ssh -p 2222 root@<cowrie_public_ip>` — n'importe quel mot de passe est accepté
- **Dashboard Wazuh** : `https://<wazuh_public_ip>` — identifiants générés à l'installation (voir `/tmp/wazuh-install-files.tar` sur la VM)
- **Admin réel des VM** : `ssh -i ~/.ssh/<clé> azadmin@<ip>` (restreint à l'IP de l'opérateur via NSG)

### Destruction (pour ne pas laisser tourner l'infra inutilement)

```bash
cd terraform/
tofu destroy
```

## Détection

Wazuh ne dispose pas nativement de règles pour interpréter les logs JSON de Cowrie. Des règles custom ont été écrites (`ansible/roles/wazuh_manager/tasks/main.yml`) pour détecter et classer les événements : tentatives de connexion (réussies/échouées), commandes exécutées par l'attaquant, téléchargements de fichiers.

## Résultats

Le honeypot a capturé, dès les premières heures d'exposition, plusieurs profils d'attaque distincts : des scans de credentials automatisés basiques, ainsi qu'une chaîne d'infection complète (dépôt de clé SSH, tentative de téléchargement de payload distant, nettoyage des traces), caractéristique d'un botnet auto-propagateur.

Analyse détaillée : voir [`docs/analysis-report.md`](docs/analysis-report.md).

## Auteur

Cédric Poisson — projet personnel