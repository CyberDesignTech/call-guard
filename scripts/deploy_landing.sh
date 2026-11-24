#!/usr/bin/env bash
set -euo pipefail
umask 077

die() {
  printf 'deploy_landing: %s\n' "$*" >&2
  exit 1
}

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
PROJECT_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd -P)
LANDING_DIR="$PROJECT_ROOT/landing"

DRY_RUN=false
for argument in "$@"; do
  case "$argument" in
    --dry-run) DRY_RUN=true ;;
    *) die "Невідомий аргумент: $argument. Використання: scripts/deploy_landing.sh [--dry-run]" ;;
  esac
done

DEPLOY_ENV_FILE=${DEPLOY_ENV_FILE:-"${HOME:?HOME не задано}/.callguard_deploy.env"}
if [[ ! -f "$DEPLOY_ENV_FILE" ]]; then
  cat >&2 <<EOF
Файл конфігурації деплою не знайдено: $DEPLOY_ENV_FILE

Створіть його поза репозиторієм і задайте такі змінні:
# Протокол: ssh, sftp або ftp (за замовчуванням ssh)
  DEPLOY_PROTOCOL=ssh
  DEPLOY_HOST=example.com
  DEPLOY_PORT=22
  DEPLOY_USER=your-user
  DEPLOY_KEY=/absolute/path/to/private-key
  DEPLOY_PASS=
  DEPLOY_REMOTE_DIR=/path/to/landing

Для ssh/sftp типовий порт — 22, для ftp — 21. DEPLOY_PASS потрібен для FTP
та для SFTP, якщо не використовується SSH-ключ.

Захистіть файл правами доступу: chmod 600 "$DEPLOY_ENV_FILE"
EOF
  exit 1
fi
[[ -r "$DEPLOY_ENV_FILE" ]] || die "Немає прав читати файл конфігурації: $DEPLOY_ENV_FILE"

# Resolve the config path and reject credentials stored anywhere in this repo.
command -v readlink >/dev/null 2>&1 || die "Потрібна команда readlink для перевірки шляху конфігурації"
DEPLOY_ENV_FILE=$(readlink -f -- "$DEPLOY_ENV_FILE") || die "Не вдалося визначити шлях файлу конфігурації"
case "$DEPLOY_ENV_FILE" in
  "$PROJECT_ROOT"|"$PROJECT_ROOT"/*)
    die "Файл конфігурації із секретами має бути поза репозиторієм: $PROJECT_ROOT"
    ;;
esac

command -v stat >/dev/null 2>&1 || die "Потрібна команда stat для перевірки прав файлу конфігурації"
config_mode=$(stat -c '%a' -- "$DEPLOY_ENV_FILE") || die "Не вдалося перевірити права файлу конфігурації"
if (( (8#$config_mode & 077) != 0 )); then
  die "Файл конфігурації доступний групі або іншим користувачам; виконайте chmod 600 '$DEPLOY_ENV_FILE'"
fi

# Config values are parsed as data (not sourced/evaluated as shell code).
DEPLOY_PROTOCOL=
DEPLOY_HOST=
DEPLOY_PORT=
DEPLOY_USER=
DEPLOY_KEY=
DEPLOY_PASS=
DEPLOY_REMOTE_DIR=

trim() {
  local value=$1
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

while IFS= read -r line || [[ -n "$line" ]]; do
  line=${line%$'\r'}
  line=$(trim "$line")
  [[ -z "$line" || "$line" == \#* ]] && continue
  if [[ "$line" =~ ^export[[:space:]]+ ]]; then
    line=${line#export }
  fi
  [[ "$line" == *=* ]] || die "Невірний рядок у конфігурації (очікується NAME=value)"

  key=$(trim "${line%%=*}")
  value=$(trim "${line#*=}")
  if (( ${#value} >= 2 )); then
    first=${value:0:1}
    last=${value: -1}
    if [[ ( "$first" == '"' && "$last" == '"' ) || ( "$first" == "'" && "$last" == "'" ) ]]; then
      value=${value:1:${#value}-2}
    fi
  fi

  case "$key" in
    DEPLOY_PROTOCOL) DEPLOY_PROTOCOL=$value ;;
    DEPLOY_HOST) DEPLOY_HOST=$value ;;
    DEPLOY_PORT) DEPLOY_PORT=$value ;;
    DEPLOY_USER) DEPLOY_USER=$value ;;
    DEPLOY_KEY) DEPLOY_KEY=$value ;;
    DEPLOY_PASS) DEPLOY_PASS=$value ;;
    DEPLOY_REMOTE_DIR) DEPLOY_REMOTE_DIR=$value ;;
    *) die "Невідома змінна '$key' у файлі конфігурації" ;;
  esac
done < "$DEPLOY_ENV_FILE"

DEPLOY_PROTOCOL=${DEPLOY_PROTOCOL:-ssh}
if [[ -z "$DEPLOY_PORT" ]]; then
  case "$DEPLOY_PROTOCOL" in
    ftp) DEPLOY_PORT=21 ;;
    ssh|sftp) DEPLOY_PORT=22 ;;
    *) die "Непідтримуваний DEPLOY_PROTOCOL='$DEPLOY_PROTOCOL'; використайте ssh, sftp або ftp" ;;
  esac
fi
[[ -n "$DEPLOY_HOST" ]] || die "У конфігурації не задано DEPLOY_HOST"
[[ -n "$DEPLOY_USER" ]] || die "У конфігурації не задано DEPLOY_USER"
[[ -n "$DEPLOY_REMOTE_DIR" ]] || die "У конфігурації не задано DEPLOY_REMOTE_DIR"

case "$DEPLOY_PROTOCOL" in
  ssh|sftp|ftp) ;;
  *) die "Непідтримуваний DEPLOY_PROTOCOL='$DEPLOY_PROTOCOL'; використайте ssh, sftp або ftp" ;;
esac
[[ "$DEPLOY_HOST" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || die "DEPLOY_HOST має бути hostname або IPv4-адресою без схеми URL"
[[ "$DEPLOY_USER" =~ ^[A-Za-z0-9_][A-Za-z0-9_.-]*$ ]] || die "DEPLOY_USER містить непідтримувані символи"
[[ "$DEPLOY_PORT" =~ ^[0-9]{1,5}$ ]] || die "DEPLOY_PORT має бути числом від 1 до 65535"
port_number=$((10#$DEPLOY_PORT))
(( port_number >= 1 && port_number <= 65535 )) || die "DEPLOY_PORT має бути числом від 1 до 65535"
DEPLOY_PORT=$port_number

[[ "$DEPLOY_REMOTE_DIR" =~ ^/[A-Za-z0-9_./-]*$ ]] || die "DEPLOY_REMOTE_DIR має бути абсолютним шляхом без пробілів і shell-символів"
case "$DEPLOY_REMOTE_DIR" in
  */../*|*/..) die "DEPLOY_REMOTE_DIR не може містити сегмент '..'" ;;
