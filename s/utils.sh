# UTILS

# CFG

save_cfg_value() {
  local config_file=${3:-CFG_FILE}
  if [[ -f "$config_file" ]]; then
    sed --in-place='' "/^$1=.*$/d" "$config_file"
  fi
  if [ -n "$2" ]; then
    printf "$1=%s\n" "$2" >> "$config_file"
  fi
  return 0
}

reload_cfg() {
  local config_file=${1:-CFG_FILE}
  local sanitized=""
  # shellcheck disable=SC1097
  while IFS== read -r var value; do
    [[ "$var" =~ ^# ]] && continue
    printf -v sanitized "%q" "$value"
    eval "$var"="$sanitized"
  done < "$config_file"
  return 0
}

# INTERACTION

prompt() {
  ask "$1" notif
}

ask_string() {
  echo -ne "$1:"
  read -rp " " ask_res
}

# set_or_ask

set_or_ask() {
  local dvar="$1"     # destination var to set
  local sval="$2"     # source value
  local prompt="$3"   # (if required) Supports tags %sp (standard prompt) and %var (dest var name)
  local pdef="$4"     # (for the prompt)
  local asserter="$5" # assert function (with "?" suffix allows nulls)

  _set_var "$dvar" ""

  prompt="${prompt//%sp/Please provide the}"
  prompt="${prompt//%var/$dvar}"

  local res="$sval"
  local def=""
  local nullable=false
  [[ "$asserter" =~ ^.*\?$ ]] && nullable=true

  while true; do
    [ -z "$res" ] && {
      if [ -n "$asserter" ]; then
        "$asserter" "${dvar}_DEFAULT" "$pdef" "silent"
        def="$pdef"
      else
        def="$pdef"
      fi

      if [ -n "$def" ]; then
        read -rep "$prompt ($def): " res
        [ -z "$res" ] && [ -n "$def" ] && res="$pdef"
      else
        read -rep "$prompt: " res
      fi
    }

    if [ -n "$asserter" ]; then
      if [ -n "$res" ] || ! $nullable; then
        "$asserter" "$dvar" "$res" || {
          res=""
          continue
        }
      fi
    fi

    break
  done
  _set_var "$dvar" "$res"
}

ask() {
  while true; do
    [ "$2" == "notif" ] && echo -ne "$1" || echo -ne "$1 (y/n/q)"
    if [ "$OPT_YES_FOR_ALL" = true ]; then
      echo " (auto-yes/ok)"
      return 0
    fi

    # shellcheck disable=SC2162
    read -p " " res
    [ "$2" == "notif" ] && return 0
    case $res in
      [Yy]*) return 0 ;;
      [Nn]*) return 1 ;;
      [Qq]*) exit 99 ;;
      *) echo "Please answer yes, no or quit." ;;
    esac
  done
}

FATAL() {
  echo -e "---"
  _log_e 0 "FATAL: $*"
  xu_set_status "FATAL: $*"
  exit 77
}

EXIT_UE() {
  echo -e "---"
  [ "$1" != "" ] && _log_w 0 "$@"
  xu_set_status "USER-ERROR"
  exit 1
}

# PROGRAM STATUS

xu_clear_status() {
  [ "$XU_STATUS_FILE" != "" ] && [ -f "$XU_STATUS_FILE" ] && rm -- "$XU_STATUS_FILE"
}

xu_set_status() {
  [ "$XU_STATUS_FILE" != "" ] && echo "$@" > "$XU_STATUS_FILE"
}

xu_get_status() {
  XU_RES=""
  if [ "$XU_STATUS_FILE" != "" ] && [ -f "$XU_STATUS_FILE" ]; then
    XU_RES="$(cut "$XU_STATUS_FILE" -d':' -f1)"
  fi
  return 0
}

snake_to_camel() {
  local res="$(echo "$2" | sed -E 's/[ _-]([a-z])/\U\1/gi;s/^([A-Z])/\l\1/')"
  _set_var "$1" "$res"
}

# Returns the index of the given argument
index_of_arg() {
  par="$1"
  shift
  i=1
  while [ "$1" != "$par" ] && [ -n "$1" ] && [ $i -lt 100 ]; do
    i=$((i + 1))
    shift
  done
  [ $i -eq 100 ] && return 0
  [ -n "$1" ] && return $i || return $((i - 1))
}
