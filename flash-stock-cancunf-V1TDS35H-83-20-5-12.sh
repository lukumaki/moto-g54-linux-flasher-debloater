#!/usr/bin/env bash
set -Eeuo pipefail

# Motorola Moto G54 5G (cancunf) stock firmware flasher for Linux
# Derived from:
#   CANCUNF_G_SYS V1TDS35H.83-20-5-12 flashfile.xml
#
# IMPORTANT:
# - Run this script FROM the extracted stock firmware directory.
# - It intentionally mirrors the flash/erase/oem order in flashfile.xml.
# - It does NOT relock the bootloader.
# - It does NOT reboot the phone automatically.
# - It WILL erase nvdata, userdata, metadata and debug_token exactly as
#   Motorola's flashfile.xml instructs.
# - If a fastboot command fails, the script stops immediately.
#
# Recommended invocation:
#   chmod +x flash-stock-cancunf-V1TDS35H-83-20-5-12.sh
#   ./flash-stock-cancunf-V1TDS35H-83-20-5-12.sh 2>&1 | tee flash-stock.log

EXPECTED_PRODUCT="cancunf"
EXPECTED_CID="0x0032"
# flashfile.xml only contains "_a" slot partition images. If current-slot
# ever reports "b" (e.g. after an OTA switched the active slot), switch
# back before running this script:
#   fastboot set_active a
EXPECTED_SLOT="a"
EXPECTED_SPARSE="268435456"
EXPECTED_BUILD="V1TDS35H.83-20-5-12"

FB_MODE_SET=0
CURRENT_STAGE="preflight"

die() {
    printf '\nSTOPPED: %s\n' "$*" >&2

    if [[ "$FB_MODE_SET" -eq 1 ]]; then
        printf '\nMotorola fb_mode is currently SET.\n' >&2
        printf 'Do not reboot blindly.\n' >&2
        printf 'Review why the script stopped before issuing further fastboot commands.\n' >&2
    fi

    exit 1
}

on_error() {
    local rc=$?
    printf '\n============================================================\n' >&2
    printf 'FLASHING STOPPED: command failed during stage: %s\n' "$CURRENT_STAGE" >&2
    printf 'Exit code: %s\n' "$rc" >&2
    if [[ "$FB_MODE_SET" -eq 1 ]]; then
        printf '\nMotorola fb_mode is still SET.\n' >&2
        printf 'DO NOT reboot or continue blindly. Inspect the error first.\n' >&2
        printf 'When appropriate, fb_mode can later be cleared manually with:\n' >&2
        printf '  fastboot oem fb_mode_clear\n' >&2
    fi
    printf '============================================================\n' >&2
    exit "$rc"
}
trap on_error ERR

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
    [[ "$answer" == "YES" ]] || die "Stopped by user before next stage."
}

getvar_value() {
    local var="$1"
    local out
    out="$(fastboot getvar "$var" 2>&1 || true)"
    printf '%s\n' "$out" | sed -nE "s/^(\\(bootloader\\) )?${var}: ?//p" | head -n1
}

bootloader_unlocked_value() {
    # Tries the generic AOSP `getvar unlocked` first, then Motorola's
    # `securestate` (flashing_locked / flashing_unlocked - the value shown
    # directly on the fastboot screen on this device's MediaTek bootloader,
    # and the one confirmed present when `unlocked` is not), then falls
    # back to `oem device-info`. Prints "yes", "no", or nothing if none of
    # the sources return a recognizable value.
    local val
    val="$(getvar_value unlocked)"

    if [[ -z "$val" || "$val" == "not supported"* ]]; then
        case "$(getvar_value securestate)" in
            flashing_unlocked) val="yes" ;;
            flashing_locked) val="no" ;;
            *) val="" ;;
        esac
    fi

    if [[ -z "$val" ]]; then
        val="$(fastboot oem device-info 2>&1 | sed -nE 's/^\(bootloader\) *Device unlocked: *//Ip' | head -n1 | tr -d '\r')"
    fi

    case "${val,,}" in
        yes|true) printf 'yes' ;;
        no|false) printf 'no' ;;
        *) printf '' ;;
    esac
}

print_xml_step() {
    # Looks up and prints the literal <step> in flashfile.xml that this
    # fastboot command corresponds to, so the log shows exactly which
    # Motorola-authored line each command came from. Warns instead of
    # guessing if no matching step exists.
    local op="$1"; shift
    local partition="" filename="" var=""

    case "$op" in
        flash)
            partition="$1"
            filename="$2"
            ;;
        erase)
            partition="$1"
            ;;
        getvar|oem)
            var="$*"
            ;;
        *)
            return 0
            ;;
    esac

    python3 - "$op" "$partition" "$filename" "$var" <<'PY'
import sys
import xml.etree.ElementTree as ET

op, partition, filename, var = sys.argv[1:5]
root = ET.parse("flashfile.xml").getroot()

