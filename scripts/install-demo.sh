#!/usr/bin/env bash
# ===========================================================================
# scripts/install-demo.sh — click-through preview of the installer
#
# Runs every installer menu, then prints the disk.nix it WOULD write, the
# commands it WOULD run and the post-install checklist. Touches no disks,
# writes nothing to the repo. Only writes: a throwaway SSH key (temp dir,
# deleted on exit) and the saved answers in /tmp/install-demo-answers/, so
# a second run of the same host can offer "reinstall with saved answers".
#
# Usage:
#   nix run .#install-demo                              # your real disks
#   sudo nix run .#install-demo                         # + SMART health (needs root)
#   nix run .#install-demo -- --fake-disks 2-equal      # 2× 2T NVMe (mirror)
#   nix run .#install-demo -- --fake-disks 3-mixed      # uneven disks, one worn
#   nix run .#install-demo -- --fake-disks 4-hdd        # NAS, one disk failing
#   nix run .#install-demo -- --fake-disks windows      # Windows on its own NVMe
#   (scripts/install-demo.sh … works too)
#
# Keys: enter select · esc back one step · ctrl+c quit
# ===========================================================================
set -euo pipefail

if ! command -v gum >/dev/null || ! command -v qrencode >/dev/null || ! command -v smartctl >/dev/null; then
  [[ -n "${_DEMO_SHELL:-}" ]] && { echo "gum/qrencode/smartctl unavailable" >&2; exit 1; }
  _DEMO_SHELL=1 exec nix shell nixpkgs#gum nixpkgs#qrencode nixpkgs#jq nixpkgs#smartmontools -c bash "$0" "$@"
fi
{ : </dev/tty; } 2>/dev/null || [[ -n ${INSTALL_TEST:-} ]] || { echo "install-demo needs an interactive terminal" >&2; exit 1; }

REPO="${INSTALLER_REPO:-$(cd "$(dirname "$0")/.." && pwd)}"
FAKE=""; [[ "${1:-}" == --fake-disks ]] && FAKE="${2:?scenario: 2-equal|3-mixed|4-hdd|windows}"
ANSWERS_DIR=/tmp/install-demo-answers   # real installer: $REPO/hosts/<host>/install.json
TMP="$(mktemp -d)"
ALT=0
trap '((ALT)) && { tput cnorm; tput rmcup; } 2>/dev/null; rm -rf "$TMP"' EXIT

G=$'\e[32m' Y=$'\e[33m' R=$'\e[31m' D=$'\e[90m' B=$'\e[1m' P=$'\e[38;5;212m' N=$'\e[0m'

# --------------------------------------------------------------------------
# Screen model: every prompt redraws the whole screen in place —
#   header · TITLE · CTX (step content) · NOTE (one-shot warnings) · prompt
#   … and a status bar pinned to the bottom two rows (keys, then steps).
# Menus and text input are drawn here (not gum) so the status bar can be
# repainted on every keypress. pick/ask set a variable (no subshell).
# esc → return 1 (= back), ctrl+c → quit.
# --------------------------------------------------------------------------
TITLE=""; CTX=""; NOTE=""; HOST=""; SCR=""; HEADER_BIG=""; HEADER_SLIM=""; FORMAT_CMDS=()
HOME_LABEL=home; DATA_LABEL=data; DATA_OLDLABEL=""
STEP_NAMES=(Host Disks Filesystem Boot Encrypt Swap Secrets Review)
CUR=0
TTY=/dev/tty; [[ -n ${INSTALL_TEST:-} ]] && TTY=/dev/null

box() { gum style --border rounded --border-foreground 240 --padding "0 1" --foreground 250 "$@"; }
panel() { TITLE=$1; CTX=${2:-}; }
warn() { NOTE+="${Y}⚠ $*${N}"$'\n'; }
hsize() { numfmt --to=si --format=%.1f "$1"; }

compose() {  # $1 = prompt height · freeze the screen; big header if it fits, else slim
  local body="" rows need
  [[ -n $TITLE ]] && body+="${B}${P}${TITLE}${N}"$'\n'
  [[ -n $CTX ]] && body+="$CTX"$'\n'
  [[ -n $NOTE ]] && { body+="$NOTE"; NOTE=""; }
  rows=$(tput lines 2>/dev/null || echo 50)
  need=$(( $(wc -l <<<"$HEADER_BIG") + 2 + $(wc -l <<<"$body") + ${1:-0} + 4 ))
  if (( need <= rows )); then SCR="$HEADER_BIG"; else SCR="$HEADER_SLIM"; fi
  SCR+=$'\n\n'"$body"$'\n'
}

render() {  # $1 = prompt block, $2 = key hints
  local out="$SCR$1"
  if [[ -n ${INSTALL_TEST:-} ]]; then printf '%s\n' "$out"; footer "$2"; return; fi
  tput cup 0 0
  printf '%s' "${out//$'\n'/$'\e[K\n'}"; printf '\e[K\e[J'
  footer "$2"
}

footer() {  # pinned bottom rows: progress legend · key hints · step chain
  local i chain="" rows; rows=$(tput lines 2>/dev/null || echo 0)
  for i in "${!STEP_NAMES[@]}"; do
    ((i)) && chain+="${D} ─ ${N}"
    if ((i < CUR)); then chain+="${G}● ${STEP_NAMES[i]}${N}"
    elif ((i == CUR)); then chain+="${B}${P}◉ ${STEP_NAMES[i]}${N}"
    else chain+="${D}○ ${STEP_NAMES[i]}${N}"; fi
  done
  local legend="${D}step $((CUR + 1))/${#STEP_NAMES[@]} · ${G}●${D} done ${P}◉${D} now ○ next${N}"
  local keys="${D}$1 · esc back · ctrl+c quit${N}"
  if [[ -z ${INSTALL_TEST:-} ]] && ((rows > 12)); then
    tput cup $((rows - 3)) 0; printf ' %s\e[K' "$legend"
    tput cup $((rows - 2)) 0; printf ' %s\e[K' "$keys"
    tput cup $((rows - 1)) 0; printf ' %s\e[K' "$chain"
  else printf ' %s\n %s\n %s\n' "$legend" "$keys" "$chain"; fi
}

# key → up|down|enter|back|char:<c>|bs   (arrow keys arrive as ESC [ A)
readkey() {
  local k rest
  IFS= read -rsn1 k <"$TTY" || exit 1   # terminal gone (e.g. SSH dropped): never auto-confirm
  case $k in
    '') KEY=enter ;;
    $'\e') if IFS= read -rsn2 -t 0.05 rest <"$TTY"; then
             case $rest in '[A') KEY=up ;; '[B') KEY=down ;; *) KEY=none ;; esac
           else KEY=back; fi ;;
    $'\x7f'|$'\b') KEY=bs ;;
    *) KEY="char:$k" ;;
  esac
}

