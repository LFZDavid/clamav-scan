# Résolution de problèmes - ClamAV Docker Scanner

## 🚨 Problèmes courants et solutions

### 🐳 Problèmes Docker

#### Docker daemon inaccessible

**Symptômes :**
```
[ERROR] Docker daemon n'est pas accessible
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Solutions :**
```bash
# Démarrer le service Docker
sudo systemctl start docker
sudo systemctl enable docker

# Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER
newgrp docker  # Ou se reconnecter

# Vérifier les permissions
ls -la /var/run/docker.sock
sudo chmod 666 /var/run/docker.sock  # Temporaire
```

#### Image Docker introuvable

**Symptômes :**
```
Unable to find image 'clamav/clamav:latest' locally
Error response from daemon: pull access denied
```

**Solutions :**
```bash
# Forcer le téléchargement
docker pull clamav/clamav:latest

# Vérifier la connectivité
ping registry-1.docker.io

# Utiliser un autre tag si nécessaire
DOCKER_IMAGE=clamav/clamav:stable ./clamav-scan.sh
```

#### Container déjà en cours d'exécution

**Symptômes :**
```
docker: Error response from daemon: Conflict. The container name "/clamav-scanner" is already in use
```

**Solutions :**
```bash
# Arrêter et supprimer le container
docker stop clamav-scanner
docker rm clamav-scanner

# Ou utiliser un nom différent
CONTAINER_NAME=clamav-scanner-$(date +%s) ./clamav-scan.sh
```

### 📁 Problèmes de permissions

#### Permissions refusées sur les répertoires

**Symptômes :**
```
[ERROR] mkdir: cannot create directory '/var/clamav/quarantine': Permission denied
```

**Solutions :**
```bash
# Créer les répertoires avec les bonnes permissions
sudo mkdir -p /var/clamav/quarantine /var/log/clamav /var/lib/clamav
sudo chown -R $USER:$USER /var/clamav /var/log/clamav /var/lib/clamav
chmod -R 750 /var/clamav /var/log/clamav /var/lib/clamav

# Ou utiliser des répertoires dans votre home
QUARANTINE_DIR="$HOME/clamav/quarantine"
LOG_DIR="$HOME/clamav/logs"
SIGNATURES_DIR="$HOME/clamav/signatures"
```

#### Erreur "Operation not permitted"

**Symptômes :**
```
mv: cannot move 'infected.file' to '/var/clamav/quarantine/': Operation not permitted
```

**Solutions :**
```bash
# Vérifier les attributs étendus
lsattr /path/to/file

# Supprimer l'attribut immutable si présent
sudo chattr -i /path/to/file

# Vérifier SELinux (si activé)
getenforce
sudo setsebool -P container_manage_cgroup true
```

### 🦠 Problèmes de signatures

#### Mise à jour des signatures échoue

**Symptômes :**
```
[WARNING] Problème lors de la mise à jour des signatures (code: 1)
ERROR: Can't download daily.cvd from database.clamav.net
```

**Solutions :**
```bash
# Vérifier la connectivité
ping database.clamav.net

# Utiliser un miroir différent
SIGNATURE_AGENT_MIRROR=db.fr.clamav.net ./clamav-scan.sh

# Mise à jour manuelle
docker run --rm -v "$PWD/signatures:/var/lib/clamav" clamav/clamav:latest freshclam

# Proxy si nécessaire
docker run --rm \
  -e HTTP_PROXY=http://proxy:8080 \
  -v "$PWD/signatures:/var/lib/clamav" \
  clamav/clamav:latest freshclam
