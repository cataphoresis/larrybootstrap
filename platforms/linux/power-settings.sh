#!/usr/bin/env bash
set -euo pipefail
module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/modules"
# shellcheck source=modules/common.sh
source "$module_dir/common.sh"
# shellcheck source=modules/apps.sh
source "$module_dir/apps.sh"
configure_xfce_lid_suspend
