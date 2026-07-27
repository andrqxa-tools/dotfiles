# Console YouTube for mpv

`yt` is a terminal YouTube player: search from the shell, pick tracks in an
`fzf` menu, listen with `mpv` in audio-only mode — or watch the video inside the
terminal itself. Bookmarks (channels, playlists, single videos) live in a TSV
catalog, same shape as the [`Radio`](../Radio) command.

## Install

```sh
./install-linux.sh
```

The installer supports `apt-get`, `dnf`, `pacman` and `zypper` for `mpv`/`fzf`,
and installs `yt-dlp` through `pipx` — the packaged `yt-dlp` is usually stale and
YouTube breaks it (the Ubuntu 24.04 package resolves *no* playable formats).
Pass `--system-ytdlp` to accept the distro build anyway, or `--skip-packages`
when the dependencies are managed elsewhere.

It deploys:

```text
~/.local/bin/yt
~/.config/yt/bookmarks.tsv      # seeded once, never overwritten afterwards
~/.config/yt/mpv-audio.conf
~/.config/yt/mpv-video.conf
```

The global `~/.config/mpv/mpv.conf` is not touched; `yt` uses its own isolated
mpv configs. Changed files are preserved as timestamped backups.

Keep `yt-dlp` fresh — YouTube changes often:

```sh
yt update
```

## Use

```sh
yt queen bohemian rhapsody     # search, pick, listen
yt https://youtu.be/VIDEO_ID   # play a link straight away
yt v кличко бокс               # same, but video inside the terminal
yt fav                         # pick from bookmarks
yt fav Лекції                  # pick inside one category
yt favv                        # bookmarks, with video
yt add <URL> [name] [category] # add a bookmark (name is fetched when omitted)
yt list [category]             # print bookmarks
yt cats                        # print categories
yt edit                        # edit the deployed catalog
yt dl <query|URL>              # download audio as mp3
yt update                      # upgrade yt-dlp
```

In the `fzf` menu, type to search, `Tab` marks several entries (they become one
mpv playlist), `Enter` selects, `Esc` cancels. During playback: `9`/`0` volume,
`m` mute, `Space` pause, `<`/`>` previous/next, `[`/`]` speed, `q` quit.

Channel and playlist URLs are expanded by `yt` with a flat `yt-dlp` pass before
mpv sees them. Handing a channel URL to mpv directly makes its `ytdl_hook`
resolve every entry in full — minutes of waiting; the flat pass costs a second.
`YT_PLAYLIST_LIMIT` caps how many entries are taken (default 30).

## Video in the terminal

The backend is picked automatically and can be forced with `YT_VO`:

| `--vo` | When it is chosen | Quality |
|--------|-------------------|---------|
| `kitty` | kitty terminal, outside tmux | best |
| `sixel` | foot / wezterm / mlterm / contour, outside tmux | good |
| `tct` | everything else, and always inside tmux | ANSI blocks, works anywhere |

Inside tmux the graphics protocols do not pass through reliably (sixel needs
tmux ≥ 3.4 built with `--enable-sixel`; the Ubuntu package is not), so `tct` is
used. Resolution equals the window size in cells — a smaller font means more
pixels, and `tct` decoding in software is CPU-hungry. Audio mode is the daily
driver; terminal video is a party trick.

## Bookmarks

Three tab-separated fields:

```text
category<TAB>name<TAB>URL
```

Channels, playlists and mixes are all valid URLs. `yt add` fetches the title
itself: the container title for a channel or playlist, the video title for a
single video.

## Environment

| Variable | Meaning |
|----------|---------|
| `YT_SEARCH_LIMIT` | search results requested (default 25) |
| `YT_PLAYLIST_LIMIT` | entries taken from a channel/playlist (default 30) |
| `YT_SHUFFLE=1` | shuffle the playlist |
| `YT_VO` | force `kitty`, `sixel` or `tct` |
| `YT_COOKIES_FROM_BROWSER` | `firefox`, `chromium`, … — see below |
| `YT_DOWNLOAD_DIR` | download target (default `~/Music/youtube`) |
| `YT_CONFIG_DIR` | config dir (default `~/.config/yt`) |
| `YT_BOOKMARKS_FILE`, `YT_MPV_AUDIO_CONFIG`, `YT_MPV_VIDEO_CONFIG` | override single paths |

## Troubleshooting

- **`Sign in to confirm you're not a bot`** — export
  `YT_COOKIES_FROM_BROWSER=firefox` (or `chromium`); it is passed on to `yt-dlp`
  for both playback and downloads.
- **`Requested format is not available`** — a stale `yt-dlp`. Run `yt update`,
  or install it with `pipx` if it came from the distro package.
- **`No supported JavaScript runtime could be found`** — a `yt-dlp` warning;
  playback still works, but the format list is truncated. Install the runtime
  with [`../Deno/deno-install.sh`](../Deno/deno-install.sh) — `deno` is the only
  engine `yt-dlp` enables by default — and the high-bitrate audio formats
  (`251 opus 133k`, `140 m4a 129k`) come back.
- **`yt: mpv не найден в PATH`** — re-run `./install-linux.sh`.
- `yt dl` needs `ffmpeg` for mp3 extraction and thumbnail embedding.
