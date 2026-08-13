# OPENDASH

> OpenCodex 请求仪表盘 —— 深空极光风实时监控面板

一个为 [OpenCodex](https://github.com/bitkyc08/opencodex) 打造的请求监控面板，拥有炫酷的"方舟反应堆"供应商分布图、实时速率曲线、7 天趋势、模型热度排行与实时请求流。纯静态单文件，无需构建，插上即用。


## ✨ 特性

- **实时速率曲线**：5 分钟 / 60 分钟两种粒度的请求速率趋势，均值标注
- **实时请求流**：最新请求日志实时滚动，置于页面首屏醒目位置
- **供应商分布（反应堆）**：方舟反应堆风格的环形图，双层反向旋转线圈、能量粒子环绕，悬停时核心被点亮并染上对应供应商的颜色
- **实时吞吐卡片**：最近 10 分钟请求数、Token 流量、输入/输出拆分、P50/P95 延迟与成功/限流/失败计数
- **7 天趋势**：启用模型的每日请求柱状图
- **模型热度排行**：Top 20 模型请求量排行，进度条带延伸生长动画与渐变发光
- **6 张指标卡**：请求数 / Token / 模型数 / 成本 / 成功率 / 延迟，数值滚动递增动画
- **自动轮询**：用量、日志、模型清单每 3 秒并行刷新，连续失败才提示并自动降低离线轮询频率

## 🚀 安装（Windows）

1. 确保本机已安装并启动 OpenCodex（默认端口 `10100`）
2. 双击 `install-opendash.bat`，按提示操作
3. 脚本会自动定位 OpenCodex 的静态目录并安装，完成后访问：

   <http://localhost:10100/opendash.html>

### 手动指定目录

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-opendash.ps1 -DistDir "D:\opencodex\gui\dist"
```

### 其他端口

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File install-opendash.ps1 -Port 8080
```

> 重新安装或升级 OpenCodex 后，仪表盘文件会被覆盖，再次运行安装脚本即可恢复。

## 🗂 文件说明

| 文件 | 说明 |
| --- | --- |
| `opendash.html` | 仪表盘页面（单文件，全部样式与逻辑内嵌） |
| `install-opendash.ps1` | 安装脚本（自动定位目录 + 安装 + 访问验证） |
| `install-opendash.bat` | Windows 双击运行入口 |

## 🔧 排障

- 页面打开后一直空白：确认 OpenCodex 服务已启动、端口正确
- 安装脚本找不到目录：优先用 `-DistDir` 手动指定 `gui\dist` 路径
- 接口偶发超时：面板带轮询防误报，连续失败才提示"接口异常"

## 📄 License

[MIT](LICENSE)
