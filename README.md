# <img src="assets/opendash.svg" width="30" alt="OPENDASH logo" align="absmiddle"> OPENDASH

为 [OpenCodex](https://github.com/lidge-jun/opencodex) 打造的本地请求观测台。单文件、无构建步骤、无外部字体或图表依赖。**一体化双主题**设计，默认白天版（液态玻璃），页面内支持随时一键无感切换黑夜版（深空极光）。

## 主题

| 主题 | 风格 |
| --- | --- |
| ☀️ 白天版（默认） | macOS 26 Liquid Glass 启发的浅色玻璃：左暖杏、右冷蓝环境光，五层材质分级，光标边缘折射追光，玻璃数据环 |
| 🌙 黑夜版 | 深空极光：星海背景、极光漂移、霓虹曲线、能量核心环形图 |

入口统一为 `opendash.html`，点击右上角「☾ 深空极光」或「☼ 液态玻璃」按钮即可在两套主题间秒切，自动记忆偏好。

## 功能

- 白天版：受 macOS 26 Liquid Glass 启发的浅色玻璃界面（Web CSS 模拟，不等价于 Apple 原生系统材质）；黑夜版：深空极光背景、能量核心、霓虹曲线。均含卡片渐次入场、请求滑入与数值过渡。
- 渐进增强：不支持 `backdrop-filter` 时回退实色；`prefers-reduced-transparency` / `prefers-contrast: more` / `prefers-reduced-motion` 下自动降级，页面内动效开关与系统偏好都生效。
- 动效开关会记住选择；首次打开遵循系统减少动画偏好，页面进入后台后停止连续绘图并暂停轮询。
- 全部历史 / 当前启用模型切换，统一应用于累计、趋势、供应商和实时统计。默认显示全部历史，禁用模型不会让历史累计凭空减少。
- 请求流支持异常 / 429 限流筛选。同一请求状态与用量更新时原位替换，阅读旧记录时保留滚动位置。
- 最近 5 分钟、60 分钟速率曲线；7 天账本趋势；Top 20 模型排行；最近 10 分钟成功率、耗时、Token 与 P50/P95。
- 暂停 / 继续刷新和立即刷新；断线自动退避，401/403 后重新引导会话并重试一次，不生成演示业务数据。
- 桌面与窄屏布局；窄屏优先显示模型、状态、时间和 Token。

## 安装

确保 OpenCodex 已启动：

1. **双击 `opendash.bat`**（或 `install-opendash.bat`）；
2. 脚本会自动定位本地 OpenCodex 的 GUI 静态目录并安全完成部署；
3. 打开浏览器访问：[本机面板](http://localhost:10100/opendash.html)（也可使用 [目录入口](http://localhost:10100/opendash/index.html)）。

> 命令行方式运行：请先 `cd` 进入本项目目录，再执行 `opendash.bat`；如需指定自定义路径或端口：
> ```powershell
> powershell -NoProfile -ExecutionPolicy Bypass -File install-opendash.ps1 -DistDir "D:\opencodex\gui\dist" -Port 10100
> ```

想换主题无需重新安装，直接在页面右上角点击按钮即可即时秒切；更新面板时重新运行脚本即可，旧面板会自动备份在 `deployment-backups/` 目录中。

## 数据口径与限制

- 七天累计来自 `/api/usage?range=7d`；供应商分布与排行榜按相同模型范围聚合。模型数按“供应商 / 模型”区分；排行最多显示 20 项，模型总数不受此限制。未知模型按账本原样保留。
- 估算费用不是实际账单。面板显示计价覆盖比例，未计价和未上报请求可能造成低估。缓存 Token 是输入细分，不再次计入总量。
- 实时数据来自 `/api/logs`，首次取最多 2,000 条，平时取 120 条；发现批次与本地历史断档时补取最多 2,000 条，合并、更新并保留最近一小时，浏览器缓存上限 20,000 条。**服务端日志保留量有限、刚打开面板、高峰流量或长时间离线，都可能造成实时窗口不完整**，因此实时曲线、分位数为已获取日志样本统计，不能当作完整账本。
- 当前启用模型模式需要配置和模型清单均就绪；首次清单不可用时明确提示展示全部历史，恢复后自动筛选。状态筛选仅影响请求列表，不修改全局指标。
- 日志每 3 秒、用量每 15 秒、模型清单每 60 秒刷新。连续失败后指数退避至最多 60 秒。暂停时正在进行的请求可能仍会完成；“立即刷新”仍可手动更新。
- 原有同源会话机制用于只读访问，凭证仅保存在页面内存；不保存到本地存储。请通过 OpenCodex 服务地址访问，不要直接双击 HTML。

## 验证

```powershell
node --test tests/dashboard.test.cjs
# 可选：隔离的空数据/断线页面，不调用真实上游
node tests/serve-fixtures.cjs
```

本地测试页为 `http://127.0.0.1:10109/empty.html`（白天）、`/empty-dark.html`（黑夜）、`/offline.html` 与 `/offline-dark.html`。测试服务仅监听本机，用完按 Ctrl+C 关闭。

## 文件

| 文件 | 用途 |
| --- | --- |
| `opendash.html` | 一体化面板：内置白天液态玻璃 + 黑夜深空极光双主题，页面内一键即时无感切换，默认白天版 |
| `opendash-light.html` | 白天版面板（液态玻璃）：全部界面、样式、数据与动画逻辑 |
| `opendash-dark.html` | 黑夜版面板（深空极光）：同一数据逻辑的深色主题 |
| `opendash.bat` / `install-opendash.bat` | Windows 一键安装批处理入口（双击即可自动部署） |
| `install-opendash.ps1` | PowerShell 自动化安装脚本，支持自动化路径解析与状态校验 |
| `tests/dashboard.test.cjs` | 数据统计、过滤、会话续期与空态回归测试套件 |
| `tests/serve-fixtures.cjs` | 隔离浏览器测试服务 |

MIT License。
