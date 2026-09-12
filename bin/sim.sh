#!/bin/zsh
# Helpers for driving Season42 in the iOS Simulator with idb.
#
# Every idb command needs an explicit --udid, so $U is the one thing to set: it defaults to
# whichever simulator is booted. The bug these drive (#100) shows only on an iPhone 16 Pro
# on iOS 26.5, so boot that one before sourcing this.
export PATH=$PATH:$HOME/.local/bin:/opt/homebrew/bin
U=${U:-$(xcrun simctl list devices booted -j | jq -r '[.devices[][]][0].udid // empty')}
if [[ -z "$U" ]]; then echo "sim.sh: no booted simulator — boot one, or set U=<udid>" >&2; return 1 2>/dev/null || exit 1; fi
APP=com.season42.app

tree() { idb ui describe-all --udid $U; }

# One line per element: label, value, type, x, y, w, h. The frames are what makes numeric
# assertions possible — "is this row above the keyboard's top edge?" beats eyeballing a shot.
elems() {
  tree | jq -r '.[] | [(.AXLabel//""),(.AXValue//""),.type,(.frame.x|floor),(.frame.y|floor),(.frame.width|floor),(.frame.height|floor)] | @tsv'
}

# center <regex> [type] — centre of the first element whose label or value matches.
center() {
  tree | jq -r --arg re "$1" --arg ty "${2:-}" '[.[] | select(($ty=="" or .type==$ty) and (((.AXLabel//"")|test($re)) or ((.AXValue//"")|test($re))))][0] | if . == null then "NONE" else "\((.frame.x + .frame.width/2)|floor) \((.frame.y + .frame.height/2)|floor)" end'
}

tap_label() {
  local c=$(center "$1" "$2")
  if [[ "$c" == "NONE" ]]; then echo "tap_label: no element matching /$1/" >&2; return 1; fi
  echo "tap /$1/${2:+ ($2)} at $c" >&2
  idb ui tap --udid $U ${=c}
}

tap_xy() { idb ui tap --udid $U $1 $2; }

# Type by tapping the keys of the on-screen keyboard. idb's own text entry arrives as
# hardware-keyboard input, which makes iOS put the software keyboard away for the rest of
# the boot — and the keyboard is the whole point of this repro.
type_keys() {
  local ch c
  for ch in ${(s::)1}; do
    # The keys are Buttons in the tree, labelled uppercase whatever the shift state shows.
    c=$(center "^(${(U)ch}|${(L)ch})\$" Button)
    if [[ "$c" == "NONE" ]]; then echo "type_keys: no key '$ch' on screen" >&2; return 1; fi
    idb ui tap --udid $U ${=c}
    sleep 0.4
  done
}

# A swipe at idb's default speed doesn't hold a SwiftUI row open, hence the duration.
swipe() { idb ui swipe --udid $U --duration ${3:-0.4} $1 $2 $4 $5 2>/dev/null; }
shot() { xcrun simctl io $U screenshot "$1" >/dev/null 2>&1; }
relaunch() { xcrun simctl terminate $U $APP >/dev/null 2>&1; launch; sleep 1.5; }

# The simulator only raises the software keyboard on a freshly booted device: after an app
# relaunch it stays down, whatever the hardware-keyboard setting says. So a run that needs
# the keyboard resets by rebooting the device.
reboot_device() {
  xcrun simctl shutdown $U >/dev/null 2>&1 || true
  sleep 3
  xcrun simctl boot $U >/dev/null 2>&1
  xcrun simctl bootstatus $U -b >/dev/null 2>&1
  sleep 4
  launch
  sleep 3
}

# SpringBoard sometimes refuses the first launch after a boot ("denied by service delegate").
# It is not the bug under test, so retry rather than let the run fail as if it were one.
launch() {
  local n=0
  while (( n < 5 )); do
    if xcrun simctl launch $U $APP >/dev/null 2>&1; then return 0; fi
    sleep 3; n=$((n+1))
  done
  echo "launch: the simulator would not start $APP after 5 tries" >&2
  exit 3
}
