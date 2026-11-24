#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

export PATH="$HOME/.local/bin:$PATH"

# Ignore duplicate commands in history
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
PROMPT_COMMAND='history -a; history -n'

export LS_COLORS='di=1;34:ln=1;36:ex=1;32:fi=0:*.js=38;5;220:*.jsx=38;5;220:*.ts=38;5;220:*.tsx=38;5;220:*.mjs=38;5;220:*.py=38;5;39:*.sh=38;5;114:*.c=38;5;81:*.cpp=38;5;81:*.h=38;5;81:*.rs=38;5;208:*.go=38;5;81:*.java=38;5;208:*.php=38;5;141:*.rb=38;5;204:*.lua=38;5;39:*.html=38;5;208:*.css=38;5;213:*.scss=38;5;213:*.json=38;5;114:*.yaml=38;5;114:*.yml=38;5;114:*.toml=38;5;114:*.xml=38;5;114:*.ini=38;5;114:*.conf=38;5;114:*.env=38;5;114:*.md=38;5;114:*.mdx=38;5;114:*.txt=38;5;250:*.log=38;5;244:*.csv=38;5;150:*.sql=38;5;39:*.pdf=38;5;203:*.docx=38;5;203:*.xlsx=38;5;82:*.pptx=38;5;208:*.png=38;5;213:*.jpg=38;5;213:*.jpeg=38;5;213:*.gif=38;5;213:*.webp=38;5;213:*.svg=38;5;213:*.mp3=38;5;141:*.wav=38;5;141:*.flac=38;5;141:*.mp4=38;5;205:*.mkv=38;5;205:*.avi=38;5;205:*.webm=38;5;205:*.zip=38;5;208:*.tar=38;5;208:*.gz=38;5;208:*.xz=38;5;208:*.zst=38;5;208:*.7z=38;5;208:*.rar=38;5;208:*.iso=38;5;208:*.db=38;5;39:*.sqlite=38;5;39:*.lock=38;5;244:*.bak=38;5;244:*.tmp=38;5;244:*.patch=38;5;150:*.diff=38;5;150'

bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

alias grep='grep --color=auto'

git_branch() {
    local branch
    branch=$(git branch --show-current 2>/dev/null)
    [[ -n "$branch" ]] && printf "(%s)" "$branch"
}

PS1='\[\e[38;5;117m\]\u@\h \[\e[38;5;110m\]\w\[\e[38;5;46m\]$(git_branch)\[\e[38;5;117m\]❯ \[\e[0m\]'

eval "$(zoxide init bash)"

cd() {
    if [ -d "$1" ] || [ -z "$1" ]; then
        builtin cd "$@"
    else
        z "$@"
    fi
}


batterylive() {
    watch -n 2 'upower -i "$(upower -e | grep BAT)" | grep -E "energy:|energy-full:|energy-rate:|percentage:|time to empty:"'
}

batteryrep() {
    upower -i "$(upower -e | grep BAT)" | grep -E 'state|energy'
}

c() {
    setsid -f code . >/dev/null 2>&1
}

scannetw() {
    local subnet ip mac vendor

    subnet=$(ip -4 route get 1.1.1.1 2>/dev/null |
        awk '{for(i=1;i<=NF;i++) if($i=="src") {split($(i+1),a,"."); print a[1]"."a[2]"."a[3]; exit}}')

    if [[ -z "$subnet" ]]; then
        echo "Could not detect subnet."
        return 1
    fi

    echo "Scanning $subnet.0/24..."

    for i in {1..254}; do
        ping -c 1 -W 1 "$subnet.$i" >/dev/null 2>&1 &
    done
    wait

    printf '\033[2J\033[H'
    printf "%-16s %-18s %s\n" "IP" "MAC" "VENDOR"
    printf '%s\n' "------------------------------------------------------------"

    ip neigh show |
    awk -v subnet="$subnet" '
        $1 ~ "^" subnet "\\." &&
        $0 ~ /lladdr/ {
            for(i=1;i<=NF;i++)
                if($i=="lladdr") {
                    print $1, tolower($(i+1))
                    break
                }
        }
    ' |
    while read -r ip mac; do
        vendor=$(curl -fsS --max-time 3 "https://api.macvendors.com/$mac" 2>/dev/null)
        printf "%-16s %-18s %s\n" "$ip" "$mac" "${vendor:-Unknown}"
    done
}

copy() {
    : > ~/.copyfiles
    for f in "$@"; do realpath -e -- "$f" >> ~/.copyfiles || return 1; done
}

