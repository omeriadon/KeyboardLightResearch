# Keyboard Light

A small native SwiftUI app for the built-in keyboard backlight on this Mac. Requires macOS 26 or later. Verified hardware: M2 MacBook Air, Mac14,2, macOS 27.2.

## Build and open

```sh
cd KeyboardLight
./Scripts/build-app.sh
open 'dist/Keyboard Light.app'
```

The build uses Swift Package Manager and makes an ad-hoc signed local app. There are no third-party dependencies, login items, privileged helpers, or network services.

## Controls

Brightness controls apply to the entire keyboard. Routines provide decorative white-light effects with configurable brightness, pace, and short fades. This keyboard has a shared lighting channel, so it cannot display colors or patterns across individual keys.

Launching the app only reads keyboard state. Manual brightness choices apply instantly and remain selected, while the original automatic-brightness and idle-dimming policies are restored immediately afterward.

- **Twinkle:** random timing and brightness clustered near the dim and bright limits, usually jumping to the opposite end, with short fades.
- **Sparkle:** soft flashes close to the bright limit above a dim base level.
- **Breathe:** gradual rises and falls.

Twinkle and Sparkle default to a 120 ms fade, adjustable from 50–500 ms. Breathe uses longer transitions. Set dim and bright levels and pace before pressing Play. Looping is enabled by default; turn it off for timed playback.

Routine playback temporarily suspends idle dimming and automatic brightness, then restores the captured brightness and policies on Stop, tab/window close, sleep, session deactivation, or normal quit. Switching to manual brightness stops the routine first. If restoration fails, the app retains the failed restoration state, provides a Restore action, and blocks new playback until recovered. Forced termination cannot guarantee restoration. The private system interface may change with future macOS releases.

## Backlight wear

Instant brightness changes within the normal range are not expected to damage the backlight. The observed controller uses PWM at approximately 25 kHz; the app changes brightness through Apple's existing driver rather than changing current limits, voltage, or PWM frequency. PWM itself turns LED output on and off rapidly, as described in [Texas Instruments' PWM dimming explanation](https://www.ti.com/document-viewer/lit/html/SSZTAY6).

This is an engineering inference, not an Apple durability guarantee for this exact assembly. The app defaults to short fades for a softer decorative effect. It does not overdrive the backlight.

See the adjacent [investigation report](../investigation.md) for measured PWM state and research limitations.

## Verification

Built and packaged with the full installed Xcode toolchain using Swift Package Manager, with no compiler warnings. Eight mock-backend tests cover nonmutating startup, idle-level capture, cancellation ownership, timed completion, invalid input, and restoration failure/retry. Two deterministic pattern tests check that Twinkle favors visible jumps and respects custom limits. A separate opt-in hardware test played a brief routine on this Mac and checked that brightness and policy state were restored.

```sh
set -o pipefail
DEVELOPER_DIR='/Applications/Xcode 27.2 rc.app/Contents/Developer' swift test 2>&1 | xcsift -f toon -w
```

The hardware test only runs when `KEYBOARD_LIGHT_HARDWARE_TEST=1` is explicitly set. It changes the light briefly and restores the starting state.

The build script selects the installed full Xcode toolchain locally because the globally selected Command Line Tools lack a SwiftUI macro plugin. It does not change `xcode-select`.
