#!/system/bin/sh
# 卸载: 停掉后台进程。配置与日志保留, 需要彻底清理请手动 rm -rf /data/adb/tristate_xiaobu

DATA_ROOT=/data/adb/tristate_xiaobu
RUN_DIR=$DATA_ROOT/run

for f in watchdog.pid daemon.pid service.pid; do
  if [ -f "$RUN_DIR/$f" ]; then
    pid=$(cat "$RUN_DIR/$f" 2>/dev/null)
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    [ -n "$pid" ] && kill -9 "$pid" 2>/dev/null
    rm -f "$RUN_DIR/$f"
  fi
done

# 兜底清理残留的 daemon / getevent 子进程(模式不要匹配到本脚本自身)
for pid in $(ps -A -o PID,ARGS 2>/dev/null | grep -E 'bin/daemon\.sh|getevent -l /dev/input' | grep -v grep | awk '{print $1}'); do
  kill "$pid" 2>/dev/null
  kill -9 "$pid" 2>/dev/null
done

rm -rf "$RUN_DIR"
