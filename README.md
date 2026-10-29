# Codex App Proxy Launcher

Windows 便携启动器：为 Microsoft Store 版 ChatGPT/Codex 桌面应用配置已有的本机 HTTP/mixed 或 SOCKS5 代理，不需要开启 Windows 系统代理或 TUN。

本仓库 fork 自 [leisair/codex-app-proxy](https://github.com/leisair/codex-app-proxy)，感谢原项目。此 Fork 在原项目基础上支持向 Codex 后台进程传递代理设置，修复配置向导生成 PowerShell 命令时的注入问题，并增加 MinGW GCC 构建支持。具体变更见 [CHANGELOG.md](CHANGELOG.md)。

![START-HERE 离线配置向导](docs/images/start-here.png)

## 使用前提

- Windows 10/11 x64，并已安装 Microsoft Store 版 ChatGPT/Codex 桌面应用。
- 已有并启动 V2RayN、Clash Verge、Mihomo 或其他代理软件，确认其本地 HTTP/mixed 或 SOCKS5 监听地址和端口。
- 本项目只负责启动应用，不提供代理节点、订阅或网络服务。独立启动的 Codex CLI 不受这个启动器控制。

默认配置为 HTTP `127.0.0.1:10808`，通常适用于 V2RayN 的 mixed 端口。其他软件请以实际监听端口为准：Clash Verge Rev 常见 `7897`，Clash/Mihomo 常见 `7890`，通用 SOCKS5 常见 `1080`。

## 使用

从源码构建后，将以下文件放在同一个可写文件夹中：

| 文件 | 用途 |
| --- | --- |
| `CodexProxyLauncher.exe` | 启动桌面应用 |
| `START-HERE.html` | 离线配置向导 |
| `config.json` | 实际生效的代理配置 |
| `README.md` | 使用说明 |

1. 启动本机代理软件。打开 `START-HERE.html`，按代理软件的实际地址、类型和端口生成 `config.json`，保存到启动器所在目录。
2. 完全退出已运行的 ChatGPT/Codex 桌面应用，包括托盘中的后台进程。已有进程可能不接收新的启动参数。
3. 双击 `CodexProxyLauncher.exe`，然后发送消息确认连接正常。

如果直接启动失败，程序可能回退到 Windows 应用包激活，并提示这种方式不能保证后台进程继承代理。看到提示时，请检查实际通讯情况。日志默认只在启动出错时写入同目录 `logs/`；分享日志前请检查是否包含本机路径或其他敏感信息。

## 工作原理与范围

启动器读取同目录 `config.json`，检查代理端口和已运行的桌面进程，找到应用后：

- 给桌面界面传入 Chromium 的 `--proxy-server`、`--proxy-bypass-list` 参数，并按配置决定是否传入 `--disable-quic`。
- 优先直接启动应用，并在启动器进程中设置 `HTTP_PROXY`、`HTTPS_PROXY` 和 `ALL_PROXY`，供桌面应用及其后台子进程继承；不会写入用户或系统环境变量。
- 如果只能通过 Windows 应用包激活，会显示后台代理可能无法继承的提示。

启动器不会设置 Windows 系统代理，也不创建 TUN 网卡或额外常驻服务。TCP 端口可连接只说明该端口有监听，不能证明节点、认证、WebSocket 或所有应用流量一定正常。默认直连列表包含回环和部分私网地址；本工具不是强制全流量代理或断网保护工具。

配置向导会校验代理地址和直连列表，并对生成的 PowerShell 命令使用安全引用。仍应只使用可信配置，并在复制命令前检查内容。

## 从源码构建

需要 Windows x64、CMake 3.20 或更新版本，以及以下任一 C++ 工具链：

- **Visual Studio 2022**：安装包含 C++ 桌面开发工具和 Windows SDK 的 Build Tools。
- **MinGW-w64 GCC 和 Ninja**：需要支持 C++17 的 GCC/G++、Ninja、`ar`、`ranlib` 和 `windres`。本项目已在 Conda GCC 14.4 环境验证；工具链及 Windows 运行库需要相互兼容。

Node.js 18 或更新版本用于配置向导校验。构建程序本身不需要下载代理节点。

在源码仓库根目录的 PowerShell 中，使用 Visual Studio 2022：

```powershell
.\build.ps1
```

使用 Conda MinGW GCC 时，将下面路径替换为自己的环境目录：

```powershell
.\build.ps1 -Toolchain MinGW -GccBin 'D:\app_data\miniforge\envs\gcc\Library\bin'
```

构建目录统一位于仓库根目录的 `build/`，按工具链和配置区分；便携输出位于 `out/` 对应的子目录。本机保留的便携包及历史产物可放在 `local-artifacts/`；这些目录和本地项目日志 `.agent-journal/` 均不会提交到 Git。脚本默认运行 Debug C++ 测试和向导校验。完整步骤和手动 CMake 命令见 [MinGW 构建说明](docs/BUILD-MINGW.md)。

从已有输出目录复制文件时，请保留或备份已有的 `config.json`，避免覆盖个人代理设置。CMake 缓存包含绝对路径，移动源码或更换工具链后需要重新配置。

## 常见问题

**提示无法连接本地代理：**确认代理软件正在运行，配置的是本机 HTTP/mixed 或 SOCKS5 监听端口，而不是远程节点端口。

**能看到登录状态但发送消息超时：**确认已完全退出旧桌面进程并用此启动器重新打开；检查后台代理是否继承、代理节点是否可用，以及是否出现应用包激活回退提示。

**Windows 提示未知发布者：**自行构建的 EXE 没有代码签名，可能触发 SmartScreen；来源与文件完整性需要自行核实。仓库源码不代表已经提供了可下载的 Release。

## 开发与安全反馈

提交问题前，请提供 Windows、桌面应用和代理软件版本，以及脱敏后的相关错误信息。安全问题的处理方式见 [SECURITY.md](SECURITY.md)，变更记录见 [CHANGELOG.md](CHANGELOG.md)。

---

A Windows x64 launcher for the Microsoft Store ChatGPT/Codex app. This fork configures the desktop UI and its directly launched backend to use an existing local proxy; it does not provide a VPN, proxy nodes, or a guarantee that every connection is proxied.
