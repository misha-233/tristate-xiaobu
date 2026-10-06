#!/system/bin/sh
# detect.sh —— 诊断报告(装完/排错时先跑这个)

SELF_DIR=$(cd "${0%/*}" 2>/dev/null && pwd) || SELF_DIR=$(pwd)
. "$SELF_DIR/common.sh"
load_conf

hr() { echo "------------------------------------------------------------"; }

echo "三段式按键 → 小布记忆「一键闪记」  诊断报告"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
hr

echo "【设备】"
echo "  型号    : $(getprop ro.product.model) / $(getprop ro.product.name)"
echo "  系统    : Android $(getprop ro.build.version.release) (SDK $(getprop ro.build.version.sdk))"
echo "  版本号  : $(getprop ro.build.display.id)"
echo "  ROM     : $(getprop ro.build.version.oplusrom)"
echo "  SELinux : $(getenforce 2>/dev/null)"
echo "  uid     : $(id -u 2>/dev/null)"

hr
echo "【档位来源】"
if _v=$(read_tri_state); then
  echo "  OK  $TRI_STATE_NODE = $_v  →  $(pos_desc "$(norm_pos "$_v")")"
else
  echo "  失败 读不到 $TRI_STATE_NODE"
fi
if _r=$(ringer_mode); then
  echo "  OK  铃声模式 = $_r (0=静音 1=振动 2=响铃)  →  推断档位 $(pos_from_ringer)"
else
  echo "  失败 读不到铃声模式"
fi
if [ -e "$INPUT_DEVICE" ]; then
  echo "  OK  按键事件节点 $INPUT_DEVICE 存在"
else
  echo "  失败 按键事件节点 $INPUT_DEVICE 不存在"
fi
echo "  内核模块: $(lsmod 2>/dev/null | grep -o '^oplus_bsp_tri_key' | head -n1)"

hr
echo "【闪记服务】"
if pm path com.oplus.gleanerservice >/dev/null 2>&1; then
  echo "  OK  $(pm path com.oplus.gleanerservice 2>/dev/null | head -n1 | sed 's/package://')"
  echo "      闪记采集服务可用（触发命令见 bin/trigger.sh）"
else
  echo "  未找到闪记服务 —— flashnote 动作不可用"
fi

hr
echo "【模块运行状态】"
if [ -f "$RUN_DIR/daemon.pid" ]; then
  _p=$(cat "$RUN_DIR/daemon.pid" 2>/dev/null)
  if [ -n "$_p" ] && kill -0 "$_p" 2>/dev/null; then
    echo "  daemon 运行中 (pid=$_p)"
  else
    echo "  daemon 未运行(pid 文件残留: $_p)"
  fi
else
  echo "  daemon 未运行(无 pid 文件)"
fi

hr
echo "【当前配置】"
echo "  触发档位 : $(pos_desc "$(norm_pos "$TRIGGER_POSITION")")  (TRIGGER_POSITION=$TRIGGER_POSITION)"
echo "  触发模式 : $TRIGGER_MODE   冷却 ${COOLDOWN}s"
echo "  动作     : $ACTION"
case "$ACTION" in
  flashnote) echo "  闪记来源 : triggerType=$FLASHNOTE_TRIGGER_TYPE" ;;
  command)   echo "  自定义   : $CUSTOM_COMMAND" ;;
  intent)    echo "  intent   : $INTENT_ARGS" ;;
  key)       echo "  按键     : $KEYCODE" ;;
esac
echo "  亮屏限制 : SCREEN_ON_ONLY=$SCREEN_ON_ONLY"

hr
echo "【最近日志】"
if [ -f "$LOG_FILE" ]; then
  tail -n 15 "$LOG_FILE"
else
  echo "  (暂无日志)"
fi