match = None
for step in root.findall(".//step"):
    if step.get("operation") != op:
        continue
    if op == "flash":
        if step.get("partition") == partition and step.get("filename") == filename:
            match = step
            break
    elif op == "erase":
        if step.get("partition") == partition:
            match = step
            break
    else:
        if step.get("var") == var:
            match = step
            break

if match is not None:
    print("# flashfile.xml: " + ET.tostring(match).decode().strip())
else:
    print(f"# WARNING: no matching <step> found in flashfile.xml for: fastboot {op} {partition or var} {filename}".rstrip())
PY
}

run_fb() {
    print_xml_step "$@"
    printf '\n+ fastboot'
    printf ' %q' "$@"
    printf '\n'
    fastboot "$@"
}

banner "Motorola Moto G54 5G stock firmware preflight"

command -v fastboot >/dev/null 2>&1 || die "fastboot is not installed or not in PATH."
command -v python3  >/dev/null 2>&1 || die "python3 is required for XML/MD5 validation."

[[ -f flashfile.xml ]] || die "flashfile.xml not found. Run this script from the extracted firmware directory."

python3 - "$EXPECTED_PRODUCT" "$EXPECTED_CID" "$EXPECTED_BUILD" <<'PY'
import sys
import xml.etree.ElementTree as ET

expected_product, expected_cid, expected_build = sys.argv[1:4]
root = ET.parse("flashfile.xml").getroot()

model = root.find("./header/phone_model")
software = root.find("./header/software_version")
cid = root.find("./header/cid_value")
sparse = root.find("./header/sparsing")

if model is None or software is None or cid is None or sparse is None:
    raise SystemExit("ERROR: flashfile.xml is missing expected Motorola header fields.")

xml_model = model.get("model", "")
xml_version = software.get("version", "")
xml_cid = cid.get("value", "")
xml_sparse = sparse.get("max-sparse-size", "")

if not xml_model.startswith(expected_product):
    raise SystemExit(f"ERROR: XML model mismatch: {xml_model!r}")
if expected_build not in xml_version:
    raise SystemExit(f"ERROR: XML build mismatch: {xml_version!r}")
if xml_cid.lower() != expected_cid.lower():
    raise SystemExit(f"ERROR: XML CID mismatch: {xml_cid!r}")
if xml_sparse != "268435456":
    raise SystemExit(f"ERROR: XML max-sparse-size mismatch: {xml_sparse!r}")

print(f"XML model:       {xml_model}")
print(f"XML build:       {xml_version}")
print(f"XML CID:         {xml_cid}")
print(f"XML sparse size: {xml_sparse}")
print("XML identity check: OK")
PY

mapfile -t FB_DEVICES < <(fastboot devices | awk 'NF >= 2 && $2 == "fastboot" {print $1}')
[[ "${#FB_DEVICES[@]}" -eq 1 ]] || die "Expected exactly one fastboot device; found ${#FB_DEVICES[@]}."

SERIAL="${FB_DEVICES[0]}"
printf 'Fastboot device:  %s\n' "$SERIAL"

PRODUCT="$(getvar_value product)"
CID="$(getvar_value cid)"
SLOT="$(getvar_value current-slot)"
SPARSE="$(getvar_value max-sparse-size)"
SECURE="$(getvar_value secure)"
BOOTLOADER="$(getvar_value version-bootloader)"
UNLOCKED="$(bootloader_unlocked_value)"

printf 'Device product:   %s\n' "${PRODUCT:-<unavailable>}"
printf 'Device CID:       %s\n' "${CID:-<unavailable>}"
printf 'Current slot:     %s\n' "${SLOT:-<unavailable>}"
printf 'Max sparse size:  %s\n' "${SPARSE:-<unavailable>}"
printf 'Secure:           %s\n' "${SECURE:-<unavailable>}"
printf 'Bootloader:       %s\n' "${BOOTLOADER:-<unavailable>}"
printf 'Unlocked:         %s\n' "${UNLOCKED:-<unknown>}"

[[ "$PRODUCT" == "$EXPECTED_PRODUCT" ]] || die "Product mismatch: expected $EXPECTED_PRODUCT, got ${PRODUCT:-<empty>}."
[[ "${CID,,}" == "${EXPECTED_CID,,}" ]] || die "CID mismatch: expected $EXPECTED_CID, got ${CID:-<empty>}."
[[ "$SLOT" == "$EXPECTED_SLOT" ]] || die "Current slot must be $EXPECTED_SLOT, got ${SLOT:-<empty>}. If this is slot b, run: fastboot set_active $EXPECTED_SLOT"
[[ "$SPARSE" == "$EXPECTED_SPARSE" ]] || die "max-sparse-size mismatch: expected $EXPECTED_SPARSE, got ${SPARSE:-<empty>}."

if [[ "$UNLOCKED" == "no" ]]; then
    cat <<'EOF'

