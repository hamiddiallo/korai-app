#!/usr/bin/env bash
# Lance l'émulateur Android avec l'app Korai. Démarre aussi PostgreSQL, le backend et serviceIA
# s'ils ne tournent pas déjà ; ils restent en arrière-plan après le script (arrêt : ./arreter.sh).
# Après un démarrage à froid, saisissez le code de l'émulateur : l'app s'ouvre ensuite.
#
# Utilisation :
#   ./demarrer-android.sh                recompile l'app puis l'ouvre
#   ./demarrer-android.sh --sans-build   rouvre l'app déjà installée
case "${1:-}" in -h | --aide | --help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
exec "$(cd "$(dirname "$0")" && pwd)/demarrer.sh" --sans-ios --detache "$@"
