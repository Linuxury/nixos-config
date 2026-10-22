# led-sync — push Noctalia's primary color to the host's RGB.
# Run as the post_hook of the led-sync user template (modules/shells/noctalia),
# which writes the bare hex (e.g. cdbdff) to $XDG_CACHE_HOME/noctalia/led-color.
#
# Material primaries are pastels (~25% saturation) that look white on LEDs,
# so saturation is raised to at least LED_MIN_SAT (0-255) and value maxed out.

min_sat="${LED_MIN_SAT:-200}"
hex=$(tr -dc '0-9a-fA-F' < "${XDG_CACHE_HOME:-$HOME/.cache}/noctalia/led-color")

# hex -> HSV -> boosted hex + QMK hue/sat (both 0-255)
read -r led_hex qmk_hue qmk_sat < <(awk -v hex="$hex" -v min_sat="$min_sat" 'BEGIN {
  r = strtonum("0x" substr(hex, 1, 2)) / 255
  g = strtonum("0x" substr(hex, 3, 2)) / 255
  b = strtonum("0x" substr(hex, 5, 2)) / 255
  max = r > g ? (r > b ? r : b) : (g > b ? g : b)
  min = r < g ? (r < b ? r : b) : (g < b ? g : b)
  d = max - min
  if (d == 0)        h = 0
  else if (max == r) h = 60 * ((g - b) / d)
  else if (max == g) h = 60 * ((b - r) / d + 2)
  else               h = 60 * ((r - g) / d + 4)
  if (h < 0) h += 360
  s = max ? d / max : 0
  if (d > 0 && s < min_sat / 255) s = min_sat / 255   # grey stays white

  k = (h / 60) % 2 - 1; if (k < 0) k = -k
  c = s; x = c * (1 - k); m = 1 - c
  if      (h < 60)  { R = c; G = x; B = 0 }
  else if (h < 120) { R = x; G = c; B = 0 }
  else if (h < 180) { R = 0; G = c; B = x }
  else if (h < 240) { R = 0; G = x; B = c }
  else if (h < 300) { R = x; G = 0; B = c }
  else              { R = c; G = 0; B = x }
  printf "%02x%02x%02x %d %d\n", (R + m) * 255 + 0.5, (G + m) * 255 + 0.5, (B + m) * 255 + 0.5,
    int(h / 360 * 255 + 0.5) % 256, int(s * 255 + 0.5)
}')

# Aura ARGB headers come up as 0-LED zones (the 1.1 server ignores the saved
# sizes), so the board's own pink chase keeps running on the strips. Size them
# first. ponytail: 120 = Aura max, real count unknown; oversizing is harmless.
board="ASUS ROG STRIX B550-E GAMING"
openrgb --client localhost:6742 -d "$board" -z 1 -sz 120 -d "$board" -z 2 -sz 120 >/dev/null 2>&1 || true

# OpenRGB: RAM, motherboard (+ ARGB headers), monitor — everything the server knows.
openrgb --client localhost:6742 --mode static --color "$led_hex" >/dev/null 2>&1 || true

# Lemokey P1 HE (wired): VIA raw-HID interface = usage page 0xFF60.
# 07 03 02 01 = rgb_matrix effect -> solid color; 07 03 04 HH SS = hue, sat.
# No VIA save (0x09): would write EEPROM on every palette change.
for uevent in /sys/class/hidraw/*/device/uevent; do
  grep -q 'HID_ID=0003:0000362D:00000610' "$uevent" || continue
  dir=${uevent%/uevent}
  [ "$(od -An -tx1 -N3 "$dir/report_descriptor" | tr -d ' \n')" = 0660ff ] || continue
  dev=/dev/$(basename "${dir%/device}")
  [ -w "$dev" ] || continue
  printf '\x07\x03\x02\x01' | dd of="$dev" bs=32 conv=sync status=none || true
  printf '%b' "\\x07\\x03\\x04\\x$(printf %02x "$qmk_hue")\\x$(printf %02x "$qmk_sat")" \
    | dd of="$dev" bs=32 conv=sync status=none || true
done
