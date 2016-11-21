## mpv-multisock

Automatically moves/renames mpv's JSON IPC socket on startup.

### Use cases

* Automatically pause any playing mpv instance when headphones are unplugged.
* When you start playback in a mpv window, pause any other currently playing mpv windows.

### Installation

Place `multisock.lua` in your `~/.mpv/scripts` or `~/.config/mpv/scripts` directory.

Ensure that `input-ipc-server` is set in `mpv.conf`, and matches the `src_socket`
script option; by default this is `~/.mpv-socket`. The script options can be changed in
`~~/lua-settings/multisock.conf`, where `~~` is your mpv configuration directory, i.e.
the directory containing `mpv.conf`. If the directories do not match, this script will
not work.

### License

GPLv3
