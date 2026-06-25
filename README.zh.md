# API Designer

[English](./README.md) · [한국어](./README.ko.md) · **中文**

一款本地桌面工具，用于**手动录制网站的 HTTP API 流量**，然后借助 Claude **分析捕获到的接口**并**生成可直接运行的 FastAPI 客户端**。浏览器由你自己操作，没有自主智能体（agent）。

由 FastAPI 后端和 Flutter 桌面外壳（macOS）组成。

---

## ⚠️ 负责任地使用 — 请先阅读

本工具会从你指向的站点捕获实时 HTTP 流量（包括身份验证头、Cookie 和令牌），并可生成重放这些凭据的代码。

- **仅可用于你拥有或已获明确授权测试的 API 与站点。** 捕获第三方流量、绕过服务条款（ToS）或未经授权访问系统，可能违反目标方的 ToS、计算机滥用相关法律（如 CFAA 及同类法规）以及数据保护法规。
- 捕获的会话包含**真实凭据**。请将导出的会话和生成的代码视为机密。
- 本软件以 Apache-2.0 许可证按**“原样（as is）”、不附带任何担保**提供。使用后果由你自行承担。

---

## 功能

1. **录制（手动）。** 启动 Chromium 浏览器，由你自己浏览并操作目标站点。浏览过程中会捕获 API 请求/响应和 DOM 快照。
2. **分析。** 将捕获的流量发送到 Claude API，识别接口、认证方式、数据模式，以及用户需要提供的输入项。
3. **生成。** 生成一个完整的 FastAPI 客户端项目，复现所发现的 API。密钥从环境变量读取，绝不硬编码。

## 环境要求

- macOS（桌面外壳目前面向 macOS）
- Python 3.11+
- Flutter 3.x
- 一个 Anthropic API 密钥（分析/生成步骤所需）

## 安装

### 1. 后端

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
playwright install chromium   # 必需 —— 下载浏览器二进制文件
```

### 2. 桌面应用

```bash
cd flutter_app
flutter pub get
flutter run -d macos
```

应用会自动启动后端。如需自行运行后端：`cd backend && .venv/bin/python main.py`。

### 3. API 密钥

在 **Settings** 标签页中输入 Anthropic API 密钥，或在启动后端前通过环境变量设置：

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

## 使用方法

1. 打开 **Record** 标签页，输入目标 URL 并开始录制。
2. 自行浏览并操作站点 —— 登录、导航、触发你关心的 API 调用。
3. 停止录制，先 **Analyze**（分析）会话，再 **Generate**（生成）客户端代码。
4. 生成的项目写入 `backend/output/` 目录（已在 gitignore 中）。

## 安全说明

- 后端仅绑定 **127.0.0.1**，并拒绝跨源（cross-origin）浏览器请求与非本地 `Host` 头（防御 drive-by 与 DNS 重绑定）。来自非本地源的 WebSocket 连接同样会被拒绝。
- 仅允许 `http://` 与 `https://` 导航目标。
- Anthropic API 密钥以**明文**存储于 `backend/storage/settings.json`（文件权限 `600`）。捕获的会话存储于 `backend/storage/` 下；两者均已 gitignore。若不希望持久化，请使用 `ANTHROPIC_API_KEY` 环境变量。
- 在将流量发送到 Claude API 之前，认证相关头（Authorization、Cookie 等）的**值**会被掩码，仅共享其存在与结构。
- **生成的代码是基于不可信站点流量的 AI 产物。运行前务必审查**，最好在容器或虚拟机中运行。

## 许可证

[Apache License 2.0](./LICENSE)。
