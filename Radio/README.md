# Console radio for mpv

A searchable terminal radio menu backed by `mpv` and `fzf`. The catalog ships
with 51 verified streams grouped into Ukrainian music, rock, metal, jazz,
classical, electronic, ambient/chill, indie/alternative, soul/funk/hip-hop,
reggae/world, retro and news/talk.

## Install

```sh
./install-linux.sh
```

The installer supports `apt-get`, `dnf`, `pacman` and `zypper`. It installs
missing `mpv`/`fzf` packages and deploys the radio files for the current user.
Use `--skip-packages` when the dependencies are already managed elsewhere.

Existing deployed files are preserved as timestamped backups when their
contents differ. The global `~/.config/mpv/mpv.conf` is not changed; radio uses
its isolated `~/.config/radio/mpv.conf`.

## Use

```sh
radio                  # choose a genre, then a station
radio rock             # open one genre directly
radio all              # search all stations
radio random jazz      # play a random station in a genre
radio list             # print the full catalog
radio genres           # print available genres
radio edit             # edit the deployed catalog
radio m3u [file]       # export the catalog as M3U
```

In the `fzf` menu, type to search, use arrow keys to move, `Enter` to select
and `Esc` to cancel. During playback, use `9`/`0` for volume, `m` for mute,
`Space` for pause and `q` to quit.

The station catalog is a TSV file with three fields:

```text
genre<TAB>station name<TAB>stream URL
```
