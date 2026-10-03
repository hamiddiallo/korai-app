#!/usr/bin/env bash
# Lance le simulateur iOS avec l'app Korai. Démarre aussi PostgreSQL, le backend et serviceIA
# s'ils ne tournent pas déjà ; ils restent en arrière-plan après le script (arrêt : ./arreter.sh).
#
# Utilisation :
#   ./demarrer-ios.sh                recompile l'app puis l'ouvre
#   ./demarrer-ios.sh --sans-build   rouvre l'app déjà installée
case "${1:-}" in -h | --aide | --help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac
exec "$(cd "$(dirname "$0")" && pwd)/demarrer.sh" --sans-android --detache "$@"
