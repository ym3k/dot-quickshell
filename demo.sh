#!/usr/bin/env bash
# Demo of the Hyprland + Quickshell desktop
#   ./demo.sh            run the demo
#   ./demo.sh --record   run the demo while recording to ~/Videos/demo.mp4
set -euo pipefail

MONITOR="eDP-1"        # monitor to record
THEME="teal"           # theme at the start and the end
TYPE_DELAY=110         # delay between typed characters (ms)

d()     { hyprctl dispatch "$1" >/dev/null || true; }   # Hyprland dispatcher (Lua expression)
bar()   { qs ipc call bar "$@" >/dev/null; }
launch(){ qs ipc call launcher toggle "$1" >/dev/null; }
typ()   { wtype -d "$TYPE_DELAY" "$1"; }
key()   { wtype -k "$1"; }
# focus workspace N on the current monitor (pulls it here if it lives on another monitor)
ws()    { d "hl.dsp.focus({ workspace = $1, on_current_monitor = true })"; }
run()   { d "hl.dsp.exec_cmd(\"$1\")"; }

# kitty window addresses (needs jq)
kitty_addrs() { hyprctl clients -j | jq -r '.[] | select(.class == "kitty") | .address' | sort; }

# start kitty with a command and print the address of the new window
new_kitty() {
    local before after
    before=$(kitty_addrs)
    run "kitty $1"
    for _ in $(seq 30); do                      # wait up to 3 s for the window
        sleep 0.1
        after=$(kitty_addrs)
        [[ "$after" != "$before" ]] && break
    done
    comm -13 <(echo "$before") <(echo "$after") | head -n1
}

focus_win() { d "hl.dsp.focus({ window = \"address:$1\" })"; }
resize()    { d "hl.dsp.window.resize({ x = $1, y = $2, relative = true })"; }
close_win() { d "hl.dsp.window.close({ window = \"address:$1\" })"; }
swap()      { d "hl.dsp.window.swap({ direction = \"$1\" })"; }   # swap the focused window with its neighbour

# analog clock window: "address x y w h"
clock_info() {
    hyprctl clients -j | jq -r '.[] | select(.title == "Analog Clock") | "\(.address) \(.at[0]) \(.at[1]) \(.size[0]) \(.size[1])"' | head -n1
}
# logical size and position of the monitor: "x y w h"
monitor_info() {
    hyprctl monitors -j | jq -r --arg m "$MONITOR" '.[] | select(.name == $m) | "\(.x) \(.y) \(.width / .scale | floor) \(.height / .scale | floor)"'
}
move_win() { d "hl.dsp.window.move({ x = $2, y = $3, window = \"address:$1\" })"; }   # absolute position

# ── recording ──
rec=""
if [[ "${1:-}" == "--record" ]]; then
    mkdir -p ~/Videos
    gpu-screen-recorder -w "$MONITOR" -f 60 -o ~/Videos/demo.mp4 &
    rec=$!
    trap '[[ -n "$rec" ]] && kill -INT "$rec" 2>/dev/null; wait "$rec" 2>/dev/null || true' EXIT
    sleep 2
fi

# ── 0. setup: work on eDP-1 (workspaces 1-3), start with the teal theme ──
d "hl.dsp.focus({ monitor = \"$MONITOR\" })"; sleep 0.5
bar theme "$THEME"; sleep 1

# ── 1. workspace 1: three kitty windows + resize + swap ──
#   big (left): btop / right: two plain shells
ws 1; sleep 1
k_big=$(new_kitty "btop"); sleep 1.2
k_top=$(new_kitty "");     sleep 1.2
k_bot=$(new_kitty "");     sleep 1.5

# resize: widen / narrow the big window, then the top-right one taller / shorter
focus_win "$k_big"; sleep 0.5
for _ in 1 2 3 4; do resize 80 0;  sleep 0.25; done; sleep 0.5
for _ in 1 2 3 4; do resize -80 0; sleep 0.25; done; sleep 0.5
focus_win "$k_top"; sleep 0.5
for _ in 1 2 3; do resize 0 60;  sleep 0.25; done; sleep 0.5
for _ in 1 2 3; do resize 0 -60; sleep 0.25; done
sleep 0.8

# swap: move btop to the right, then back to the left
focus_win "$k_big"; sleep 0.5
swap right; sleep 1.2
swap left;  sleep 1

# ── 2. workspace 2: VS Code ──
ws 2; sleep 1
run code; sleep 5          # VS Code takes a while to start

ws 1; sleep 1.5
ws 2; sleep 1.5

# ── 3. workspace 3: launcher (app search, calculator, emoji) ──
ws 3; sleep 1
launch apps; sleep 1
typ "kitty"; sleep 1.2
key Escape; sleep 0.8

launch apps; sleep 1
typ "sqrt(2)^3"; sleep 2
key Escape; sleep 0.8

launch emoji; sleep 1
typ "party"; sleep 1.5
key Escape; sleep 0.8

# ── 4. workspace 3: panels on the bar, analog clock ──
for p in calendar audio wifi theme; do
    bar open "$p"; sleep 1.5
done
bar close; sleep 0.6

# analog clock: show it, move it to the center of the screen, then back to where it was
bar clock; sleep 1.5
read -r c_addr c_x c_y c_w c_h <<< "$(clock_info)"
read -r m_x m_y m_w m_h <<< "$(monitor_info)"
if [[ -n "${c_addr:-}" && -n "${m_w:-}" ]]; then
    move_win "$c_addr" $(( m_x + (m_w - c_w) / 2 )) $(( m_y + (m_h - c_h) / 2 )); sleep 2
    move_win "$c_addr" "$c_x" "$c_y"; sleep 1.5
fi
bar clock; sleep 1

# ── 5. workspace 1: theme switching (with the kitty windows visible) ──
ws 1; sleep 1
for t in blue rose orange lavender smoke legacy; do
    bar theme "$t"; sleep 1.5
done
bar theme "$THEME"; sleep 1.5

# ── 6. Noson (hidden special workspace) ──
d 'hl.dsp.workspace.toggle_special("sonos")'; sleep 2.5
d 'hl.dsp.workspace.toggle_special("sonos")'; sleep 1.5

# ── 7. back to workspace 1 and close the three kitty windows ──
ws 1; sleep 1
for k in "$k_bot" "$k_top"; do
    [[ -n "$k" ]] && close_win "$k"
    sleep 0.7
done
# quit btop with "q": kitty closes by itself when btop exits
if [[ -n "$k_big" ]]; then
    focus_win "$k_big"; sleep 0.5
    key q
fi
sleep 1
