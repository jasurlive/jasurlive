sudo pacman -S hcxtools
hcxpcapngtool -o capture.hc22000 capture.cap

hashcat -m 22000 -a 0 handshake.hc22000 rockyou.txt -r rules/dive.rule


Kitty-specific: scrollback copy mode

If you still want to grab something mid-scan without stopping it, kitty supports scrollback pager mode:

Ctrl+Shift+H opens scrollback in your $PAGER (less by default) — frozen, scrollable, searchable with /, and copyable normally.