esac
REMOTE_DIR=${DEPLOY_REMOTE_DIR%/}
[[ -n "$REMOTE_DIR" ]] || REMOTE_DIR=/

if [[ -n "$DEPLOY_KEY" ]]; then
  case "$DEPLOY_KEY" in
    '~/'*) DEPLOY_KEY="$HOME/${DEPLOY_KEY#\~/}" ;;
    /*) ;;
    *) DEPLOY_KEY="$HOME/$DEPLOY_KEY" ;;
  esac
  if [[ -e "$DEPLOY_KEY" ]]; then
    [[ -f "$DEPLOY_KEY" && -r "$DEPLOY_KEY" ]] || die "DEPLOY_KEY має бути доступним для читання файлом"
    resolved_key=$(readlink -f -- "$DEPLOY_KEY") || die "Не вдалося визначити шлях DEPLOY_KEY"
    case "$resolved_key" in
      "$PROJECT_ROOT"|"$PROJECT_ROOT"/*)
        die "Приватний ключ має зберігатися поза репозиторієм: $PROJECT_ROOT"
        ;;
    esac
    DEPLOY_KEY=$resolved_key
  else
    printf 'Попередження: DEPLOY_KEY не знайдено; буде використано інші доступні способи автентифікації.\n' >&2
    DEPLOY_KEY=
  fi
fi

[[ -f "$LANDING_DIR/index.html" ]] || die "Не знайдено $LANDING_DIR/index.html"
shopt -s nullglob
apk_files=("$LANDING_DIR"/release/CallGate-*.apk)
has_apk=false
for apk_file in "${apk_files[@]}"; do
  if [[ -f "$apk_file" ]]; then
    has_apk=true
    break
  fi
done
[[ "$has_apk" == true ]] || die "У $LANDING_DIR/release не знайдено CallGate-*.apk"

js_files=("$LANDING_DIR"/assets/js/*.js)
if command -v node >/dev/null 2>&1; then
  for js_file in "${js_files[@]}"; do
    node --check "$js_file"
  done
else
  printf 'Попередження: node не встановлено; перевірку JS пропущено.\n' >&2
fi

exclude_patterns=(
  '.DS_Store'
  '**/.DS_Store'
  '*~'
  '*.swp'
  '*.swo'
  '*.tmp'
  '*.bak'
  '*.orig'
  '*.rej'
  '.#*'
  '#*#'
  '.git/'
)
lftp_exclude_patterns=("${exclude_patterns[@]}" '.well-known/' '.well-known/**')

