# Diagnosing VoLTE/IMS and confirming calls actually work (cancunf)

This documents the diagnostic method used to investigate a real problem on the tested device — calls not registering over IMS/VoLTE — across both a custom ROM and multiple stock builds, and how it was actually resolved in practice. It is troubleshooting methodology, not a guaranteed fix: the root cause below is a plausible, evidence-based hypothesis, not a confirmed one.

## The symptom

`dumpsys phone` showed the MMTEL (voice-over-IMS) feature bound and `READY`, but its only reported capability was ever `{ EMERGENCY_OVER_MMTEL }` — never normal voice. This was identical across a custom ROM (YAAP-16) and two different stock builds (`V1TDS35H.83-20-5-6` and `-12`), on the same SIM, roaming (Greek SIM, Hungarian network). Same firmware/ROM, different Android versions, same result — which rules out a ROM-specific bug and points at something the ROM has no control over.

## Step 1: check whether Android even thinks IMS *should* work here

```bash
adb shell dumpsys carrier_config
```

Look specifically for the SIM's own carrier-config override block (`mConfigFromDefaultApp`, matched by `carrier_config_version_string` for your SIM's MCC/MNC), not just the generic defaults above it. The keys that actually matter:

- `carrier_volte_available_bool` — VoLTE enabled for this carrier at all.
- `imsvoice.carrier_volte_roaming_available_bool` — **specifically** whether VoLTE-while-roaming is permitted. If this is `false`, that's a real "no roaming agreement" block and there's nothing to chase further.
- `carrier_wfc_ims_available_bool` / `carrier_default_wfc_ims_roaming_mode_int` — the same, for Wi-Fi calling.

On the tested device, `imsvoice.carrier_volte_roaming_available_bool` was `true` — Android itself was authorized to attempt IMS registration. That ruled out the simplest explanation ("no agreement between the home and visited carrier") and shifted suspicion toward something OEM/modem-side gating registration independently of what CarrierConfig permits — MediaTek modems in particular are known to sometimes keep an internal roaming-partner allow-list separate from CarrierConfig. This was never confirmed directly; it remained a hypothesis.

## Step 2: capture the radio log during a real call attempt

```bash
adb logcat -b radio -c
adb logcat -b radio -v threadtime > radio-call-test.log
```

Then place/receive a call while it's running. Two pitfalls found the hard way:

- **The file can grow to very long lines** (cell-tower dumps, signal-strength reports). A plain `grep` without `-a` silently treats the file as binary and returns nothing — always use `grep -a`.
- **A `while read` loop that runs `adb shell` per line will eat the rest of its own input.** `adb shell` inherits stdin by default; inside `while read pkg; do ... adb shell ... ; done < file`, that swallows the loop's file after the first iteration. Redirect it away: `adb shell <command> < /dev/null`.

Useful signal to grep for, once you have the log:

```bash
grep -a -E "update phone state|GET_CURRENT_CALLS \{\[id=1,[A-Z]+|onDisconnect|isImsRegistered|getImsRegistrationTechnology|CarrierConfigChange" radio-call-test.log
```

`update phone state, old=X new=Y` and `GET_CURRENT_CALLS {[id=1,STATE...` trace the actual call state machine: `DIALING` → `ALERTING` (ringing) → `ACTIVE` (answered, two-way audio) → disconnect. `onDisconnect: cause=N` gives Android's own `DisconnectCause` enum value — the ones that came up in practice:

| Value | Meaning |
|---|---|
| 1 | `INCOMING_MISSED` — rang, never answered |
| 2 | `NORMAL` — a normal, clean hangup after being connected |
| 3 | `LOCAL` — ended from this device's side (can be a real answered call the user then ended, not necessarily a failure) |

A `PersistAtomsStorage: setup_failed: true` line nearby is Android's own call-metrics classification for "never reached ACTIVE" — it fires for a call ended while still ringing, which is not itself evidence of a network or IMS problem.

