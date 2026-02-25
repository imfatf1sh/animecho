Experimental MPV support, works out-of-the-box on archlinux. Needs a custom build of mpv or mpv-android otherwise.

Specifically, Mpv needs to be linked against LuaJIT instead of Lua. It is usually trivial to do such recompilation.

This script uses native UDP networking APIs, accessed via FFI provided by LuaJIT.

On desktops, copy the Lua script file into mpv's directory, you can read this: https://mpv.io/manual/master/#files

You can also load the script manually from command-line: https://mpv.io/manual/master/#options-script

This option can also be written in your mpv.conf file.

On Android, to make the script accessible by mpv, copy it into your storage -> "Android" -> mpv's package ID -> "data" -> "files", create the directory if needed.

This script sends playback progress (an 32-bit integer, which is 4 bytes) to the app every 1s.

You can change the address if mpv and app are running on different devices.

This script constantly attempts to communicate with the configured address, even if it can't reach the app. This probably doesn't harm. (TODO: better ways?)