if [[ "$DEPLOY_PROTOCOL" == ssh ]]; then
  command -v rsync >/dev/null 2>&1 || die "Для DEPLOY_PROTOCOL=ssh потрібен rsync"
  command -v ssh >/dev/null 2>&1 || die "Для DEPLOY_PROTOCOL=ssh потрібен ssh"

  ssh_command=(ssh -p "$DEPLOY_PORT")
  [[ -z "$DEPLOY_KEY" ]] || ssh_command+=(-i "$DEPLOY_KEY")
  printf -v rsync_ssh_command '%q ' "${ssh_command[@]}"

  rsync_args=(-avz --delete)
  [[ "$DRY_RUN" == false ]] || rsync_args+=(--dry-run --itemize-changes)
  for pattern in "${exclude_patterns[@]}"; do
    rsync_args+=("--exclude=$pattern")
  done

  remote_destination="$DEPLOY_USER@$DEPLOY_HOST:$REMOTE_DIR/"
  if [[ "$DRY_RUN" == true ]]; then
    printf 'Тестовий деплой через SSH: %s → %s\n' "$LANDING_DIR/" "$remote_destination"
  else
    printf 'Деплой через SSH: %s → %s\n' "$LANDING_DIR/" "$remote_destination"
  fi
  rsync "${rsync_args[@]}" -e "$rsync_ssh_command" "$LANDING_DIR/" "$remote_destination"
else
  command -v lftp >/dev/null 2>&1 || die "Для DEPLOY_PROTOCOL=$DEPLOY_PROTOCOL потрібен lftp"

  shell_quote() {
    local value=${1//\'/\'\\\'\'}
    printf "'%s'" "$value"
  }
  lftp_quote() {
    local input=$1 output='"' character
    local index
    for ((index = 0; index < ${#input}; index++)); do
      character=${input:index:1}
      case "$character" in
        \\|\"|\$|\` ) output+="\\$character" ;;
        *) output+=$character ;;
      esac
    done
    output+='"'
    printf '%s' "$output"
  }

  lftp_password_option=
  [[ -z "$DEPLOY_PASS" ]] || lftp_password_option=--env-password
  lftp_connection_settings=
  if [[ "$DEPLOY_PROTOCOL" == sftp ]]; then
    command -v ssh >/dev/null 2>&1 || die "Для DEPLOY_PROTOCOL=sftp потрібен ssh"
    sftp_connect_program="ssh -a -x -p $DEPLOY_PORT"
    [[ -z "$DEPLOY_KEY" ]] || sftp_connect_program+=" -i $(shell_quote "$DEPLOY_KEY")"
    sftp_connect_program+=" -oBatchMode=$([[ -n "$DEPLOY_PASS" ]] && printf no || printf yes)"
    lftp_connect_program=$(lftp_quote "$sftp_connect_program")
    lftp_connection_settings="set sftp:connect-program $lftp_connect_program"
    lftp_open_command="open -u \"$DEPLOY_USER\" $lftp_password_option sftp://$DEPLOY_HOST"
  else
    [[ -n "$DEPLOY_PASS" ]] || die "Для DEPLOY_PROTOCOL=ftp потрібно задати DEPLOY_PASS"
    # Opportunistic explicit FTPS: use TLS when AUTH TLS is supported, otherwise FTP.
    lftp_connection_settings=$'set ftp:ssl-allow yes\nset ftp:ssl-force no\nset ftp:ssl-protect-data yes'
    lftp_open_command="open -u \"$DEPLOY_USER\" --env-password -p $DEPLOY_PORT ftp://$DEPLOY_HOST"
  fi

  lftp_mirror_args=(--reverse --delete --verbose --parallel=2)
  [[ "$DRY_RUN" == false ]] || lftp_mirror_args+=(--dry-run)
  for pattern in "${lftp_exclude_patterns[@]}"; do
    lftp_mirror_args+=("--exclude-glob='$pattern'")
  done
  printf -v lftp_mirror_command '%s ' "${lftp_mirror_args[@]}"

  if [[ "$DRY_RUN" == true ]]; then
    printf 'Тестовий деплой через %s: %s → %s:%s\n' "$DEPLOY_PROTOCOL" "$LANDING_DIR/" "$DEPLOY_HOST" "$REMOTE_DIR"
  else
    printf 'Деплой через %s: %s → %s:%s\n' "$DEPLOY_PROTOCOL" "$LANDING_DIR/" "$DEPLOY_HOST" "$REMOTE_DIR"
  fi

  # Commands arrive on stdin; passwords are provided via LFTP_PASSWORD, not argv.
  lftp_script=$(cat <<EOF
set cmd:fail-exit yes
$lftp_connection_settings
$lftp_open_command
mirror $lftp_mirror_command "$LANDING_DIR" "$REMOTE_DIR"
bye
EOF
  )
  if [[ -n "$DEPLOY_PASS" ]]; then
    printf '%s\n' "$lftp_script" | LFTP_PASSWORD="$DEPLOY_PASS" lftp -f /dev/stdin
  else
    printf '%s\n' "$lftp_script" | lftp -f /dev/stdin
  fi
fi

printf 'Деплой завершено.\n'
