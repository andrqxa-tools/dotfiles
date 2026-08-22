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
~/.config/yt/mpv-input.conf    # key bindings (seek, percent jumps)
~/.config/yt/yt_seek.lua       # the typed «перейти к» prompt
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
mpv playlist), `Enter` selects, `Esc` cancels.

## Playback keys

| Key | Action |
|-----|--------|
| `→` / `←` | seek ±5 s |
| `Shift+→` / `Shift+←` | seek ±30 s |
| `↑` / `↓` | seek ±60 s |
| `0` … `9` | jump to 0 %, 10 % … 90 % of the length |
| `Home` | back to the start |
| `t` or `g` | type an exact position, `Enter` confirms, `Esc` cancels |
| `/` / `*` | volume down/up |
| `m` | mute |
| `Space` | pause |
| `<` / `>` | previous / next entry |
| `[` / `]` | speed |
| `q` | quit |

The `t` prompt accepts `mm:ss`, `h:mm:ss`, bare seconds (`90`), a percentage
(`42%`) and relative jumps (`+30`, `-1:30`). `Backspace` erases. An absolute
target beyond the end is clamped to the end instead of skipping to the next
entry, so a mistyped `1:02:03` in a short clip does not kill playback; relative
jumps keep mpv's behaviour and roll over to the next entry.

Digits are mpv's contrast/brightness/gamma keys by default — useless for
YouTube, hence the percent jumps. Volume is unaffected: `/` and `*` are mpv
defaults too, only `9`/`0` moved. Bindings live in `mpv-input.conf` (loaded with
`--input-conf`, so every other mpv default stays), the prompt in `yt_seek.lua`
(loaded with `--script`). mpv 0.38 added `mp.input.get` for exactly this, but
0.37 — the Ubuntu 24.04 build — has no such API, so the script collects the line
through `any_unicode` the way `console.lua` does; that also shadows `q` while
typing.

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
| `YT_REMOTE_COMPONENTS` | yt-dlp JS challenge solver (default `ejs:github`; set empty to disable) |
| `YT_DOWNLOAD_DIR` | download target (default `~/Music/youtube`) |
| `YT_CONFIG_DIR` | config dir (default `~/.config/yt`) |
| `YT_BOOKMARKS_FILE`, `YT_MPV_AUDIO_CONFIG`, `YT_MPV_VIDEO_CONFIG`, `YT_MPV_INPUT_CONFIG`, `YT_SEEK_SCRIPT` | override single paths |

## Troubleshooting

- **`Sign in to confirm you're not a bot`** — export
  `YT_COOKIES_FROM_BROWSER=firefox` (or `chromium`); it is passed on to `yt-dlp`
  for search, playback and downloads.
  This repository also includes an optional persistent setting in
  [`../Shell/profile.d/youtube.sh`](../Shell/profile.d/youtube.sh).
- **`Only images are available` / `n challenge solving failed`** — the script
  enables yt-dlp's recommended `ejs:github` challenge solver by default. Deno
  must also be installed; use [`../Deno/deno-install.sh`](../Deno/deno-install.sh).
- **`Requested format is not available`** — a stale `yt-dlp`. Run `yt update`,
  or install it with `pipx` if it came from the distro package.
- **`No supported JavaScript runtime could be found`** — a `yt-dlp` warning;
  playback still works, but the format list is truncated. Install the runtime
  with [`../Deno/deno-install.sh`](../Deno/deno-install.sh) — `deno` is the only
  engine `yt-dlp` enables by default — and the high-bitrate audio formats
  (`251 opus 133k`, `140 m4a 129k`) come back.
- **`yt: mpv не найден в PATH`** — re-run `./install-linux.sh`.
- `yt dl` needs `ffmpeg` for mp3 extraction and thumbnail embedding.
