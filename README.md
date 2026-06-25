# API Designer

**English** · [한국어](./README.ko.md) · [中文](./README.zh.md)

A local desktop tool to **manually record a website's HTTP API traffic**, then use Claude to **analyze the captured endpoints** and **generate a ready-to-run FastAPI client**. You drive the browser yourself — there is no autonomous agent.

It is a FastAPI backend plus a Flutter desktop shell (macOS).

---

## ⚠️ Responsible use — read first

This tool captures live HTTP traffic — including authentication headers, cookies, and tokens — from whatever site you point it at, and can generate code that replays that authentication.

- **Only use it against APIs and sites you own or are explicitly authorized to test.** Capturing third-party traffic, bypassing Terms of Service, or accessing systems without permission may violate the target's ToS, computer-misuse laws (e.g. the CFAA and equivalents), and data-protection regulations.
- Captured sessions contain **live credentials**. Treat exported sessions and generated code as secrets.
- This software is provided **"as is", without warranty**, under the Apache-2.0 license. You are solely responsible for how you use it.

---

## What it does

1. **Record (manual).** Launch a Chromium browser, navigate and interact with the target site yourself. API requests/responses and DOM snapshots are captured as you browse.
2. **Analyze.** Send the captured traffic to the Claude API to identify endpoints, the authentication scheme, data patterns, and the inputs a user would need to supply.
3. **Generate.** Produce a complete FastAPI client project that mirrors the discovered API. Secrets are read from environment variables — never hardcoded.

## Requirements

- macOS (the desktop shell currently targets macOS)
- Python 3.11+
- Flutter 3.x
- An Anthropic API key (for the Analyze / Generate steps)

## Setup

### 1. Backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
playwright install chromium   # required — downloads the browser binary
```

### 2. Desktop app

```bash
cd flutter_app
flutter pub get
flutter run -d macos
```

The app launches the backend automatically. If you prefer to run the backend yourself: `cd backend && .venv/bin/python main.py`.

### 3. API key

Enter your Anthropic API key in the **Settings** tab, or set it in the environment before launching the backend:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

## Usage

1. Open the **Record** tab, enter a target URL, and start recording.
2. Browse and interact with the site — log in, navigate, trigger the API calls you care about.
3. Stop recording, then **Analyze** the session, then **Generate** the client code.
4. Generated projects are written under `backend/output/` (gitignored).

## Security notes

- The backend binds to **127.0.0.1** only and rejects cross-origin browser requests and non-local `Host` headers (defense against drive-by and DNS-rebinding). WebSocket connections from non-local origins are refused.
- Only `http://` and `https://` navigation targets are allowed.
- The Anthropic API key is stored **in cleartext** at `backend/storage/settings.json` (file mode `600`). Captured sessions are stored under `backend/storage/` — both are gitignored. Use the `ANTHROPIC_API_KEY` env var if you prefer not to persist it.
- Before traffic is sent to the Claude API, the **values** of credential-bearing headers (Authorization, Cookie, etc.) are masked; only their presence/structure is shared.
- **Generated code is AI output derived from untrusted site traffic. Review it before running it,** ideally in a container or VM.

## License

[Apache License 2.0](./LICENSE).
