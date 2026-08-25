# Visual Verification

Read this before finishing any change with a visual effect: Magikos shell
styling and layout, panels, menus, notifications, desktop appearance,
animations, transitions, screenshots, and screen recording flows.

Visual changes must be verified in the running UI in addition to automated
tests. Creating an artifact is not sufficient: inspect it for clipping,
overlap, incorrect spacing, stale state, focus problems, and visual
regressions before finishing.

Take a full-screen screenshot without opening the editor:

```bash
magikos capture screenshot fullscreen save
```

The command prints the saved path and writes to the configured Pictures
directory. Use `magikos screenshot` for the interactive smart-region flow.
Capture reference and candidate states as separate images when changing a
layer-shell surface or layout, then compare both.

Record a short full-screen video for animation, transition, timing, capture, or
screen-recording changes:

```bash
magikos screenrecord --fullscreen
# Exercise the changed behavior.
magikos screenrecord --stop-recording
```

The stop command prints the saved video path in the configured Videos
directory. Review the recording before finishing, and keep it short and focused
on the changed behavior.

For interactive UI work, use `wtype` to simulate keyboard input when available.
Example: start the UI in the background, wait briefly for focus, then run
`wtype -k Right -k Return` to exercise keyboard selection and confirm the
resulting command output or state change. Prefer this over manual-only
verification when a UI returns a selected value or changes a symlink/config.

If a launched UI would otherwise remain open, keep track of its PID and stop it
after the screenshot or recording; avoid broad process kills unless checking
with `ps` first.

SDDM theme previews carry an extra trap: `sddm-greeter --test-mode --theme
/usr/share/sddm/themes/magikos` takes over the screen and can never log anyone
in, because test mode has no connection to the SDDM daemon — pressing Enter on
the password field silently fails and the only way back is a TTY. Run
`magikos-refresh-sddm` first so the preview reflects the repo instead of a
stale installed copy, launch the greeter only once you are ready to inspect
it, and stop that exact PID before finishing; the process ignores SIGTERM, so
end with `kill -9` on the tracked PID.
