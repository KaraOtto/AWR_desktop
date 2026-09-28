# 民国腐败与清洗系统

## 接入位置

本模块面向《全面抗战》现有 CHI 权力集团系统。`common/on_actions/CHI_on_actions.txt` 在原文件基础上加入初始化和月度结算；其余文件均为新增文件。

## 核心变量

- `CHI_army_corruption`
- `CHI_capital_corruption`
- `CHI_technocrat_corruption`
- 对应的 `*_corruption_coefficient` 为每月增长值，默认分别为 0.07、0.06、0.05。

每月对三类腐败分别生成 0 到 1 的随机数；随机数小于当前腐败值时触发案件。案件严重度按需求文档分段抽取。0.41 到 0.70 档原稿权重合计为 105，本实现保留 35、45、25 的相对权重，由引擎自动归一化。

## 元首背景

默认设置为军队背景。以下互斥国旗用于后续路线或人物脚本接入：

- `CHI_corruption_leader_background_army`
- `CHI_corruption_leader_background_capital`
- `CHI_corruption_leader_background_technocrat`

当清洗与元首背景相同的集团时，不执行该集团的影响力转移。

## 白名单接口

军官使用 `CHI_corruption_whitelist` 特质。行政人员可在角色作用域设置 `CHI_corruption_whitelist` 角色旗标。随机目标选择会排除这些角色。

## 终止接口

未来反腐国策的完成效果直接调用：

```txt
CHI_end_corruption_system = yes
```

系统也提供“完成制度化反腐”决议用于现阶段闭环测试。

## 调试

控制台在 CHI 作用域执行 `set_country_flag CHI_corruption_debug`，即可显示背景切换与案件测试决议。
