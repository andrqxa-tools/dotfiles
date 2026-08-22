# shellcheck shell=sh
# YouTube rejects anonymous yt-dlp requests on this network.
# The yt wrapper forwards this setting to search, playback and downloads.
export YT_COOKIES_FROM_BROWSER="${YT_COOKIES_FROM_BROWSER-firefox}"
