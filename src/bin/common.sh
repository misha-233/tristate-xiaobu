#!/system/bin/sh
# common.sh —— 公共函数库(被其它脚本 source, 不要直接执行)

MODID=tristate_xiaobu
DATA_DIR=${DATA_DIR:-/data/adb/tristate_xiaobu}
RUN_DIR=${RUN_DIR:-$DATA_DIR/run}
LOG_FILE=$DATA_DIR/tristate.log
CONF_FILE=$DATA_DIR/config.conf

if [ -z "$MODDIR" ]; then
  if [ -d "/data/adb/modules/$MODID" ]; then
    MODDIR="/data/adb/modules/$MODID"
  else
    MODDIR=$(cd "${0%/*}/.." 2>/dev/null && pwd)
    [ -n "$MODDIR" ] && [ -d "$MODDIR" ] || MODDIR="/data/adb/modules/$MODID"
  fi
fi

mkdir -p "$DATA_DIR" "$RUN_DIR" 2>/dev/null

# ---------------- 日志 ----------------
log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE" 2>/dev/null
  _n=$(wc -l <"$LOG_FILE" 2>/dev/null)
  if [ -n "$_n" ] && [ "$_n" -gt 500 ]; then
    tail -n 300 "$LOG_FILE" >"$LOG_FILE.tmp" 2>/dev/null && mv -f "$LOG_FILE.tmp" "$LOG_FILE" 2>/dev/null
  fi
}

die() { echo "错误: $*" >&2; exit 1; }

# ---------------- 配置 ----------------
load_conf() {
  [ -f "$MODDIR/config.conf" ] && . "$MODDIR/config.conf"
  [ -f "$CONF_FILE" ] && . "$CONF_FILE"
  [ -z "$TRIGGER_POSITION" ] && TRIGGER_POSITION=1
  [ -z "$TRIGGER_MODE" ] && TRIGGER_MODE=position
  [ -z "$DOUBLE_WINDOW" ] && DOUBLE_WINDOW=3
  [ -z "$COOLDOWN" ] && COOLDOWN=3
  [ -z "$SCREEN_ON_ONLY" ] && SCREEN_ON_ONLY=1
  [ -z "$ACTION" ] && ACTION=flashnote
  [ -z "$FLASHNOTE_TRIGGER_TYPE" ] && FLASHNOTE_TRIGGER_TYPE=2
  [ -z "$TRI_STATE_NODE" ] && TRI_STATE_NODE=/proc/tristatekey/tri_state
  [ -z "$INPUT_DEVICE" ] && INPUT_DEVICE=/dev/input/event5
  [ -z "$EVENT_TIMEOUT" ] && EVENT_TIMEOUT=60
  [ -z "$ALLOW_RINGER_FALLBACK" ] && ALLOW_RINGER_FALLBACK=1
  return 0
}

conf_set() {
  _k="$1"; _v="$2"
  [ -f "$CONF_FILE" ] || cp -f "$MODDIR/config.conf" "$CONF_FILE" 2>/dev/null
  if grep -q "^${_k}=" "$CONF_FILE" 2>/dev/null; then
    sed -i "s#^${_k}=.*#${_k}=${_v}#" "$CONF_FILE"
  else
    printf '%s=%s\n' "$_k" "$_v" >>"$CONF_FILE"
  fi
}

# ---------------- 档位 ----------------
# 归一化: 1/up = 上(静音), 2/mid = 中(振动), 3/down = 下(响铃)
norm_pos() {
  case "$1" in
    1|up|mute|silent|静音|上)       echo up ;;
    2|mid|middle|vibrate|振动|震动|中) echo mid ;;
    3|down|ring|normal|响铃|铃声|下)  echo down ;;
    *) echo "$1" ;;
  esac
}

pos_desc() {
  case "$1" in
    up)   echo "上档(静音)" ;;
    mid)  echo "中档(振动)" ;;
    down) echo "下档(响铃)" ;;
    *)    echo "未知($1)" ;;
  esac
}

# 读档位真相: /proc/tristatekey/tri_state -> 1 / 2 / 3
read_tri_state() {
  [ -r "$TRI_STATE_NODE" ] || return 1
  _v=$(cat "$TRI_STATE_NODE" 2>/dev/null | tr -dc '0-9')
  case "$_v" in
    1|2|3) echo "$_v"; return 0 ;;
  esac
  return 1
}

# 铃声模式: 0=静音 1=振动 2=响铃
ringer_mode() {
  _v=$(settings get global mode_ringer 2>/dev/null | tr -dc '0-9')
  case "$_v" in
    0|1|2) echo "$_v"; return 0 ;;
  esac
  _line=$(dumpsys audio 2>/dev/null | grep -i 'ringer mode' | head -n 1)
  case "$_line" in
    *SILENT*)  echo 0; return 0 ;;
    *VIBRATE*) echo 1; return 0 ;;
    *NORMAL*)  echo 2; return 0 ;;
  esac
  _line=$(dumpsys notification 2>/dev/null | grep -i 'ringer mode' | head -n 1)
  case "$_line" in
    *SILENT*)  echo 0; return 0 ;;
    *VIBRATE*) echo 1; return 0 ;;
    *NORMAL*)  echo 2; return 0 ;;
  esac
  return 1
}

# 用铃声模式反推档位(回退方案)
pos_from_ringer() {
  _r=$(ringer_mode) || return 1
  case "$_r" in
    0) echo 1 ;;
    1) echo 2 ;;
    2) echo 3 ;;
    *) return 1 ;;
  esac
}

# 当前档位: 优先 tri_state, 失败再退回铃声模式
current_pos() {
  _p=$(read_tri_state) && { echo "$_p"; return 0; }
  [ "$ALLOW_RINGER_FALLBACK" = "1" ] && pos_from_ringer && return 0
  return 1
}

# 拨动之后等到档位真的变成"与 old 不同", 最多约 2 秒
wait_new_pos() {
  _old="$1"
  _i=0
  while [ "$_i" -lt 20 ]; do
    _v=$(read_tri_state)
    if [ -n "$_v" ] && [ "$_v" != "$_old" ]; then
      sleep 0.1
      _v2=$(read_tri_state)
      [ -n "$_v2" ] && _v=$_v2
      echo "$_v"
      return 0
    fi
    sleep 0.1
    _i=$((_i + 1))
  done
  _v=$(current_pos)
  [ -n "$_v" ] && echo "$_v"
  return 0
}

# ---------------- 屏幕 ----------------
screen_is_on() {
  dumpsys power 2>/dev/null | grep -q 'mWakefulness=Awake' && return 0
  dumpsys display 2>/dev/null | grep -q 'mScreenState=ON' && return 0
  return 1
}
