# 多格载具框体 (Multitile Vehicles)

模块 ID：MULTITILE_VEHICLES

### 说明：

给天关补上一套「占据多格」的载具框架。天关（及上游 Nova / /tg/）的载具都是一格一格的，无法表达
一辆 2x2、3x3 的车体。本模块引入一个多格命中盒 `/obj/hitbox`：它是隐形、密实、不可摧毁的
`/obj`，包围盒被放大到覆盖整辆车，把**碰撞、前缘判定、伤害中继**三件事集中到一处，并带着
站在车顶上的人一起移动。

来源：概念参考 TGMC（TerraGov-Marine-Corps）的 multitile hitbox（其本身源自 CM 的坦克命中盒），
但**不是照搬**——TGMC 是 Colonial Marines 血统、不是 /tg/ 的现役分支，变量名与模型早已分叉
（`soft_armor`/`obj_integrity`/`allow_pass_flags`/`move_delay` 等在本仓库都不存在），
因此全部按本仓库的现代 API 重写（`atom_integrity`、`pass_flags_self`、`flags_1`、
`resistance_flags`），并且**不含任何战斗层**（无 soft_armor、无异形接口、无弹道拦截）。

附带的调试终端让现场验证变得可行：手持后按 **Z**（或直接使用物品）弹出选择列表，点选即在脚下
召唤对应框体。

### 核心文件 / Proc 改动：

- `code/modules/unit_tests/_unit_tests.dm`：新增 1 行 `#include "~tianguan\multitile_vehicles.dm"`，
  带 `TIANGUAN EDIT ADDITION` 标记。
  **为什么不能模块化**：该文件底部有 `#undef TEST_ASSERT` / `#undef TEST_ASSERT_EQUAL` /
  `#undef TEST_ASSERT_NOTEQUAL`，所以模块单测只有在本文件的作用域内 include 才拿得到断言宏
  （属于指南里列明的「编译顺序限制」）。上游 Nova 出于同样原因把自己的模块单测放在
  `code/modules/unit_tests/~nova/`，本模块沿用该先例，放在 `~tianguan/`。
- `tgstation.dme`：`// BEGIN_INCLUDE` 块的 modular_tianguan 段新增 4 行 include
  （该块由 DreamMaker 维护，既有条目均无注释标记，本模块保持一致）。
- 其余改动全部是**新增文件**，未编辑任何核心文件正文。

### 模块化覆盖：

- `modular_tianguan/modules/multitile_vehicles/code/hitbox.dm`
  - 新类型 `/obj/hitbox`（含 `two_by_two` / `three_by_three` / `two_by_three` / `three_by_four` 四种框体）
  - 对核心类型 `/obj/vehicle` 的**增量声明**（新文件内扩展，不编辑核心文件）：
    `var/obj/hitbox/hitbox`、`proc/add_desant(mob/living)`、`proc/remove_desant(mob/living)`
    —— 后两者是供子类覆写的空钩子。
  - 行内 `#define COMSIG_MULTITILE_VEHICLE_ROTATED`，文件底部已 `#undef`。
- `modular_tianguan/modules/multitile_vehicles/code/multitile_vehicle.dm`
  - 新类型 `/obj/vehicle/sealed/multitile`：驾驶（`relaymove` / `vehicle_move`）、原地转向、
    上下车落点（`exit_location` / `find_exit_turf`）、点击车体爬上/爬下车顶。
- `modular_tianguan/modules/multitile_vehicles/code/multitile_vehicles.dm`
  - 示例框体 `/obj/vehicle/sealed/multitile/hauler`、`/obj/vehicle/sealed/multitile/hauler/cargo`。
- `modular_tianguan/modules/multitile_vehicles/code/debug_spawner.dm`
  - 新类型 `/obj/item/multitile_debug_spawner`（调试终端）
  - 新键位 `/datum/keybinding/multitile_debug_spawner`（默认 **Z**，`can_use` 仅在
    手持该终端时为真，因此不会抢占别人的 Z）
- `code/modules/unit_tests/~tianguan/multitile_vehicles.dm`：5 个单测（见「测试方式」）。

