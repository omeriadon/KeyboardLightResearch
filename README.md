# Keyboard backlight investigation

Research and experimental keyboard-brightness controls developed on this Mac. See [investigation](investigation.md) for findings and [primary sources](primary-sources.md) for references. `evidence/` contains the captured diagnostic evidence; `inspect.m`, `probe.m`, and `fade-test.m` are the investigation tools.

[KeyboardLight](KeyboardLight/README.md) is the Swift package and macOS control app. Its build script generates an ad-hoc signed app locally. Generated binaries and build caches are excluded from Git.

`DesktopGlow/` retains the initial desktop-effect prototype from this investigation. The current, complete Metal wallpaper renderer and its performance work are maintained separately in [DesktopGlow](https://github.com/omeriadon/DesktopGlow).
