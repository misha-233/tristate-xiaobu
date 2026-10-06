#!/system/bin/sh
# trigger.sh —— 执行触发动作
# 用法: sh trigger.sh [档位] [--force]
#   --force 会跳过"只在亮屏时触发"的限制(手动测试用)

SELF_DIR=$(cd "${0%/*}" 2>/dev/null && pwd) || SELF_DIR=$(pwd)
. "$SELF_DIR/common.sh"
load_conf

FORCE=0
POS=""
for _a in "$@"; do
  case "$_a" in
    --force|-f) FORCE=1 ;;
    --*) ;;
    *) POS="$_a" ;;
  esac
done

log "触发请求: 档位=${POS:-未指定} 动作=$ACTION"

if [ "$FORCE" != "1" ] && [ "$SCREEN_ON_ONLY" = "1" ]; then
  if ! screen_is_on; then
    log "屏幕未点亮, 跳过 (SCREEN_ON_ONLY=1)"
    exit 0
  fi
fi

run_cmd() {
  log "执行: $*"
  _out=$("$@" 2>&1)
  _rc=$?
  [ -n "$_out" ] && log "  -> $_out"
  [ "$_rc" != "0" ] && log "  -> 退出码 $_rc"
  return $_rc
}

# 小布记忆「一键闪记」: 拉起闪记采集服务
# 该服务受签名级权限保护, 但对 uid 0(root) 直接放行
do_flashnote() {
  case "$FLASHNOTE_TRIGGER_TYPE" in
    ''|*[!0-9]*)
      log "错误: FLASHNOTE_TRIGGER_TYPE 必须是数字, 当前为 [$FLASHNOTE_TRIGGER_TYPE]"
      return 1
      ;;
  esac

  if ! pm path com.oplus.gleanerservice >/dev/null 2>&1; then
    log "错误: 未找到闪记服务"
    log "     本模块的 flashnote 动作只适用于 OPPO/一加 ColorOS 的闪记"
    log "     可把 config.conf 的 ACTION 改成 command 并自定义命令"
    return 1
  fi

  run_cmd am start-foreground-service \
    -n com.oplus.gleanerservice/.flashnotes.business.service.DataCollectService \
    -a oplus.gleanerservice.intent.action.COLLECT_DATA \
    --ei triggerType "$FLASHNOTE_TRIGGER_TYPE" $AM_EXTRA
}

case "$ACTION" in
  flashnote) do_flashnote ;;
  command)   run_cmd sh -c "$CUSTOM_COMMAND" ;;
  intent)    run_cmd am start $AM_EXTRA $INTENT_ARGS ;;
  broadcast) run_cmd am broadcast $AM_EXTRA $INTENT_ARGS ;;
  key)       run_cmd input keyevent $KEYCODE ;;
  none)      log "ACTION=none, 只记日志不动作" ;;
  *)         log "未知 ACTION: $ACTION" ;;
esac
