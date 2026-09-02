#!/usr/bin/env bash
set -Eeuo pipefail

# Conservative Android user-0 debloat for the Moto G54 5G (cancunf).
#
# Automates the exact `pm uninstall --user 0` removal batches documented in
# docs/debloat.md, in the same order, together with the before/after
# `pm list packages` snapshots that make a run auditable.
#
# IMPORTANT:
# - This does NOT delete APKs from /system, /product or /system_ext. It only
#   removes packages for Android user 0 with `pm uninstall --user 0`, which
#   is normally reversible with `adb shell cmd package install-existing`.
# - Run this only AFTER Google sign-in and any Play Store "restore apps"
#   step have already happened and settled. A fresh sign-in can silently
#   reinstall dozens of your own previously-used apps; see the "Watch out
#   for Google Play auto-restore on a fresh flash" section in
#   docs/stock-applications.md. This script only ever touches the 26
#   packages below, but a bloated `packages-before` snapshot is a sign you
#   should re-check what "stock" actually means on your device first.
# - Requires exactly one authorized `adb` device reporting product cancunf.
# - Pauses for confirmation between stages so you can test the phone in
#   between, matching the manual procedure in docs/debloat.md.
# - A failed removal on one package is reported but does not abort the
#   run - inspect FAILED lines in the log before deciding what to do.
#   (On the tested device, com.amazon.appmanager and com.orange.aura.oobe
#   were already disabled and are deliberately NOT in this script's list;
#   see docs/stock-applications.md.)
#
# Recommended invocation:
#   chmod +x debloat-cancunf.sh
#   ./debloat-cancunf.sh 2>&1 | tee debloat-run.log

EXPECTED_PRODUCT="cancunf"
REFERENCE_STOCK_COUNT=403

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_DIR="debloat-logs/${TIMESTAMP}"

# Stage 1: unwanted Google apps and Motorola/partner promo components.
STAGE1_NAME="Stage 1: Google apps and Motorola/partner promo components"
STAGE1=(
    com.google.android.apps.docs.editors.sheets
    com.google.android.apps.docs.editors.docs
    com.google.android.apps.docs.editors.slides
    com.google.android.apps.magazines
    com.google.android.apps.fitness
    com.google.android.apps.podcasts
    com.google.android.apps.nbu.files
    com.google.android.apps.youtube.music
    com.aura.oobe.motorola
    com.dti.motorola
    com.taboola.mip
    com.glance.lockscreenM
)

# Stage 2: Google One and Google Meet.
STAGE2_NAME="Stage 2: Google One and Google Meet"
STAGE2=(
    com.google.android.apps.subscriptions.red
    com.google.android.apps.tachyon
)

# Stage 3: promotional Motorola packages and Meta helper packages.
STAGE3_NAME="Stage 3: promotional Motorola packages and Meta helper packages"
STAGE3=(
    com.motorola.brapps
    com.motorola.demo
    com.motorola.ccc.notification
    com.facebook.appmanager
    com.facebook.system
    com.facebook.services
    com.motorola.gamemode
    com.motorola.timeweatherwidget
    com.motorola.livewallpaper3
    com.motorola.spaces
    com.google.android.apps.googleassistant
    com.google.android.apps.photos
)

die() {
    printf '\nSTOPPED: %s\n' "$*" >&2
    exit 1
}

banner() {
    printf '\n============================================================\n'
    printf '%s\n' "$1"
    printf '============================================================\n'
}

checkpoint() {
    local msg="$1"
    printf '\n%s\n' "$msg"
    printf 'Type YES to proceed, or anything else to stop: '
    read -r answer
    [[ "$answer" == "YES" ]] || die "Stopped by user before next stage. Nothing further was changed."
}

adb_list() {
    # $1: output file, remaining args: extra `pm list packages` flags (if any)
    local out="$1"; shift
    adb shell pm list packages "$@" | tr -d '\r' | sed 's/^package://' | sort > "$out"
}

snapshot() {
    local label="$1"
    adb_list "$LOG_DIR/packages-${label}.txt"
    adb_list "$LOG_DIR/packages-with-paths-${label}.txt" -f
    adb_list "$LOG_DIR/packages-disabled-${label}.txt" -d
    adb_list "$LOG_DIR/packages-third-party-${label}.txt" -3
}

remove_stage() {
    local name="$1"; shift
    local pkgs=("$@")
    banner "$name"

    for pkg in "${pkgs[@]}"; do
        printf '+ pm uninstall --user 0 %s ... ' "$pkg"
        local out rc=0
        out="$(adb shell pm uninstall --user 0 "$pkg" 2>&1)" || rc=$?
        out="$(printf '%s' "$out" | tr -d '\r')"

        if [[ "$rc" -eq 0 ]] && printf '%s' "$out" | grep -qi 'success'; then
            printf 'OK\n'
            printf 'OK       %s\n' "$pkg" >> "$LOG_DIR/removal-results.txt"
        else
            printf 'FAILED (%s)\n' "$out"
            printf 'FAILED   %s (%s)\n' "$pkg" "$out" >> "$LOG_DIR/removal-results.txt"
        fi
    done
}

