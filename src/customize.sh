#!/system/bin/sh
# 安装脚本(Magisk 会 source 它; KernelSU 若忽略也不影响, post-fs-data.sh 会兜底)

SKIPUNZIP=0

DATA_ROOT=/data/adb/tristate_xiaobu

ui_print " "
ui_print "********************************************"
ui_print "  三段式按键 -> 小布记忆 一键闪记"
ui_print "  ColorOS 三段式按键"
ui_print "********************************************"
ui_print " "

mkdir -p "$DATA_ROOT/run"
if [ -f "$DATA_ROOT/config.conf" ]; then
  ui_print "- 保留已有配置: $DATA_ROOT/config.conf"
else
  cp -f "$MODPATH/config.conf" "$DATA_ROOT/config.conf"
  ui_print "- 已写入默认配置: $DATA_ROOT/config.conf"
fi

for f in "$MODPATH"/*.sh "$MODPATH"/bin/*.sh; do
  [ -f "$f" ] && set_perm "$f" 0 0 0755
done
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$DATA_ROOT" 0 0 0755
set_perm "$DATA_ROOT/run" 0 0 0755
[ -f "$DATA_ROOT/config.conf" ] && set_perm "$DATA_ROOT/config.conf" 0 0 0600

ui_print " "
ui_print "- 安装完成, 重启后自动生效"
ui_print "- 默认: 拨到【上档(静音)】触发一键闪记"
ui_print "- 改档位/改动作: 编辑 $DATA_ROOT/config.conf"
ui_print "- 诊断报告: su -c 'sh $MODPATH/bin/detect.sh'"
ui_print " "
