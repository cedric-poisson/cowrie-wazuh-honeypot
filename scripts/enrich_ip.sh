#!/bin/bash
set -euo pipefail

# Enrichit une IP avec les données AbuseIPDB (pays, ISP, score d'abus)
# Usage : ./scripts/enrich_ip.sh <IP>
# Nécessite une clé API AbuseIPDB dans la variable d'env ABUSEIPDB_API_KEY

if [ -z "${ABUSEIPDB_API_KEY:-}" ]; then
    echo "Erreur : variable ABUSEIPDB_API_KEY non définie."
    echo "Récupère une clé gratuite sur https://www.abuseipdb.com/account/api"
    echo "Puis : export ABUSEIPDB_API_KEY='ta_clé'"
    exit 1
fi

if [ -z "${1:-}" ]; then
    echo "Usage : $0 <IP>"
    exit 1
fi

IP="$1"

curl -s -G "https://api.abuseipdb.com/api/v2/check" \
    --data-urlencode "ipAddress=${IP}" \
    -d maxAgeInDays=90 \
    -H "Key: ${ABUSEIPDB_API_KEY}" \
    -H "Accept: application/json" | \
    jq -r '.data | "IP: \(.ipAddress)\nPays: \(.countryCode // "inconnu")\nISP: \(.isp // "inconnu")\nScore d'\''abus: \(.abuseConfidenceScore)%\nSignalements: \(.totalReports)\nDernier signalement: \(.lastReportedAt // "jamais")"'