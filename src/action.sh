#!/system/bin/sh
# Magisk 应用里的[操作]按钮: 输出一份设备探测报告

MODDIR=${0%/*}
exec sh "$MODDIR/bin/detect.sh"