cpaste() {
    [[ -s ~/.copyfiles ]] || { echo "Nothing to copy"; return 1; }
    while IFS= read -r f; do
        [[ -e "$f" ]] && cp -anv -- "$f" .
    done < ~/.copyfiles
    rm -f ~/.copyfiles
}

grab() {
    : > ~/.grabfiles
    for f in "$@"; do realpath -e -- "$f" >> ~/.grabfiles || return 1; done
}

gpaste() {
    [[ -s ~/.grabfiles ]] || { echo "Nothing to move"; return 1; }
    while IFS= read -r f; do [[ -e "$f" ]] && mv -vn -- "$f" .; done < ~/.grabfiles
    rm -f ~/.grabfiles
}

cc() {
    [[ $# -gt 0 ]] || {
        echo "Usage: fc <file|folder> [...]"
        return 1
    }

    local uris=()
    local file

    for file in "$@"; do
        if [[ -e "$file" ]]; then
            uris+=("$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$file")")
        else
            echo "✗ Not found: $file"
        fi
    done

    ((${#uris[@]})) || return 1

    {
        printf 'copy\n'
        printf '%s\n' "${uris[@]}"
    } | wl-copy --type 'x-special/gnome-copied-files' &&
    printf '%s\r\n' "${uris[@]}" | wl-copy --type 'text/uri-list'

    echo "✓ Clipboard prepared: ${#uris[@]} item(s)"
}

wifi() {
    nmcli -f IN-USE,SSID,SIGNAL,SECURITY device wifi list
}

connect() {
    nmcli --ask device wifi connect "$*"
}

scale1() {
    sed -i 's/scale = [0-9.]*/scale = 1/' ~/.config/hypr/monitors.lua
}

scale2() {
    sed -i 's/scale = [0-9.]*/scale = 1.25/' ~/.config/hypr/monitors.lua
}

# Find files by name
ff() {
    find . -iname "*$1*"
}

# Find text inside files
ft() {
    grep -Rni -- "$1" .
}

#git clone from jasurlive
gitclone() {
    local repo="$1"
    if [ -z "$repo" ]; then
        read -rp "Repo name: " repo
    fi
    [ -z "$repo" ] && { echo "No repo name given."; return 1; }
    git clone --depth 1  "https://github.com/jasurlive/${repo}.git" && cd "$repo"
}

gpr() {
    gh pr create && gh pr merge --merge --delete-branch
}

usb() {
    local mountpoint="/mnt/usb"

    if [[ "$1" == "unmount" ]]; then
        cd ~
        sudo umount "$mountpoint" && echo "USB unmounted."
        return
    fi

    if [[ -z "$1" ]]; then
        lsblk -o NAME,TRAN,LABEL,SIZE,FSTYPE,MOUNTPOINTS
        return
    fi

    local dev="/dev/$1"

    if [[ ! -b "$dev" ]]; then
        echo "Device not found: $dev"
        return 1
    fi

    sudo mkdir -p "$mountpoint"
    sudo mount "$dev" "$mountpoint" || return 1

    echo "Mounted at: $mountpoint"
    cd "$mountpoint"
}

bind '"\e1":"sudo airmon-ng start wlp1s0; sudo airodump-ng wlp1s0mon"'
bind '"\e2":"sudo airodump-ng -d BSSID -w FILE  -c CH wlp1s0mon"'
bind '"\e3":"sudo aireplay-ng -0 10 -a BSSID -c STATION wlp1s0mon"'
bind '"\e4":"sudo  aircrack-ng -w ../hack/rockyou.txt file-01.cap"'
bind '"\e5":"editcap -F pcapng AAA-01.cap AAA-01.pcapng"'
bind '"\e6":"hcxpcapngtool -o outp.hc22000 inp-01.pcapng"'
bind '"\e7":"hashcat -m 22000 -a 3 -w 3 name.hc22000 ?d?d?d?d?d?d?d?d"'
bind '"\e9":"sudo airmon-ng stop wlp1s0mon"'

alias fm='xdg-open .' #uses whatever is the default filemanager, opens current path in fm
alias fr='firefox &'
alias tg='Telegram &'
alias hs='history'
alias edithypr='nano ~/.config/hypr/hyprland.lua'
alias venv='source .venv/bin/activate'
alias shut='sudo shutdown now'
alias reboot='sudo reboot now'
alias copytoacer='scp ~/Videos/*.mp4 jasur@192.168.47.112:"C:/Users/jasur/Videos/"'

alias l='ls -lh --color=auto'
alias ls='command ls --color=auto'
alias la='command ls -A --color=auto'

alias memory='df -h'
alias display='nwg-displays'

alias airon='sudo airmon-ng start wlp1s0'
alias airoff='sudo airmon-ng stop wlp1s0mon'


