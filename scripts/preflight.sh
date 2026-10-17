#!/usr/bin/env bash
# Release checks: clean tree, no placeholder signing values, privacy manifests, tests pass.
# Tests run on the physical device in DEVICE_UDID (env or .env); without it they're skipped with a warning.
# FORCE=1 allows uncommitted changes.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  while IFS='=' read -r key value || [[ -n $key ]]; do
    if [[ $key =~ ^[A-Z_]+$ && -z "${!key:-}" ]]; then export "$key=$value"; fi
  done < .env
fi

failures=0
fail() { echo "preflight: FAIL $*" >&2; failures=$((failures + 1)); }
pass() { echo "preflight: ok   $*"; }

# docs/ never goes into the build.
dirty=$(git status --porcelain -- . ':!docs')
if [[ -z $dirty ]]; then
  pass "clean tree"
elif [[ ${FORCE:-} == 1 ]]; then
  echo "preflight: warn uncommitted changes (FORCE=1):" >&2
  echo "$dirty" >&2
else
  fail "uncommitted or untracked files go into the build (FORCE=1 to override):"
  echo "$dirty" >&2
fi

setting() { sed -n "s/^$1 *= *//p" Local.xcconfig | tr -d '[:space:]'; }
if [[ ! -f Local.xcconfig ]]; then
  fail "missing Local.xcconfig (cp Local.xcconfig.example Local.xcconfig)"
else
  team=$(setting DEVELOPMENT_TEAM)
  bundle=$(setting APP_BUNDLE_ID)
  if [[ -z $team || $team == *REPLACE* ]]; then fail "DEVELOPMENT_TEAM in Local.xcconfig is empty or a placeholder"; else pass "team id set"; fi
  if [[ -z $bundle || $bundle == com.example* ]]; then fail "APP_BUNDLE_ID in Local.xcconfig is empty or a placeholder"; else pass "bundle id set"; fi
fi

shipped=(EveryTime EveryTimeWidget Glance project.yml ExportOptions.plist)
if hits=$(grep -rnE 'group\.com\.example|iCloud\.com\.example|REPLACE_WITH' --exclude='*.md' "${shipped[@]}"); then
  fail "placeholder values in shipped files:"
  echo "$hits" >&2
else
  pass "no placeholders in shipped files"
fi

for manifest in EveryTime/PrivacyInfo.xcprivacy EveryTimeWidget/PrivacyInfo.xcprivacy; do
  if [[ -f $manifest ]] && plutil -lint -s "$manifest"; then pass "$manifest"; else fail "missing or invalid $manifest"; fi
done

if (( failures > 0 )); then
  echo "preflight: $failures check(s) failed" >&2
  exit 1
fi

if [[ -z ${DEVICE_UDID:-} ]]; then
  echo "preflight: warn tests skipped, set DEVICE_UDID to run them on the iPhone" >&2
else
  team_arg=()
  [[ -n ${TEAM_ID:-} ]] && team_arg=("DEVELOPMENT_TEAM=$TEAM_ID")
  xcodegen generate --quiet
  if nice -n 10 xcodebuild test -scheme EveryTime -destination "id=$DEVICE_UDID" -derivedDataPath /tmp/everytime-build \
      -allowProvisioningUpdates -quiet ${team_arg[@]+"${team_arg[@]}"}; then
    pass "tests on device"
  else
    echo "preflight: FAIL tests" >&2
    exit 1
  fi
fi
echo "preflight: passed"