# pick VAR "question" "label|value"...
pick() {
  local __v=$1 h=$2; shift 2
  local labels=() values=() o i sel=0 top body
  for o; do labels+=("${o%%|*}"); values+=("${o##*|}"); done
  if [[ -n ${INSTALL_TEST:-} ]]; then   # tests: take option $TEST_IDX, but always "Install" on review
    sel=${TEST_IDX:-0}; ((sel < ${#values[@]})) || sel=0
    for i in "${!values[@]}"; do [[ ${values[i]} == go ]] && sel=$i; done
  fi
  compose $(( (${#labels[@]} < 12 ? ${#labels[@]} : 12) + 2 ))
  while :; do
    top=$(( sel > 11 ? sel - 11 : 0 )); body=""
    [[ -n $h ]] && body+="${D}$h${N}"$'\n'
    for ((i = top; i < ${#labels[@]} && i < top + 12; i++)); do
      if ((i == sel)); then body+="${B}${P}> ${labels[i]}${N}"$'\n'; else body+="  ${labels[i]}"$'\n'; fi
    done
    render "$body" "↑↓ move · enter select"
    [[ -n ${INSTALL_TEST:-} ]] && break
    readkey
    case $KEY in
      up)   ((sel > 0)) && sel=$((sel - 1)) ;;
      down) ((sel < ${#labels[@]} - 1)) && sel=$((sel + 1)) ;;
      char:k) ((sel > 0)) && sel=$((sel - 1)) ;;
      char:j) ((sel < ${#labels[@]} - 1)) && sel=$((sel + 1)) ;;
      enter) break ;;
      back) return 1 ;;
    esac
  done
  printf -v "$__v" '%s' "${values[sel]}"
}

# ask VAR [--header H] [--placeholder P] [--value V]
ask() {
  local __v=$1 h="" ph="" val="" max=0; shift
  while (($#)); do case $1 in --header) h=$2 ;; --placeholder) ph=$2 ;; --value) val=$2 ;; --max) max=$2 ;; esac; shift 2; done
  [[ -n ${INSTALL_TEST:-} && -z $val ]] && val=$ph
  compose 3
  while :; do
    local shown="$val${P}▏${N}"; [[ -z $val ]] && shown="${P}▏${N}${D}$ph${N}"
    ((max)) && shown+="   ${D}${#val}/$max${N}"
    render "${h:+${D}$h${N}$'\n'}${B}${P}> ${N}$shown"$'\n' "type · enter confirm"
    [[ -n ${INSTALL_TEST:-} ]] && break
    readkey
    case $KEY in
      enter) break ;;
      back) return 1 ;;
      bs) val=${val%?} ;;
      char:*) if ((max == 0 || ${#val} < max)); then val+=${KEY#char:}; fi ;;
    esac
  done
  printf -v "$__v" '%s' "$val"
}

# yesno "question" — No is the default (first)
yesno() { local a; pick a "$1" "No|n" "Yes|y" || return 1; [[ $a == y ]]; }

# --------------------------------------------------------------------------
# Hardware detection (sysfs only — works on the bare ISO)
# --------------------------------------------------------------------------
detect_hw() {
  [[ -d /sys/firmware/efi ]] && FW=uefi || FW=bios
  RAM_B=$(awk '/MemTotal/{print $2*1024}' /proc/meminfo)
  ping -c1 -W2 nixos.org >/dev/null 2>&1 && NET="✓" || NET="✗ (would launch nmtui)"
  case $(grep -m1 vendor_id /proc/cpuinfo) in *AMD*) HW_CPU=AMD ;; *Intel*) HW_CPU=Intel ;; *) HW_CPU=other ;; esac
  local d gpus=() virt
  for d in /sys/bus/pci/devices/*; do
    [[ $(<"$d/class") == 0x03* ]] || continue
    case $(<"$d/vendor") in 0x1002) gpus+=(AMD) ;; 0x10de) gpus+=(NVIDIA) ;; 0x8086) gpus+=(Intel) ;; *) gpus+=(other) ;; esac
  done
  HW_GPU=$(printf '%s\n' "${gpus[@]:-none}" | sort -u | paste -sd+)
  virt=$(systemd-detect-virt 2>/dev/null || true)
  if [[ -n $virt && $virt != none ]]; then HW_FORM="virtual machine"
  elif ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then HW_FORM=laptop
  else HW_FORM=desktop; fi
  HW_WIFI=0; if ls -d /sys/class/net/*/wireless >/dev/null 2>&1; then HW_WIFI=1; fi
}

# --------------------------------------------------------------------------
# Disks — real (lsblk + smartctl) or fake; both normalised to:
# [{name,size,model,serial,tran,rm,rota,segs:[{fs,label,size,uuid}],smart,parts,os,uuid}]
# --------------------------------------------------------------------------
real_disks() {
  lsblk -J -b -o NAME,SIZE,MODEL,SERIAL,TRAN,RM,ROTA,TYPE,FSTYPE,LABEL,UUID | jq '
    [.blockdevices[] | select(.type=="disk" and (.name|test("^(zram|loop|sr)")|not)) |
     {name, size, model:(.model//"?"), serial:(.serial//.name), tran:(.tran//"?"), rm, rota,
      segs:[.children[]? | {name, fs:(.fstype//"raw"), label, size, uuid}]}]'
}

smart_real() {
  local r=""
  if [[ $EUID == 0 ]]; then
    r=$(smartctl -j -H -A "/dev/$1" 2>/dev/null | jq -r '
      (.smart_status.passed) as $ok
      | ([.ata_smart_attributes.table[]? | select(.id==5 or .id==197) | .raw.value] | add // 0) as $bad
      | (.nvme_smart_health_information_log // {}) as $n
      | (($n.media_errors // 0) + ($n.critical_warning // 0)) as $nbad
      | (.power_on_time.hours // 0) as $h
      | if $ok == false then "fail|SMART overall-health FAILED"
        elif $bad > 0 then "warn|\($bad) reallocated/pending sectors"
        elif $nbad > 0 then "warn|NVMe media errors / critical warning"
        elif ($n.percentage_used // 0) >= 90 then "warn|\($n.percentage_used)% worn out"
        elif $ok == true then "ok|\($h)h powered on"
        else empty end' 2>/dev/null || true)
    echo "${r:-?|no SMART data}"
  else echo "?|run with sudo for SMART"; fi
}

fake_disks() {
  local stick='{"name":"sdz","size":8004304896,"model":"SanDisk Ultra (boot USB)","serial":"4C530001","tran":"usb","rm":true,"rota":false,"smart":"?|","segs":[{"fs":"iso9660","label":"nixos-minimal","size":1600000000}]}'
  case "$1" in
    2-equal) cat <<EOF
[{"name":"nvme0n1","size":2000398934016,"model":"Samsung 990 PRO 2TB","serial":"S6B2NS0W100001","tran":"nvme","rm":false,"rota":false,"smart":"ok|1204h powered on","segs":[]},
 {"name":"nvme1n1","size":2000398934016,"model":"Samsung 990 PRO 2TB","serial":"S6B2NS0W100002","tran":"nvme","rm":false,"rota":false,"smart":"ok|1198h powered on","segs":[]},$stick]
EOF
    ;;
    3-mixed) cat <<EOF
[{"name":"nvme0n1","size":1000204886016,"model":"WD SN850X 1TB","serial":"23170D800001","tran":"nvme","rm":false,"rota":false,"smart":"ok|3310h powered on","segs":[]},
 {"name":"sda","size":4000787030016,"model":"WD Red Plus 4TB","serial":"WD-WX12D0000001","tran":"sata","rm":false,"rota":true,"smart":"ok|21877h powered on","segs":[{"fs":"btrfs","label":"data","size":4000785960960,"uuid":"3f1c9a2e-5b7d-4c1e-9f0a-2d6e8b4c7a10"}]},
 {"name":"sdb","size":2000398934016,"model":"Seagate IronWolf 2TB","serial":"ZFL0000002","tran":"sata","rm":false,"rota":true,"smart":"warn|48 reallocated/pending sectors","segs":[]},
 {"name":"sdc","size":1000204886016,"model":"Crucial MX500 1TB","serial":"2149E5000003","tran":"sata","rm":false,"rota":false,"smart":"ok|9021h powered on","segs":[]},$stick]
EOF
    ;;
    4-hdd) cat <<EOF
[{"name":"nvme0n1","size":500107862016,"model":"WD SN770 500GB","serial":"22451F800001","tran":"nvme","rm":false,"rota":false,"smart":"ok|820h powered on","segs":[]},
 {"name":"sda","size":4000787030016,"model":"WD Red Plus 4TB","serial":"WD-WX12D0000011","tran":"sata","rm":false,"rota":true,"smart":"ok|15002h powered on","segs":[]},
 {"name":"sdb","size":4000787030016,"model":"WD Red Plus 4TB","serial":"WD-WX12D0000012","tran":"sata","rm":false,"rota":true,"smart":"ok|15010h powered on","segs":[]},
 {"name":"sdc","size":4000787030016,"model":"WD Red Plus 4TB","serial":"WD-WX12D0000013","tran":"sata","rm":false,"rota":true,"smart":"ok|14998h powered on","segs":[]},
 {"name":"sdd","size":4000787030016,"model":"WD Red Plus 4TB","serial":"WD-WX12D0000014","tran":"sata","rm":false,"rota":true,"smart":"fail|SMART overall-health FAILED","segs":[]},$stick]
EOF
    ;;
    windows) cat <<EOF
[{"name":"nvme0n1","size":2000398934016,"model":"Samsung 990 PRO 2TB","serial":"S6B2NS0W100021","tran":"nvme","rm":false,"rota":false,"smart":"ok|4120h powered on","segs":[{"fs":"vfat","label":"EFI","size":536870912},{"fs":"btrfs","label":"nixos","size":1999860000000,"uuid":"7f13c8ae-3795-4d20-a739-d72f40091859"}]},
 {"name":"nvme1n1","size":1000204886016,"model":"WD SN850X 1TB","serial":"23170D800022","tran":"nvme","rm":false,"rota":false,"smart":"ok|2210h powered on","segs":[{"fs":"vfat","label":null,"size":104857600},{"fs":"ntfs","label":"Windows","size":1000000000000,"uuid":"6A1C2D3E4F5A6B7C"}]},
 {"name":"sda","size":4000787030016,"model":"WD Red Plus 4TB","serial":"WD-WX12D0000023","tran":"sata","rm":false,"rota":true,"smart":"ok|18000h powered on","segs":[{"fs":"xfs","label":"Games","size":4000785960960,"uuid":"a374ae2d-efab-4e1a-8af8-fe25861a9585"}]},$stick]
EOF
    ;;
    *) echo "unknown scenario: $1" >&2; exit 1 ;;
  esac
}

norm() {
  jq '[.[] | ([.segs[]?.label]) as $l | ([.segs[]?.fs]) as $f | . + {
    segs: (.name as $d | [.segs // [] | to_entries[] | .value + {dev: (.value.dev // .value.name
             // ($d + (if ($d|test("^(nvme|mmcblk)")) then "p" else "" end) + ((.key + 1)|tostring)))}]),
    parts: ([.segs[]? | .fs + (if (.label//"") != "" then " \"" + .label + "\"" else "" end)] | join(", ")),
    uuid:  ([.segs[]? | select(.fs != "vfat") | .uuid // empty][0] // null),
    curlabel: ([.segs[]? | select(.fs != "vfat") | .label // empty][0] // ""),
    datadev: (.name as $d | [.segs // [] | to_entries[] | select(.value.fs != "vfat")][0] as $e
              | if $e == null then null else ($e.value.name // ($d + (if ($d|test("^(nvme|mmcblk)")) then "p" else "" end) + (($e.key + 1)|tostring))) end),
    smart: (.smart // "?|"),
    os: (if ($l|index("nixos")) or ($l|index("nixos-luks")) then "nixos"
         elif ($f|index("ntfs")) then "windows"
         elif ($f|index("apfs")) then "macos"
         elif ($f|map(select(.=="ext4" or .=="btrfs" or .=="xfs"))|length) > 0 and ($f|index("vfat")) then "linux"
         else "" end)}]'
}

health() {
  case ${1%%|*} in
    ok) echo "${G}✓ ${1#*|}${N}" ;; warn) echo "${Y}⚠ ${1#*|}${N}" ;;
    fail) echo "${R}✗ ${1#*|}${N}" ;; *) echo "${D}? SMART${N}" ;;
  esac
}

# One partition, fixed 43 columns: dev · label · filesystem · size
fmt_seg() { printf '%-10.10s %-12.12s %-11.11s %7s' "$1" "${2:--}" "$3" "$(hsize "$4")"; }
SEG_HEAD=$(printf '%-10s %-12s %-11s %7s' PARTITION LABEL FILESYSTEM SIZE)
SEG_JQ='.segs[] | [.dev, (.label // ""), .fs, (.size|tostring), (.purpose // "")] | join("\u001f")'

# disk_table <json> [after-json] — each disk: header line, then its partitions as a tree.
# With after-json (Review): NOW → AFTER INSTALL side by side, plus what each partition is for.
disk_table() {
  local before=$1 after=${2:-} n s t m h o note status i d l f z u tree same card_seen=""
  local -a LS RS
  if [[ -z $after ]]; then echo "    ${D}$SEG_HEAD${N}"; else echo "            ${D}$SEG_HEAD   USED FOR${N}"; fi
  while IFS=$'\x1f' read -r n s t m h o; do
    mapfile -t LS < <(jq -r --arg n "$n" ".[] | select(.name==\$n) | $SEG_JQ" <<<"$before")
    if [[ -z $after ]]; then   # Disks screen: header + partition tree
      note=""; case $o in windows|macos|linux) note="${Y}⚠ other OS: $o${N}" ;; nixos) note="${D}previous NixOS install${N}" ;; esac
      printf "${B}%-8s${N} %7s  %-5s %-30.30s %s  %s\n" "$n" "$(hsize "$s")" "${t^^}" "$m" "$(health "$h")" "$note"
      if (( ${#LS[@]} == 0 )); then echo "  ${D}(empty — no partitions)${N}"; continue; fi
      for i in "${!LS[@]}"; do
        IFS=$'\x1f' read -r d l f z u <<<"${LS[i]}"
        tree="├"; ((i == ${#LS[@]} - 1)) && tree="└"
        printf "  %s %s\n" "$tree" "$(fmt_seg "$d" "$l" "$f" "$z")"
      done
      continue
    fi
    # Review: one card per disk — now, then after (fits ~80 columns)
    status=$(jq -r --arg n "$n" '.[] | select(.name==$n) | .action' <<<"$after")
    same=$(jq -r --arg n "$n" '.[] | select(.name==$n) | .same' <<<"$after")
    mapfile -t RS < <(jq -r --arg n "$n" ".[] | select(.name==\$n) | $SEG_JQ" <<<"$after")
    local warnh=""; [[ ${h%%|*} == warn || ${h%%|*} == fail ]] && warnh="  $(health "$h")"
    [[ -n ${card_seen:-} ]] && echo; card_seen=1
    printf "${B}%s${N} · %s %s · %.34s%s   %s\n" "$n" "$(hsize "$s")" "${t^^}" "$m" "$warnh" "$status"
    if [[ $same == true ]]; then
      if (( ${#LS[@]} == 0 )); then echo "          ${D}(empty — unchanged)${N}"; fi
      for i in "${!LS[@]}"; do
        IFS=$'\x1f' read -r d l f z u <<<"${LS[i]}"
        tree="├"; ((i == ${#LS[@]} - 1)) && tree="└"
        printf "          %s %s   ${D}%s${N}\n" "$tree" "$(fmt_seg "$d" "$l" "$f" "$z")" "$( ((i == 0)) && echo "(unchanged)" || true)"
      done
      continue
    fi
    if (( ${#LS[@]} == 0 )); then echo "   ${D}now      (empty — no partitions)${N}"; fi
    for i in "${!LS[@]}"; do
      IFS=$'\x1f' read -r d l f z u <<<"${LS[i]}"
      tree="├"; ((i == ${#LS[@]} - 1)) && tree="└"
      printf "   ${D}%-6s${N} %s ${D}%s${N}\n" "$( ((i == 0)) && echo now || true)" "$tree" "$(fmt_seg "$d" "$l" "$f" "$z")"
    done
    for i in "${!RS[@]}"; do
      IFS=$'\x1f' read -r d l f z u <<<"${RS[i]}"
      tree="├"; ((i == ${#RS[@]} - 1)) && tree="└"
      printf "   ${B}%-6s${N} %s %s   ${G}%s${N}\n" "$( ((i == 0)) && echo after || true)" "$tree" "$(fmt_seg "$d" "$l" "$f" "$z")" "$u"
    done
  done < <(jq -r '.[] | [.name, .size, .tran, .model, .smart, .os] | map(tostring) | join("\u001f")' <<<"$before")
}

disk() { jq -r --arg n "$1" ".[] | select(.name==\$n) | $2 // \"\"" <<<"$DISKS"; }
uid_of() { awk -v u="$1" '$1 == u { gsub(/;/, "", $3); print $3 }' "$REPO/modules/users/uids.nix"; }
part() { [[ $1 == nvme* || $1 == mmcblk* ]] && echo "/dev/${1}p$2" || echo "/dev/$1$2"; }
is_foreign() { [[ $(disk "$1" .os) =~ ^(windows|macos|linux)$ ]]; }

# Refuse failing disks unless confirmed; just warn on worn ones
health_ok() {
  local s; s=$(disk "$1" .smart)
  case ${s%%|*} in
    fail) warn "$1: ${s#*|} — data on this disk is at risk"
          yesno "Use $1 anyway?" ;;
    warn) warn "$1: ${s#*|} — usable, but keep an eye on it"; return 0 ;;
    *)    return 0 ;;
  esac
}

confirm_wipe_foreign() {
  local model typed keep=$CTX; model=$(disk "$1" .model)
  CTX="$keep"$'\n'"$(box "$1 has another OS ($(disk "$1" .os)). To reuse it, type its model exactly:" "$model")"
  ask typed --placeholder "$model" || { CTX=$keep; return 1; }
  CTX=$keep
  [[ $typed == "$model" ]] || { warn "model didn't match — keeping $1 untouched"; return 1; }
}

# --------------------------------------------------------------------------
# Labels — the name a file manager shows. Limits are per filesystem.
# --------------------------------------------------------------------------
label_max() { case $1 in xfs) echo 12 ;; ext4) echo 16 ;; vfat) echo 11 ;; exfat) echo 15 ;; *) echo 32 ;; esac; }
relabel_cmd() {  # fs dev label
  case $1 in
    xfs) echo "xfs_admin -L $3 /dev/$2" ;; btrfs) echo "btrfs filesystem label /dev/$2 $3" ;;
    ext4) echo "e2label /dev/$2 $3" ;; vfat) echo "fatlabel /dev/$2 $3" ;;
    ntfs) echo "ntfslabel /dev/$2 $3" ;; exfat) echo "exfatlabel /dev/$2 $3" ;;
    *) echo "# relabel not supported for $1" ;;
  esac
}
mkfs_cmd() {  # fs dev label
  case $1 in
    vfat) echo "mkfs.fat -F32 -n $3 /dev/$2" ;; ntfs) echo "mkfs.ntfs -f -L $3 /dev/$2" ;;
    xfs|btrfs) echo "mkfs.$1 -f -L $3 /dev/$2" ;; *) echo "mkfs.$1 -L $3 /dev/$2" ;;
  esac
}

# ask_label VAR fs default — validated, vfat forced to UPPERCASE
ask_label() {
  local __lv=$1 fs=$2 def=$3 max __lbl what="Label (name shown in the file manager)"
  [[ $fs == zfs ]] && what="Pool name"
  max=$(label_max "$fs")
  while :; do
    ask __lbl --header "$what · $fs: max $max characters · letters, digits, . _ -" --value "$def" --max "$max" || return 1
    [[ $fs == vfat ]] && __lbl=${__lbl^^}
    if [[ ! $__lbl =~ ^[A-Za-z0-9._-]+$ ]]; then warn "use letters, digits, . _ - only (no spaces)"; continue; fi
    break
  done
  printf -v "$__lv" '%s' "$__lbl"
}

# Disk tool: format any disk right now, then return to the Disks screen.
# Real installer runs the commands immediately; the demo only updates its view.
format_tool() {
  local n fs lbl dopts=() keep=$CTX
  TITLE="Disks · format a disk"
  for n in "${NAMES[@]}"; do dopts+=("$(printf '%-9s %-7s %-28.28s %s' "$n" "$(hsize "$(disk "$n" .size)")" "$(disk "$n" .model)" "$(disk "$n" .parts)")|$n"); done
  pick n "Which disk? (esc = cancel)" "${dopts[@]}" || return 1
  CTX="$keep"$'\n'"$(box \
    "ext4   Linux. Simple and very reliable." \
    "xfs    Linux. Great for big files (games, media). Cannot shrink." \
    "btrfs  Linux. Snapshots + compression." \
    "exfat  Shared with Windows/macOS. Big files OK. Best for drives you move around." \
    "ntfs   Windows' own filesystem. Linux reads/writes it (ntfs3)." \
    "vfat   FAT32 — works everywhere, but 4G max file size.")"
  pick fs "Format $n as…" "ext4|ext4" "xfs|xfs" "btrfs|btrfs" "exfat|exfat" "ntfs|ntfs" "vfat (FAT32)|vfat" || { CTX=$keep; return 1; }
  ask_label lbl "$fs" "$(disk "$n" .curlabel | tr -cd 'A-Za-z0-9._-' | cut -c1-"$(label_max "$fs")")" || { CTX=$keep; return 1; }
  [[ -z $lbl ]] && lbl=data
  CTX=$keep
  if is_foreign "$n"; then confirm_wipe_foreign "$n" || return 1
  else yesno "Format $n as $fs \"$lbl\"? Everything on it is ERASED. (demo: simulated)" || return 1; fi
  local p; p=$(part "$n" 1); p=${p#/dev/}
  FORMAT_CMDS+=("wipefs -a /dev/$n && parted -s /dev/$n -- mklabel gpt mkpart data 1MiB 100%" "$(mkfs_cmd "$fs" "$p" "$lbl")")
  local seg; seg=$(jq -nc --arg p "$p" --arg fs "$fs" --arg l "$lbl" --argjson s "$(disk "$n" .size)" --arg u "$(cat /proc/sys/kernel/random/uuid)" \
    '[{name:$p, fs:$fs, label:$l, size:($s - 1048576), uuid:$u}]')
  local j; for j in ALL VISIBLE DISKS; do
    printf -v "$j" '%s' "$(jq --arg n "$n" --argjson g "$seg" '(.[] | select(.name==$n)).segs = $g' <<<"${!j}" | norm)"
  done
  NOTE+="${G}✓ $n formatted as $fs \"$lbl\"${N} ${D}(demo: simulated — the real installer formats it now)${N}"$'\n'
}

# Disk tool: rename a partition's label in place (no data touched).
rename_tool() {
  local n i d fs cur lbl dopts=() popts=() PARTS=()
  TITLE="Disks · rename a label"
  for n in "${NAMES[@]}"; do dopts+=("$(printf '%-9s %-7s %-28.28s %s' "$n" "$(hsize "$(disk "$n" .size)")" "$(disk "$n" .model)" "$(disk "$n" .parts)")|$n"); done
  pick n "Which disk? (esc = cancel)" "${dopts[@]}" || return 1
  mapfile -t PARTS < <(jq -r --arg n "$n" '.[] | select(.name==$n) | .segs[] | select(.fs | test("^(ext4|xfs|btrfs|vfat|ntfs|exfat)$"))
                                      | [.dev, .fs, (.label // "")] | join("\u001f")' <<<"$DISKS")
  if (( ${#PARTS[@]} == 0 )); then warn "$n has no partition with a renameable filesystem (ext4, xfs, btrfs, FAT, NTFS, exFAT)"; return 1; fi
  i=0
  if (( ${#PARTS[@]} > 1 )); then
    for i in "${!PARTS[@]}"; do IFS=$'\x1f' read -r d fs cur <<<"${PARTS[i]}"; popts+=("$(printf '%-11s %-6s %s' "$d" "$fs" "${cur:-—}")|$i"); done
    pick i "Which partition on $n?" "${popts[@]}" || return 1
  fi
  IFS=$'\x1f' read -r d fs cur <<<"${PARTS[i]}"
  if [[ $cur =~ ^(nixos|nixos-luks.*|EFI[0-9]*)$ ]]; then
    warn "\"$cur\" is a system label — your host configs find the system disk by this name, so it stays as is"; return 1
  fi
  ask_label lbl "$fs" "$cur" || return 1
  [[ $lbl == "$cur" ]] && return 1
  if is_foreign "$n"; then yesno "$n belongs to another OS ($(disk "$n" .os)). Rename \"${cur:-no label}\" → \"$lbl\"?" || return 1; fi
  FORMAT_CMDS+=("$(relabel_cmd "$fs" "$d" "$lbl")   # rename only — data untouched")
  local j; for j in ALL VISIBLE DISKS; do
    printf -v "$j" '%s' "$(jq --arg d "$d" --arg l "$lbl" 'map(.segs |= map(if .dev == $d then .label = $l else . end))' <<<"${!j}" | norm)"
  done
  NOTE+="${G}✓ $d renamed ${cur:-(no label)} → $lbl${N} ${D}(demo: simulated — the real installer renames it now)${N}"$'\n'
}

# --------------------------------------------------------------------------
# RAID suggestions — sizes on stdin → "id|usable|survives|note|star" / "-|id|reason"
# --------------------------------------------------------------------------
raid_options() {
  awk -v scope="$1" '
    { s[NR]=$1; sum+=$1; if (NR==1 || $1<min) min=$1
      if ($1>max) { max2=max; max=$1 } else if ($1>max2) max2=$1 }
    function lo(a,b) { return a<b ? a : b }
    function opt(id,u,f,note,star) { printf "%s|%.0f|%d|%s|%s\n", id,u,f,note,star }
    END {
      n=NR; eq=(max/min<=1.05); waste=sum-n*min
      zn = eq ? "" : sprintf("⚠ every disk counted as %.1fT → %.1fT wasted", min/1e12, waste/1e12)
      best = n==2 ? (eq?"zfs-mirror":"btrfs-raid1") : n==3 ? (eq?"zfs-raidz1":"btrfs-raid1") : (eq?"zfs-raidz2":"btrfs-raid10")
      if (scope=="system" && best ~ /raidz/) best = eq ? "zfs-mirror" : "btrfs-raid1"
      opt("btrfs-raid1",  lo(sum/2, sum-max), 1, eq?"flexible, add any size disk later":"mixed sizes — btrfs uses all of them", best=="btrfs-raid1")
      if (n>=3) opt("btrfs-raid1c3", lo(sum/3, sum-max-max2), 2, "3 copies of everything", 0); else print "-|btrfs-raid1c3|needs ≥ 3 disks"
      if (n>=4) opt("btrfs-raid10", lo(sum/2, sum-max), 1, "striped mirrors — faster", best=="btrfs-raid10"); else print "-|btrfs-raid10|needs ≥ 4 disks"
      opt("zfs-mirror", min, n-1, (n>2 ? n "-way, " : "") "fastest reads " zn, best=="zfs-mirror")
      if (scope=="data") {
        if (n>=3) opt("zfs-raidz1", (n-1)*min, 1, "best space with protection " zn, best=="zfs-raidz1"); else print "-|zfs-raidz1|needs ≥ 3 disks"
        if (n>=4) opt("zfs-raidz2", (n-2)*min, 2, "any 2 disks can die " zn, best=="zfs-raidz2"); else print "-|zfs-raidz2|needs ≥ 4 disks"
        if (n>=5) opt("zfs-raidz3", (n-3)*min, 3, "for very large pools " zn, 0); else print "-|zfs-raidz3|needs ≥ 5 disks"
      }
    }'
}

# choose_raid <system|data> disk… → RAID_CHOICE
choose_raid() {
  local scope=$1; shift
  local sizes rows labels=() blocked="" warns="" d s
  sizes=$(for d in "$@"; do disk "$d" .size; done)
  rows=$(raid_options "$scope" <<<"$sizes")
  while IFS='|' read -r id u f note star; do
    if [[ $id == - ]]; then blocked+=$(printf "\n   %-16s %s" "$u" "$f"); continue; fi
    labels+=("$(printf "%-16s %-8s %-10s %s %s" "$id" "$(hsize "$u")" "$f disk$([[ $f == 1 ]] || echo s)" "$([[ $star == 1 ]] && echo ★ || true)" "$note")|$id")
  done <<<"$rows"
  [[ $(for d in "$@"; do disk "$d" .rota; done | sort -u | wc -l) -gt 1 ]] && warns+="⚠ SSD + HDD mixed — pool runs at HDD speed"$'\n'
  for d in "$@"; do
    s=$(disk "$d" .smart)
    [[ ${s%%|*} == warn ]] && warns+="⚠ $d: ${s#*|} — weakest disk in the pool"$'\n'
    [[ $(disk "$d" .tran) == usb ]] && warns+="⚠ $d is USB-attached — USB disks drop out of pools at random"$'\n'
    [[ -n $(disk "$d" .parts) ]] && warns+="⚠ $d has data ($(disk "$d" .parts)) — will be WIPED"$'\n'
  done
  CTX=$(box "$# disks: $(for d in "$@"; do printf '%s %s · ' "$d" "$(hsize "$(disk "$d" .size)")"; done)" \
       "" "Mirror = every block on 2+ disks. Parity (raidz) = data + parity spread over 3+ disks." \
       "★ = best fit for these disks. RAID is NOT a backup — it survives dead disks, not rm -rf." \
       "${warns%$'\n'}" "${blocked:+unavailable:$blocked}")
  pick RAID_CHOICE "   LAYOUT           USABLE   SURVIVES" "${labels[@]}"
}

# --------------------------------------------------------------------------
# Saved answers — choices stored per host, disks matched by SERIAL
# (device names like sda/nvme0n1 can swap between boots)
# --------------------------------------------------------------------------
serial_of() { disk "$1" .serial; }
name_of() { jq -r --arg s "$1" '.[] | select(.serial==$s) | .name' <<<"$ALL"; }

answers_json() {
  local o ser=() m mir=() dat=() d
  for m in "${MIRRORS[@]}"; do mir+=("$(serial_of "$m")"); done
  for d in "${DATA[@]}"; do dat+=("$(serial_of "$d")"); done
  for o in "${OTHER[@]}"; do ser+=("$(serial_of "${o%%|*}")|${o#*|}"); done
  jq -n --arg host "$HOST" --arg user "$NIXUSER" --arg layout "$LAYOUT" \
    --arg sys "$(serial_of "$SYS")" --arg home "$([[ -n $HOME_DISK ]] && serial_of "$HOME_DISK" || true)" \
    --arg fs "$FS" --arg sysraid "$SYS_RAID" --arg homefs "$HOME_FS" --arg homelabel "$HOME_LABEL" --arg dlabel "$DATA_LABEL" \
    --arg draid "$DATA_RAID" --arg dfs "$DATA_FS" --arg dkeep "$DATA_KEEP" --arg dmnt "$DATA_MNT" \
    --arg boot "$BOOT" --arg enc "$ENC" --arg swap "$SWAP" \
    --args '{version: 1, host: $host, user: $user, layout: $layout,
      disks: {system: $sys, mirrors: ($ARGS.positional[0] | split(" ") | map(select(. != ""))),
              home: $home, data: ($ARGS.positional[1] | split(" ") | map(select(. != ""))),
              other: ($ARGS.positional[2] | split(" ") | map(select(. != "")))},
      fs: $fs, sys_raid: $sysraid, home_fs: $homefs, home_label: $homelabel,
      data: {raid: $draid, fs: $dfs, keep: ($dkeep == "1"), mount: $dmnt, label: $dlabel},
      boot: $boot, enc: $enc, swap: $swap}' "${mir[*]}" "${dat[*]}" "${ser[*]}"
}

# load_answers <file> — sets every choice; returns 1 if a saved disk is missing
load_answers() {
  local f=$1 s n missing=()
  a() { jq -r "$1 // \"\"" "$f"; }
  SYS=$(name_of "$(a .disks.system)"); [[ -n $SYS ]] || missing+=("system $(a .disks.system)")
  MIRRORS=(); for s in $(a '.disks.mirrors[]'); do n=$(name_of "$s"); if [[ -n $n ]]; then MIRRORS+=("$n"); else missing+=("mirror $s"); fi; done
  DATA=();    for s in $(a '.disks.data[]');    do n=$(name_of "$s"); if [[ -n $n ]]; then DATA+=("$n"); else missing+=("data $s"); fi; done
  OTHER=();   for s in $(a '.disks.other[]');   do n=$(name_of "${s%%|*}"); [[ -n $n ]] && OTHER+=("$n|${s#*|}"); done
  HOME_DISK=""; s=$(a .disks.home); if [[ -n $s ]]; then HOME_DISK=$(name_of "$s"); [[ -n $HOME_DISK ]] || missing+=("home $s"); fi
  LAYOUT=$(a .layout); FS=$(a .fs); SYS_RAID=$(a .sys_raid); HOME_FS=$(a .home_fs); HOME_LABEL=$(a .home_label); HOME_LABEL=${HOME_LABEL:-home}
  DATA_RAID=$(a .data.raid); DATA_FS=$(a .data.fs); DATA_MNT=$(a .data.mount); DATA_LABEL=$(a .data.label); DATA_LABEL=${DATA_LABEL:-data}
  DATA_KEEP=0; [[ $(a .data.keep) == true ]] && DATA_KEEP=1
  BOOT=$(a .boot); ENC=$(a .enc); SWAP=$(a .swap)
  DISKS=$ALL; mapfile -t NAMES < <(jq -r '.[].name' <<<"$VISIBLE")
  if ((DATA_KEEP)) && ((${#DATA[@]})); then DATA_OLDLABEL=$(disk "${DATA[0]}" .curlabel); fi
  if (( ${#missing[@]} )); then LOAD_MISSING=$(printf '  ✗ %s\n' "${missing[@]}"); return 1; fi
}

# --------------------------------------------------------------------------
# Banner — thin "nixos-config" wordmark in the two NixOS logo blues
# (#7EBAE4 / #5277C3), coloured per word so no UTF-8 glyph is ever split.
# compose() shows it whenever it fits the screen, else the slim one-line bar.
# --------------------------------------------------------------------------
banner() {  # banner big|slim
  local lb=$'\e[38;5;110m' db=$'\e[38;5;68m' tb=$'\e[1;38;5;117m' facts demo
  facts="${D}${FW^^} · $HW_CPU CPU · $HW_GPU GPU · $(hsize "$RAM_B") RAM · $HW_FORM$([[ $HW_WIFI == 1 ]] && echo " · WiFi" || true) · network $NET · disks ${FAKE:-real}${N}"
  demo=$(gum style --foreground 214 'DEMO — nothing is written')
  if [[ $1 == slim ]]; then
    printf '%s\n %s' "${tb}❄ nixos-config installer${N}  $demo" "$facts"; return
  fi
  # "nixos-config" in toilet's thin "future" font: nixos light blue, -config dark blue
  local -a w1=('┏┓╻╻╻ ╻┏━┓┏━┓' '┃┗┫┃┏╋┛┃ ┃┗━┓' '╹ ╹╹╹ ╹┗━┛┗━┛')
  local -a w2=('   ┏━╸┏━┓┏┓╻┏━╸╻┏━╸' '╺━╸┃  ┃ ┃┃┗┫┣╸ ┃┃╺┓' '   ┗━╸┗━┛╹ ╹╹  ╹┗━┛')
  local -a side=("${tb}installer${N}" "${D}Linuxury/nixos-config${N}" "$demo")
  local r
  for r in 0 1 2; do printf ' %s%s%s%s%s   %s\n' "$lb" "${w1[r]}" "$db" "${w2[r]}" "$N" "${side[r]}"; done
  printf ' %s' "$facts"
}

# Host facts read from its config (default: the chosen $HOST)
host_desktop() {
  local f="$REPO/hosts/${1:-$HOST}/default.nix" d
  [[ -f $f ]] || { echo "${PROFILE:-?} (new host)"; return; }
  d=$(grep -E '^\s*\.\./\.\./modules/(desktops|compositors|shells)/[a-z0-9-]+' "$f" | sed -E 's#.*modules/[a-z]+/([a-z0-9-]+).*#\1#' | sort -u | paste -sd+)
  echo "${d:-headless}"
}
host_profile() {
  local h=${1:-$HOST}
  if [[ -z ${1:-} && $NEWHOST == 1 ]]; then echo "$PROFILE"
  elif [[ $(host_desktop "$h") == headless* ]]; then echo server
  elif grep -qiE 'services\.tlp|battery|laptop' "$REPO/hosts/$h/default.nix" 2>/dev/null; then echo laptop
  else echo desktop; fi
}
host_kernel() {
  [[ -z ${1:-} && ${FS:-} == zfs ]] && { echo "LTS (ZFS-supported)"; return; }
  local k; k=$(grep -hoE '^\s*boot.kernelPackages = pkgs\.linuxPackages_[a-z]+' "$REPO/hosts/${1:-$HOST}/default.nix" 2>/dev/null | sed 's/.*_//')
  echo "${k:-zen}"
}

# ==========================================================================
# Steps — each returns 0 = next, 1 = back, 3 = jump to $JUMP
# ==========================================================================
step_host() {
  panel "Which host are you installing?" "${D}$(( ${#HOSTS[@]} )) hosts in flake.nix · ↻ = saved answers from a previous install (1-key reinstall)${N}"
  local opts=() l h u
  for l in "${HOSTS[@]}"; do
    read -r h u <<<"$l"
    opts+=("$(printf '%-14s %-10s %-8s %-18.18s %-7s %s' "$h" "$u" "$(host_profile "$h")" "$(host_desktop "$h")" "$(host_kernel "$h")" \
              "$([[ -f $ANSWERS_DIR/$h.json ]] && echo "↻" || true)")|$h")
  done
  pick HOST "  $(printf '%-14s %-10s %-8s %-18s %-7s' HOST USER TYPE DESKTOP KERNEL)" \
    "${opts[@]}" "+ New host     scaffold hosts/<name>/ from a template · hardware detected|NEW" || return 1
  NEWHOST=0; PROFILE=""
  if [[ $HOST == NEW ]]; then
    panel "New host" "$(box "Detected on this machine — used to fill in the new host's template:" \
         "CPU $HW_CPU (microcode) · GPU $HW_GPU (drivers$([[ $HW_GPU == *+* ]] && echo ", hybrid/PRIME" || true))" \
         "Form $HW_FORM$([[ $HW_FORM == laptop ]] && echo " (battery found → power management, LUKS suggested)" || true) · WiFi $([[ $HW_WIFI == 1 ]] && echo yes || echo no)")"
    while :; do
      ask HOST --header "Hostname (letters, digits, dashes)" --placeholder "e.g. Ryzen7700x" || return 1
      [[ $HOST =~ ^[A-Za-z][A-Za-z0-9-]*$ ]] || { warn "invalid hostname"; continue; }
      if printf '%s\n' "${HOSTS[@]}" | grep -q "^$HOST "; then warn "$HOST already exists"; continue; fi
      break
    done
    pick NIXUSER "Primary user" "linuxury   admin/dev|linuxury" "babylinux  daily driver|babylinux" "alex       restricted child account|alex" || return 1
    local lp="laptop   graphical + power management|laptop" dp="desktop  graphical, Home Manager|desktop" sp="server   headless, no Home Manager|server"
    if [[ $HW_FORM == laptop ]]; then pick PROFILE "Profile" "${lp/management/management ★}" "$dp" "$sp" || return 1
    else pick PROFILE "Profile" "${dp/Manager/Manager ★}" "$lp" "$sp" || return 1; fi
    NEWHOST=1; return 0
  fi
  for l in "${HOSTS[@]}"; do read -r h u <<<"$l"; if [[ $h == "$HOST" ]]; then NIXUSER=$u; fi; done

  local f=$ANSWERS_DIR/$HOST.json
  [[ -f $f ]] || return 0
  local summary r
  summary=$(jq -r '"saved: \(.fs)\(if .sys_raid != "" then " (" + .sys_raid + ")" else "" end) · \(.boot) · encryption \(.enc) · swap \(.swap)"' "$f")
  if load_answers "$f"; then
    panel "Reinstall $HOST" "$(box "$summary" "All saved disks found (matched by serial number):" \
      "$(printf '  ✓ %s\n' "$SYS" "${MIRRORS[@]}" "${DATA[@]}" ${HOME_DISK:+"$HOME_DISK"})")"
    pick r "" "Reinstall with saved answers ★   → new host key, then review|saved" "Start fresh|fresh" || return 1
    if [[ $r == saved ]]; then JUMP=6; return 3; fi
  else
    panel "Reinstall $HOST" "$(box "$summary" "Some saved disks are not in this machine anymore:" "$LOAD_MISSING" "" "→ starting fresh")"
    pick r "" "Continue|fresh" || return 1
  fi
}

step_disks() {
  MIRRORS=(); HOME_DISK=""; DATA=(); OTHER=(); LAYOUT=single
  DISKS=$VISIBLE
  local top=""
  [[ -n $HIDDEN ]] && top+="${D}hidden: $HIDDEN (boot USB / removable)${N}"$'\n'
  [[ -z $FAKE && $EUID != 0 ]] && top+="${D}SMART health needs root — run with sudo to see it${N}"$'\n'
  local table; table="${top}$(disk_table "$DISKS")"
  panel "Disks" "$table"
  mapfile -t NAMES < <(jq -r '.[].name' <<<"$DISKS")
  local opts=("Single disk   everything on one disk, other disks untouched|single")
  (( ${#NAMES[@]} > 1 )) && opts+=("Multi-disk    give every disk a role (mirror, /home, data pool, other OS…)|multi")
  opts+=("Format a disk…   erase + new filesystem now, then back to this screen|format")
  opts+=("Rename a label…  change the name a disk shows in the file manager (data untouched)|rename")
  [[ -n $HIDDEN ]] && opts+=("Show removable disks too|show")
  pick LAYOUT "Disk layout" "${opts[@]}" || return 1
  if [[ $LAYOUT == show ]]; then VISIBLE=$ALL; HIDDEN=""; JUMP=$CUR; return 3; fi
  if [[ $LAYOUT == format ]]; then format_tool || true; JUMP=$CUR; return 3; fi
  if [[ $LAYOUT == rename ]]; then rename_tool || true; JUMP=$CUR; return 3; fi

  local dopts=() n s
  for n in "${NAMES[@]}"; do
    s=$(disk "$n" .smart)
    dopts+=("$(printf '%-9s %-7s %-28.28s %s' "$n" "$(hsize "$(disk "$n" .size)")" "$(disk "$n" .model)" "$(health "$s" | sed 's/\x1b\[[0-9;]*m//g')")$(is_foreign "$n" && echo '  ⚠ other OS' || true)|$n")
  done
  while :; do
    pick SYS "System disk (root + boot) — WILL BE WIPED" "${dopts[@]}" || return 1
    if is_foreign "$SYS" && ! confirm_wipe_foreign "$SYS"; then continue; fi
    health_ok "$SYS" || continue
    break
  done
  [[ $LAYOUT == multi ]] || return 0

  local desc act role
  for n in "${NAMES[@]}"; do
    [[ $n == "$SYS" ]] && continue
    desc="$n · $(hsize "$(disk "$n" .size)") $(disk "$n" .model) · $(disk "$n" .parts)"
    if is_foreign "$n"; then
      panel "Disks · other OS on $n" "$table"$'\n'"$(box "$desc" "" "Another OS ($(disk "$n" .os)) lives here:" \
        "• Untouched           NixOS ignores it. Boot it from the firmware menu (F8/F11/F12)." \
        "• Boot menu entry     Add it to the NixOS boot menu (GRUB os-prober, Limine chainload," \
        "                      rEFInd finds it on its own, systemd-boot via the EFI shell)." \
        "• Mount read-only     See its files at /mnt/<name> with zero risk to it." \
        "• Mount read-write    Edit its files. Refused if Windows Fast Startup/hibernation left it dirty." \
        "• Boot entry + mount  Both of the above (read-only)." \
        "• Wipe & reuse        Erase it and give it a NixOS role — you must type the disk model.")"
      pick act "What to do with $n?" "Untouched|untouched" "Boot menu entry|boot" "Mount read-only|mount-ro" \
                 "Mount read-write|mount-rw" "Boot entry + mount read-only|boot+mount-ro" "Wipe & reuse|wipe" || return 1
      if [[ $act != wipe ]] || ! confirm_wipe_foreign "$n"; then OTHER+=("$n|${act/wipe/untouched}"); continue; fi
    fi
    panel "Disks · role for $n" "$table"
    pick role "Role for $desc" \
      "Untouched       leave it exactly as it is|untouched" \
      "Mirror system   copy of the system disk — machine survives either one dying|mirror" \
      "/home           user files on their own disk|home" \
      "Data pool       extra storage at a mount point (/data, /mnt/Games…), one or more disks|data" || return 1
    if [[ $role != untouched ]] && ! health_ok "$n"; then role=untouched; fi
    case $role in
      mirror) MIRRORS+=("$n") ;;
      home)   if [[ -n $HOME_DISK ]]; then warn "/home is already $HOME_DISK — $n joins the data pool"; DATA+=("$n"); else HOME_DISK=$n; fi ;;
      data)   DATA+=("$n") ;;
      *)      OTHER+=("$n|untouched") ;;
    esac
  done
}

FS_INFO=(
  "btrfs     Snapshots (snapper, hourly), compression, subvolumes. Roll back a bad update."
  "          ★ Recommended for desktops/laptops — what every host uses today."
  "ext4      The Linux default. Very stable and simple. No snapshots."
  "xfs       Fast with big files and parallel IO. Cannot shrink. No snapshots."
  "bcachefs  In-kernel, snapshots + compression like btrfs. Still young — expect rough edges."
  "zfs       Best data integrity, pools/raidz, native encryption. Built for servers/NAS."
  "          ⚠ Out-of-tree module: kernel is held to the newest version ZFS supports"
  "            (your hosts run _latest/_zen). Uses a lot of RAM for its cache.")
step_fs() {
  SYS_RAID=""; HOME_FS=""; DATA_RAID=""; DATA_FS=""; DATA_KEEP=0; DATA_MNT=""; HOME_LABEL=home; DATA_LABEL=data; DATA_OLDLABEL=""
  if (( ${#MIRRORS[@]} )); then
    TITLE="Filesystem · system disk + mirror"
    choose_raid system "$SYS" "${MIRRORS[@]}" || return 1; SYS_RAID=$RAID_CHOICE; FS=${SYS_RAID%%-*}
  else
    panel "Filesystem for $SYS" "$(box "${FS_INFO[@]}")"
    pick FS "" "btrfs ★|btrfs" "ext4|ext4" "xfs|xfs" "bcachefs|bcachefs" "zfs  (servers)|zfs" || return 1
  fi
  if [[ -n $HOME_DISK ]]; then
    panel "Filesystem for /home on $HOME_DISK" "$(box "${FS_INFO[@]:0:4}")"
    pick HOME_FS "" "btrfs  snapshots of user files|btrfs" "ext4|ext4" "xfs|xfs" || return 1
    ask_label HOME_LABEL "$HOME_FS" home || return 1
  fi
  if (( ${#DATA[@]} )); then
    panel "Data pool · ${DATA[*]}"
    ask DATA_MNT --header "Mount point for the data pool (${DATA[*]})" --value "/data" || return 1
    if (( ${#DATA[@]} > 1 )); then
      TITLE="Data pool · $DATA_MNT"
      choose_raid data "${DATA[@]}" || return 1; DATA_RAID=$RAID_CHOICE; DATA_FS=${DATA_RAID%%-*}
      ask_label DATA_LABEL "$DATA_FS" "$([[ $DATA_FS == zfs ]] && echo tank || echo data)" || return 1
    else
      local d=${DATA[0]} k=format
      if [[ -n $(disk "$d" .parts) ]]; then
        panel "Data disk $d → $DATA_MNT" "$(disk_table "$(jq --arg n "$d" '[.[] | select(.name==$n)]' <<<"$DISKS")")"
        pick k "$d already contains: $(disk "$d" .parts)" \
          "Keep existing data   mount it as-is by UUID (reinstall-safe)|keep" \
          "Format               wipe it and start fresh|format" || return 1
      fi
      if [[ $k == keep ]]; then
        DATA_KEEP=1; DATA_FS=$(jq -r --arg n "$d" '.[] | select(.name==$n) | [.segs[] | select(.fs != "vfat")][0].fs' <<<"$DISKS")
        DATA_OLDLABEL=$(disk "$d" .curlabel)
        ask_label DATA_LABEL "$DATA_FS" "${DATA_OLDLABEL:-data}" || return 1
      else
        panel "Filesystem for $d → $DATA_MNT" "$(box "${FS_INFO[@]}")"
        pick DATA_FS "" "btrfs|btrfs" "ext4|ext4" "xfs  good for big media files|xfs" "zfs|zfs" || return 1
        ask_label DATA_LABEL "$DATA_FS" "$([[ $DATA_FS == zfs ]] && echo tank || echo data)" || return 1
      fi
    fi
  fi
}

step_boot() {
  panel "Bootloader  (${FW^^} detected)" "$(box \
       "systemd-boot  Minimal and fast, lists every generation. UEFI only. ★ current default" \
       "GRUB          Most compatible: UEFI + legacy BIOS. Themeable, a bit slower." \
       "              Best at mirrored boot (mirroredBoots) and finding other OSes (os-prober)." \
       "Limine        Modern, fast, nice menu. UEFI + BIOS. Newer NixOS module." \
       "rEFInd        Graphical, auto-detects OSes on other disks. UEFI only." \
       "              Good if you boot Windows from its own disk through the menu.")"
  local o=()
  [[ $FW == uefi ]] && o+=("systemd-boot ★|systemd-boot")
  o+=("GRUB|grub" "Limine|limine")
  [[ $FW == uefi ]] && o+=("rEFInd|refind")
  [[ $FW == bios ]] && warn "Legacy BIOS: systemd-boot and rEFInd need UEFI — hidden"
  pick BOOT "" "${o[@]}" || return 1
}

step_enc() {
  local lstar=""; [[ $HW_FORM == laptop ]] && lstar=" ★ (laptop detected)"
  if [[ $FS == zfs ]]; then
    panel "Encryption" "$(box "ZFS has its own encryption — used instead of LUKS." "Passphrase at every boot; protects data if the machine is stolen.")"
    pick ENC "" "ZFS native encryption$lstar|zfs" "None   boots straight to login|none" || return 1
  else
    panel "Encryption" "$(box "LUKS2  Passphrase at every boot. Protects your data if the device is stolen." \
         "       Recommended for laptops. With a mirror, both disks unlock with the same passphrase." \
         "None   Boots straight to login. Fine for desktops/servers that never leave the house.")"
    pick ENC "" "LUKS2$lstar|luks" "None|none" || return 1
  fi
}

step_swap() {
  local def=$(( RAM_B/1000000000 < 16 ? RAM_B/1000000000 : 16 ))
  if [[ $FS == zfs ]]; then
    panel "Swap  (RAM $(hsize "$RAM_B"))" "$(box "Swap on ZFS can deadlock under memory pressure — zram (compressed RAM) is used instead.")"
    pick SWAP "" "OK|0" || return 1
  else
    panel "Swap  (RAM $(hsize "$RAM_B"))"
    pick SWAP "" "${def}G swapfile ★   (RAM, capped at 16G — hibernate needs ≥ RAM)|$def" \
      "Custom size|custom" "zram only   compressed RAM swap, no disk swap|0" || return 1
    if [[ $SWAP == custom ]]; then ask SWAP --header "Swapfile size in GB" --value "$def" || return 1; fi
  fi
}

step_secrets() {
  [[ -f $TMP/ssh_host_ed25519_key ]] || ssh-keygen -q -t ed25519 -N "" -C "root@$HOST" -f "$TMP/ssh_host_ed25519_key"
  local pub; pub=$(cut -d' ' -f1,2 "$TMP/ssh_host_ed25519_key.pub")
  panel "Secrets (agenix)" "$(box "Host key generated for $HOST (real run: /mnt/etc/ssh/ssh_host_ed25519_key):" "$pub")
$(qrencode -t ansiutf8 -m 1 "$pub")
$(box "Via install-host (SSH): this step runs by itself on your admin machine." \
      "At the console: on your admin machine run" "  add-host $HOST '$pub'")"
  pick SECRETS "" "I ran add-host — pull the re-keyed secrets|done" "Skip — secrets fail until re-keyed later (docs/06)|skip" || return 1
}

other_action() {  # boot+mount-ro → "in boot menu + mounted read-only"
  case $1 in
    boot) echo "in boot menu" ;; mount-ro) echo "mounted read-only" ;; mount-rw) echo "mounted read-write" ;;
    boot+mount-ro) echo "in boot menu + mounted read-only" ;; *) echo "$1" ;;
  esac
}

planned() {  # DISKS + choices → same JSON shape; .segs = new layout (with .purpose), .action, .same
  local n p=() fsl sz segs act o same rootp dd
  fsl=$([[ $ENC == luks ]] && echo "luks+$FS" || echo "$FS")
  for n in "${NAMES[@]}"; do
    act="${D}untouched${N}"; same=true; sz=$(disk "$n" .size)
    segs=$(jq -c --arg n "$n" '.[] | select(.name==$n) | .segs | map(. + {purpose: "not mounted"})' <<<"$DISKS")
    if [[ " $SYS ${MIRRORS[*]} " == *" $n "* ]]; then
      act="${R}WIPE${N}"; same=false
      rootp="/ system"; [[ -z $HOME_DISK ]] && rootp+=" + /home"
      [[ $n != "$SYS" ]] && rootp="mirror copy of $SYS"
      segs=$(jq -nc --arg fs "$fsl" --arg l "nixos" --argjson s "$sz" --arg fw "$FW" \
        --arg p1 "$(part "$n" 1 | sed 's#/dev/##')" --arg p2 "$(part "$n" 2 | sed 's#/dev/##')" --arg rp "$rootp" \
        --arg bp "$([[ $n == "$SYS" ]] && echo "boot loader" || echo "boot loader (copy)")" \
        'if $fw == "uefi" then [{dev:$p1,fs:"vfat",label:"EFI",size:1073741824,purpose:$bp},{dev:$p2,fs:$fs,label:$l,size:($s-1073741824),purpose:$rp}]
         else [{dev:$p1,fs:"bios_grub",label:"",size:1048576,purpose:"GRUB boot area"},{dev:$p2,fs:$fs,label:$l,size:($s-1048576),purpose:$rp}] end')
    elif [[ $n == "$HOME_DISK" ]]; then
      act="${R}WIPE${N}"; same=false
      segs=$(jq -nc --arg n "$n" --arg fs "$HOME_FS" --arg l "$HOME_LABEL" --argjson s "$sz" '[{dev:$n,fs:$fs,label:$l,size:$s,purpose:"/home"}]')
    elif [[ " ${DATA[*]} " == *" $n "* ]]; then
      same=false
      if [[ $DATA_KEEP == 1 ]]; then
        act="${G}keep${N}"; dd=$(disk "$n" .datadev)
        [[ $DATA_LABEL != "$DATA_OLDLABEL" ]] && act+=" · label ${DATA_OLDLABEL:-—} → $DATA_LABEL"
        segs=$(jq -c --arg d "$dd" --arg l "$DATA_LABEL" --arg m "$DATA_MNT" 'map(if .dev == $d then .label = $l | .purpose = $m else . end)' <<<"$segs")
      else
        act="${R}WIPE${N}"
        segs=$(jq -nc --arg n "$n" --arg fs "${DATA_RAID:-$DATA_FS}" --arg l "$DATA_LABEL" --argjson s "$sz" \
          --arg m "$DATA_MNT$([[ -n $DATA_RAID ]] && echo " (pool member)" || true)" '[{dev:$n,fs:$fs,label:$l,size:$s,purpose:$m}]')
      fi
    else
      for o in "${OTHER[@]}"; do
        [[ ${o%%|*} == "$n" ]] || continue
        act="${D}$(other_action "${o#*|}")${N}"
        [[ ${o#*|} == untouched ]] && continue
        same=false; dd=$(disk "$n" .datadev)
        local pu=""; [[ ${o#*|} == *boot* ]] && pu="in boot menu"
        [[ ${o#*|} == *mount* ]] && pu+="${pu:+ + }/mnt/$(disk "$n" .os | sed 's/./\u&/') ($([[ ${o#*|} == *rw ]] && echo rw || echo ro))"
        segs=$(jq -c --arg d "$dd" --arg p "$pu" 'map(if .dev == $d then .purpose = $p else . end)' <<<"$segs")
      done
    fi
    p+=("$(jq -nc --arg n "$n" --argjson s "$sz" --argjson g "$segs" --arg a "$act" --argjson same "$same" '{name:$n,size:$s,segs:$g,action:$a,same:$same}')")
  done
  printf '%s\n' "${p[@]}" | jq -s .
}

review_summary() {  # "Changes: wipe nvme0n1 · keep sda → /data · 1 untouched"
  jq -r '[.[] | (.action | gsub("\u001b\\[[0-9;]*m"; "")) as $a
          | if ($a|startswith("WIPE")) then "wipe \(.name)"
            elif ($a|startswith("keep")) then "keep \(.name)" + ([.segs[] | select(.purpose|startswith("/")) | " → " + .purpose][0] // "")
            elif .same then empty else "\(.name): \($a)" end] as $c
        | ([.[] | select(.same)] | length) as $u
        | "Changes: " + (($c + (if $u > 0 then ["\($u) untouched"] else [] end)) | join(" · "))' <<<"$1"
}

# panel_box "Title" "line"… — fixed-width box so two sit side by side
panel_box() {
  local t=$1; shift
  gum style --border rounded --border-foreground 240 --padding "0 1" --width 42 \
    "$(gum style --bold --foreground 212 "$t")" "$@"
}

review_warnings() {
  local w=() n s
  for n in "$SYS" "${MIRRORS[@]}" "${DATA[@]}" ${HOME_DISK:+"$HOME_DISK"}; do
    s=$(disk "$n" .smart)
    case ${s%%|*} in warn) w+=("$n: ${s#*|}") ;; fail) w+=("$n: ${s#*|} — data at risk") ;; esac
  done
  [[ $FS == zfs || $DATA_FS == zfs ]] && w+=("ZFS holds the kernel to the newest version it supports")
  [[ $HW_FORM == laptop && $ENC == none ]] && w+=("laptop without encryption — data readable if it's stolen")
  [[ $SECRETS != "done" ]] && w+=("secrets skipped — they fail until re-keyed (docs/06)")
  [[ $FS == btrfs && -n $SYS_RAID ]] && w+=("btrfs mirror: after a disk dies, boot once with -o degraded")
  for n in "${OTHER[@]}"; do is_foreign "${n%%|*}" && w+=("${n%%|*} has another OS ($(disk "${n%%|*}" .os)) — $(other_action "${n#*|}")"); done
  if (( ${#w[@]} == 0 )); then echo "${G}✓ No warnings${N}"; else printf "${Y}⚠ %s${N}\n" "${w[@]}"; fi
}

step_review() {
  local plan; plan=$(planned)
  local shown; shown=$(jq --argjson keep "$(printf '%s\n' "${NAMES[@]}" | jq -R . | jq -s .)" '[.[] | select(.name as $n | $keep | index($n))]' <<<"$DISKS")
  local next; next=$(checklist | grep -c '☐' || true)
  local p1 p2 p3 p4
  p1=$(panel_box "System" \
    "Host     $HOST$([[ $NEWHOST == 1 ]] && echo " (new)" || true)" \
    "User     $NIXUSER (uid $(uid_of "$NIXUSER"))" \
    "Desktop  $(host_desktop)" \
    "Kernel   $(host_kernel)" \
    "Profile  $(host_profile)")
  p2=$(panel_box "Hardware" \
    "CPU      $HW_CPU (microcode)" \
    "GPU      $HW_GPU" \
    "RAM      $(hsize "$RAM_B") · $HW_FORM" \
    "Network  $NET$([[ $HW_WIFI == 1 ]] && echo " · WiFi" || true)" \
    "Firmw.   ${FW^^}")
  p3=$(panel_box "Boot & security" \
    "Boot     ${FW^^} · $BOOT" \
    "Mirror   $( (( ${#MIRRORS[@]} )) && echo "ESP on $(( ${#MIRRORS[@]} + 1 )) disks" || echo "no")" \
    "Encrypt  $([[ $ENC == none ]] && echo none || echo "$ENC (passphrase at boot)")" \
    "Swap     $([[ $SWAP == 0 ]] && echo "zram (compressed RAM)" || echo "${SWAP}G swapfile")" \
    "Secrets  $([[ $SECRETS == "done" ]] && echo "re-keyed ✓" || echo "skipped")")
  p4=$(panel_box "After install" \
    "Writes   disk.nix · install.json$([[ $NEWHOST == 1 ]] && echo " · host" || true)" \
    "Log      /tmp/nixos-install.log" \
    "Next     $next steps (docs/06)" \
    "Resume   install.sh --resume" \
    "Saved    answers → 1-key reinstall")
  panel "Review — $HOST" \
"$(gum join --horizontal "$p1" " " "$p2")
$(gum join --horizontal "$p3" " " "$p4")
$(review_warnings)

${B}$(review_summary "$plan")${N}
$(disk_table "$shown" "$plan")"
  local a; pick a "" "Install|go" "Edit a step…|edit" || return 1
  if [[ $a == edit ]]; then
    local i o=(); for ((i = 0; i < ${#STEP_NAMES[@]} - 1; i++)); do o+=("${STEP_NAMES[i]}|$i"); done
    pick JUMP "Jump to" "${o[@]}" || return 1; return 3
  fi
  local typed; ask typed --header "Type \"$HOST\" to install (DEMO: nothing happens)" --placeholder "$HOST" || return 1
  [[ $typed == "$HOST" ]] || { warn "Didn't match"; JUMP=$CUR; return 3; }
}

# ==========================================================================
# Output generators
# ==========================================================================
uefi() { [[ $FW == uefi ]]; }
gen_disk_nix() {
  local i n
  cat <<EOF
# ===========================================================================
# hosts/$HOST/disk.nix — generated by install.sh on $(date +%F)
# Disks: ${SYS_DISKS[*]}${HOME_DISK:+ · home $HOME_DISK}${DATA[*]:+ · data ${DATA[*]}}
# Everything is referenced by label/UUID — device names don't matter.
# ===========================================================================
{ config, lib, pkgs, ... }:

{
EOF
  case $BOOT in
    systemd-boot) echo '  boot.loader.systemd-boot.enable = true;'
                  echo '  boot.loader.efi.canTouchEfiVariables = true;' ;;
    grub)  echo '  boot.loader.systemd-boot.enable = lib.mkForce false;'
           echo '  boot.loader.grub.enable = true;'
           if uefi; then echo '  boot.loader.grub.efiSupport = true;'; echo '  boot.loader.efi.canTouchEfiVariables = true;'; fi
           if (( ${#MIRRORS[@]} )); then
             echo '  boot.loader.grub.mirroredBoots = ['
             for i in "${!SYS_DISKS[@]}"; do
               n=$((i+1))
               if uefi; then echo "    { path = \"/boot$([[ $n == 1 ]] || echo $n)\"; devices = [ \"nodev\" ]; }"
               else echo "    { path = \"/boot\"; devices = [ \"/dev/disk/by-id/<${SYS_DISKS[$i]}-id>\" ]; }"; fi
             done; echo '  ];'
           elif uefi; then echo '  boot.loader.grub.device = "nodev";'
           else echo "  boot.loader.grub.device = \"/dev/disk/by-id/<$SYS-id>\";"; fi
           if [[ " ${OTHER[*]} " == *"|boot"* ]]; then echo '  boot.loader.grub.useOSProber = true;   # adds the other-OS disk(s) to the menu'; fi ;;
    limine) echo '  boot.loader.systemd-boot.enable = lib.mkForce false;'
            echo '  boot.loader.limine.enable = true;'
            if uefi; then echo '  boot.loader.limine.efiSupport = true;'; else echo "  boot.loader.limine.biosDevice = \"/dev/disk/by-id/<$SYS-id>\";"; fi
            if [[ " ${OTHER[*]} " == *"|boot"* ]]; then echo '  # boot.loader.limine.extraEntries = "/Windows\n  protocol: efi\n  path: guid(<ESP-GUID>):/EFI/Microsoft/Boot/bootmgfw.efi";'; fi ;;
    refind) echo '  boot.loader.systemd-boot.enable = lib.mkForce false;'
            echo '  boot.loader.refind.enable = true;   # scans every disk for other OSes on its own'
            echo '  boot.loader.efi.canTouchEfiVariables = true;' ;;
  esac
  if [[ $BOOT == systemd-boot && " ${OTHER[*]} " == *"|boot"* ]]; then
    echo '  boot.loader.systemd-boot.edk2-uefi-shell.enable = true;'
    echo '  # boot.loader.systemd-boot.windows."11".efiDeviceHandle = "HD1b";  # find with `map -c` in the EFI shell'
  fi
  if (( ${#MIRRORS[@]} )) && [[ $BOOT != grub ]] && uefi; then
    echo; echo '  # Keep the mirror ESPs identical so either disk can boot alone'
    echo '  system.activationScripts.espMirror.text = '"''"
    for i in "${!MIRRORS[@]}"; do echo "    \${pkgs.rsync}/bin/rsync -a --delete /boot/ /boot$((i+2))/ || true"; done
    echo "  '';"
  fi
  if [[ $ENC == luks ]]; then
    echo
    for i in "${!SYS_DISKS[@]}"; do n=$((i+1))
      echo "  boot.initrd.luks.devices.\"cryptroot$n\" = { device = \"/dev/disk/by-label/nixos-luks$n\"; allowDiscards = true; };"
    done
  fi
  echo
  case $FS in
    btrfs)
      local mo='"compress=zstd:1" "noatime"' sv mp
      [[ -n $SYS_RAID ]] && echo "  # btrfs ${SYS_RAID#btrfs-} across ${#SYS_DISKS[@]} disks — one label covers every member"
      for sv in "@:/" "@home:/home" "@nix:/nix" "@log:/var/log" "@cache:/var/cache" "@snapshots:/.snapshots" "@home_snapshots:/home/.snapshots" "@swap:/swap"; do
        mp=${sv#*:}; [[ -n $HOME_DISK && $mp == /home* ]] && continue
        if [[ $mp == /swap ]]; then [[ $SWAP == 0 ]] && continue; mo='"noatime"'; fi
        echo "  fileSystems.\"$mp\" = { device = \"/dev/disk/by-label/nixos\"; fsType = \"btrfs\"; options = [ \"subvol=${sv%%:*}\" $mo ]; };"
      done ;;
    zfs)
      echo '  boot.supportedFilesystems = [ "zfs" ];'
      echo "  networking.hostId = \"$(head -c4 /dev/urandom | od -An -tx1 | tr -d ' \n')\";   # required by ZFS, random per host"
      echo '  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;   # ZFS-supported kernel (overrides _latest/_zen)'
      local ds; for ds in "root:/" "home:/home" "nix:/nix" "log:/var/log"; do
        [[ -n $HOME_DISK && ${ds#*:} == /home ]] && continue
        echo "  fileSystems.\"${ds#*:}\" = { device = \"rpool/${ds%%:*}\"; fsType = \"zfs\"; options = [ \"zfsutil\" ]; };"
      done ;;
    *) echo "  fileSystems.\"/\" = { device = \"/dev/disk/by-label/nixos\"; fsType = \"$FS\"; options = [ \"noatime\" ]; };" ;;
  esac
  if uefi; then
    echo "  fileSystems.\"/boot\" = { device = \"/dev/disk/by-label/EFI\"; fsType = \"vfat\"; options = [ \"umask=0077\" ]; };"
    for i in "${!MIRRORS[@]}"; do n=$((i+2))
      echo "  fileSystems.\"/boot$n\" = { device = \"/dev/disk/by-label/EFI$n\"; fsType = \"vfat\"; options = [ \"umask=0077\" \"nofail\" ]; };"
    done
  fi
  if [[ -n $HOME_DISK ]]; then echo; echo "  fileSystems.\"/home\" = { device = \"/dev/disk/by-label/$HOME_LABEL\"; fsType = \"$HOME_FS\"; options = [ \"noatime\" ]; };"; fi
  if (( ${#DATA[@]} )); then
    echo
    if [[ $DATA_KEEP == 1 ]]; then
      echo "  fileSystems.\"$DATA_MNT\" = { device = \"/dev/disk/by-uuid/$(disk "${DATA[0]}" .uuid)\"; fsType = \"$DATA_FS\"; options = [ \"nofail\" ]; };   # kept as-is, label $DATA_LABEL"
    elif [[ $DATA_FS == zfs ]]; then
      [[ $FS == zfs ]] || echo '  boot.supportedFilesystems = [ "zfs" ];'
      echo "  boot.zfs.extraPools = [ \"$DATA_LABEL\" ];   # ${DATA_RAID:-single disk}"
      echo "  fileSystems.\"$DATA_MNT\" = { device = \"$DATA_LABEL/data\"; fsType = \"zfs\"; options = [ \"zfsutil\" \"nofail\" ]; };"
    else
      echo "  fileSystems.\"$DATA_MNT\" = { device = \"/dev/disk/by-label/$DATA_LABEL\"; fsType = \"$DATA_FS\"; options = [ \"noatime\" \"nofail\" ]; };   # ${DATA_RAID:-single disk}"
    fi
  fi
  local o2 dn act
  for o2 in "${OTHER[@]}"; do
    dn=${o2%%|*} act=${o2#*|}
    [[ $act == *mount* ]] || continue
    echo "  fileSystems.\"/mnt/$(disk "$dn" .os | sed 's/./\u&/')\" = { device = \"/dev/disk/by-uuid/$(disk "$dn" .uuid)\"; fsType = \"ntfs3\"; options = [ \"$([[ $act == *rw ]] && echo rw || echo ro)\" \"nofail\" ]; };"
  done
  echo
  if [[ $SWAP == 0 ]]; then echo '  zramSwap.enable = true;'
  elif [[ $FS == btrfs ]]; then echo '  swapDevices = [ { device = "/swap/swapfile"; } ];'
  else echo "  swapDevices = [ { device = \"/swapfile\"; size = $((SWAP*1024)); } ];"; fi
  echo '}'
}

gen_commands() {
  local i n d p2 root=()
  echo "# Everything below is logged to /tmp/nixos-install.log; each phase saves a checkpoint."
  if (( ${#FORMAT_CMDS[@]} )); then
    echo "# [disk tools] already ran when you confirmed them on the Disks screen"
    printf '%s\n' "${FORMAT_CMDS[@]}"
  fi
  echo "# [1/7] partition"
  for i in "${!SYS_DISKS[@]}"; do d=${SYS_DISKS[$i]}; n=$((i+1))
    echo "wipefs -a /dev/$d && parted -s /dev/$d -- mklabel gpt"
    if uefi; then echo "parted -s /dev/$d -- mkpart ESP fat32 1MiB 1GiB set 1 esp on mkpart root 1GiB 100%"
                  echo "mkfs.fat -F32 -n EFI$([[ $n == 1 ]] || echo $n) $(part "$d" 1)"
    else echo "parted -s /dev/$d -- mkpart bios 1MiB 2MiB set 1 bios_grub on mkpart root 2MiB 100%"; fi
  done
  echo "# [2/7] encryption + filesystems"
  for i in "${!SYS_DISKS[@]}"; do d=${SYS_DISKS[$i]}; n=$((i+1)); p2=$(part "$d" 2)
    if [[ $ENC == luks ]]; then
      echo "cryptsetup luksFormat --type luks2 --label nixos-luks$n $p2"
      echo "cryptsetup open $p2 cryptroot$n"; root+=("/dev/mapper/cryptroot$n")
    else root+=("$p2"); fi
  done
  case $FS in
    btrfs) echo "mkfs.btrfs -f -L nixos ${SYS_RAID:+-d ${SYS_RAID#btrfs-} -m ${SYS_RAID#btrfs-} }${root[*]}"
           echo "mount ${root[0]} /mnt && for s in @ @home @nix @log @cache @snapshots @home_snapshots @swap; do btrfs subvolume create /mnt/\$s; done && umount /mnt" ;;
    zfs)   echo "zpool create -f -o ashift=12 -O compression=zstd -O acltype=posixacl -O xattr=sa -O mountpoint=none \\"
           if [[ $ENC == zfs ]]; then echo "  -O encryption=on -O keyformat=passphrase \\"; fi
           echo "  rpool $([[ -n $SYS_RAID ]] && echo mirror || true) ${root[*]}"
           echo "for d in root home nix log; do zfs create -o mountpoint=legacy rpool/\$d; done" ;;
    *)     echo "mkfs.$FS -L nixos ${root[0]}" ;;
  esac
  if [[ -n $HOME_DISK ]]; then echo "wipefs -a /dev/$HOME_DISK && mkfs.$HOME_FS -L $HOME_LABEL /dev/$HOME_DISK"; fi
  if (( ${#DATA[@]} )) && [[ $DATA_KEEP == 0 ]]; then
    local devs l; devs=$(printf '/dev/%s ' "${DATA[@]}")
    case ${DATA_RAID:-$DATA_FS} in
      btrfs-*) echo "mkfs.btrfs -f -L $DATA_LABEL -d ${DATA_RAID#btrfs-} -m ${DATA_RAID#btrfs-} $devs" ;;
      zfs-*)   l=${DATA_RAID#zfs-}; echo "zpool create -f -o ashift=12 -O compression=zstd -O mountpoint=none $DATA_LABEL $l $devs"
               echo "zfs create -o mountpoint=legacy $DATA_LABEL/data" ;;
      zfs)     echo "zpool create -f -o ashift=12 -O mountpoint=none $DATA_LABEL $devs && zfs create -o mountpoint=legacy $DATA_LABEL/data" ;;
      *)       echo "mkfs.$DATA_FS -L $DATA_LABEL $devs" ;;
    esac
  fi
  if [[ $DATA_KEEP == 1 && $DATA_LABEL != "$DATA_OLDLABEL" ]]; then
    echo "$(relabel_cmd "$DATA_FS" "$(disk "${DATA[0]}" .datadev)" "$DATA_LABEL")   # rename only — data untouched"
  fi
  echo "# [3/7] mount + swap"
  echo "mount <every fileSystems entry above> under /mnt"
  if [[ $SWAP != 0 && $FS == btrfs ]]; then echo "btrfs filesystem mkswapfile --size ${SWAP}G /mnt/swap/swapfile"; fi
  echo "# [4/7] config"
  echo "git clone https://github.com/Linuxury/nixos-config /mnt/home/$NIXUSER/nixos-config"
  if [[ $NEWHOST == 1 ]]; then echo "scaffold hosts/$HOST from hosts/_template ($PROFILE · CPU $HW_CPU · GPU $HW_GPU) + mkHost entry in flake.nix"; fi
  echo "write hosts/$HOST/disk.nix + hosts/$HOST/install.json && git add -A && git commit -m \"$HOST: install\" && git push"
  echo "# [5/7] secrets"
  echo "install -Dm600 ssh_host_ed25519_key /mnt/etc/ssh/ssh_host_ed25519_key"
  if [[ $SECRETS == "done" ]]; then echo "git pull   # add-host's re-keyed secrets"; fi
  echo "# [6/7] install"
  echo "nixos-install --flake /mnt/home/$NIXUSER/nixos-config#$HOST --no-root-passwd"
  echo "nixos-enter --root /mnt -- passwd $NIXUSER"
  echo "# [7/7] finish"
  echo "cp /tmp/nixos-install.log /mnt/var/log/ && chown -R $(uid_of "$NIXUSER"):100 /mnt/home/$NIXUSER/nixos-config && umount -R /mnt"
  echo "#"
  echo "# A phase failed (network, typo in config…)? Fix it and run:  install.sh --resume"
  echo "# → re-opens LUKS, re-mounts, and continues from the failed phase. No re-partitioning."
}

checklist() {  # post-install steps for this host, straight from docs/06
  awk -v host="$HOST" -v sec="$SECRETS" '
    /^## / { s = ($0 ~ /^## All Machines/) ? "all" : ((host != "" && index($0, host)) ? "host" : ""); if (s == "host") print "\n" substr($0, 4); next }
    /^### / && s { t = substr($0, 5)
                   if (sec == "done" && t ~ /secrets\.nix|apply secrets/) print "  ☑ " t "  (done by installer)"
                   else if (t ~ /Set user passwords/) print "  ☐ " t "  (primary user done by installer)"
                   else print "  ☐ " t }' "$REPO/docs/06-first-boot.md"
}

# ==========================================================================
# Main
# ==========================================================================
detect_hw
if [[ -n $FAKE ]]; then ALL=$(fake_disks "$FAKE" | norm)
else
  ALL=$(real_disks)
  for n in $(jq -r '.[].name' <<<"$ALL"); do
    ALL=$(jq --arg n "$n" --arg s "$(smart_real "$n")" '(.[] | select(.name==$n)).smart = $s' <<<"$ALL")
  done
  ALL=$(norm <<<"$ALL")
fi
BOOTDEV=$(findmnt -no SOURCE /iso 2>/dev/null | sed -E 's#/dev/##; s/p?[0-9]+$//' || true)
VISIBLE=$(jq --arg b "$BOOTDEV" '[.[] | select(.name != $b and .tran != "usb" and (.rm|not))]' <<<"$ALL")
HIDDEN=$(jq -r --arg b "$BOOTDEV" '[.[] | select(.name == $b or .tran == "usb" or .rm) | "\(.name) \(.model)"] | join(", ")' <<<"$ALL")
mapfile -t HOSTS < <(awk '/^ *[A-Za-z0-9-]+ = mkHost/{h=$1} h && /user *=/{gsub(/[";]/,"",$3); print h" "$3; h=""}' "$REPO/flake.nix")
SECRETS=skip
# Saved answers are per disk set — keep fake scenarios apart from real disks
[[ -n $FAKE ]] && ANSWERS_DIR+="/$FAKE"

HEADER_BIG=$(banner big); HEADER_SLIM=$(banner slim)
# alternate screen + hidden cursor: menus don't litter scrollback
if [[ -z ${INSTALL_TEST:-} ]] && tput smcup 2>/dev/null; then ALT=1; tput civis; clear; fi
STEPS=(step_host step_disks step_fs step_boot step_enc step_swap step_secrets step_review)
while (( CUR < ${#STEPS[@]} )); do
  rc=0; "${STEPS[CUR]}" || rc=$?
  case $rc in
    0) CUR=$((CUR + 1)) ;;
    3) CUR=$JUMP ;;
    *) if ((CUR > 0)); then CUR=$((CUR - 1)); fi ;;
  esac
done
if ((ALT)); then tput cnorm; tput rmcup; ALT=0; fi

SYS_DISKS=("$SYS" "${MIRRORS[@]}")
mkdir -p "$ANSWERS_DIR" && answers_json > "$ANSWERS_DIR/$HOST.json"
gum style --bold --foreground 212 "hosts/$HOST/disk.nix  (would be written)"
gen_disk_nix
echo; gum style --bold --foreground 212 "hosts/$HOST/install.json  (saved answers — would be committed)"
cat "$ANSWERS_DIR/$HOST.json"
echo; gum style --bold --foreground 212 "Commands  (would be run)"
gen_commands | gum style --foreground 245
echo; gum style --bold --foreground 212 "After first boot — checklist for $HOST  (from docs/06-first-boot.md)"
checklist
echo; gum style --foreground 82 "✓ Demo complete — nothing was written to disk or repo." \
  "Run the demo again and pick $HOST: it offers ↻ reinstall with these saved answers." \
  "Real run, from the ISO:  sudo nix run github:Linuxury/nixos-config#install" \
  "Or from your admin PC:  install-host <ip>"
