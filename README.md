# proton-drive-iac

Intégration reproductible de Proton Drive sur une machine Linux, comme
espace de stockage utilisable au quotidien — installation scriptée,
idempotente, avec surveillance et alerte intégrées.

- [`docs/FEATURES.md`](docs/FEATURES.md) — ce que fait le projet
- [`docs/USER_GUIDE.md`](docs/USER_GUIDE.md) — installation et usage
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — choix techniques et limites connues
- [`docs/CLI_REFERENCE.md`](docs/CLI_REFERENCE.md) — commandes manuelles et pièges du CLI officiel

## Démarrage rapide

```bash
git clone <url-de-ce-repo> proton-drive-iac
cd proton-drive-iac
./install.sh
```

Le script s'arrête une seule fois, à l'étape d'authentification — c'est
volontaire : vos identifiants ne doivent jamais transiter par un outil
automatisé. Suivez les instructions affichées, puis relancez `./install.sh`.

Si le montage natif n'est pas disponible au moment de l'installation
(dépendance externe indisponible), un mode de repli prend le relais
automatiquement — voir `docs/ARCHITECTURE.md`.

## Licence

MIT — voir [`LICENSE`](LICENSE).
