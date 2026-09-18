# Rapport d'analyse — Honeypot Cowrie / Wazuh

## 1. Contexte et méthodologie

Ce rapport présente l'analyse du trafic capturé par un honeypot SSH (Cowrie) déployé sur Azure et exposé publiquement pendant environ 3 jours, surveillé par un SIEM Wazuh via des règles de détection custom écrites spécifiquement pour ce projet (voir [README.md](../README.md) pour le détail de l'architecture).

**Sources de données utilisées :**
- Logs bruts Cowrie (`cowrie.json`), format JSON structuré par événement
- Alertes Wazuh générées à partir des règles custom déployées
- Enrichissement des adresses IP source via l'API AbuseIPDB (réputation, ISP, pays)
- Vérifications manuelles complémentaires (WHOIS, recherche des organisations propriétaires) pour corriger les limites du scoring automatique

**Périmètre :** 94 adresses IP distinctes ont interagi avec le honeypot sur la période, hors trafic de test (connexions personnelles et de collègues, exclues de l'analyse).

## 2. Vue d'ensemble statistique

| Indicateur | Valeur |
|---|---|
| IP sources distinctes | 94 |
| Sessions totales | > 150 |
| IP la plus active | `130.12.180.51` (9 sessions complètes, 18 téléchargements de fichiers) |
| Part du trafic issue d'acteurs de threat intelligence légitimes | ~24 % |
| Part du trafic issue d'infrastructure cloud commerciale | ~52 % |
| Part du trafic issue de connexions résidentielles (FAI grand public) | ~22 % |

## 3. Typologie comportementale des sources

Plutôt que de classer les IP uniquement par origine (pays, hébergeur), l'analyse s'est appuyée sur **ce que chaque source a réellement tenté de faire** sur le honeypot, en s'appuyant sur la séquence d'événements Cowrie déclenchés par session. Sept comportements distincts se dégagent :

| Comportement | IP concernées (approx.) | Description |
|---|---|---|
| Scan de port pur | 17 | Vérifie uniquement que le port 2222 répond (connexion + fermeture immédiate), aucune négociation SSH engagée |
| Reconnaissance SSH passive | 36 | Négociation SSH complète (version, algorithmes) sans tentative d'authentification |
| Négociation anormale | 4 | Paquets SSH malformés (`client.malformed_packet`), probablement des scanners bas niveau ou des outils mal configurés |
| Authentification réussie sans action | 9 | Connexion réussie, aucune commande ni action observée ensuite |
| Authentification + test de tunneling SSH | 10 | Connexion réussie suivie d'une tentative de `direct-tcpip` vers une cible externe fixe |
| Authentification + reconnaissance système | 9 | Connexion réussie suivie d'une ou plusieurs commandes de reconnaissance (`uname`, etc.) |
| Authentification + chaîne d'infection complète | 1 | Reconnaissance, dépôt de clé SSH, tentative de récupération de payload distant, nettoyage des traces |

## 4. Études de cas détaillées

### 4.1 L'acteur le plus actif : `130.12.180.51`

Cette IP, hébergée chez **Virtualine Technologies** (Allemagne, infrastructure de data center/hosting), s'est connectée à 9 reprises sur la période de collecte, à intervalles de quelques heures. Chaque session suit exactement la même séquence scriptée :

1. Authentification (credentials variables selon les tentatives)
2. Reconnaissance système (`uname -a`)
3. Envoi d'une commande de vérification ("beacon") encodée en hexadécimal, décodant en `auth_ok`, probablement destinée à confirmer côté attaquant que la commande s'exécute dans un vrai shell avant de poursuivre
4. Dépôt d'une clé privée SSH lui appartenant dans `/tmp/key.ppk`
5. Tentative de récupération d'un fichier `sh` depuis un serveur distant (`217.60.103.56`) via SCP authentifié par cette clé, avec un repli en HTTP/HTTPS (`wget`/`curl`) en cas d'échec
6. Suppression des fichiers temporaires utilisés

Le fichier de clé SSH déposé est **strictement identique** (même hash SHA-256) sur les 9 sessions, confirmant qu'il s'agit d'un script figé et automatisé, pas d'une intervention manuelle. AbuseIPDB confirme cette IP avec un score d'abus de 100 % et plus de 3250 signalements par 138 utilisateurs distincts.

L'usage d'une authentification par clé plutôt qu'un simple téléchargement HTTP public est notable : il rend le payload plus difficile à récupérer et analyser par des tiers (chercheurs, honeypots), contrairement à un fichier hébergé en clair.

### 4.2 Le groupe de tunneling SSH coordonné

Dix adresses IP, réparties dans des pays et sur des infrastructures très différentes (Russie, Pakistan, Vénézuela, Chili, Suède, Australie, etc.), présentent un comportement identique : authentification réussie suivie d'une demande de tunnel SSH (`direct-tcpip`) vers **la même cible exacte**, `8.8.8.8:443`.

L'analyse du contenu du tunnel (avant son rejet par Cowrie) révèle le tout début d'un handshake TLS légitime (SNI `dns.google`), ce qui exclut une simple erreur de configuration : il s'agit d'un test de connectivité sortante, probablement pour valider qu'un serveur compromis peut être utilisé comme **relais/proxy réseau**, une pratique courante sur les marchés de revente d'accès à des serveurs compromis (proxy résidentiel ou serveur, utilisé pour masquer l'origine d'autres activités malveillantes).

Un fingerprint HASSH identique (`46a2ae5b447a73d9fbe6516e4b25976e`) a été observé sur trois de ces dix IP (`178.70.54.245`, `39.59.19.218`, `178.141.253.67`), confirmant que ces machines, bien que géographiquement dispersées, utilisent le même client SSH, très probablement le même outil ou framework de scan déployé sur plusieurs machines compromises ou VPS loués.

### 4.3 Les acteurs de threat intelligence légitimes

Une part significative du trafic capturé (~24 % des IP distinctes) provient d'organisations de cybersécurité menant des campagnes de scan à but défensif, et non d'attaquants :

- **Palo Alto Networks** (7 IP, probablement Cortex Xpanse) : négociation SSH ou scan de port pur, jamais d'authentification
- **Infrawatch Limited** (6 IP, société britannique de threat intelligence fondée en 2026) : comportement similaire
- **Modat B.V.** (5 IP, société néerlandaise de cartographie de l'internet) : comportement similaire
- **Google LLC** (5 IP) : négociation SSH ou scan de port, cohérent avec une activité de cartographie d'infrastructure

Point méthodologique important : le score de réputation AbuseIPDB s'est révélé **peu fiable pour distinguer ces acteurs légitimes des attaquants réels**. Les IP de Palo Alto Networks et Google affichent un score de 0 % malgré plusieurs milliers de signalements bruts, signe qu'AbuseIPDB les reconnaît et neutralise leur score. En revanche, Infrawatch et Modat, sociétés plus récentes, conservent un score de 100 %, identique à celui d'infrastructures clairement malveillantes comme `130.12.180.51`. Seule une vérification manuelle (recherche WHOIS, consultation du site de l'organisation) a permis de lever cette ambiguïté. Ce constat illustre une limite concrète des systèmes de réputation automatisés : ils reflètent la notoriété d'un acteur autant que son comportement réel.

### 4.4 Infrastructure résidentielle potentiellement compromise

Plusieurs IP (`73.9.142.149` chez Comcast, `84.26.0.88` chez Ziggo) correspondent à des blocs d'adressage grand public (FAI résidentiel), et non à des hébergeurs professionnels. Ces machines sont très probablement des équipements personnels ou domestiques compromis et intégrés à un botnet à l'insu de leurs propriétaires, plutôt que des postes d'attaquants agissant consciemment. Cette distinction entre infrastructure louée sciemment par l'attaquant et infrastructure victime recrutée à son insu est utile pour ne pas assimiler systématiquement "IP source" et "attaquant".

## 5. Cartographie MITRE ATT&CK

| Tactique | Technique | Observation |
|---|---|---|
| Reconnaissance | T1595 – Active Scanning | Scans de port et négociation SSH passive (majorité des IP) |
| Initial Access | T1110 – Brute Force | Tentatives d'authentification avec credentials variés |
| Execution | T1059 – Command and Scripting Interpreter | Commandes shell exécutées post-authentification |
| Command and Control | T1090 – Proxy | Tentatives de tunneling SSH vers `8.8.8.8:443` (groupe de 10 IP) |
| Defense Evasion | T1070 – Indicator Removal | Suppression des fichiers temporaires en fin de session (`130.12.180.51`) |
| Persistence (tentée) | T1098 – Account Manipulation (via clé SSH) | Dépôt d'une clé privée SSH destinée à un usage par l'attaquant, pas à des fins de persistance côté victime |

## 6. Limites de l'étude

- Les événements survenus avant le déploiement des règles de détection custom (les premières heures d'exposition) ne sont pas remontés dans Wazuh, seule la donnée brute Cowrie en garde la trace.
- Cowrie n'exécute jamais réellement les commandes tapées par les attaquants : les tentatives de téléchargement de payload via `wget`/`curl`/`scp` n'ont pas abouti à la récupération d'un échantillon réel de malware, seule la commande tapée a été capturée.
- L'échantillon de 3 jours reste limité en durée ; une période d'observation plus longue affinerait la représentativité des catégories identifiées.

## 7. Conclusions

Ce projet a permis de confirmer plusieurs constats généraux sur l'exposition d'un service SSH sur internet, tout en apportant des observations plus spécifiques :

- La majorité du trafic reçu par un honeypot fraîchement exposé est constituée de **reconnaissance automatisée passive**, pas d'attaques actives.
- Une part non négligeable de ce trafic provient d'**acteurs de sécurité légitimes**, ce qui impose de systématiquement vérifier l'origine d'une IP avant de la qualifier de malveillante, plutôt que de se fier à un unique score de réputation automatisé.
- Un même outil d'attaque peut être **identifié et corrélé à travers plusieurs IP géographiquement dispersées** grâce au fingerprinting du client SSH (HASSH) et à la comparaison des cibles/comportements observés, une approche particulièrement utile quand l'origine IP seule est peu fiable (infrastructure jetable, VPS).
- L'intégration d'une source de log non supportée nativement par un SIEM (Cowrie sur Wazuh) nécessite une véritable démarche d'ingénierie de détection : compréhension de l'architecture décodage/règles, écriture et validation de règles custom, ajustement des niveaux de sévérité au contexte métier plutôt que reprise de valeurs par défaut génériques.

## Annexe — Méthodologie technique

Le détail de l'architecture (infrastructure OpenTofu, configuration Ansible, règles de détection Wazuh) est disponible dans le [README](../README.md) du projet. Les règles custom Wazuh utilisées pour la détection sont versionnées dans `ansible/roles/wazuh_manager/tasks/main.yml`. Le script d'enrichissement IP (`scripts/enrich_ip.sh`) automatise l'interrogation de l'API AbuseIPDB pour toute adresse IP capturée.