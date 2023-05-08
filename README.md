# memo
A recent files menu for mpv.

This script saves your watch history, and displays it in a nice menu.

![Preview](https://user-images.githubusercontent.com/42466980/236659593-59d6b517-c560-4a2f-b30c-cb8daf7050e2.png)

## Installation
Place memo.lua in your mpv `scripts` folder.  
Default settings are listed in memo.conf, copy it to your mpv `script-opts` folder to customize.

The default key to open the history menu is **h**.  
Select a history entry to reopen the file.

This script comes with a simple menu, which gets automatically enhanced for users of [uosc](https://github.com/tomasklaen/uosc).

## Custom keybinds
Four keybinds are provided for use in `input.conf`.  
Example usage: `h script-binding memo-history`

`memo-history`  
Brings up the recent files menu, or closes it if already open. Default key is **h**.

`memo-next`  
Jumps to the next page of history entries, if there is one. Also opens the menu if it's closed.

`memo-prev`  
Jumps to the previous page of history entries, if there is one. Also opens the menu if it's closed.

`memo-last`  
Opens the last non-deleted file that isn't the current file, and isn't in the same directory if `hide_same_dir=yes`. Also closes the menu if it's open.

Navigation keybinds for vanilla menu can be configured through `script-opts/memo.conf`.

## uosc menus and buttons
Adding a menu: append ` #! History` to your `input.conf` keybind, or use this for a menu-only config.
```
# script-binding memo-history #! History
```

Adding a button above timeline: add `command:history:script-binding memo-history?History` to your uosc.conf `controls` option.

## Configuration
All further configuration, like the number of entries to show in menu, is done in `script-opts/memo.conf`.

## Disabling for specific directories
It is possible to disable logging of specific files with any criteria that can be queried through [auto profiles](https://mpv.io/manual/master/#conditional-auto-profiles).  
Below is an example to exclude files when "MyCunnyFolder" is part of the directory path.  
The first line goes in your main config, before any profiles.
```ini
script-opts-append=memo-enabled=yes

[dont-log-my-porn]
profile-cond=string.match(string.lower(string.gsub(require "mp.utils".join_path(get("working-directory", ""), get("path", "")), string.gsub(get("filename", ""), "([^%w])", "%%%1").."$", "")), "mycunnyfolder")~=nil
profile-restore=copy-equal
script-opts-append=memo-enabled=no
```

## What sets this apart from other history scripts?
Some scripts only write a history file without the ability to navigate it.  
Scripts that do, by design, read the entire history before displaying your files.  
This means they will get slower with time, while memo reads only what it needs.  
Despite reading little data, it lets you browse as far back as you'd like.  
The file format used allows you to retroactively change display and filtering options.  
This is the nicest menu out of all history scripts I know about, and has uosc integration.

## Acknowledgements
uosc version check and vanilla menu lifted from [mpv-quality-menu](https://github.com/christoph-heinrich/mpv-quality-menu) (improvements: scroll alignment)  
UTF-8 title truncation from [recent-menu](https://github.com/natural-harmonia-gropius/recent-menu)
