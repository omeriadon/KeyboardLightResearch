# Keyboard backlight: primary-source research

Investigated 2026-10-29. Target supplied by parent: MacBook Air M2, Mac14,2, macOS 27.2. This document contains source research only; it does not claim any local hardware test. Upstream `master`/`main` URLs are mutable.

## Exact-model hardware control

**Observed in source:** Linux's Asahi-authored `t8112-j413.dts` explicitly identifies the 13-inch MacBook Air M2 (2022), J413. It declares one white `kbd_backlight` LED under `pwm-leds`, connected to `fpwm1`, channel 0, with a 40,000 ns period, maximum logical brightness 255, and `default-state = keep`. The board enables `fpwm1`. There is no per-key LED array in this keyboard-backlight definition. [Exact-model device tree](https://raw.githubusercontent.com/torvalds/linux/master/arch/arm64/boot/dts/apple/t8112-j413.dts), lines 14–33 and 85–87.

**Observed in source:** The M2 SoC description locates `fpwm1` at MMIO base `0x235044000`, length `0x4000`, compatible with `apple,t8112-fpwm` and `apple,s5l-fpwm`. [M2 device tree](https://raw.githubusercontent.com/torvalds/linux/master/arch/arm64/boot/dts/apple/t8112.dtsi).

**Inference:** The supported physical control is a single whole-keyboard illumination channel. These sources strongly oppose the hypothesis of a hidden software-addressable LED for every key. A Linux description alone cannot mathematically exclude an undocumented controller or unused hardware. Complete proof would require the exact backlight assembly schematic or destructive tracing, neither performed here. The 255 maximum is the Linux LED abstraction; it is not proof of an eight-bit hardware limit.

## Does hardware force a slow fade?

**Observed in source:** The Asahi-authored Apple PWM driver registers one channel. Its apply function calculates on/off cycle counts from duty cycle and period, writes them to offsets `0x1c` and `0x18`, then writes enable/output-enable/update flags to offset `0x00`. Disabling writes zero to control. There is no multistep fade, delay, timer, or two-second interpolation in that function. The comment says existing devices use a 24 MHz system clock. [Apple PWM driver](https://raw.githubusercontent.com/torvalds/linux/master/drivers/pwm/pwm-apple.c), lines 20–27, 39–67, 101, 114–116.

**Observed in source:** The generic `pwm-leds` brightness setter computes duty cycle as period × requested brightness / maximum brightness, then applies that state. It also contains no interpolation loop. [PWM LED driver](https://raw.githubusercontent.com/torvalds/linux/master/drivers/leds/leds-pwm.c), lines 39–62.

**Inference:** A slow fade is not inherent to the documented M2 keyboard PWM control path. This supports searching macOS software for an animation policy. It does not prove that ordinary macOS applications can reach that control path directly, or establish an optical latency measurement.

## macOS private API: explicit duration exists

**Observed in source:** KBPulse's Objective-C bridge declares `KeyboardBrightnessClient` methods including `setBrightness:fadeSpeed:commit:forKeyboard:` with parameter types `float`, `int`, Boolean, and 64-bit keyboard identifier. Its animator passes a caller-selected duration directly into `fadeSpeed`, committing the change for keyboard 1. [Header](https://raw.githubusercontent.com/EthanRDoesMC/KBPulse/main/KBPulse/KeyboardBrightnessClient.h), [Animator implementation](https://raw.githubusercontent.com/EthanRDoesMC/KBPulse/main/KBPulse/KBPAnimator.m).

The header's historical comments give automatic dimming as 500 ms and manual fading as 350 ms. These comments date to 2021 and are not a specification for macOS 27.2. They also mean that a universal fixed two-second duration should not be assumed from older API examples. [Header](https://raw.githubusercontent.com/EthanRDoesMC/KBPulse/main/KBPulse/KeyboardBrightnessClient.h).

**Author's reported test scope:** KBPulse's README names a 2020 M1 MacBook Pro as personally tested and exposes fade-duration configuration. That is historical support for whole-keyboard animation, not current proof on this Mac. [KBPulse README](https://github.com/EthanRDoesMC/KBPulse).

## Important counterexample: success can be misleading

**Author's reported observations, not independently reproduced:** Dim Keys' maintainer reports that on Mac17,9/M5 Pro/macOS 26.6.2, HID SetReport and `KeyboardBrightnessClient.setBrightness:fadeSpeed:commit:forKeyboard:` can report success without changing hardware. Their working path is `BrightnessSystemClient` property `KeyboardBacklightBrightness`. They attribute direct-HID restrictions to an entitlement and report the application also working on M4 Air. These are different hardware and OS versions from the target. Treat the entitlement diagnosis and universal wording as this author's conclusions rather than Apple's contract. [Maintainer's README, hardware and nonworking-path sections](https://github.com/dmartoon/MacBook-Keyboard-Backlight-Limiter).

**Observed in source:** The maintained Swift implementation loads CoreBrightness, enumerates keyboard identifiers, prefers a built-in keyboard, checks the brightness property exists, and writes a normalized NSNumber through `setProperty:withKey:keyboardID:`. This write has no exposed duration argument. [Implementation](https://raw.githubusercontent.com/dmartoon/MacBook-Keyboard-Backlight-Limiter/main/Sources/KeyboardBacklightLimiter/KeyboardBacklight.swift), lines 42–78.

**Implication:** Local tests must observe the actual PWM or light output, not rely on a Boolean return or target-brightness property. Testing the duration parameter is justified; its success is not established by these sources.

## Physical light distribution

**Direct repair account, exact model:** D-LIFE's A2681/M2 keyboard-replacement account documents peeling a backlight sheet off the keyboard assembly (section 4). This supports a sheet-style illumination assembly. The article does not provide a circuit schematic or individually trace LED connections. [M2 A2681 repair account](https://ekishousyuuri.com/keyboard/37410).

**Direct teardown, different model:** iFixit's 16-inch 2019 MacBook Pro teardown describes a flexible diffuser carrying light from edge LEDs. This is evidence of the shared-light-guide construction in a related Magic Keyboard generation, not direct proof that the M2 Air uses an identical assembly. [iFixit teardown, step 11](https://www.ifixit.com/Teardown/MacBook+Pro+16-Inch+2019+Teardown/128106).

## Why old SMC examples need qualification

**Observed in source:** Linux `applesmc.c` explicitly describes Intel-based Apple computers and defines `LKSB` as a two-byte keyboard backlight key. It is an older Intel path and should not be assumed to identify the M2 control path. [Linux applesmc driver](https://raw.githubusercontent.com/torvalds/linux/master/drivers/hwmon/applesmc.c), lines 1–4 and 58.

**Observed in source:** AsusSMC emulates both `LKSB` and `LKSS` in a VirtualSMC plugin. This confirms these names occur in older compatibility code; it does not establish that they exist or control backlight on the target Apple Silicon machine. [AsusSMC source](https://github.com/hieplpvip/AsusSMC/blob/master/AsusSMC/AsusSMC.cpp), lines 844–850.

## Open questions for local investigation

1. Which CoreBrightness classes/selectors are present on macOS 27.2, and what are their actual Objective-C encodings?
2. Which process implements the observed fade, and do zero-duration commands reach the PWM state?
3. Do installed control apps call legacy KeyboardBrightnessClient, BrightnessSystemClient, HID reports, or another route?
4. Is a driver-accessible brightness reading actual PWM or merely target state?
5. Does macOS enforce entitlement checks on this M2's PWM/HID path, rather than the different M5 system in the counterexample?

No public source found in this investigation documents a per-key brightness command for the M2 Air built-in keyboard. The exact-model single-PWM definition is the strongest evidence against software-only per-key control.
