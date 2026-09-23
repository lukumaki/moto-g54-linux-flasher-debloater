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
#   docs/stock-applications.md. This script only ever touches the 26 core
#   packages, the optional Stage 4 batch, and the Stage 5 batch below
#   (docs/debloat.md, sections 14 and 16), but a bloated `packages-before`
#   snapshot is a sign you should re-check what "stock" actually means on
#   your device first.
# - Stage 5 removes some real, working features (Motorola Smart
#   Connect/desktop mode, the screensaver, Dynamic System Updates, system
#   tracing, Motorola Care), not just promotional bloat - read
#   docs/debloat.md section 16 before running it.
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

# Stage 4 (optional): casual games and other junk observed appearing after
# Google sign-in on the tested device - NOT guaranteed present on every
# phone (depends on the signed-in account and/or Motorola's regional
# bundled-app promotions, not the firmware). See docs/debloat.md, section
# 14. Each package is checked for presence before removal is attempted.
STAGE4_NAME="Stage 4 (optional): post-Google-sign-in bundled/junk apps"
STAGE4=(
    ball.sort.puzzle.color.sorting.bubble.games
    com.block.juggle
    com.king.candycrushsaga
    com.nebula.mahjongtile
    com.vitastudio.mahjong
    com.oakever.tiletrip
    com.oakever.arrows
    ringtonesforandroidphonefree.ringtones.ringtonessongs.ringtonesapp
    com.motorola.lmsaappclient
    com.google.android.apps.bard
    com.google.android.apps.photosgo
)

# Stage 5: additional stock components identified from a community debloat
# list, cross-checked against this project's own 403-package stock
# baseline and existing REMOVE/KEEP decisions (see docs/debloat.md,
# section 16). Unlike Stage 4, every package here is a confirmed part of
# the stock ROM, so the regular remove_stage is used - a genuinely
# missing one is handled gracefully (ALREADY REMOVED / FAILED) the same
# way as Stages 1-3.
#
# NOTE: this stage includes packages that remove real, working features
# rather than pure promotional bloat - specifically the Motorola Smart
# Connect / desktop-mode cluster (mobiledesktop.core, motcameradesktop,
# freeform, systemui.desk), the screensaver (dreams.basic), Dynamic
# System Updates (dynsystem), system tracing (traceur), and Motorola
# Care (motocare). Read docs/debloat.md section 16 before running this
# stage on a device where you might want those.
STAGE5_NAME="Stage 5: additional stock/diagnostic/feature components (community list)"
STAGE5=(
    com.android.bookmarkprovider
    com.android.dreams.basic
    com.android.dynsystem
    com.android.egg
    com.android.providers.partnerbookmarks
    com.android.traceur
    com.google.android.feedback
    com.google.android.gms.supervision
    com.google.android.printservice.recommendation
    com.lenovo.lsf.user
    com.motorola.android.nativedropboxagent
    com.motorola.android.providers.chromehomepage
    com.motorola.att.phone.extensions
    com.motorola.attvowifi
    com.motorola.bug2go
    com.motorola.ccc.mainplm
    com.motorola.contacts.preloadcontacts
    com.motorola.dimo
    com.motorola.enterprise.adapter.service
    com.motorola.enterprise.service
    com.motorola.freeform
    com.motorola.genie
    com.motorola.mobiledesktop.core
    com.motorola.motcameradesktop
    com.motorola.motocare
    com.motorola.omadm.vzw
    com.motorola.spectrum.setup.extensions
    com.motorola.systemui.desk
    com.motorola.vzw.pco.extensions.pcoreceiver
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
        elif printf '%s' "$out" | grep -qi 'not installed for 0'; then
            # Already removed for user 0 before this run started (e.g. a
            # prior debloat pass) - nothing to do, not a real failure.
            printf 'ALREADY REMOVED\n'
            printf 'ALREADY-REMOVED %s (%s)\n' "$pkg" "$out" >> "$LOG_DIR/removal-results.txt"
        else
            printf 'FAILED (%s)\n' "$out"
            printf 'FAILED   %s (%s)\n' "$pkg" "$out" >> "$LOG_DIR/removal-results.txt"
        fi
    done
}

is_installed() {
    local pkg="$1"
    adb shell pm list packages "$pkg" 2>/dev/null | tr -d '\r' | grep -qx "package:${pkg}"
}

remove_stage_if_present() {
    # Like remove_stage, but for packages that are not guaranteed to exist
    # on every phone (Stage 4): checks presence first and logs a SKIPPED
    # entry instead of attempting - and failing - an uninstall of
    # something that was never there.
    local name="$1"; shift
    local pkgs=("$@")
    banner "$name"

    for pkg in "${pkgs[@]}"; do
        if ! is_installed "$pkg"; then
            printf '+ pm uninstall --user 0 %s ... SKIPPED (not installed)\n' "$pkg"
            printf 'SKIPPED  %s (not installed)\n' "$pkg" >> "$LOG_DIR/removal-results.txt"
            continue
        fi

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
stock. This script only ever removes the packages listed below,
regardless of what else shows up in that snapshot.
EOF
fi

banner "Core packages this script will remove (26 total, user 0 only)"
printf '%s\n' "${STAGE1[@]}" "${STAGE2[@]}" "${STAGE3[@]}"

banner "Optional Stage 4 packages (removed only if actually present)"
printf '%s\n' "${STAGE4[@]}"
cat <<'EOF'

These are not part of the stock firmware and are not guaranteed present
on your phone - see docs/debloat.md, section 14. Each is checked before
any removal is attempted.
EOF

banner "Stage 5 packages (additional stock/diagnostic/feature components)"
printf '%s\n' "${STAGE5[@]}"
cat <<'EOF'

This includes packages that remove real, working features, not just
promotional bloat - the Motorola Smart Connect/desktop-mode cluster,
the screensaver, Dynamic System Updates, system tracing, and Motorola
Care. See docs/debloat.md, section 16, before proceeding if you might
want any of those.
EOF

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

checkpoint "Stage 3 complete. Next: optional post-Google-sign-in bundled/junk apps (only removed if present)."

remove_stage_if_present "$STAGE4_NAME" "${STAGE4[@]}"

checkpoint "Stage 4 complete. Next: additional stock/diagnostic/feature components, including Motorola Smart Connect/desktop mode, the screensaver, Dynamic System Updates, system tracing, and Motorola Care (see docs/debloat.md, section 16)."

remove_stage "$STAGE5_NAME" "${STAGE5[@]}"

banner "Capturing after-state snapshot"
snapshot "after"

diff -u "$LOG_DIR/packages-before.txt" "$LOG_DIR/packages-after.txt" > "$LOG_DIR/diff-before-after.txt" || true

FAILED_COUNT="$(grep -c '^FAILED' "$LOG_DIR/removal-results.txt" || true)"
OK_COUNT="$(grep -c '^OK' "$LOG_DIR/removal-results.txt" || true)"
ALREADY_REMOVED_COUNT="$(grep -c '^ALREADY-REMOVED' "$LOG_DIR/removal-results.txt" || true)"
SKIPPED_COUNT="$(grep -c '^SKIPPED' "$LOG_DIR/removal-results.txt" || true)"

banner "DEBLOAT RUN COMPLETE"
cat <<EOF
Removed successfully: $OK_COUNT
Already removed before this run (nothing to do): $ALREADY_REMOVED_COUNT
Failed: $FAILED_COUNT
Skipped (Stage 4 packages not present on this phone): $SKIPPED_COUNT

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
