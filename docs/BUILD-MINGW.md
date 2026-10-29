# 使用 MinGW GCC 和 Ninja 构建

项目的 `build.ps1` 支持 Windows x64 的 MinGW GCC/Ninja 和 Visual Studio 2022。构建目录统一放在仓库的 `build/` 下，便携输出放在 `out/` 下；它们都被 Git 忽略。

## 准备环境

需要支持 C++17 的 MinGW-w64 GCC/G++、CMake 3.20 或更新版本、Ninja、对应的 `ar`、`ranlib` 和 `windres`，以及用于验证向导的 Node.js 18 或更新版本。已验证的环境是 Conda GCC 14.4。

## 构建与验证

在 PowerShell 进入仓库目录后运行：

```powershell
.\build.ps1 -Toolchain MinGW -GccBin 'D:\app_data\miniforge\envs\gcc\Library\bin'
```

`-GccBin` 是工具所在目录，请按自己的环境修改。如果已激活相应 Conda 环境，也可以省略该参数，脚本会使用 `$env:CONDA_PREFIX\Library\bin`。脚本只在构建期间调整本进程的 `PATH`，完成或失败后恢复。

默认执行启用断言的 Debug C++ 测试和配置向导校验，再构建 Release。生成位置：

- `build/mingw-debug/`：Debug 构建及测试。
- `build/mingw-release/`：Release 构建。
- `out/mingw-release/`：包含 EXE、向导、配置和 README 的便携目录。

输出目录已有 `config.json` 时会保留原配置；日志等其他已有文件也不会被删除。验证打包内容时使用独立的临时目录。`-Config Debug` 可生成 Debug 便携版；`-SkipTests` 可跳过测试；`-Clean` 仅清理此次使用的对应构建目录后重新构建。

MinGW 配置会静态链接 GCC 运行库，但程序仍依赖 Windows 系统组件和通用 C 运行库（UCRT）。Debug 测试不启动 Codex 桌面应用，实际代理通讯需另行验证。

CMake 缓存包含源码、构建目录和工具的绝对路径。移动源码、构建目录或更换工具链后，应清理对应构建目录并重新配置。
