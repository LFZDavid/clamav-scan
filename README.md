# ClamAV Docker Scanner

🛡️ **Script d'analyse antivirus avec ClamAV dans Docker** - Architecture modulaire basée sur des agents

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Required-blue.svg)](https://www.docker.com/)
[![ClamAV](https://img.shields.io/badge/ClamAV-Latest-green.svg)](https://www.clamav.net/)

## 📋 Vue d'ensemble

Ce projet fournit un script bash robuste pour effectuer des analyses antivirus avec ClamAV dans un environnement Docker. Il utilise une architecture modulaire basée sur des agents pour une maintenance facile et des extensions futures.

### ✨ Fonctionnalités principales

- 🐳 **Containerisé** - Utilise l'image Docker officielle ClamAV
- 🔧 **Modulaire** - Architecture basée sur 7 agents spécialisés
- ⚙️ **Configurable** - Gestion flexible via fichiers `.env`
- 🦠 **Actions sur infectés** - Quarantaine, suppression ou copie
- 📊 **Rapports détaillés** - Formats text, JSON, HTML
- 📧 **Notifications** - Email avec extensions futures (Slack, Discord)
- 🔄 **Mise à jour auto** - Signatures antivirus automatiques
- 🧹 **Nettoyage intelligent** - Gestion de la rétention et cleanup

### 🏗️ Architecture des agents

```
ConfigAgent → SignatureAgent → DockerAgent → ScannerAgent
                                                   ↓
NotificationAgent ← ReportAgent ← QuarantineAgent
```

## 🚀 Installation rapide

### Prérequis

- **Docker** installé et fonctionnel
- **Bash** 4.0+ 
- **Permissions** pour exécuter Docker
- **Espace disque** pour signatures (~200MB) et quarantaine

### Installation

```bash
# Cloner le projet
git clone https://github.com/votre-user/clamav-scan.git
cd clamav-scan

# Copier et adapter la configuration
cp .env.example .env
nano .env  # Adapter selon vos besoins

# Premier scan de test
./clamav-scan.sh --help
```

## ⚙️ Configuration

### Configuration de base

Editez le fichier `.env` avec vos paramètres :

```bash
# Répertoires principaux
SCAN_DIR=/data                          # Répertoire à scanner
QUARANTINE_DIR=/var/clamav/quarantine   # Quarantaine
LOG_DIR=/var/log/clamav                 # Logs

# Action sur fichiers infectés
QUARANTINE_AGENT_ACTION=quarantine      # quarantine, remove, copy

# Notifications
EMAIL_ENABLED=true                      # Activer email
EMAIL_TO=admin@example.com              # Destinataire
```

📝 **Voir [CONFIGURATION.md](docs/CONFIGURATION.md) pour la configuration complète**

## 🎯 Utilisation

### Commandes de base

```bash
# Scan standard du répertoire par défaut
./clamav-scan.sh

# Scan d'un répertoire spécifique
./clamav-scan.sh -d /var/www

# Scan complet (archives, PDF, emails)
./clamav-scan.sh -d /home -f

# Scan rapide (fichiers basiques uniquement)
./clamav-scan.sh -d /tmp -q

# Suppression directe des infectés (⚠️ irréversible)
./clamav-scan.sh -d /uploads -r

# Mode silencieux pour les crons
./clamav-scan.sh -d /data -s

# Mise à jour des signatures uniquement
./clamav-scan.sh --update-only
```

### Modes de scan

| Mode | Description | Usage recommandé |
|------|-------------|------------------|
| `standard` | Équilibré vitesse/profondeur | Scans quotidiens |
| `full` | Complet (archives, PDF, emails) | Scans hebdomadaires |
| `quick` | Rapide, fichiers basiques | Scans fréquents |

### Actions sur fichiers infectés

| Action | Description | Récupération |
|--------|-------------|--------------|
| `quarantine` | Déplace vers quarantaine | ✅ Possible |
| `remove` | Supprime définitivement | ❌ Impossible |
| `copy` | Copie vers quarantaine | ✅ Original intact |

## 📊 Exemples d'utilisation

### Scan quotidien automatisé

```bash
# Crontab pour scan quotidien à 3h du matin
0 3 * * * /opt/clamav-scan/clamav-scan.sh -d /var/www -s >> /var/log/clamav/cron.log 2>&1
```

### Scan complet hebdomadaire

```bash
# Dimanche à 2h, scan complet avec notification
0 2 * * 0 /opt/clamav-scan/clamav-scan.sh -d /home -f
```

### Surveillance répertoire uploads

```bash
# Scan rapide et suppression immédiate
./clamav-scan.sh -d /var/www/uploads -q -r -s
```

## 📈 Monitoring et logs

### Structure des logs

```
/var/log/clamav/
├── scan_2024-12-14_15-30-00.log    # Log détaillé du scan
├── report_2024-12-14_15-30-00.txt  # Rapport final
└── report_2024-12-14_15-30-00.json # Rapport JSON (si activé)
```

### Codes de retour

| Code | Signification | Action |
|------|---------------|---------|
| `0` | ✅ Aucun virus | Continuer |
| `1` | 🦠 Virus trouvé | Vérifier quarantaine |
| `2+` | ❌ Erreur | Consulter les logs |

## 🔧 Administration

### Gestion de la quarantaine

```bash
# Lister les fichiers en quarantaine
ls -la /var/clamav/quarantine/

# Restaurer un fichier (après vérification)
mv /var/clamav/quarantine/fichier.txt /path/original/

# Vider la quarantaine
rm -rf /var/clamav/quarantaine/*
```

### Maintenance

```bash
# Vérifier l'état des signatures
ls -la /var/lib/clamav/

# Forcer la mise à jour des signatures
./clamav-scan.sh --update-only

# Nettoyer les anciens logs (>30 jours)
find /var/log/clamav/ -name "*.log" -mtime +30 -delete
```

## 🛠️ Développement

### Structure du projet

```
clamav-scan/
├── .env.example              # Template de configuration
├── .env                      # Configuration locale (non versionné)
├── clamav-scan.sh           # Script principal
├── AGENTS.md                # Architecture détaillée
├── README.md                # Ce fichier
├── docs/                    # Documentation avancée
│   ├── CONFIGURATION.md     # Configuration complète
│   ├── TROUBLESHOOTING.md   # Résolution de problèmes
│   └── CONTRIBUTING.md      # Guide de contribution
└── dev/                     # Développement
    ├── conversation.md      # Notes de conception
    └── tests/               # Scripts de test
```

### Extensions futures

- 🚀 **API REST** pour déclenchement distant
- 📊 **Dashboard web** avec métriques temps réel
- 🔔 **Intégrations** Slack, Discord, webhooks
- 🗄️ **Base de données** pour historique et analytics
- 📱 **Notifications push** mobiles

## 🆘 Support

### Problèmes courants

**Docker non accessible**
```bash
sudo systemctl start docker
sudo usermod -aG docker $USER
```

**Permissions refusées**
```bash
sudo chown -R $USER:$USER /var/clamav
chmod -R 750 /var/clamav
```

**Signatures obsolètes**
```bash
./clamav-scan.sh --update-only
```

📚 **Voir [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) pour plus de solutions**

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🤝 Contribution

Les contributions sont les bienvenues ! Voir [CONTRIBUTING.md](docs/CONTRIBUTING.md) pour les guidelines.

---

**Développé avec ❤️ pour la sécurité des serveurs**