# Configuration complète - ClamAV Docker Scanner

## 📋 Vue d'ensemble

Ce document détaille toutes les options de configuration disponibles pour le scanner ClamAV Docker.

## 🔧 Fichiers de configuration

### Hiérarchie de chargement

```
.env.example → .env → .env.local → Variables CLI
(template)   (base)  (surcharge)   (priorité max)
```

### Structure recommandée

```bash
# Créer votre configuration
cp .env.example .env
nano .env

# Surcharge locale optionnelle
touch .env.local
```

## ⚙️ Configuration par sections

### 🗂️ Répertoires de base

```bash
# CONFIGURATION GÉNÉRALE
SCAN_DIR=/data                           # Répertoire à scanner
QUARANTINE_DIR=/var/clamav/quarantine    # Fichiers infectés
LOG_DIR=/var/log/clamav                  # Logs et rapports  
SIGNATURES_DIR=/var/lib/clamav           # Signatures antivirus
```

**Recommandations :**
- Utiliser des chemins absolus
- S'assurer que l'utilisateur a les permissions d'écriture
- Prévoir suffisamment d'espace disque (signatures ~200MB, logs variables)

### 🤖 Configuration des agents

#### ConfigAgent - Validation et prérequis

```bash
CONFIG_AGENT_LOG_LEVEL=INFO              # DEBUG, INFO, WARN, ERROR
CONFIG_AGENT_VERBOSE=false               # Logs détaillés
```

#### SignatureAgent - Mise à jour des signatures

```bash
SIGNATURE_AGENT_UPDATE_FREQUENCY=daily   # daily, weekly, manual
SIGNATURE_AGENT_AUTO_UPDATE=true         # Mise à jour au démarrage
SIGNATURE_AGENT_MIRROR=db.local.clamav.net  # Serveur de signatures
```

**Fréquences recommandées :**
- `daily` : Serveurs de production
- `weekly` : Serveurs de développement  
- `manual` : Environnements déconnectés

#### DockerAgent - Gestion des containers

```bash
DOCKER_AGENT_CLEANUP_POLICY=auto         # auto, manual, aggressive
DOCKER_IMAGE=clamav/clamav:latest         # Image Docker
CONTAINER_NAME=clamav-scanner             # Nom du container
DOCKER_PULL_POLICY=missing               # always, missing, never
```

**Politiques de nettoyage :**
- `auto` : Nettoie les containers ClamAV orphelins
- `manual` : Aucun nettoyage automatique
- `aggressive` : Nettoie tous les containers orphelins

#### ScannerAgent - Configuration du scan

```bash
SCANNER_AGENT_DEFAULT_MODE=standard       # standard, full, quick
MAX_FILE_SIZE=100M                        # Taille max d'un fichier
MAX_SCAN_SIZE=500M                        # Taille max totale
SCAN_TIMEOUT=3600                         # Timeout en secondes
```

**Modes de scan détaillés :**

| Mode | Vitesse | Archives | PDF | Emails | Usage |
|------|---------|----------|-----|---------|-------|
| `quick` | ⚡ Très rapide | ❌ | ❌ | ❌ | Surveillance temps réel |
| `standard` | 🔄 Équilibré | ✅ | ❌ | ❌ | Scans quotidiens |
| `full` | 🐌 Lent | ✅ | ✅ | ✅ | Audits sécurité |

#### QuarantineAgent - Gestion des fichiers infectés

```bash
QUARANTINE_AGENT_ACTION=quarantine        # quarantine, remove, copy
QUARANTINE_AGENT_RETENTION_DAYS=7         # Rétention (0 = infini)
QUARANTINE_AGENT_AUTO_CLEANUP=true        # Nettoyage automatique
```

