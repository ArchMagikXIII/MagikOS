# Capture and Sharing

Read this before taking screenshots or screen recordings, extracting text from
the screen, or sharing files with other machines.

## Screenshots

```bash
magikos screenshot                            # Interactive smart-region flow
magikos capture screenshot region             # Select a region
magikos capture screenshot windows            # Pick a window
magikos capture screenshot fullscreen save    # Full screen, straight to disk (no editor)
```

The first argument picks the mode (`smart|region|windows|fullscreen`), the
second what happens with it (`slurp|copy|save`). `save` skips the annotation
editor and prints the saved path. Screenshots land in the configured Pictures
directory (override with `MAGIKOS_SCREENSHOT_DIR`).

## Screen Recording

```bash
magikos screenrecord --fullscreen             # Start recording the full screen
# ...exercise whatever you want on film...
magikos screenrecord --stop-recording         # Stop; prints the saved path
```

Optional flags: `--with-desktop-audio`, `--with-microphone-audio`,
`--with-webcam` (plus `--webcam-device=` and `--webcam-size=`), and
`--resolution=<size>`. Without `--fullscreen` a region picker opens first.
Recordings land in the configured Videos directory (override with
`MAGIKOS_SCREENRECORD_DIR`). Resize a live webcam overlay with
`magikos capture webcam resize <smaller|larger|reset|small|medium|large>`.

If recording fails to start, rerun with `MAGIKOS_SCREENRECORD_DEBUG=true` to
collect a log at `/tmp/magikos-screenrecord.log` worth attaching to a bug
report.

## Text Capture (OCR)

```bash
magikos capture text    # Select a region; extracted text goes to the clipboard
```

## Sharing Files

```bash
magikos share clipboard               # Share the clipboard via LocalSend
magikos share file <path...>          # Share files with nearby devices
magikos share folder <path>           # Share a folder

magikos tailscale send <machine> <file...>    # Taildrop to a tailnet machine
magikos tailscale receive [directory]         # Save incoming Taildrop files
```

Shrink large captures before sharing them:

```bash
magikos transcode <input> [format] [resolution]   # Re-encode pictures/videos for sharing
```
