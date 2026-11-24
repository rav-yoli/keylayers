# Publier une nouvelle version de KeyLayers

Ce guide s’utilise sous Windows, dans le terminal PowerShell de VS Code à la racine du dépôt. La version `1.1.0b` sert d’exemple. Remplace-la par celle que tu veux publier.

## 1. Préparer et tester la version

Place `Publish-KeyLayers.ps1` à la racine du dépôt. Ajoute cette règle dans le `.gitignore` existant, sur sa propre ligne.

```gitignore
dist/*
```

Committe tes changements, y compris le script et le `.gitignore` lors de leur ajout. Vérifie que tu es sur `main`, que le dossier de travail est propre et que l’identité Git est bien celle de **Rav Yoli**.

```powershell
git status --short --branch
git var GIT_COMMITTER_IDENT
```

Pour préparer un ZIP local avec le numéro visé, utilise le script de test existant.

```powershell
.\Build-KeyLayersTestZip.ps1 -Version 1.1.0b -OutputDirectory .\dist
```

Installe et teste le ZIP en jeu. Le script de test applique le numéro de version aux fichiers dans l’archive.

Si la version de **WoW Forever** ciblée change, vérifie la compatibilité en jeu et aligne `## Interface:` dans le `.toc` avec la version recherchée par **Resolve CurseForge game version** dans `.github/workflows/package.yml`. Si tu modifies le workflow, teste-le d’abord sur `main` via **Actions → Package KeyLayers → Run workflow**.

## 2. Publier depuis PowerShell

Une fois les tests terminés, lance la commande de publication.

```powershell
.\Publish-KeyLayers.ps1 -Version 1.1.0b
```

Le script vérifie l’état de `main` et la disponibilité du tag en local et sur GitHub. Il met à jour `## Version:` dans le `.toc`, la version de secours dans `Core.lua` et le titre du `README.md` si celui-ci affiche un numéro. Si le numéro change, il crée le commit `Release KeyLayers 1.1.0b`. Il crée le tag annoté `v1.1.0b` sur le dernier commit, puis pousse `main` et ce tag ensemble. [Documentation Git sur le push atomique](https://git-scm.com/docs/git-push#Documentation/git-push.txt---atomic)

Le tag déclenche **Package KeyLayers**. Le workflow construit `KeyLayers-by-Rav-Yoli-1.1.0b.zip`, le joint à la release GitHub, puis envoie la même archive à CurseForge en type **Release**. Le tag historique `v1.0.1b` est exclu de l’envoi automatique à CurseForge.

## 3. Vérifier la publication

1. Ouvre l’exécution **Package KeyLayers** du tag. Vérifie **Build and validate ZIP**, **Publish GitHub release** et **Upload ZIP to CurseForge**. La dernière étape affiche le **CurseForge file ID** quand l’API accepte l’envoi. [GitHub Actions](https://github.com/rav-yoli/keylayers/actions)
2. Vérifie le nom du ZIP joint et complète les notes si nécessaire. CurseForge affiche un lien vers ces notes. [GitHub Releases](https://github.com/rav-yoli/keylayers/releases)
3. Dans **Files** sur CurseForge, vérifie le ZIP, son type **Release** et la version de WoW Forever. CurseForge traite ensuite le fichier selon son processus de modération.

## Si une étape échoue

- **Push refusé ou interrompu.** Le commit et le tag peuvent déjà exister en local. Vérifie le tag avant de relancer quoi que ce soit avec `git show --no-patch v1.1.0b` et `git ls-remote --tags origin refs/tags/v1.1.0b`. Si le tag local pointe vers le bon commit, que le tag est absent sur GitHub et que le problème réseau ou d’accès est réglé, reprends l’envoi avec la commande ci-dessous. Si GitHub signale une divergence, inspecte d’abord l’historique.
- **Le workflow échoue avant la création de la release.** Si l’erreur est temporaire, relance l’exécution du même tag. Si la correction change des fichiers de la release, prépare une nouvelle version et un nouveau tag. [Relancer une exécution GitHub Actions](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/re-run-workflows-and-jobs)
- **GitHub a publié le ZIP, mais l’envoi CurseForge a échoué.** Vérifie d’abord **Files** sur CurseForge. Si le ZIP est absent, télécharge celui de la GitHub Release et envoie-le manuellement. Le workflow actuel essaie de créer la release GitHub à chaque exécution pour un tag. Vérifie aussi le secret `CF_API_TOKEN` et la version de WoW Forever ciblée si le journal signale une erreur à ce sujet.

```powershell
git push --atomic --no-follow-tags origin refs/heads/main:refs/heads/main refs/tags/v1.1.0b:refs/tags/v1.1.0b
```