banner "Moto G54 5G debloat preflight"

command -v adb >/dev/null 2>&1 || die "adb is not installed or not in PATH."

mapfile -t ADB_DEVICES < <(adb devices | awk 'NF >= 2 && $2 == "device" {print $1}')
[[ "${#ADB_DEVICES[@]}" -eq 1 ]] || die "Expected exactly one authorized adb device; found ${#ADB_DEVICES[@]}. Run 'adb devices' to check."

SERIAL="${ADB_DEVICES[0]}"
printf 'ADB device:     %s\n' "$SERIAL"

PRODUCT="$(adb shell getprop ro.product.device | tr -d '\r')"
printf 'Device product: %s\n' "${PRODUCT:-<unavailable>}"
[[ "$PRODUCT" == "$EXPECTED_PRODUCT" ]] || die "Product mismatch: expected $EXPECTED_PRODUCT, got ${PRODUCT:-<empty>}."

mkdir -p "$LOG_DIR"
: > "$LOG_DIR/removal-results.txt"

banner "Capturing before-state snapshot"
snapshot "before"

BEFORE_COUNT="$(wc -l < "$LOG_DIR/packages-before.txt")"
printf 'Total packages before: %s (this project'"'"'s documented stock baseline is %s)\n' "$BEFORE_COUNT" "$REFERENCE_STOCK_COUNT"

if [[ "$BEFORE_COUNT" -gt "$REFERENCE_STOCK_COUNT" ]]; then
    cat <<EOF

NOTE: This device reports more packages than the documented stock
baseline ($REFERENCE_STOCK_COUNT). That is expected if you have already
installed your own apps, but it can also mean Google Play's "restore
apps" feature reinstalled your previous app history after a fresh flash
and Google sign-in. See docs/stock-applications.md, "Watch out for
Google Play auto-restore on a fresh flash", before assuming every
third-party package in $LOG_DIR/packages-third-party-before.txt is
stock. This script only removes the 26 packages listed below regardless.
EOF
fi

banner "Packages this script will remove (26 total, user 0 only)"
printf '%s\n' "${STAGE1[@]}" "${STAGE2[@]}" "${STAGE3[@]}"

cat <<'EOF'

This uses `pm uninstall --user 0`, not deletion from a signed partition.
A removed system package can normally be restored with:
  adb shell cmd package install-existing PACKAGE.NAME
EOF

printf '\nTo authorize this run, type exactly: YES\n> '
read -r confirmation
[[ "$confirmation" == "YES" ]] || die "Debloat not authorized. Nothing was changed."

remove_stage "$STAGE1_NAME" "${STAGE1[@]}"
checkpoint "Stage 1 complete. Reboot and test the phone (Settings, calls, Wi-Fi, Play Store) before continuing."

remove_stage "$STAGE2_NAME" "${STAGE2[@]}"
checkpoint "Stage 2 complete. Next: promotional Motorola packages and Meta helper packages."

remove_stage "$STAGE3_NAME" "${STAGE3[@]}"

banner "Capturing after-state snapshot"
snapshot "after"

diff -u "$LOG_DIR/packages-before.txt" "$LOG_DIR/packages-after.txt" > "$LOG_DIR/diff-before-after.txt" || true

FAILED_COUNT="$(grep -c '^FAILED' "$LOG_DIR/removal-results.txt" || true)"
OK_COUNT="$(grep -c '^OK' "$LOG_DIR/removal-results.txt" || true)"

banner "DEBLOAT RUN COMPLETE"
cat <<EOF
Removed successfully: $OK_COUNT
Failed / already absent: $FAILED_COUNT

Full results: $LOG_DIR/removal-results.txt
Before/after snapshots and diff: $LOG_DIR/
EOF

if [[ "$FAILED_COUNT" -gt 0 ]]; then
    printf '\nFAILED entries (inspect before assuming they are harmless):\n'
    grep '^FAILED' "$LOG_DIR/removal-results.txt"
fi

cat <<'EOF'

Recommended next steps:
  1. Reboot the phone.
  2. Walk through the manual test checklist in docs/debloat.md
     (calls/SMS, mobile data, Wi-Fi, Bluetooth, camera, Motorola
     gestures/settings, Play Store, notifications, OTA).
  3. Review the diff in the log directory above for an auditable
     record of exactly what changed.
EOF
