#!/system/bin/sh
# daemon.sh —— 常驻监听三段式开关
#
# 原理(不要改):
#   三段式按键设备只上报 KEY_F3 的一次"点击", 事件里没有任何档位信息,
#   所以每次事件后必须去读 /proc/tristatekey/tri_state 才知道拨到了哪一档。
#   这里用 getevent -c 1 阻塞等待(空闲零 CPU), 事件来了再读档位并比对。

SELF_DIR=$(cd "${0%/*}" 2>/dev/null && pwd) || SELF_DIR=$(pwd)
. "$SELF_DIR/common.sh"

load_conf
mkdir -p "$RUN_DIR" 2>/dev/null

PIDFILE="$RUN_DIR/daemon.pid"
if [ -f "$PIDFILE" ]; then
  _old=$(cat "$PIDFILE" 2>/dev/null)
  if [ -n "$_old" ] && kill -0 "$_old" 2>/dev/null; then
    log "daemon 已在运行 (pid=$_old), 退出"
    exit 0
  fi
fi
echo $$ >"$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT INT TERM HUP

CONF_MTIME=$(stat -c %Y "$CONF_FILE" 2>/dev/null || echo 0)

reload_if_changed() {
  _m=$(stat -c %Y "$CONF_FILE" 2>/dev/null || echo 0)
  if [ "$_m" != "$CONF_MTIME" ]; then
    CONF_MTIME=$_m
    load_conf
    log "配置已重新加载: 触发档位=$(pos_desc "$(norm_pos "$TRIGGER_POSITION")") 动作=$ACTION"
  fi
}

fire() {
  _pos=$(norm_pos "$1")
  [ "$_pos" = "$(norm_pos "$TRIGGER_POSITION")" ] || return 0

  _now=$(date +%s)

  if [ "$TRIGGER_MODE" = "double" ]; then
    _last=$(cat "$RUN_DIR/last_enter_$_pos" 2>/dev/null)
    [ -z "$_last" ] && _last=0
    echo "$_now" >"$RUN_DIR/last_enter_$_pos"
    if [ $((_now - _last)) -gt "$DOUBLE_WINDOW" ]; then
      log "double 模式: 首次拨到 $_pos, ${DOUBLE_WINDOW}s 内再拨回来才触发"
      return 0
    fi
  fi

  _lf=$(cat "$RUN_DIR/last_fire" 2>/dev/null)
  [ -z "$_lf" ] && _lf=0
  if [ $((_now - _lf)) -lt "$COOLDOWN" ]; then
    log "冷却中, 忽略 (档位 $_pos)"
    return 0
  fi
  echo "$_now" >"$RUN_DIR/last_fire"

  log ">>> 触发 (档位 $(pos_desc "$_pos"), 动作=$ACTION)"
  ( sh "$MODDIR/bin/trigger.sh" "$_pos" ) >>"$DATA_DIR/daemon.out" 2>&1 &
}

main() {
  log "===== daemon 启动 (pid=$$) ====="
  log "触发档位=$(pos_desc "$(norm_pos "$TRIGGER_POSITION")") 模式=$TRIGGER_MODE 动作=$ACTION"
  log "档位节点=$TRI_STATE_NODE 事件节点=$INPUT_DEVICE 等待上限=${EVENT_TIMEOUT}s"

  _last=$(current_pos)
  if [ -n "$_last" ]; then
    log "当前档位: $(pos_desc "$(norm_pos "$_last")") ($_last)"
  else
    log "警告: 读不到当前档位"
  fi

  _poll_warned=0
  while :; do
    reload_if_changed

    if [ -e "$INPUT_DEVICE" ]; then
      timeout "$EVENT_TIMEOUT" getevent -c 1 "$INPUT_DEVICE" >/dev/null 2>&1
    else
      if [ "$_poll_warned" = "0" ]; then
        log "警告: 事件节点 $INPUT_DEVICE 不存在, 退回轮询档位"
        _poll_warned=1
      fi
      sleep 1
    fi

    _pos=$(wait_new_pos "$_last")
    if [ -z "$_pos" ]; then
      sleep 1
      continue
    fi

    if [ "$_pos" != "$_last" ]; then
      [ "$VERBOSE" = "1" ] && log "档位变化: $(pos_desc "$(norm_pos "$_pos")") ($_last -> $_pos)"
      _last=$_pos
      fire "$_pos"
    fi

    sleep 0.2
  done
}

main
