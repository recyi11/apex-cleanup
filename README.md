中文 | [English](#english)

## 简介

一个用于处理 Apex Legends 卡死、退出失败、反作弊残留或启动器残留的小工具。

它只会尝试关闭卡住的游戏进程、EA App / Steam 相关残留进程，以及 Easy Anti-Cheat / EA AntiCheat 相关服务或进程。它不会绕过、修改或禁用反作弊。

## 适用情况

- Apex Alt+F4 后关不掉
- 任务管理器里还残留 `r5apex` 或 `r5apex_dx12`
- EA App / Steam / Overlay 卡住导致 Apex 无法彻底退出
- Easy Anti-Cheat / EA AntiCheat 残留导致下一次启动异常

## 使用方法

### EXE 版

EXE 版放在单独的 `exe` 分支，下载 `ApexCleanup.exe` 后直接双击运行。

下载地址：[ApexCleanup.exe](https://github.com/recyi11/apex-cleanup/blob/exe/ApexCleanup.exe)

这是自包含单文件版本，不需要另外安装 .NET，也不需要把 `.cmd` 和 `.ps1` 放在一起。

如果弹出管理员权限请求，请允许。

### 脚本版

1. 下载本仓库里的两个文件：
   - `apex-cleanup.cmd`
   - `apex-cleanup.ps1`
2. 把两个文件放在同一个文件夹里。
3. 双击 `apex-cleanup.cmd`。
4. 如果弹出管理员权限请求，请允许。

## 行为说明

- 如果 Steam 或 EA App 原本正在运行，工具会先记录它们的真实路径。
- 清理完成后，工具会重新启动原本正在运行的 Steam 或 EA App。
- 如果 Steam / EA App 原本没开，工具不会主动打开它们。
- 工具不包含硬编码安装路径，可以放在任意目录使用。

## 如果仍然关不掉

有时 Windows 会留下一个“看起来还在，但已经无法被终止”的死进程对象。此时 `taskkill` 可能会提示：

```text
There is no running instance of the task.
```

这种情况通常只能通过重启 Windows 清理。

如果想在检测到残留时自动重启，可以用：

```powershell
powershell -ExecutionPolicy Bypass -File .\apex-cleanup.ps1 -RestartIfStuck
```

## 安全说明

本工具只调用 Windows 自带的进程、服务和重启命令：

- `Stop-Process`
- `taskkill.exe`
- `Stop-Service`
- `Start-Process`
- `shutdown.exe`，仅在你传入 `-RestartIfStuck` 时使用

它不会修改游戏文件、反作弊文件或注册表。

---

## English

A small Windows helper for cleaning up stuck Apex Legends, launcher, and anti-cheat leftovers.

It only attempts to close stuck game processes, EA App / Steam related leftover processes, and Easy Anti-Cheat / EA AntiCheat services or processes. It does not bypass, modify, or disable anti-cheat.

## When To Use

- Apex does not close after Alt+F4
- `r5apex` or `r5apex_dx12` remains in Task Manager
- EA App / Steam / Overlay leftovers keep Apex from exiting cleanly
- Easy Anti-Cheat / EA AntiCheat leftovers cause the next launch to fail

## Usage

### EXE Version

The EXE build lives on the separate `exe` branch. Download `ApexCleanup.exe`, then double-click it.

Download: [ApexCleanup.exe](https://github.com/recyi11/apex-cleanup/blob/exe/ApexCleanup.exe)

This is a self-contained single-file build, so it does not require installing .NET or keeping the `.cmd` and `.ps1` files together.

Allow the Administrator prompt if Windows asks.

### Script Version

1. Download these two files from this repository:
   - `apex-cleanup.cmd`
   - `apex-cleanup.ps1`
2. Put both files in the same folder.
3. Double-click `apex-cleanup.cmd`.
4. Allow the Administrator prompt if Windows asks.

## What It Does

- If Steam or EA App was already running, the tool records its real executable path first.
- After cleanup, it restarts the Steam or EA App client that was originally running.
- If Steam / EA App was not running, the tool will not launch it.
- The tool has no hard-coded install directory and can be used from any folder.

## If Apex Still Will Not Close

Sometimes Windows keeps a dead process object visible even though it can no longer be terminated. In that state, `taskkill` may say:

```text
There is no running instance of the task.
```

That state is usually cleared only by restarting Windows.

To automatically restart when leftovers remain, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\apex-cleanup.ps1 -RestartIfStuck
```

## Safety

This tool only uses built-in Windows process, service, and restart commands:

- `Stop-Process`
- `taskkill.exe`
- `Stop-Service`
- `Start-Process`
- `shutdown.exe`, only when you pass `-RestartIfStuck`

It does not modify game files, anti-cheat files, or the registry.