NOTE: bootloader reports LOCKED.
On this device's MediaTek Motorola bootloader, a locked state does not by
itself block flashing Motorola's own officially signed, CID-matching
firmware via fastboot - confirmed working on the tested device. This is
NOT a general "any locked bootloader accepts any image" guarantee:
unsigned or custom images still require a genuine unlock. If a flash
command below fails with something like "not allowed in locked state",
see the README section "Before you start: Developer options, unlocking,
and relocking".
EOF
elif [[ -z "$UNLOCKED" ]]; then
    printf '\nWARNING: could not confirm bootloader unlock state (getvar unlocked / securestate / oem device-info did not return a recognizable value).\n'
    printf 'Proceeding anyway - if the next fastboot command fails with something like "not allowed in locked state", unlock the bootloader first (see the README).\n'
fi

banner "Verify every firmware file against flashfile.xml"

python3 <<'PY'
import hashlib
import xml.etree.ElementTree as ET
from pathlib import Path

root = ET.parse("flashfile.xml").getroot()
checked = 0
errors = 0

for step in root.findall(".//step"):
    filename = step.get("filename")
    expected = step.get("MD5")
    if not filename or not expected:
        continue

    checked += 1
    path = Path(filename)
    if not path.is_file():
        print(f"MISSING  {filename}")
        errors += 1
        continue

    md5 = hashlib.md5()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b""):
            md5.update(chunk)

    actual = md5.hexdigest()
    if actual.lower() == expected.lower():
        print(f"OK       {filename}")
    else:
        print(f"FAILED   {filename}")
        print(f"         expected {expected}")
        print(f"         actual   {actual}")
        errors += 1

print()
print(f"Checked {checked} firmware files.")
if errors:
    raise SystemExit(f"{errors} integrity problem(s) found. DO NOT FLASH.")
print("ALL FIRMWARE FILES MATCH flashfile.xml")
PY

banner "DESTRUCTIVE OPERATION WARNING"
cat <<'EOF'
This procedure will now follow Motorola's flashfile.xml.

It will:
  * rewrite the GPT
  * flash the MediaTek preloader and other low-level firmware
  * flash boot / vendor_boot / AVB partitions
  * flash all 22 super sparse chunks
  * ERASE nvdata
  * ERASE userdata
  * ERASE metadata
  * ERASE debug_token

It will NOT:
  * relock the bootloader
  * reboot automatically at the end

Keep the USB cable connected and do not interrupt power during flashing.
EOF

printf '\nTo authorize actual flashing, type exactly: YES\n> '
read -r confirmation
[[ "$confirmation" == "YES" ]] || die "Flashing not authorized."

CURRENT_STAGE="1: GPT and Motorola flash mode"
banner "$CURRENT_STAGE"

run_fb flash gpt PGPT
run_fb getvar max-sparse-size
run_fb oem fb_mode_set
FB_MODE_SET=1

checkpoint "Stage 1 completed successfully. Next: flash preloader and core _a firmware."

CURRENT_STAGE="2: preloader and core firmware"
banner "$CURRENT_STAGE"

run_fb flash preloader preloader.img
run_fb flash lk_a lk.img
run_fb flash tee_a tee.img
run_fb flash mcupm_a mcupm.img
run_fb flash pi_img_a pi_img.img
run_fb flash sspm_a sspm.img
run_fb flash dtbo_a dtbo.img
run_fb flash logo_a logo.img

checkpoint "Stage 2 completed successfully. Next operation is Motorola's explicit ERASE of nvdata."

CURRENT_STAGE="3: erase nvdata and flash remaining firmware"
banner "$CURRENT_STAGE"

run_fb erase nvdata
run_fb flash spmfw_a spmfw.img
run_fb flash scp_a scp.img
run_fb flash vbmeta_a vbmeta.img
run_fb flash vbmeta_system_a vbmeta_system.img
run_fb flash md1img_a md1img.img
run_fb flash dpm_a dpm.img
run_fb flash gz_a gz.img
run_fb flash vcp_a vcp.img
run_fb flash gpueb_a gpueb.img
run_fb flash efuseBackup efuse.img
run_fb flash boot_a boot.img
run_fb flash vendor_boot_a vendor_boot.img

checkpoint "Stage 3 completed successfully. Next: flash all 22 super sparse chunks."

CURRENT_STAGE="4: super dynamic partition"
banner "$CURRENT_STAGE"

for i in {0..21}; do
    run_fb flash super "super.img_sparsechunk.${i}"
done

checkpoint "Stage 4 completed successfully. Next: final destructive erases and Motorola cleanup."

CURRENT_STAGE="5: userdata/metadata erase and Motorola cleanup"
banner "$CURRENT_STAGE"

run_fb erase userdata
run_fb erase metadata
run_fb erase debug_token
run_fb oem fb_mode_clear
FB_MODE_SET=0
run_fb oem config unset console
run_fb oem config unset cmdl

CURRENT_STAGE="complete"

banner "FLASHFILE.XML SEQUENCE COMPLETED SUCCESSFULLY"
cat <<'EOF'
All operations from flashfile.xml completed without a detected command failure.

The script intentionally DID NOT reboot the phone and DID NOT relock the
bootloader.

Recommended next action:
  Stop here and review the terminal/log before issuing any reboot command.
EOF
