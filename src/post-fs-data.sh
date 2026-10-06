#!/system/bin/sh
# 开机早期: 只保证目录和配置存在, 其余交给 service.sh

MODDIR=${0%/*}
DATA_ROOT=/data/adb/tristate_xiaobu

mkdir -p "$DATA_ROOT/run" 2>/dev/null
if [ ! -f "$DATA_ROOT/config.conf" ]; then
  cp -f "$MODDIR/config.conf" "$DATA_ROOT/config.conf" 2>/dev/null
  chmod 600 "$DATA_ROOT/config.conf" 2>/dev/null
fi