## Step 3: watch the actual radio access technology during the call

```bash
grep -a "getRilVoiceRadioTechnology" radio-call-test.log
```

On the tested device, the status-bar network indicator visibly dropped from 5G/LTE to **`E`** (EDGE/2G) for the duration of each call. This is the real, working explanation for why calls succeeded despite VoLTE never registering: this is **CSFB (Circuit-Switched Fallback)** — the modem correctly falling back to the legacy 2G/3G circuit-switched voice network to place a normal call, specifically because IMS/VoLTE isn't available. It's expected, correct fallback behavior on a network without (working) VoLTE roaming, not a malfunction.

## Step 4: confirm with a real, answered call — not just a ring

A call that only reaches `ALERTING` proves the network accepted setup and rang the other end; it does not prove two-way audio worked. Get the other party to actually answer at least once and watch for `GET_CURRENT_CALLS {[id=1,ACTIVE,...` in the log before concluding calling works. On the tested device this was confirmed on both a custom ROM and stock, both directions (an outgoing call reaching `ACTIVE`, and an incoming call being answered), and it held up again after a full conservative debloat (see [`docs/debloat.md`](debloat.md#confirmed-a-full-run-including-stage-5-does-not-break-calls)) — including removal of `com.motorola.attvowifi`, whose name suggests VoWiFi involvement but which had no observed effect on calling.

## An unexplained observation: which Hungarian network the SIM registers on

Two things the device owner noticed that the diagnostics above did not measure, recorded here in case they turn out to matter:

- **From the point where the calling problem went away** (during an earlier reflash cycle, before the radio-log captures in this document), the SIM registered on **Telekom HU** instead of Yettel HU. The home operator's welcome text on entering Hungary also pointed at Telekom HU.
- **Manually selecting** Telekom HU or Vodafone/One HU, earlier on, failed with errors. The exact error text was not recorded.

For comparison, what the captures in this document show: during the answered test calls on stock `V1TDS35H.83-20-5-12`, the radio log and `dumpsys` reported registration on **Yettel HU** (MCC-MNC 216-01) with automatic network selection, and calls worked there over CSFB. So the Telekom observation and the logged Yettel calls come from different times; they were not compared side by side.

**Why it might matter (a hypothesis, not tested):** home operators typically steer roaming SIMs towards preferred visited networks (which is what a welcome text does), and VoLTE/IMS roaming is often only provisioned with some of those partners. If IMS registers only on the preferred partner, IMS never registering on a different visited network would be unsurprising, and it would fit the pattern seen here: `carrier_config` permits IMS while roaming, yet nothing registers. It could also explain why the same SIM behaved differently on another phone in the same city, if that phone had attached to the preferred network. Neither point was established.

**What would test it:** note the registered PLMN (`getprop gsm.operator.numeric`) whenever calling behaviour changes (Hungary: `21601` Yettel, `21630` Telekom, `21670` Vodafone/One); capture the radio log (Step 2) during a failed manual network selection to get the actual reject cause; and check the MMTEL capabilities (Step 1's `dumpsys phone` output) while the phone is registered on Telekom HU.

**A note on operator names:** in every capture here the SIM reported its operator as `NOVA` (MCC-MNC 202-10, matched by `carrier_config` on that MCC-MNC, not on the display name). Operator names are display strings; registration and IMS provisioning key off the MCC-MNC, so a different trading or legal name for the same operator is not expected to affect any of this. The name "Telestet" was raised by the owner but does not appear in any capture from this project, so where it came from is unknown.

## Practical takeaway

If VoLTE/IMS never registers while roaming but `imsvoice.carrier_volte_roaming_available_bool` says it should, don't assume calling is broken — check whether CSFB is quietly doing the job instead. The network indicator dropping to `E`/`3G` during a call attempt, followed by a genuinely answered call in the radio log, is the actual test that matters, not the IMS registration state on its own.
