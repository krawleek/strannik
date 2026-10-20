# Stage 3 artwork provenance

Source: [Pet Finance App, Stage 3 tasks](https://www.figma.com/design/sZM7SZ1aoBWiBmDS6LqAoC/Pet-Finance-App?node-id=40000217-20793).

- `safety_unknown.png`: original incoming-call avatar, node `40000217:20821`, asset `d1033.svg`; rasterized directly with Sharp at 3× (252×252), transparent background.
- `safety_scammer.png`: original `image 101` overlay, node `40000217:21100`, asset `31aa8.png`. Original transparent pixels preserved.
- `safety_bubble.png`: original Speech Bubble Union, asset `93935.svg`, rasterized directly with Sharp at natural 324×98 for the existing nine-patch speech bubble renderer.

Existing assets reused without alteration: `cat_avatar.png`, `reward_cat.png`, `glasses.png`, `learning_background.png`, `assets/icons/stage_star.png`.

Temporary Figma screenshot exports with an opaque canvas background were discarded. Full-screen reference images are QA evidence only and are not bundled as lesson screens.

## Current topic extension (2026-10-20)

- `safety_finale_cat.png`: original static cat image from `40000215:83238`, asset `e6bba.png`; used at 160×203 logical pixels.
- `safety_celebration_star.png`: original `8cdb1.svg` from `40000215:83252`, rasterized at 3×; used at 46×45 and 40×40.
- `safety_detective.png`: original illustration subtree `40000215:83343` (328×370), exported as a single static scene. Contains no screen controls, lesson text, system bars or full-screen UI.
- `safety_story_cat.png`: original `a0851.png` from `40000215:83359`, used at 64×70.
- `safety_locked.png`: original shield image `5d4cb.png` in unavailable card `40000220:35583`.
- `safety_map_call.png` / `safety_map_email.png`: original phone-off `6e47e.svg` / mail-check `f97a9.svg` from `40000215:83438` / `83444`; directly rasterized at 3× and shown at 62×62.
- `safety_guide_bubble.png`: original guide Union `05592.svg` from `40000220:35620`, transformed to match its Figma orientation and rasterized for the existing patch renderer.

Downloaded assets are bundled locally; no temporary Figma URL is used at runtime.