```

#### Signatures corrompues

**Symptômes :**
```
LibClamAV Error: cli_loaddbdir(): No supported database files found
```

**Solutions :**
```bash
# Supprimer et retélécharger les signatures
rm -rf /var/lib/clamav/*
./clamav-scan.sh --update-only

# Vérifier l'intégrité
sigtool --info /var/lib/clamav/main.cvd
```

### 📧 Problèmes de notifications

#### Email non envoyé

**Symptômes :**
```
[WARNING] Commande 'mail' non disponible
```

**Solutions :**
```bash
# Installer mailutils
sudo apt install mailutils  # Ubuntu/Debian
sudo yum install mailx       # CentOS/RHEL

# Configuration postfix
sudo dpkg-reconfigure postfix

# Test manuel
echo "Test" | mail -s "Subject" admin@example.com
```

#### SMTP authentication failed

**Symptômes :**
```
send-mail: SMTP AUTH authentication failed
```

**Solutions :**
```bash
# Configurer SMTP dans /etc/mail.rc
set smtp=smtp://smtp.gmail.com:587
set smtp-use-starttls
set smtp-auth=login
set smtp-auth-user=your-email@gmail.com
set smtp-auth-password=your-app-password

# Redémarrer le service
sudo systemctl restart postfix
```

### 🔍 Problèmes de scan

#### Scan très lent

**Symptômes :**
- Scan qui dure des heures
- CPU à 100% en continu

**Solutions :**
```bash
# Réduire la charge
MAX_FILE_SIZE=50M
MAX_SCAN_SIZE=250M
SCAN_MAX_THREADS=1

# Ajouter des exclusions
EXCLUDE_DIRS="^/proc|^/sys|^/dev|^/tmp|large-backup-dir"

# Utiliser le mode rapide
./clamav-scan.sh -q
```

#### Timeout du scan

**Symptômes :**
```
timeout: the monitored command dumped core
```

**Solutions :**
```bash
# Augmenter le timeout
SCAN_TIMEOUT=7200  # 2 heures

# Ou diviser le scan
./clamav-scan.sh -d /var/www/uploads
./clamav-scan.sh -d /var/www/files
```

#### Faux positifs

**Symptômes :**
- Fichiers légitimes mis en quarantaine

**Solutions :**
```bash
# Vérifier sur VirusTotal
curl -X POST 'https://www.virustotal.com/vtapi/v2/file/scan' \
  -F 'apikey=YOUR_API_KEY' \
  -F 'file=@suspect_file'

# Exclure des extensions spécifiques
EXCLUDE_EXTENSIONS="tmp|log|cache|jpg|png|pdf"

# Restaurer depuis la quarantaine
mv /var/clamav/quarantine/fichier.txt /path/original/
```

### 💾 Problèmes d'espace disque

#### Espace disque insuffisant

**Symptômes :**
```
No space left on device
```

**Solutions :**
```bash
# Vérifier l'espace
df -h /var

# Nettoyer les anciens logs
find /var/log/clamav -name "*.log" -mtime +7 -delete

# Nettoyer la quarantaine
rm -rf /var/clamav/quarantine/*

# Configurer le nettoyage automatique
QUARANTINE_AGENT_RETENTION_DAYS=3
QUARANTINE_AGENT_AUTO_CLEANUP=true
```

#### Logs qui grossissent

**Solutions :**
```bash
# Rotation des logs avec logrotate
cat > /etc/logrotate.d/clamav-scan << 'EOF'
/var/log/clamav/*.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 644 user group
}
EOF
```

## 🔧 Outils de diagnostic

### Script de diagnostic automatique

```bash
cat > diagnose.sh << 'EOF'
#!/bin/bash
echo "🔍 Diagnostic ClamAV Scanner"
echo "============================"

# Version Docker
echo -n "Docker: "
docker --version 2>/dev/null || echo "❌ Non disponible"

# Connectivité
echo -n "Réseau ClamAV: "
ping -c 1 database.clamav.net &>/dev/null && echo "✅ OK" || echo "❌ Échec"

# Espace disque
echo "Espace disque:"
df -h /var 2>/dev/null || df -h .

# Permissions
echo "Permissions:"
ls -la /var/clamav/ 2>/dev/null || echo "⚠️ Répertoire inexistant"

# Processus Docker
echo "Processus Docker:"
docker ps | grep clam || echo "Aucun container ClamAV"

# Dernières signatures
echo "Dernières signatures:"
ls -la /var/lib/clamav/*.cvd 2>/dev/null || echo "⚠️ Signatures non trouvées"

echo "============================"
echo "✅ Diagnostic terminé"
EOF

chmod +x diagnose.sh
./diagnose.sh
```

### Logs de debug avancés

```bash
# Activer tous les logs de debug
DEBUG_MODE=true
VERBOSE_DOCKER=true
CONFIG_AGENT_VERBOSE=true
./clamav-scan.sh -v -d /tmp
```

### Test de configuration minimal

```bash
# Test avec configuration minimale
cat > .env.test << 'EOF'
SCAN_DIR=/tmp
QUARANTINE_DIR=/tmp/quarantine-test
LOG_DIR=/tmp/logs-test
SIGNATURES_DIR=/tmp/signatures-test
NOTIFICATION_AGENT_ENABLED=false
QUARANTINE_AGENT_ACTION=quarantine
EOF

# Test
mv .env .env.backup
mv .env.test .env
./clamav-scan.sh -d /tmp
mv .env.backup .env
```

## 📞 Support et aide

### Informations à fournir

Lors d'une demande de support, incluez :

```bash
# Collecte d'informations système
cat > support-info.txt << 'EOF'
=== INFORMATIONS SYSTÈME ===
$(uname -a)
$(docker --version)
$(docker info | head -10)

=== CONFIGURATION ===
$(cat .env | grep -v -E '^#|^$')

=== LOGS RÉCENTS ===
$(tail -50 /var/log/clamav/scan_*.log | tail -50)

=== ERREUR PRÉCISE ===
[Coller ici l'erreur exacte]

=== COMMANDE EXÉCUTÉE ===
[Coller ici la commande qui a échoué]
EOF
```

### Channels de support

- 📋 **Issues GitHub** : Pour bugs et demandes de fonctionnalités
- 📧 **Email** : support@example.com
- 💬 **Discord** : [Lien vers serveur]

### Ressources utiles

- [Documentation officielle ClamAV](https://docs.clamav.net/)
- [Docker Hub ClamAV](https://hub.docker.com/r/clamav/clamav)
- [Base de connaissances](https://github.com/votre-user/clamav-scan/wiki)

---

**💡 Conseil :** Activez toujours le mode debug lors de l'investigation d'un problème pour avoir des logs détaillés.