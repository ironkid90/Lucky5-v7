#!/usr/bin/env bash
set -euo pipefail

echo "Lucky5 multi-region deployment is not supported by the current production architecture." >&2
echo "The backend still uses in-memory machine sessions, ledgers, and admin state, so active/active regional deployment would split game state and RTP memory." >&2
echo "Use 'bash scripts/setup-azure.sh' for the supported single-region Azure App Service deployment." >&2
echo "See AZURE_MULTI_REGION_GUIDE.md for the prerequisites before enabling multi-region." >&2
exit 1