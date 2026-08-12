#!/usr/bin/env bash
# agent-run.sh n'accepte qu'un nom de fichier nu : ce wrapper porte l'argument.
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gd/run-gd-agent.sh" gd-audit
