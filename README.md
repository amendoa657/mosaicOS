<div align="center">

# Mosaic OS

**A Quickshell desktop for Hyprland: a liquid island, a glass dock and themes that change colors *and* shapes.**

My first rice.

![Mosaic OS with the Horizonte theme](docs/media/horizonte-desktop.webp)

</div>

> [!NOTE]
> **About authorship:** the QML code was written with the help of **Claude** (Anthropic's AI). **The whole visual idea, the design and the mockups are mine.** Every screen, animation and theme started as my sketch and my direction; Claude helped turn them into code.

---

## Demo

![Mosaic OS in motion, Gruvbox theme](docs/media/demo-gruvbox.gif)

## Features

- **The island:** a floating pill at the top of the screen that morphs with spring physics. It turns into:
  - a quick panel (weather, music, toggles, tray, record button);
  - a compass of the workspaces (hold <kbd>Super</kbd>);
  - live events: volume, brightness, music, screenshots, charging and phone calls (KDE Connect).
- **Liquid notifications:** they drop out of the island as a goo bubble and melt back into it (SDF shaders).
- **Start menu and quick notes,** each in a card fused to the island.
- **Glass dock** with a subtle macOS-style wave. It shows on an empty desktop, hides over windows and comes back when you touch the bottom edge.
- **Sidebars:**
  - left: translator, to-do list and AI chat;
  - right: quick toggles, sliders, phone, calendar and notifications.
- **Screen recorder:** full screen with system audio, mic or no sound, plus a live recording indicator in the island.
- **Wallpaper and theme window:** wallpapers with search and color filters, desktop widget toggles, recording settings, plus glass, transparency, darkness and grain for the widgets, the dock and every app.
- **Liquid glass** on the island, dock and sidebars through the hyprglass plugin, adjustable from the UI.

## Themes

A theme here is **colors, shapes and style**. It paints the shell, Hyprland (borders and corners), kitty with the starship prompt, Neovim, the Mosaic Store and the Zen browser.

| | |
|---|---|
| **Mosaic**<br>Soft glass and round pills. All colors come from the wallpaper (Matugen). | ![Mosaic](docs/media/mosaic-desktop.webp) |
| **Gruvbox**<br>Warm neo-brutalism: square shapes, solid surfaces, cream outlines and hard orange shadows that buttons sink into. | ![Gruvbox](docs/media/gruvbox-desktop.webp) |
| **Horizonte**<br>Dark only, a 70s sunset: a navy sky, an orange horizon, serif titles and film grain on everything. A Hyprland screen shader puts the grain on the apps too, and it turns itself off in full screen games. | ![Horizonte](docs/media/horizonte-desktop.webp) |

## Gallery

### The island

| Mosaic | Gruvbox | Horizonte |
|---|---|---|
| ![](docs/media/mosaic-island.webp) | ![](docs/media/gruvbox-island.webp) | ![](docs/media/horizonte-island.webp) |

### Sidebars

| Right (Mosaic) | Right (Gruvbox) | Right (Horizonte) | Left (Horizonte) |
|---|---|---|---|
| ![](docs/media/mosaic-sidebar-right.webp) | ![](docs/media/gruvbox-sidebar-right.webp) | ![](docs/media/horizonte-sidebar-right.webp) | ![](docs/media/horizonte-sidebar-left.webp) |

### Wallpaper and theme window

| Wallpapers (Gruvbox) | Wallpapers (Mosaic) | Look settings and grain (Horizonte) |
|---|---|---|
| ![](docs/media/gruvbox-picker.webp) | ![](docs/media/mosaic-picker.webp) | ![](docs/media/horizonte-look.webp) |

### Start menu

![Start menu fused to the island](docs/media/horizonte-start.webp)

## Requirements

- **Hyprland 0.57+** with the Lua config.
- **Quickshell.**
- **hyprglass** plugin, for the liquid glass.
- **Matugen 4,** for the wallpaper colors.
- **wf-recorder,** for screen recording.
- **KDE Connect,** optional, for the phone events.
- **Fonts:**
  - Space Grotesk and JetBrains Mono;
  - Fraunces (`ttf-fraunces-variable`), for the Horizonte titles.

## Install

Mosaic OS lives next to [illogical-impulse](https://github.com/end-4/dots-hyprland) and swaps with it, so start from a working illogical-impulse setup.

```bash
git clone https://github.com/amendoa657/mosaicOS ~/.config/quickshell/mosaic
```

```bash
~/.config/quickshell/mosaic/scripts/mosaic-os.sh ligar
```

`hypr/mosaic.lua` holds the glass presets and the keybinds; source it from your Hyprland config. To go back to illogical-impulse:

```bash
~/.config/quickshell/mosaic/scripts/mosaic-os.sh desligar
```

## Keybinds

| Keys | What it does |
|---|---|
| <kbd>Super</kbd> | Start menu (hold it for the workspace compass) |
| <kbd>Ctrl</kbd> <kbd>Super</kbd> <kbd>M</kbd> | Switch between Mosaic OS and illogical-impulse |
| <kbd>Super</kbd> <kbd>Alt</kbd> <kbd>N</kbd> | Quick notes |

Everything also has an IPC, for example:

```bash
qs -c mosaic ipc call theme set horizonte
```

## Docs

- [`DOCS.md`](DOCS.md): every part of the code explained, from the shaders and springs to the theme system (in Portuguese).
- [`VISAO.md`](VISAO.md): the design decisions, in order (in Portuguese).

## Credits

- [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse): the shell Mosaic OS started from. Its services and many of its widgets are still underneath.
- hyprdots: ideas for the floating island and the wallpaper index.
- hyprglass: the liquid glass.
- **Wallpapers** belong to their authors. The Horizonte wallpaper is the hero image from Anthropic's Claude Opus 5.5 page.

## License

Mosaic OS is built on illogical-impulse, which is licensed under the GPL-3.0, so this project follows the same license.