### Defines：

- `COMSIG_MULTITILE_VEHICLE_ROTATED`（`code/hitbox.dm` 顶部，文件底部 `#undef`）
- `COMSIG_KB_TIANGUAN_MULTITILE_SPAWN_DOWN`（`code/debug_spawner.dm` 顶部，文件底部 `#undef`）

两个都是模块内单文件使用，按指南放在文件顶部并 `#undef`，未污染全局 define 区域。

### 本模块目录外的依赖文件：

- 只**读取**核心资源，未新增：`/obj/hitbox` 借用 `icons/effects/effects.dmi` 的 `"nothing"`
  状态作为隐形占位图标（放大包围盒需要一个真实 icon 才能算出像素边界）。
- 调试终端的手持外观借用核心 `icons/mob/inhands/items/devices_*.dmi` 与 `inhand_icon_state = "electronic"`。
- 本模块自己的资源都在 `modular_tianguan/modules/multitile_vehicles/icons/`：
  `multitile_vehicles.dmi`（2x2 框体，2 状态 × 4 朝向）、`debug_spawner.dmi`（32x32 终端）。

### 测试方式：

- `dm.exe tgstation.dme` 编译 **0 errors**（BYOND 516.1659，与 `dependencies.sh` 一致）。
- 运行时：临时打开 `code/_compile_options.dm` 的 `#define UNIT_TESTS`，编译后用
  `dreamdaemon tgstation.dmb -trusted -port <空闲端口> -log data/xxx.log -verbose` 跑，读
  `data/unit_tests.json`。5 个单测全部 PASS，且日志中本模块相关 runtime 为 0：
  - `multitile_vehicle_footprint`：2x2 包围盒确实生成 4 格、都在同一 z、锚点正确。
  - `multitile_vehicle_leading_edge`：四向前缘各 2 格、坐标正确、不含自身格。
  - `multitile_vehicle_collision`：空场可通行 / 前缘放密实结构后拒动 / 移走障碍后恢复。
  - `multitile_vehicle_damage_relay`：打命中盒掉的是车体的血，且不放大伤害。
  - `multitile_vehicle_hull_rider`：踩上任意一格（含非锚点格）登记为车顶乘客；进入车厢会
    自动取消；车体移动时乘客被带着走。
  **注意**：去焦点跑整套单测很慢（含 `create_and_destroy`）；本模块验证时用 `TEST_FOCUS`
  只跑这 5 个（焦点标记属临时调试手段，验证完已撤除）。
- **尚未做游戏内目视验证**：未在任何真实地图上刷车实操过。请在测试图用调试终端召唤一辆，
  确认四向素材对位、上下车、撞门/撞障碍的手感。

### 维护备注：

- `/obj/hitbox` 的 footprint 是**用锚点格 + 体量算出并缓存**的（`calculate_footprint()`），
  不依赖 BYOND 的 `locs`。原因之一是这条实测教训：**不要往初值为 null 的 typed 列表上 `+=`**
  （`var/list/turf/x` 为 null 时 `x += some_turf` 对本仓库会抛 `bad pixloc`，先 `x = list()` 即可）；
  之二是让「有一份权威且廉价的格子列表」这件事只在一个地方定义。
- 在共享 turf 上 `RegisterSignal` 必须带 `override = TRUE`，否则会被已有监听挡住并告警
  （核心的 `/datum/element/connect_loc` 也是这么做的）。
- 想加新框体：写一个 `/obj/vehicle/sealed/multitile` 子类，指定 `hitbox = <框体 typepath>`、
  同步 `footprint_width/footprint_length`，再配一张填满包围盒的素材即可。调试终端的列表是
  用 `subtypesof()` 自动生成的，**加子类就会自动出现在列表里**，不需要改终端。
- 非正方形框体（`three_by_four`）的旋转会重算包围盒并重排框体格；该分支尚未实测。

### 致谢：

- mohu19（天关作者）
- 概念来源：TGMC 的 multitile hitbox（其上游为 Colonial Marines）
