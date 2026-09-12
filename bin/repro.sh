#!/bin/zsh
# Repro loop for issue #100: with the keyboard up on a series or movie form, a trip into the
# Streaming Service list leaves the form unable to scroll — its last row stays behind the
# keyboard and no amount of swiping brings it clear.
#
#   exit 0  PASS — the last row can be scrolled onto screen, clear of the keyboard if one is up
#   exit 1  FAIL — the bug is there
#   exit 2  INCONCLUSIVE — the keyboard never came up, so the run proves nothing
#   exit 3  the simulator would not start the app — nothing was tested
#
# Run it against an iPhone 16 Pro on iOS 26.5: it does not reproduce on 26.0 or 18.1.
#
#   ./bin/repro.sh                 the reported flow, search and copy and all
#   SKIP_SEARCH=1 ./bin/repro.sh   the minimal four steps — form, focus Title, service list, scroll
#   SKIP_SERVICE=1 ./bin/repro.sh  the control: the same without the trip, which passes
cd "$(dirname "$0")/.."
source bin/sim.sh
set -e

: ${STOP_AFTER:=all}   # copy | service | all
: ${FOCUS:=title}      # title | none — focus (and type in) the Title field before Search
: ${SKIP_SEARCH:=0}    # 1 = skip the search/copy trip entirely
: ${SKIP_SERVICE:=0}   # 1 = skip the trip into the service list (the control)
: ${SERVICE:=Prime Video}
: ${OUT:=$(mktemp -d)}

wait_for() {
  local n=0
  while (( n < ${2:-12} )); do
    if [[ "$(center "$1" "$3")" != "NONE" ]]; then return 0; fi
    sleep 1; n=$((n+1))
  done
  echo "wait_for: /$1/ never appeared" >&2; return 1
}

# Top edge of the keyboard, or NONE when it is down.
kb_top() {
  tree | jq -r '[.[] | select(.type=="GenericElement" and .frame.height > 250 and .frame.y > 300)][0] | if .==null then "NONE" else (.frame.y|floor) end'
}

# Bottom edge of the screen — what the last row has to fit above when the keyboard is down.
screen_h() {
  tree | jq -r '[.[] | select(.type=="Application")][0] | if .==null then 874 else ((.frame.y + .frame.height)|floor) end'
}

# Bottom edge of the form's last row.
bottom_row() {
  tree | jq -r '[.[] | select((.AXLabel//"")=="Next episode date")][0] | if .==null then "MISSING" else ((.frame.y + .frame.height)|floor) end'
}

: ${RESET:=device}     # device = reboot the simulator (the only way to get the software keyboard)
if [[ $RESET == device ]]; then reboot_device; else relaunch; fi
tap_xy 150 820; sleep 1         # Library tab
tap_xy 364 84;  sleep 1         # +
tap_label '^Series$'; sleep 2

if [[ $FOCUS == title ]]; then
  tap_label '^Title$'; sleep 1.5
  raised=$(kb_top)
  echo "  keyboard after focusing Title: $raised" >&2
  if [[ $SKIP_SEARCH == 0 ]]; then type_keys "severance"; sleep 1; fi
fi
if [[ $SKIP_SEARCH == 0 ]]; then
  tap_label '^Search$'; sleep 2
  wait_for '^Severance$' 40 Button
  tap_label '^Severance$' Button; sleep 3
  for i in 1 2 3 4 5 6; do
    if [[ "$(center '^Copy into the form$')" != "NONE" ]]; then break; fi
    swipe 200 700 0.5 200 250; sleep 1.2
  done
  wait_for '^Copy into the form$' 10
  tap_label '^Copy into the form$'; sleep 2
  tap_label '^Copy$'
  # Watch for the keyboard coming back over the form.
  for i in 1 2 3 4 5 6 7 8; do
    sleep 0.7
    echo "  t=$i keyboard top: $(kb_top)" >&2
  done
fi
shot $OUT/after-copy.png
if [[ $STOP_AFTER == copy ]]; then echo "--- after copy ---"; elems; exit 0; fi

if [[ $SKIP_SERVICE == 0 ]]; then
  tap_label '^Streaming service, '; sleep 2
  if [[ "$(center "^${SERVICE}\$")" != "NONE" ]]; then tap_label "^${SERVICE}\$"; else tap_label '^None$'; fi
  sleep 3
fi
shot $OUT/after-service.png
if [[ $STOP_AFTER == service ]]; then echo "--- after service ---"; elems; exit 0; fi

# With the keyboard where it is, can the last row of the form be scrolled clear of it?
echo "before scrolling: keyboard $(kb_top), bottom row $(bottom_row)"
for i in 1 2 3 4 5 6 7; do
  swipe 200 500 0.5 200 200 >/dev/null 2>&1; sleep 0.9
  echo "  swipe $i: keyboard $(kb_top), bottom row $(bottom_row)"
done
sleep 1
shot $OUT/after-scroll-down.png
k=$(kb_top); b=$(bottom_row)
echo
echo "screenshots in $OUT"
echo "keyboard top: $k    bottom of the form: $b"

# The run only proves something if the keyboard came up in the first place — that is the
# precondition the bug needs, and the simulator does not always give it.
if [[ "${raised:-NONE}" == "NONE" ]]; then
  echo "INCONCLUSIVE: the keyboard never came up on the form, so the run proves nothing"
  exit 2
fi

# What the last row has to fit above: the keyboard where one is still up, the foot of the
# screen where the trip put it down. Either way the row has to be reachable.
if [[ "$k" == "NONE" ]]; then limit=$(screen_h); else limit=$k; fi
if [[ "$b" == "MISSING" ]] || (( b > limit )); then
  echo "FAIL: the last row will not scroll above $limit — it stays out of reach, issue #100 reproduced"
  exit 1
fi
echo "PASS: the last row scrolls into reach (above $limit)"
