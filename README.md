# 天关13 · 开箱即用汉化私服包

> **这是「一键开服」分支（`deploy/oneclick-package`）** —— 给你一份**解压就能跑的中文 SS13 私服**，自带引擎与编译好的服务端，不需要安装任何工具。
>
> 📖 **想看源码 / 改代码 / 提改动** → **[README.dev.md](./README.dev.md)**（原开发文档，全文完整保留，一字未删）
> 🈶 **汉化分支说明** → [README.zh-Hans.md](./README.zh-Hans.md)

---

## 一、这是什么

适合三类人：

- 想体验「天关13」中文内容 / 玩法更新的**玩家**
- 想自己测试某个功能、某个地图、某套配置的玩家
- 想拉几个朋友开个**局域网 / 公网小服**的人

包里带什么：

| 内容 | 说明 |
|---|---|
| `tgstation.dmb` / `tgstation.rsc` | **已编译好的服务器本体**（无需任何工具即可运行） |
| `byond/` | 便携版 BYOND 引擎 **516.1685**（DreamDaemon + DreamMaker），绿色免安装 |
| `tgui/public/` | **已构建好的游戏内界面**（聊天、电脑、各种 UI、语音面板） |
| 完整 DM 源码 | `code/` `modular_nova/` `modular_tianguan/` `icons/` `sound/` 等，可自行改代码后重新编译 |
| `strings/i18n/zh-Hans/` | 全服中文翻译库（56 个分类文件） |

---

## 二、下载

| 方式 | 说明 |
|---|---|
| **完整包（推荐）** | **[点此下载](https://github.com/mohu19/TianGuan13/releases/tag/oneclick-package-20261007)** → `TianGuan13_oneclick_zh-Hans_20261007.zip`（约 621 MB） |
| 只取部署套件 | 就是本分支：`git clone -b deploy/oneclick-package`，再双击一次 `build_server.bat` 自己编译（约 1.5 分钟，包内已带 BYOND 编译器） |

> **为什么完整包只能放 Release？** 服务器运行必须要有 `tgstation.rsc`（283 MB）——实测缺它开不了服
> （日志刷 `bad icon operation`、初始化永远不完成，也不会自动生成）。而 GitHub 对单个文件有 100 MB 硬上限，
> 所以它进不了 git 分支，只能作为 Release 附件分发。

---

## 三、快速开始（3 步）

1. 解压到任意目录（路径建议纯英文，如 `D:\TianGuan13\`）
2. 双击 **`start_server.bat`**
3. 等窗口出现类似下面这行就说明开好了（约 1~2 分钟）：

   ```
   Initializations complete within 81.0813 seconds!
   ```

**本机连接：** 装好 [BYOND 客户端](https://www.byond.com/download)（免费）后，地址栏输入 `byond://127.0.0.1:1337`
—— 本机连接**自动获得管理员权限**（`config/config.txt` 里 `ENABLE_LOCALHOST_RANK` 默认开启）。

**局域网朋友连接：** 把 `127.0.0.1` 换成你电脑的局域网 IP（`ipconfig` 查看），并在 Windows 防火墙放行 1337 端口。

---

## 四、给其他玩家开管理员

运行 `setup_admin.bat`，输入对方的 **BYOND 账号名**（登录名，全小写），会写入 `config\admins.txt`：

```
对方的账号 = Host
```

改完**重启服务器**生效。`Host` 是最高权限，其它权限名见 `config/admin_ranks.txt`。

---

## 五、本分支自带的部署件

| 文件 | 作用 |
|---|---|
| `start_server.bat` | 启动 DreamDaemon（端口 1337、`-trusted`、日志写 `data\server.log`） |
| `build_server.bat` | 改完 `.dm` 后重新编译（`byond\bin\dm.exe -DCBT tgstation.dme`） |
| `setup_admin.bat` | 给局域网 / 公网玩家加 Host 权限 |
| `开服指南.md` | **面向玩家的完整中文说明**（快速开始 / 管理员 / 重编译 / 配置表 / FAQ / 改动清单） |
| `byond/` | 便携 BYOND 引擎 516.1685（服务器 + 编译器 + 客户端） |
| `tgui/public/*.bundle.*` | 已构建的游戏内界面产物（上游把它 gitignore 掉了，本分支必须带上，否则进游戏界面空白） |

> ⚠️ 编译时 `-DCBT` **必须写在 `tgstation.dme` 前面**，顺序写反会被编译器静默忽略，
> 表现为编译"0 errors"但游戏里所有电脑图标变成红色 ERROR 方块。`build_server.bat` 已经写对。

---

## 六、版本与校验

| 项 | 值 |
|---|---|
| 快照基线 | 上游 `mastercopy` 分支 tip `1d275ebf`（2026-10-06） |
| 编译结果 | **0 errors, 0 warnings**（耗时 1 分 23 秒） |
| 起服实测 | 三次均成功：`Initializations complete within 81.08s / 78.44s / 76.45s` |
| 与上游比对 | 26,777 / 26,783 个文件**逐字节一致**，0 个缺失 |
| 源码改动 | **未修改任何一行 `.dm` 源码**（只改了 2 处配置默认 + 4 个工具生成的文案目录） |
| 中文 | 全服中文为上游默认（`config/game_options.txt` 的 `I18N_SERVER_LOCALE zh-Hans`），改 `en` 可切英文 |

内容上是目前最新的一版：上游「天关」模块 **23 个**（含大厅改版、UAR 部门系列、管理员全局倒计时、
歌曲磁带、赞助者配装、大厅歌单、传真网络、指南浏览器 等），以及上游新增的**语音表达系统**。

---

## 七、已知报错（不影响游玩）

服务器启动日志里可能出现这一条：

```
Runtime in code/controllers/subsystem/tts.dm,115:
  http://127.0.0.1:5002/tts-voices: Connection Failed (os error 10061)
```

这是**语音（TTS）子系统**在找一个独立的语音后端服务，**本包不含该服务**所以连不上。
不碰语音相关功能就完全无视它，服务器照常开。上游自身也有同样的报错。

另有一些 `arrivals_shuttle` / `docking_port unregistered` 警告，属上游既有的正常噪音。

---

## 📖 开发 / 源码文档（跳转）

本仓库的**原始说明文档全部保留**，没有被删改：

| 文档 | 内容 |
|---|---|
| **[README.dev.md](./README.dev.md)** | 原 `README.md` 全文 —— 源码结构、编译环境、模块化规范、贡献流程、许可证等 |
| **[README.zh-Hans.md](./README.zh-Hans.md)** | 汉化分支说明 |
| **[AGENTS.md](./AGENTS.md)** | 面向 AI 协作者 / 开发者的仓库约定 |
| **[modular_tianguan/readme.md](./modular_tianguan/readme.md)** | 「天关」模块化开发规范 |

---

## 许可

继承上游仓库的开源许可（详见 `LICENSE` / `GPLv3.txt`）。本包仅作个人 / 社区测试用途。
