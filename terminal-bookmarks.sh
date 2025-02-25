# --------------------------------------------------------------------------- #
# ------------------------ B o o k m a r k s BEGIN -------------------------- #
# --------------------------------------------------------------------------- #
#
# TODO: Legg til sjekk slik at du må confirm før du overskriver allerede eksisterende bookmark 
# FIXME: Legg til funksjonalitet som når man godkjenner å overskrive en allerede eksisterende bokmerke så forskyves det bokmærke til bokmerket som påfølger
# NOTE: <== Per nå så forskyves bare ett bokmerke, ikke hele arrayet
# TODO: Legg til funksjonalitet for å kunne slette bokmerke direkte uten å forskyve 

# Fil der bokmerker lagres
BOOKMARK_FILE="$HOME/.bookmarks"

# Global assosiativ array for bokmerker
typeset -A bookmarks

# Laster bokmerker fra filen
load_bookmarks() {
#  echo "DEBUG: Starter load_bookmarks" >&2
  bookmarks=()
#  echo "DEBUG: Sjekker om fil eksisterer: $BOOKMARK_FILE" >&2
  if [ -f "$BOOKMARK_FILE" ]; then
#    echo "DEBUG: Fil finnes, leser med cat" >&2
    while IFS="=" read -r key value || [[ -n "$key" ]]; do
#      echo "DEBUG: Leser linje: key=$key, value=$value" >&2
      [[ -n "$key" && -n "$value" ]] && bookmarks[$key]="$value"
    done < <(cat "$BOOKMARK_FILE")
#    echo "DEBUG: Fullførte lesing fra fil" >&2
  fi
#  echo "DEBUG: Avslutter load_bookmarks" >&2
}

# Lagrer bokmerker til filen
save_bookmarks() {
#  echo "DEBUG: Starter save_bookmarks" >&2
#  echo "DEBUG: Sjekker skrivetillatelse for $BOOKMARK_FILE" >&2
  if [ ! -w "$BOOKMARK_FILE" ] && [ -e "$BOOKMARK_FILE" ]; then
#    echo "Feil: $BOOKMARK_FILE eksisterer, men er ikke skrivbar." >&2
    return 1
  fi
#  echo "DEBUG: Sørger for at filen eksisterer" >&2
  if ! touch "$BOOKMARK_FILE" 2>/dev/null; then
    echo "Feil: Kunne ikke opprette eller oppdatere $BOOKMARK_FILE. Sjekk rettigheter." >&2
    return 1
  fi
#  echo "DEBUG: Tømmer filen" >&2
  if ! : > "$BOOKMARK_FILE" 2>/dev/null; then
    echo "Feil: Kunne ikke tømme $BOOKMARK_FILE. Sjekk rettigheter eller filstatus." >&2
    return 1
  fi
#  echo "DEBUG: Skriver til $BOOKMARK_FILE" >&2
  for key in ${(n)${(k)bookmarks}}; do
#    echo "DEBUG: Skriver linje: $key=${bookmarks[$key]}" >&2
    echo "$key=${bookmarks[$key]}" >> "$BOOKMARK_FILE" 2>/dev/null || {
      echo "Feil: Kunne ikke skrive til $BOOKMARK_FILE under oppdatering." >&2
      return 1
    }
  done
#  echo "DEBUG: Fullførte save_bookmarks" >&2
}

# Flytter bokmerker oppover
shift_bookmarks_from() {
  local num=$1
  local i
#  echo "DEBUG: Starter shift_bookmarks_from med num=$num" >&2
  for i in ${(n)${(k)bookmarks}}; do
    if [[ $i -ge $num ]]; then
      bookmarks[$((i + 1))]="${bookmarks[$i]}"
    fi
  done
#  echo "DEBUG: Fullførte shift_bookmarks_from" >&2
}

# Setter et bokmerke
set_bookmark() {
  local num=$1
#  echo "DEBUG: Starter set_bookmark med num=$num" >&2
  if ! [[ "$num" =~ '^[0-9]+$' ]]; then
#    echo "Feil: '$num' er ikke et gyldig nummer." >&2
    return 1
  fi
#  echo "DEBUG: Kaller load_bookmarks" >&2
  load_bookmarks
#  echo "DEBUG: load_bookmarks fullført" >&2
  if [[ -n "${bookmarks[$num]}" ]]; then
#    echo "DEBUG: Bokmerke finnes, venter på input" >&2
    read -u 0 "confirm?Bokmerke $num finnes allerede (mappe: ${bookmarks[$num]}). Overskriv og flytt eksisterende bokmerker oppover? (y/n): "
    if [[ "$confirm" != "y" ]]; then
      echo "Handling avbrutt." >&2
      return
    else
#      echo "DEBUG: Kaller shift_bookmarks_from" >&2
      shift_bookmarks_from "$num"
    fi
  fi
#  echo "DEBUG: Setter bokmerke" >&2
  bookmarks[$num]="$PWD"
#  echo "DEBUG: Lagrer bokmerker" >&2
  save_bookmarks
#  echo "Bokmerke $num satt til $PWD" >&2
}

