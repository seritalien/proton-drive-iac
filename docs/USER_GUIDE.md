# Guide d'utilisation

## Prérequis

- Une machine Linux avec systemd (utilisation en mode utilisateur —
  aucun droit administrateur requis pour l'usage courant)
- Un compte Proton avec Proton Drive activé
- `curl`, `unzip`, `jq` (généralement déjà présents sur une distribution
  récente)

## Installation

```bash
git clone <url-du-repo> proton-drive-iac
cd proton-drive-iac
./install.sh
```

Le script s'arrête une seule fois, à l'étape d'authentification, avec un
message explicite. **C'est volontaire** : vos identifiants de compte ne
doivent jamais transiter par un script automatisé. À ce moment-là :

1. Ouvrez un terminal
2. Lancez la commande affichée à l'écran vous-même
3. Suivez les instructions (email, mot de passe, éventuel code de
   double authentification)
4. Une fois connecté, relancez `./install.sh` — tout le reste s'enchaîne
   automatiquement

Si le montage natif n'est pas disponible au moment de l'installation
(dépendance externe temporairement indisponible), le script vous
l'indique clairement et bascule sur le mode de repli — voir
`scripts/cli/install.sh` pour ce chemin alternatif, avec la même logique
de pause à l'authentification.

## Vérifier que tout fonctionne

**Montage natif** :
```bash
mountpoint ~/ProtonDrive
systemctl --user status proton-drive-mount.service
```

**Mode de repli (synchronisation périodique)** :
```bash
systemctl --user status proton-drive-cli-sync.timer
tail -50 ~/.local/state/proton-drive-cli-sync.log
```

## Utilisation au quotidien

**Avec le montage natif** : rien à faire. `~/ProtonDrive` se comporte
comme n'importe quel dossier — glissez-déposez, ouvrez, éditez vos
fichiers normalement.

**Avec le mode de repli** : le dossier local se synchronise
automatiquement selon le calendrier configuré (par défaut : une fois par
jour). Vous pouvez aussi forcer une synchronisation immédiate :
```bash
scripts/cli/20-sync-bidirectional.sh
```

## Exclure un dossier ou fichier du sync (mode de repli)

Créez (ou éditez) `~/.config/proton-drive/sync-exclude` — un chemin par
ligne, relatif à `~/ProtonDrive`, lignes vides et commençant par `#`
ignorées :

```
Documents/Confidentiel
Documents/brouillon.docx
```

Ce fichier n'est jamais versionné (propre à chaque machine). Un chemin
exclu — ou un chemin dont un descendant est exclu — n'est plus transféré
dans aucun des deux sens au prochain sync. **Ça n'agit que sur les
prochains passages** : un contenu déjà présent côté cloud avant
l'exclusion n'est pas supprimé automatiquement — à faire vous-même si
besoin (`proton-drive filesystem delete "/my-files/..."`, voir
`docs/CLI_REFERENCE.md`).

## Que faire en cas de problème

Une notification desktop apparaît automatiquement en cas d'échec. Pour
en savoir plus sur ce qui s'est passé :

```bash
# Historique des échecs
cat ~/.local/state/proton-drive-failures.log

# Détail d'un échec du montage natif
journalctl --user -u proton-drive-mount.service -n 100

# Détail d'un échec de synchronisation (mode de repli)
tail -100 ~/.local/state/proton-drive-cli-sync.log
```

Dans la grande majorité des cas, relancer le service concerné suffit :
```bash
systemctl --user restart proton-drive-mount.service
```

## Questions fréquentes

**Est-ce que mes fichiers sont accessibles depuis mon téléphone / un autre
ordinateur ?**
Oui — aucune couche de chiffrement supplémentaire n'est ajoutée par
défaut, précisément pour préserver cet accès natif depuis les autres
applications Proton.

**Que se passe-t-il si je redémarre ma machine pendant une
synchronisation ?**
Rien de grave. La synchronisation reprend au prochain lancement (manuel
ou planifié) sans retransférer ce qui a déjà été envoyé.

**Puis-je utiliser ceci sur plusieurs machines ?**
Oui. Chaque machine génère ses propres secrets techniques et
s'authentifie séparément — il n'y a rien à copier d'une machine à
l'autre.

**Le mode de repli synchronise-t-il vraiment dans les deux sens ?**
Il rapatrie les nouveaux éléments du cloud et envoie les nouveaux
éléments locaux. Il ne détecte en revanche pas les modifications d'un
fichier déjà présent des deux côtés — voir `ARCHITECTURE.md` pour le
détail de cette limite et pourquoi le montage natif reste l'objectif.
