# M2 MacBook Air keyboard backlight investigation

Date: 2026-10-29. Machine: MacBook Air, Mac14,2, Apple M2, macOS 27.2 build 26B123. No serial number is needed for these findings.

## Findings

1. **The fade can be bypassed on this Mac.** A CoreBrightness request with `fadeSpeed:0` changed the PWM driver's reported state to its final value by the first completed sample, 1.863 ms after the test began. A request with `fadeSpeed:350` produced a gradual ramp. This is a measured driver-state result, not an optical timing measurement.
2. **No software-addressable per-key backlight was found.** The live hardware exposes one PWM channel for the keyboard. The exact-model Linux device tree independently describes one white keyboard backlight on that same PWM controller. This is strong evidence that independent key illumination needs different hardware, rather than another private brightness API. It is not a circuit-level proof that every conceivable undocumented mechanism is absent.
3. **No kernel modification is needed to remove the fade.** The successful test ran as the ordinary user, without sudo, an entitlement, a kernel extension, disabling SIP, a direct SMC write, or mapping hardware registers.

## Local evidence: physical control

IORegistry reports this hierarchy:

```
fpwm1@35044000                    AppleARMIODevice
  AppleS5L8920XFPWM
    kbd-backlight@0               AppleARMPWMDevice
```

The keyboard PWM node has `reg = 0`, a 24,000,000 Hz clock, and a default frequency of 25,000 Hz. The observed high/low cycle counts sum to 960, consistent with 24 MHz / 25 kHz. Its brightness mapping includes two nits-to-PWM tables. Saved evidence: [PWM node](evidence/kbd-backlight.txt) and [device-tree node](evidence/kbd-devicetree.txt).

The operating system also exposes a privileged virtual HID device named `Keyboard Backlight`, keyboard identifier 95158272. Its feature descriptors contain scalar controls with report count 1, rather than a per-key array. Report 1 contains two 32-bit scalar elements; report 3 contains one 8-bit and one 32-bit element. Their meanings must not be guessed solely from their usages. This virtual-device identifier identifies the keyboard as a whole, not an individual key. Saved evidence: [targeted HID descriptor and elements](evidence/backlight-hid.plist).

The internal keyboard's HID descriptor separately advertises standard LED usages 1–5. Standard status indicators, including Caps Lock, do not establish independent illumination of the key legends. No vendor HID reports were written.

The Asahi-authored Linux device tree for **this exact M2 Air J413 model** declares one white `kbd_backlight` on `fpwm1`, channel 0. The Apple PWM driver's apply method directly updates duty-cycle registers and commits the update; it contains no fade loop. These sources corroborate the local channel count and distinguish physical PWM capability from macOS animation policy. [Exact-model source](https://raw.githubusercontent.com/torvalds/linux/master/arch/arm64/boot/dts/apple/t8112-j413.dts), [PWM driver](https://raw.githubusercontent.com/torvalds/linux/master/drivers/pwm/pwm-apple.c).

The likely optical implementation uses a shared light-distribution sheet. Exact M2 repair evidence and related-model teardown evidence are qualified separately in [primary-sources.md](primary-sources.md). This investigation did not dismantle the keyboard or inspect its exact electrical schematic. The conclusion is about the supported and observed hardware control, not a claim that a single LED physically illuminates every key.

## Local evidence: private framework and animation

A small Objective-C inspector loads the installed CoreBrightness from the dyld shared cache and enumerates Objective-C runtime methods. The relevant interfaces are present on this OS:

```objc
- (NSArray *)copyKeyboardBacklightIDs;
- (float)brightnessForKeyboard:(uint64_t)keyboard;
- (float)backlightLevelForKeyboard:(uint64_t)keyboard;
- (BOOL)setBrightness:(float)value
           fadeSpeed:(int)duration
              commit:(BOOL)commit
         forKeyboard:(uint64_t)keyboard;
```

The actual runtime encoding for the last method is `B36@0:8f16i20B24Q28`: Boolean result, float brightness, int duration, Boolean commit, unsigned 64-bit keyboard identifier. That avoids guessing types or hardcoding the old keyboard identifier 1 used in historical examples. Saved evidence: [method inventory](evidence/corebrightness-methods.txt), [inspector source](inspect.m).

LLDB launched only our own read-only probe. It disassembled the installed framework's code after loading it; no system daemon was attached or patched. Important findings:

- `KeyboardBrightnessClient` packages `Brightness`, `FadeSpeed`, and `Commit` in a dictionary and sends it as `KeyboardBacklightBrightness` through a `BrightnessSystemClient` keyboard property operation.
- `setBrightness:forKeyboard:` chooses **350** for a positive value and **500** otherwise, then delegates to the explicit-duration setter. These are milliseconds, consistent with the measured ramp and historical independent source.
- `KeyboardBacklight` contains `rampToBrightness:withDuration:`, `startRamp`, `stopRamp`, and timer routines. The ramp-start code checks for a positive duration.
- Several HID-curve implementations participate in brightness conversion. Their presence alone does not establish that every implementation runs on this machine.

