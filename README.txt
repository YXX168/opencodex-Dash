OpenCodex 请求仪表盘安装器
============================

文件说明
  opendash.html            仪表盘页面（最新版本）
  install-opendash.ps1     安装脚本
  install-opendash.bat     双击运行入口（Windows）

安装方法（Windows）
  1. 把整个文件夹拷贝到其他电脑（例如通过 U 盘或压缩包）。
  2. 确保那台电脑已经安装并启动 opencodex（端口默认 10100）。
  3. 双击 install-opendash.bat，按提示操作。
  4. 脚本会自动查找 opencodex 安装目录并安装；
     如果自动查找失败，会提示你手动输入 opencodex 的 gui\dist 路径。
  5. 安装完成后访问：http://localhost:10100/opendash.html

手动指定目录
  powershell -NoProfile -ExecutionPolicy Bypass -File install-opendash.ps1 -DistDir "D:\opencodex\gui\dist"

其他端口
  如果 opencodex 不在 10100 端口，用 -Port 指定：
  powershell -NoProfile -ExecutionPolicy Bypass -File install-opendash.ps1 -Port 8080

注意事项
  - 重新安装或升级 opencodex 后，仪表盘文件会被覆盖，重新运行本脚本即可。
  - 脚本只复制文件，不会修改 opencodex 配置，也不会删除任何数据。
