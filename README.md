<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://shieldcn.dev/header/gradient.svg?title=Player+Widget&subtitle=Now-playing+album+art+for+the+Omarchy+bar&align=center&theme=violet&mode=dark" />
    <img alt="Player Widget" src="https://shieldcn.dev/header/gradient.svg?title=Player+Widget&subtitle=Now-playing+album+art+for+the+Omarchy+bar&align=center&theme=violet&mode=light" />
  </picture>
</p>

<p align="center">
  <a href="LICENSE"><img alt="license" src="https://shieldcn.dev/badge/license-MIT-blue.svg?variant=secondary" /></a>
  <img alt="version" src="https://shieldcn.dev/badge/version-1.0.0-informational.svg?variant=secondary" />
</p>

# Player Widget

An [Omarchy](https://omarchy.org/) shell plugin: the currently playing
album art sits directly in the bar, with a short elided slice of the
title alongside it, and a click opens a small panel with pause, skip
back, and skip forward.

Omarchy already ships a built-in `omarchy.media` bar widget (glyph +
scrolling title, controls behind a right-click popup). This plugin is a
deliberately different take: the thumbnail carries the state at a
glance — art missing or paused looks different from art actively
playing — with just enough title text to identify the track without
opening the panel.

It binds `Quickshell.Services.Mpris` directly rather than the built-in
`omarchy.media` service: Omarchy's `firstPartyServiceFor()` is only
handed out to first-party plugins and to plugins of kind `bar` (a full
custom bar), so an ordinary third-party bar-widget plugin has no route
to it. Player selection (most-recently-active, preferring one that's
actively playing) is reimplemented locally to match.

## Install

```bash
omarchy plugin add https://github.com/Saikomantisu/omarchy-playerwidget.git --enable --yes
omarchy bar move io.github.saikomantisu.playerwidget --after omarchy.clock
```

Plugins run as unsandboxed code inside `omarchy-shell`, so read the source
first — it is one QML file.

### Removing it

```bash
omarchy plugin remove io.github.saikomantisu.playerwidget --yes
```

### Requirements

Omarchy with the Quickshell-based shell (`omarchy-shell`). Nothing else —
no runtime, no daemon, no account, no network access. Nothing is written
to disk. Any MPRIS-capable player (Spotify, browsers, VLC, etc.) is picked
up automatically; no other plugin needs to be enabled.

## The bar widget

- Shows nothing when nothing is playing.
- The thumbnail's border switches to the accent color while playing, and
  back to a plain border when paused.
- An elided slice of the title sits next to the thumbnail. Right-click
  toggles it off if you'd rather keep just the art.
- No art available (some players don't expose one) falls back to a music
  note glyph in the same square.
- Click toggles the panel.

## The panel

Bigger art, title, artist, and three buttons: previous, play/pause, next.
Deliberately nothing else — no seek bar, no volume, no source switcher.
Disabled buttons dim rather than disappear, since a track that can't skip
back is still worth knowing has a "back" button that won't do anything.

## Layout

- `BarWidget.qml` — the whole plugin: bar thumbnail, direct MPRIS binding
  and player selection, and the panel.

Saving any file under `~/.config/omarchy/plugins/` hot-reloads it. Stale
generations can linger, so `omarchy restart shell` is the honest way to
test a change.

## Licence

MIT — see [LICENSE](LICENSE).
