#!/system/bin/sh
# 开机后期服务: 等 boot_completed 后拉起 daemon, 并做看门狗

MODDIR=${0%/*}
DATA_ROOT=/data/adb/tristate_xiaobu
RUN_DIR=$DATA_ROOT/run

mkdir -p "$RUN_DIR" 2>/dev/null

(
  # 等系统真正起来(ActivityManager / settings 可用)
  i=0
  while [ "$i" -lt 150 ]; do
    [ "$(getprop sys.boot_completed)" = "1" ] && break
    sleep 2
    i=$((i + 1))
  done
  sleep 5

  echo $$ > "$RUN_DIR/watchdog.pid"

  # 看门狗: daemon 退出就重启; 模块被卸载(目录消失)则退出
  while [ -d "$MODDIR" ]; do
    sh "$MODDIR/bin/daemon.sh" >> "$DATA_ROOT/daemon.out" 2>&1
    sleep 10
  done
  rm -f "$RUN_DIR/watchdog.pid"
) &

echo $! > "$RUN_DIR/service.pid"
