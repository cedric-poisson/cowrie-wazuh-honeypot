#!/bin/bash
set -euo pipefail

# Génère l'inventaire Ansible à partir des outputs OpenTofu
# Usage : ./scripts/update_inventory.sh (à lancer depuis la racine du repo)

TERRAFORM_DIR="terraform"
INVENTORY_FILE="ansible/inventory/hosts.yml"

if [ ! -d "$TERRAFORM_DIR" ]; then
    echo "Erreur : dossier $TERRAFORM_DIR introuvable. Lance ce script depuis la racine du repo."
    exit 1
fi

echo "Récupération des IP depuis le state OpenTofu..."
cd "$TERRAFORM_DIR"

COWRIE_IP=$(tofu output -raw cowrie_public_ip)
WAZUH_IP=$(tofu output -raw wazuh_public_ip)
WAZUH_PRIVATE_IP=$(tofu output -raw wazuh_private_ip)

cd - > /dev/null

if [ -z "$COWRIE_IP" ] || [ -z "$WAZUH_IP" ] || [ -z "$WAZUH_PRIVATE_IP" ]; then
    echo "Erreur : impossible de récupérer les IP. As-tu bien fait 'tofu apply' ?"
    exit 1
fi

echo "IP Cowrie       : $COWRIE_IP"
echo "IP Wazuh        : $WAZUH_IP"
echo "IP Wazuh privée : $WAZUH_PRIVATE_IP"

cat > "$INVENTORY_FILE" << EOF
all:
  children:
    honeypot:
      hosts:
        cowrie:
          ansible_host: "${COWRIE_IP}"
    siem:
      hosts:
        wazuh:
          ansible_host: "${WAZUH_IP}"
          wazuh_private_ip: "${WAZUH_PRIVATE_IP}"
  vars:
    ansible_user: azadmin
    ansible_ssh_private_key_file: ~/.ssh/homelab_vm_rsa
    ansible_ssh_common_args: "-o StrictHostKeyChecking=accept-new"
EOF

echo "Inventaire mis à jour : $INVENTORY_FILE"