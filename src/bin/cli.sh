#!/system/bin/sh
# cli.sh —— 命令行工具
#   sh cli.sh status | show | pos | set K V | test | flashnote [N] |
#              restart | stop | start | log [N] | detect | trigger-types

SELF_DIR=$(cd "${0%/*}" 2>/dev/null && pwd) || SELF_DIR=$(pwd)
. "$SELF_DIR/common.sh"
load_conf

kill_daemon() {
  _p=""
  [ -f "$RUN_DIR/daemon.pid" ] && _p=$(cat "$RUN_DIR/daemon.pid" 2>/dev/null)
  if [ -n "$_p" ] && kill -0 "$_p" 2>/dev/null; then
    kill "$_p" 2>/dev/null
    sleep 1
    kill -9 "$_p" 2>/dev/null
    echo "已停止 daemon (pid=$_p)"
  else
    echo "daemon 未在运行"
  fi
  rm -f "$RUN_DIR/daemon.pid"
}

start_daemon() {
  if [ -f "$RUN_DIR/daemon.pid" ]; then
    _p=$(cat "$RUN_DIR/daemon.pid" 2>/dev/null)
    if [ -n "$_p" ] && kill -0 "$_p" 2>/dev/null; then
      echo "daemon 已在运行 (pid=$_p)"
      return 0
    fi
  fi
  nohup sh "$MODDIR/bin/daemon.sh" >>"$DATA_DIR/daemon.out" 2>&1 &
  sleep 1
  echo "已启动 daemon (pid=$(cat "$RUN_DIR/daemon.pid" 2>/dev/null))"
}

CMD="$1"
shift 2>/dev/null

case "$CMD" in
  status)
    echo "档位节点 : $TRI_STATE_NODE"
    if _v=$(read_tri_state); then
      echo "当前档位 : $_v  →  $(pos_desc "$(norm_pos "$_v")")"
    else
      echo "当前档位 : 读不到"
    fi
    if _r=$(ringer_mode); then echo "铃声模式 : $_r"; fi
    if [ -f "$RUN_DIR/daemon.pid" ]; then
      _p=$(cat "$RUN_DIR/daemon.pid" 2>/dev/null)
      if [ -n "$_p" ] && kill -0 "$_p" 2>/dev/null; then
        echo "daemon   : 运行中 (pid=$_p)"
      else
        echo "daemon   : 未运行"
      fi
    else
      echo "daemon   : 未运行"
    fi
    echo "触发档位 : $(pos_desc "$(norm_pos "$TRIGGER_POSITION")")"
    echo "动作     : $ACTION"
    ;;

  state)
    # 机器可读状态(KEY=VALUE 每行一条), 供 WebUI 解析
    _sp=$(current_pos)
    [ -z "$_sp" ] && _sp="?"
    echo "POS=$_sp"
    echo "POS_DESC=$(pos_desc "$(norm_pos "$_sp")")"
    _sr=$(ringer_mode)
    [ -n "$_sr" ] && echo "RINGER=$_sr"
    _sd=""
    if [ -f "$RUN_DIR/daemon.pid" ]; then
      _sq=$(cat "$RUN_DIR/daemon.pid" 2>/dev/null)
      if [ -n "$_sq" ] && kill -0 "$_sq" 2>/dev/null; then _sd="$_sq"; fi
    fi
    echo "DAEMON_PID=$_sd"
    for _sk in TRIGGER_POSITION TRIGGER_MODE COOLDOWN SCREEN_ON_ONLY ACTION FLASHNOTE_TRIGGER_TYPE; do
      eval "_sv=\$$_sk"
      echo "CONF_$_sk=$_sv"
    done
    ;;

  show)
    echo "配置文件: $CONF_FILE"
    echo "------------------------------"
    grep -vE '^\s*#|^\s*$' "$CONF_FILE" 2>/dev/null
    ;;

  pos)
    current_pos || echo "读不到档位"
    ;;

  set)
    K="$1"; V="$2"
    [ -z "$K" ] && { echo "用法: sh cli.sh set KEY VALUE"; exit 1; }
    case "$K" in
      [A-Za-z_]*) ;;
      *) echo "非法配置名: $K"; exit 1 ;;
    esac
    conf_set "$K" "$V"
    echo "已设置 $K=$V"
    echo "(下一次拨动开关时自动生效; 或执行: sh $MODDIR/bin/cli.sh restart)"
    ;;

  test)
    echo "立即触发一次(忽略亮屏限制)..."
    sh "$MODDIR/bin/trigger.sh" "${1:-test}" --force
    echo "---- 日志尾部 ----"
    tail -n 8 "$LOG_FILE" 2>/dev/null
    ;;

  flashnote)
    N="${1:-$FLASHNOTE_TRIGGER_TYPE}"
    echo "直接触发闪记 triggerType=$N ..."
    _out=$(am start-foreground-service \
      -n com.oplus.gleanerservice/.flashnotes.business.service.DataCollectService \
      -a oplus.gleanerservice.intent.action.COLLECT_DATA --ei triggerType "$N" 2>&1)
    echo "$_out"
    ;;

  restart)
    kill_daemon
    start_daemon
    ;;

  stop)    kill_daemon ;;
  start)   start_daemon ;;

  log)
    N="${1:-40}"
    tail -n "$N" "$LOG_FILE" 2>/dev/null || echo "(暂无日志)"
    ;;

  detect)
    exec sh "$MODDIR/bin/detect.sh"
    ;;

  trigger-types)
    cat <<'EOF'
闪记 triggerType 枚举:
   1  MAGIC_KEY                  闪记物理键
   2  THREE_FINGERS_UP           三指上滑(默认, 与系统手势一致)
   3  CUI
   4  SCREENSHOT
   6  SCREENSHOT_NORMAL          普通截屏
   7  SCREENSHOT_LONG            长截屏
   8  SCREENSHOT_AREA            区域截屏
  11  AUTO_PAYMENT
  12  AUTO_COLLECT
  14  AUTO_PAYMENT_NOTIFICATION
  15  AI_KEY_DOUBLE_CLICK
  17  BREENO_TOUCH
其余值 = UNKNOWN(会被服务拒绝并记 "trigger type error")
EOF
    ;;

  *)
    cat <<EOF
三段式按键 → 一键闪记   命令行工具

  sh cli.sh status              运行状态与当前档位
  sh cli.sh show                显示配置
  sh cli.sh state               机器可读状态(WebUI 用)
  sh cli.sh set KEY VALUE       修改配置项
  sh cli.sh pos                 只读当前档位
  sh cli.sh test [档位]         立即触发一次(忽略亮屏限制)
  sh cli.sh flashnote [N]       直接用 triggerType=N 触发闪记
  sh cli.sh restart             重启监听
  sh cli.sh stop | start
  sh cli.sh log [行数]          看日志
  sh cli.sh detect              完整诊断报告
  sh cli.sh trigger-types       列出可用的闪记 triggerType

模块目录: $MODDIR
配置    : $CONF_FILE
日志    : $LOG_FILE
EOF
    ;;
esac
