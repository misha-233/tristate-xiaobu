# 三段式按键 → 一键闪记

拨动三段式开关触发小布记忆「一键闪记」，抓取当前屏幕存入小布记忆。支持 Magisk / KernelSU。

## 效果

- 拨到指定档位（默认上档 / 静音）→ 抓屏 → 存入小布记忆
- 可选「拨走再拨回」防误触；息屏不触发
- 管理器内有 WebUI：改配置、立即测试、看日志

## 关键节点

| 项 | 值 |
|---|---|
| 档位来源 | `/proc/tristatekey/tri_state`：`1`=上(静音) `2`=中(振动) `3`=下(响铃) |
| 按键事件 | `/dev/input/event5`，仅上报 `KEY_F3` 且不含档位信息 |
| 闪记入口 | 小布记忆的闪记采集服务（root 可直接拉起，具体命令见 `bin/trigger.sh`） |
| 触发参数 | intent extra `triggerType`，默认 `2` |

## 安装

管理器刷入 zip → 重启。验证：`su -c 'sh /data/adb/modules/tristate_xiaobu/bin/detect.sh'`

## 配置

`/data/adb/tristate_xiaobu/config.conf`，改完下次拨动即生效；也可在 WebUI 里改。

| 键 | 默认 | 说明 |
|---|---|---|
| `TRIGGER_POSITION` | `1` | 触发档位：`1`/`2`/`3` 或 `up`/`mid`/`down` |
| `TRIGGER_MODE` | `position` | `double` = 拨走再拨回才触发 |
| `COOLDOWN` | `3` | 同档位触发冷却（秒） |
| `SCREEN_ON_ONLY` | `1` | 只在亮屏时触发 |
| `ACTION` | `flashnote` | 或 `command` / `intent` / `broadcast` / `key` / `none` |
| `FLASHNOTE_TRIGGER_TYPE` | `2` | 闪记来源，取值见下 |

`triggerType`：`1` MAGIC_KEY · `2` THREE_FINGERS_UP · `3` CUI · `4` SCREENSHOT ·
`6` SCREENSHOT_NORMAL · `7` SCREENSHOT_LONG · `8` SCREENSHOT_AREA · `11` AUTO_PAYMENT ·
`12` AUTO_COLLECT · `14` AUTO_PAYMENT_NOTIFICATION · `15` AI_KEY_DOUBLE_CLICK · `17` BREENO_TOUCH

## 命令

`sh /data/adb/modules/tristate_xiaobu/bin/cli.sh` 查看全部子命令。

## 卸载

管理器移除模块。配置与日志在 `/data/adb/tristate_xiaobu/`。
