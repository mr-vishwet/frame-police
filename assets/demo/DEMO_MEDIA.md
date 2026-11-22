# FRAME POLICE — Demo Media Manifest

Three short videos with genuinely different measurable properties, so a real probe reports different results per file. Collected/constructed 2026-11-22. **Total: 3 files, 8,073,519 bytes (~7.7 MiB)** — under the ~50 MB budget.

All three derive from the **Sintel trailer, © Blender Foundation, CC-BY 3.0** (https://durian.blender.org/). All verified with ffprobe; the defective file's defects were additionally verified with blackdetect, volumedetect, astats, and frame inspection (see below).

## Files

| File | Source | Duration | Resolution / fps | Audio | Size (bytes) | Notes |
|------|--------|----------|------------------|-------|--------------|-------|
| frame-police-clean-720p.mp4 | Sintel trailer 720p — `https://download.blender.org/durian/trailer/sintel_trailer-720p.mp4` | 20.08 s | 1280x720 / 24 | AAC | 3,105,557 | First 20 s, stream copy (no re-encode). The clean control. |
| frame-police-lowres-480p.mp4 | Sintel trailer 480p — `https://download.blender.org/durian/trailer/sintel_trailer-480p.mp4` | 20.08 s | 854x480 / 24 | AAC | 1,700,867 | First 20 s, stream copy. Genuinely lower resolution and bitrate than the clean file. |
| frame-police-defective-mixed.mp4 | CONSTRUCTED from Sintel trailer 720p (see recipe below) | 20.01 s | 1280x720 / 24 | AAC (clipped) | 3,267,095 | Same content as the clean file, with four injected defects. |

## The defective file — construction recipe

Built with ffmpeg from the Sintel trailer 720p (first 20 s). Exact command:

```
ffmpeg -i sintel_trailer-720p.mp4 -t 20 \
 -vf "drawbox=x=0:y=0:w=iw:h=ih:c=black:t=fill:enable='between(t,5,6)+between(t,12,13)',\
drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf:\
text='BREAKING NEWS - THIS HEADLINE RUNS WAY PAST THE RIGHT EDGE OF THE FRAME AND KEEPS GOING':\
fontcolor=white:fontsize=36:x=w-150:y=60:enable='between(t,2,8)',\
drawtext=fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:\
text='[ subtitles below the safe area - half cut off at the bottom edge ]':\
fontcolor=yellow:fontsize=28:x=(w-text_w)/2:y=h-12:enable='between(t,8,14)'" \
 -af "volume=4.0" -c:v libx264 -crf 20 -preset medium -c:a aac -b:a 128k \
 frame-police-defective-mixed.mp4
```

### Injected defects (all four verified measurable)

1. **Black frames** — full-frame black at t=5–6 s and t=12–13 s (`drawbox` fill). Verified with `blackdetect` (d=0.5, pix_th=0.10): the defective file shows black at 5.0–6.04 s (absent in the clean file) and extends the trailer's natural dark scene from 9.17–12.13 s to 9.17–13.04 s. The clean file's own black segments (0–1.21 s fade-in, 15.71–16.5 s, 17.5–18.33 s) are unchanged.
2. **Clipped audio peaks** — 4x linear gain (`volume=4.0`). Verified with `volumedetect` + `astats`: mean volume −10.7 dB vs −16.6 dB for the clean file; decoded peak level +12.95/+13.41 dB vs +0.47/+0.76 dB for the clean file (the +13 dB peaks are the clipping signature — a mastered trailer peaks near 0 dB).
3. **Burnt-in text overflow** — headline drawn at x=w−150, t=2–8 s, so it runs off the right edge of the frame. Verified by frame inspection at t=4 s: only "BREAKI…" is visible at the top-right, cut off at the frame edge.
4. **Subtitles below the safe area** — subtitle line at y=h−12, t=8–14 s, half cut off by the bottom edge. Verified by frame inspection at t=10 s: the yellow subtitle's lower half is clipped by the frame edge.

## How a probe should tell the three files apart

- Clean vs low-res: resolution (1280x720 vs 854x480) and bitrate (~1.2 Mbps vs ~0.68 Mbps).
- Clean vs defective: identical resolution/duration, but the defective file has extra black-frame segments, ~6 dB louder mean volume, peak levels ~13 dB over full scale, and burnt-in text (OCR-detectable) at the frame edges.