Saved evidence: [client and backlight disassembly](evidence/corebrightness-disassembly.txt), [default durations and ramp disassembly](evidence/fade-disassembly.txt). Historical corroboration: [KBPulse private interface](https://raw.githubusercontent.com/EthanRDoesMC/KBPulse/main/KBPulse/KeyboardBrightnessClient.h).

The launchd configuration `/System/Library/LaunchDaemons/com.apple.corebrightnessd.plist` associates `/usr/libexec/corebrightnessd` with the Mach service `com.apple.backlightd`. This, the client dispatch, and the ramp implementation place animation policy in the CoreBrightness software stack. This investigation did not trace every instruction from daemon to PWM register.

The user's observed roughly two-second fade was not reproduced as a universal constant. It could involve a different caller, a different duration, idle/wake transitions, or another policy path. The precise source of that particular two-second observation remains unresolved.

## Controlled experiment

Initial active brightness was 0.8125 (81.25%), auto-brightness was disabled, and the idle timeout was 30 seconds. Target brightness was 0.6125 (61.25%).

Early tests encountered idle dimming: successful setters could still leave the effective output at zero. That was a policy interaction, not proof that the setter was broken. We temporarily suspended idle dimming with the existing private client method, captured the resulting active brightness, allowed the wake ramp to settle, and restored the suspension state afterward.

The definitive experiment started both commands at PWM high/low counts **262/698**. With 350 ms requested, the high count progressed through intermediate values before reaching **188/772**. With zero requested, the first completed sample at **1.863 ms** already reported **188/772**, and subsequent samples remained there.

Readback of `brightnessForKeyboard:` and `backlightLevelForKeyboard:` jumped to the target even during the gradual PWM ramp. **Those API values alone cannot prove that a fade has been removed.** The changing PWM properties supply the stronger evidence.

The counts are read through `IORegistryEntryCreateCFProperty`, not directly from physical registers. They are driver-reported state, with polling and IPC latency. There was no photodiode, oscilloscope, or camera timing measurement. The experiment establishes removal of the software ramp; it does not establish an exact sub-millisecond optical latency or a guaranteed maximum update rate.

Artifacts:

- [Final data](evidence/settled-fade-test.csv)
- [Restoration log](evidence/settled-fade-test-status.txt)
- [Comparison chart](fade-comparison.html)
- [Bounded experiment source](fade-test.m)

The source validates the available selectors, accepts only a single discovered keyboard, bounds brightness changes to 0…1, reads PWM properties without writing them, and restores brightness and idle-dimming suspension in `@finally`. SIGINT and SIGTERM request orderly exit through that cleanup. SIGKILL or process failure cannot guarantee cleanup. No always-running service was installed.

The final log confirms brightness restored to **0.812500** and idle suspension restored to **false**. Normal idle dimming can subsequently return effective output to zero; that is expected. Auto-brightness and the idle timeout were not changed.

## What is now feasible

A user-space tool can apply whole-keyboard brightness immediately, choose a fade duration, or generate custom whole-keyboard transitions. The central verified operation is:

```objc
[client setBrightness:brightness
           fadeSpeed:0
              commit:NO
         forKeyboard:discoveredKeyboardID];
```

This test used `commit:NO` for transient changes. That flag is not a blanket guarantee of zero side effects: earlier zero-brightness tests toggled the muted preference through CoreBrightness; a later nonzero restore cleared it. Production code should explicitly account for muted, idle, suppressed, and auto-brightness states. Private interfaces may change with OS updates. A production implementation should re-check the selector encodings as well as their existence, and monitor policy interaction rather than treating a successful Boolean return as a hardware measurement.

The evidence does not support lighting WASD independently, assigning colors to keys, or creating spatial patterns across the built-in keyboard. A shared scalar channel can produce temporal effects across the whole keyboard, but cannot encode independent spatial brightness values.

## Investigation limits

Installed candidate apps included Keylume, BetterDisplay, and Karabiner-Elements. Keylume 2.0.0 was selected for static inspection; its native artifact SHA-256 is `98ea1f2f9097f54e3a30e07ec99db987cf8e05285d7982ec7b871eb330fd18b5`. REA opened the artifact, but its procedure search exceeded the 300-second tool deadline. The session was closed. No claim about that app's actual backlight implementation is made. The successful framework/PWM experiment does not depend on reversing an installed app.

No arbitrary IOKit selectors, raw HID output commands, SMC keys, kernel patches, or firmware writes were tested. Older Intel `LKSB` examples were not assumed to apply to this Apple Silicon PWM path. No kernel panic occurred. These bounded probes do not constitute a guarantee that every future private-API call is risk-free.