**Actions disponibles :**
- `quarantine` : Déplace vers quarantaine (récupérable)
- `remove` : Supprime définitivement (⚠️ irréversible)
- `copy` : Copie vers quarantaine (garde l'original)

#### ReportAgent - Génération des rapports

```bash
REPORT_AGENT_FORMAT=text                  # text, json, html
REPORT_AGENT_DETAILED=true                # Rapport détaillé
REPORT_AGENT_SAVE_HISTORY=true            # Historique
```

**Formats de rapports :**
- `text` : Lisible humain, idéal pour emails
- `json` : Intégration API, monitoring
- `html` : Présentation web, dashboards

#### NotificationAgent - Alertes et notifications

```bash
NOTIFICATION_AGENT_ENABLED=false          # Activer notifications
EMAIL_ENABLED=false                       # Notifications email
EMAIL_TO=admin@example.com                # Destinataire
EMAIL_FROM=clamav-scanner@localhost       # Expéditeur
EMAIL_SUBJECT_PREFIX=[ClamAV]             # Préfixe sujet
```

### 🔧 Limites et performance

```bash
# LIMITES ET PERFORMANCE
SCAN_MAX_THREADS=2                        # Threads parallèles
SCAN_MAX_RECURSION=16                     # Profondeur récursion
SCAN_MAX_FILES=10000                      # Nombre max de fichiers
```

**Optimisation selon le matériel :**

| CPU | RAM | SCAN_MAX_THREADS | MAX_SCAN_SIZE |
|-----|-----|------------------|---------------|
| 2 cores | 2GB | 1 | 250M |
| 4 cores | 4GB | 2 | 500M |
| 8+ cores | 8GB+ | 4 | 1G |

### 🚫 Exclusions

```bash
# EXCLUSIONS (patterns regex séparés par |)
EXCLUDE_DIRS=^/proc|^/sys|^/dev|^/tmp|\.git
EXCLUDE_FILES=\.tmp$|\.log$|\.cache$
EXCLUDE_EXTENSIONS=tmp|log|cache|swp|swo
```

**Exclusions recommandées :**

```bash
# Système Linux
EXCLUDE_DIRS="^/proc|^/sys|^/dev|^/run|^/tmp"

# Développement
EXCLUDE_DIRS="${EXCLUDE_DIRS}|\.git|node_modules|\.vscode"

# Logs et cache
EXCLUDE_FILES="\.log$|\.tmp$|\.cache$|\.pid$"
```

### 🔍 Scan avancé

```bash
# SCAN AVANCÉ (mode complet)
SCAN_ARCHIVES=true                        # Archives (zip, tar, etc.)
SCAN_MAIL=true                           # Formats email
SCAN_PDF=true                            # Documents PDF
SCAN_HTML=true                           # Contenu HTML
SCAN_OFFICE=true                         # Documents Office
SCAN_ENCRYPTED_ARCHIVES=false            # Alerter archives chiffrées
```

### 🔒 Sécurité

```bash
# SÉCURITÉ
ALLOW_ROOT=false                         # Interdire root
STRICT_PERMISSIONS=true                  # Vérifications strictes
SECURE_TEMP=true                         # Répertoires temp sécurisés
```

**Recommandations sécurité :**
- Toujours garder `ALLOW_ROOT=false` en production
- Utiliser un utilisateur dédié avec permissions minimales
- Séparer physiquement quarantaine et données

### 🐛 Développement et debug

```bash
# DÉVELOPPEMENT ET DEBUG
DEBUG_MODE=false                         # Mode debug
VERBOSE_DOCKER=false                     # Logs Docker détaillés
KEEP_CONTAINERS=false                    # Garder containers debug
SIMULATE_INFECTIONS=false                # Mode simulation
```

## 📧 Configuration email

### Prérequis

Installer `mailutils` ou `sendmail` :

```bash
# Ubuntu/Debian
sudo apt install mailutils

# CentOS/RHEL
sudo yum install mailx
```

### Configuration SMTP

#### Méthode 1 : Postfix local

```bash
sudo apt install postfix
sudo dpkg-reconfigure postfix
```

#### Méthode 2 : SMTP externe

Créer `/etc/mail.rc` :

```bash
set smtp=smtp://smtp.gmail.com:587
set smtp-use-starttls
set smtp-auth=login
set smtp-auth-user=your-email@gmail.com
set smtp-auth-password=your-app-password
set from=your-email@gmail.com
```

### Test de configuration

```bash
# Test simple
echo "Test ClamAV" | mail -s "Test" admin@example.com

# Test avec le script
EMAIL_ENABLED=true EMAIL_TO=admin@example.com ./clamav-scan.sh --update-only
```

## 🔄 Profils de configuration

### Profil Production

```bash
# .env.production
SCANNER_AGENT_DEFAULT_MODE=standard
QUARANTINE_AGENT_ACTION=quarantine
QUARANTINE_AGENT_RETENTION_DAYS=30
NOTIFICATION_AGENT_ENABLED=true
EMAIL_ENABLED=true
SIGNATURE_AGENT_UPDATE_FREQUENCY=daily
DEBUG_MODE=false
ALLOW_ROOT=false
```

### Profil Développement

```bash
# .env.development  
SCANNER_AGENT_DEFAULT_MODE=quick
QUARANTINE_AGENT_ACTION=quarantine
QUARANTINE_AGENT_RETENTION_DAYS=3
NOTIFICATION_AGENT_ENABLED=false
DEBUG_MODE=true
VERBOSE_DOCKER=true
SIGNATURE_AGENT_UPDATE_FREQUENCY=weekly
```

### Profil High Security

```bash
# .env.highsec
SCANNER_AGENT_DEFAULT_MODE=full
QUARANTINE_AGENT_ACTION=remove
SCAN_ENCRYPTED_ARCHIVES=true
STRICT_PERMISSIONS=true
SECURE_TEMP=true
NOTIFICATION_AGENT_ENABLED=true
EMAIL_ENABLED=true
```

## ✅ Validation de la configuration

### Script de validation

```bash
# Créer un script de test
cat > test-config.sh << 'EOF'
#!/bin/bash
source .env

# Tests de base
echo "🔍 Validation de la configuration..."

# Vérifier les répertoires
for dir in "$SCAN_DIR" "$QUARANTINE_DIR" "$LOG_DIR" "$SIGNATURES_DIR"; do
    if [[ ! -d "$dir" ]]; then
        echo "❌ Répertoire manquant: $dir"
    else
        echo "✅ Répertoire OK: $dir"
    fi
done

# Tester Docker
if docker info &> /dev/null; then
    echo "✅ Docker accessible"
else
    echo "❌ Docker inaccessible"
fi

# Tester email si activé
if [[ "$EMAIL_ENABLED" == "true" ]]; then
    if command -v mail &> /dev/null; then
        echo "✅ Commande mail disponible"
    else
        echo "❌ Commande mail manquante"
    fi
fi

echo "✅ Validation terminée"
EOF

chmod +x test-config.sh
./test-config.sh
```

## 🔄 Migration de configuration

### Depuis une version antérieure

```bash
# Sauvegarder l'ancienne config
cp .env .env.backup

# Merger avec le nouveau template
cp .env.example .env.new
# Éditer .env.new avec vos valeurs de .env.backup

# Valider et basculer
./test-config.sh
mv .env.new .env
```

Cette configuration complète permet d'adapter le scanner à tous types d'environnements, du développement à la production haute sécurité.