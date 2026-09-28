# 日本太平洋战争系统（第一阶段）技术说明

## 独立性与更新频率

- 所有新文件和脚本使用 `JAP_pacific_*` 前缀，不覆盖 `JAP_cis_*` 中国事变地图。
- 系统不依赖国策、意识形态事件或自动国策进度；只有日本与美国实际处于战争状态时，太平洋战争决议分类才会显示并启动。
- 战争态势与八个预定义岛群每周更新一次，南方资源航线每月更新一次；没有每日扫描全世界或全部海区。
- 地图由静态底图、60 个预生成 State 双帧图层、预生成军旗、箭头和孤立圈组成。运行时只切换可见性。

## 地图资源管线

- 静态预览：`art_source/JAP_pacific/pacific_strategy_map_preview.png`
- 日本立体军旗母版：`art_source/JAP_pacific/pacific_flag_JAP_master.png`
- 美国立体军旗母版：`art_source/JAP_pacific/pacific_flag_USA_master.png`
- 地图与图层生成器：`tools/generate_jap_pacific_map.ps1`
- GUI/GFX/Scripted GUI 生成器：`tools/generate_jap_pacific_gui.ps1`
- 预览生成器：`tools/generate_jap_pacific_preview.ps1`
- 运行方式：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "tools\\generate_jap_pacific_map.ps1"`，之后依次运行 GUI 与预览生成器。

源军旗保留透明高分辨率母版，游戏内导出为 112×112 PNG。State 图层以 1000×520、两帧横向图集生成，GUI 中按 0.5 缩放。

## 引擎限制与采用的真实近似

### 制海权与封锁

HOI4 1.19 脚本接口没有可供普通 trigger 直接读取“某个海区当前制海权百分比”的通用条件。因此不能稳定地逐海区判断孤岛封锁。本系统使用以下真实脚本条件近似：

1. 固定岛链中继基地是否由日本实际控制；
2. 日本运输船库存；
3. 原版 `naval_strength_comparison` 对美国舰队进行战略级舰力比较；
4. 连续两次周检判定孤立、连续六次判定完全封锁、连续两次恢复判定解除，以避免状态闪烁。

这是一种战略航路模型，不是假装存在逐海区制海权 trigger。

### 强行登陆

原版没有能够通过国家 modifier 绕过海军入侵最低制海权门槛的合法效果。因此“强行实施登陆作战”只使用真实 modifier：`invasion_preparation`、`amphibious_invasion`、`naval_invasion_penalty`，并给予补给、组织恢复和护航代价。它不会绕过引擎的制海权硬门槛。

### 岛屿组织度

State dynamic modifier 不能可靠地直接修改驻岛师的最大组织度，因此孤立与封锁使用真实的 `local_org_regain`、`supply_factor`、`attrition_for_controller` 表达后勤恶化，不加入夸张的直接攻防惩罚。

### 撤离与装备损失

`teleport_armies` 是原版真实效果，可以把所选 State 内的日本师撤回本国。但脚本不能稳定地逐师、逐装备类型保留精确比例。本系统保留部队与人员，并从国家库存扣除步兵装备、支援装备和运输船，近似表达重装备大量遗弃。游戏提示明确说明此限制。

## 南方资源

油田、橡胶、钨、港口、机场和基础设施项目直接修改当地 State。每月航路检查再以 State dynamic modifier 削减实际资源：航路吃紧时约 -30%，中断时约 -65%。因此控制荷属东印度不会无条件把石油传送至日本。

## 已核对的 1.19 原版语法

本阶段依据当前安装版 `D:/STEAM/steamapps/common/Hearts of Iron IV` 核对并使用：

- `invasion_preparation`
- `naval_invasion_prep_speed`
- `naval_invasion_capacity`
- `amphibious_invasion`
- `naval_invasion_penalty`
- `shore_bombardment_bonus`
- `naval_strength_comparison`
- `teleport_armies`
- `add_equipment_to_stockpile`（`convoy_1`）
- State dynamic modifiers：`supply_factor`、`local_org_regain`、`attrition_for_controller`、`state_resources_factor`

用户给出的 `/art_reference/hoi4_vanilla/` 在当前模组工作区中不存在，所以语法核对改用本机实际安装的 HOI4 1.19 数据；没有虚构缺失的 modifier。