# Bytter til bokmerke
goto_bookmark() {
  local num=$1
  if ! [[ "$num" =~ '^[0-9]+$' ]]; then
    echo "Feil: '$num' er ikke et gyldig nummer." >&2
    return 1
  fi
#  echo "DEBUG: Kaller load_bookmarks i goto_bookmark" >&2
  load_bookmarks
  if [[ -n "${bookmarks[$num]}" ]]; then
    if [[ -d "${bookmarks[$num]}" ]]; then
      cd "${bookmarks[$num]}"
    else
      echo "Feil: Mappen '${bookmarks[$num]}' eksisterer ikke lenger." >&2
    fi
  else
    echo "Bokmerke $num er ikke definert." >&2
  fi
}

# Sletter et bokmerke
del_bookmark() {
  local num=$1
  if ! [[ "$num" =~ '^[0-9]+$' ]]; then
    echo "Feil: '$num' er ikke et gyldig nummer." >&2
    return 1
  fi
#  echo "DEBUG: Kaller load_bookmarks i del_bookmark" >&2
  load_bookmarks
  if [[ -n "${bookmarks[$num]}" ]]; then
    unset bookmarks[$num]
    save_bookmarks
    echo "Bokmerke $num slettet." >&2
  else
    echo "Bokmerke $num finnes ikke." >&2
  fi
}

# Lister bokmerker
list_bookmarks() {
  load_bookmarks
  if (( ${#bookmarks} == 0 )); then
    echo "Ingen bokmerker definert."
  else
    echo "Bokmerker:"
    for key in ${(n)${(k)bookmarks}}; do
      local path
      if [[ "${bookmarks[$key]}" == "$HOME"* ]]; then
        path="~${bookmarks[$key]#$HOME}"
      else
        path="${bookmarks[$key]}"
      fi
      printf "  %2d: %s\n" "$key" "$path"
    done
  fi
  return 0
}

# Viser keybinding-hjelp
show_keybindings_help() {
  echo "Hotkeys er bundet til 'bookmark <nummer>' ved hjelp av F1–F9 for å navigere til bokmerker." >&2
  echo "For å endre dette, rediger BOOKMARK_SET_KEYS og bindkey-koden i skriptet." >&2
  echo "Gjeldende bindinger (hvis terminfo støtter det):" >&2
  for num in {1..9}; do
    if [[ -n "${terminfo[kf$num]}" ]]; then
      echo "  F$num -> bookmark $num (navigerer til bokmerke $num)" >&2
    fi
  done
  echo "Eksempel på tilpasning i ~/.zshrc: bindkey '\e[11~' 'bookmark-goto-1'" >&2
}

# Hovedfunksjon
bookmark() {
  if [[ "$1" == "set" || "$1" == "s" ]] && [[ -n "$2" ]]; then
    set_bookmark "$2"
  elif [[ "$1" == "del" || "$1" == "d" ]] && [[ -n "$2" ]]; then
    del_bookmark "$2"
  elif [[ "$1" == "help-bindings" ]]; then
    show_keybindings_help
  elif [[ -z "$1" ]]; then
    list_bookmarks
  elif [[ "$1" =~ '^[0-9]+$' ]]; then
    goto_bookmark "$1"
  else
    echo "Bruk:
  bookmark                -> List bokmerker
  bookmark set|s <nummer> -> Lagre gjeldende mappe som bokmerke
  bookmark <nummer>       -> Gå til bokmerke
  bookmark del|d <nummer> -> Slett bokmerke
  bookmark help-bindings  -> Vis keybinding-forslag" >&2
  fi
}

# Hotkey-bindinger
typeset -A BOOKMARK_SET_KEYS
BOOKMARK_SET_KEYS=(
  1 "kf1"
  2 "kf2"
  3 "kf3"
  4 "kf4"
  5 "kf5"
  6 "kf6"
  7 "kf7"
  8 "kf8"
  9 "kf9"
  10 "kf10"
  11 "kf11"
  12 "kf12"
)

# Funksjon for å definere og binde hotkeys
setup_bookmark_hotkeys() {
  # Hjelpefunksjon som navigerer til bokmerke via zle
  bookmark_goto_widget() {
    local num="$1"
    BUFFER="bookmark $num"
    zle accept-line
  }

  # Definer widgeter for hver bokmerke-nummer
  for num in ${(k)BOOKMARK_SET_KEYS}; do
    eval "bookmark_goto_${num}() { bookmark_goto_widget $num }"
    zle -N "bookmark-goto-$num" "bookmark_goto_${num}"
    local key="${terminfo[${BOOKMARK_SET_KEYS[$num]}]}"
    if [[ -n "$key" ]]; then
      bindkey "$key" "bookmark-goto-$num"
#      echo "DEBUG: Bundet F$num til bookmark-goto-$num (navigerer til bokmerke $num)" >&2
    else
#      echo "Advarsel: Ingen terminfo-verdi for F$num. Hotkey ble ikke bundet." >&2
    fi
  done
}

# Kjør oppsettet for hotkeys
setup_bookmark_hotkeys

# --------------------------------------------------------------------------- #
# ------------------------- B o o k m a r k s END --------------------------- #
# --------------------------------------------------------------------------- #
# --------------- T e r m i n a l   C a l c u l a t o r  BEGIN -------------- #
# --------------------------------------------------------------------------- #
