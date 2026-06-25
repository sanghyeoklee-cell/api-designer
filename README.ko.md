# API Designer

[English](./README.md) · **한국어** · [中文](./README.zh.md)

웹사이트의 **HTTP API 트래픽을 직접(수동) 녹화**한 뒤, Claude로 **캡처된 엔드포인트를 분석**하고 **바로 실행 가능한 FastAPI 클라이언트를 생성**하는 로컬 데스크톱 도구입니다. 브라우저는 사용자가 직접 조작하며, 자율 에이전트는 없습니다.

FastAPI 백엔드 + Flutter 데스크톱 셸(macOS) 구성입니다.

---

## ⚠️ 책임 있는 사용 — 먼저 읽어주세요

이 도구는 지정한 사이트에서 인증 헤더·쿠키·토큰을 포함한 실시간 HTTP 트래픽을 캡처하며, 그 인증을 재현하는 코드를 생성할 수 있습니다.

- **본인이 소유했거나 테스트 권한을 명시적으로 부여받은 API·사이트에만 사용하세요.** 제3자 트래픽 캡처, 이용약관(ToS) 우회, 무단 접근은 대상의 ToS와 컴퓨터 부정사용 관련 법률, 개인정보보호 규정을 위반할 수 있습니다.
- 캡처된 세션에는 **실제 인증정보**가 들어 있습니다. 내보낸 세션과 생성된 코드는 비밀로 취급하세요.
- 본 소프트웨어는 Apache-2.0 라이선스 하에 **"있는 그대로(as is)", 무보증**으로 제공됩니다. 사용에 대한 책임은 전적으로 사용자에게 있습니다.

---

## 기능

1. **녹화(수동).** Chromium 브라우저를 띄우고 사용자가 직접 대상 사이트를 탐색·조작합니다. 탐색하는 동안 API 요청/응답과 DOM 스냅샷이 캡처됩니다.
2. **분석.** 캡처된 트래픽을 Claude API로 보내 엔드포인트, 인증 방식, 데이터 패턴, 사용자가 입력해야 할 항목을 식별합니다.
3. **생성.** 발견된 API를 그대로 구현하는 완전한 FastAPI 클라이언트 프로젝트를 만듭니다. 비밀값은 환경변수에서 읽으며 코드에 하드코딩하지 않습니다.

## 요구사항

- macOS (데스크톱 셸은 현재 macOS 대상)
- Python 3.11+
- Flutter 3.x
- Anthropic API 키 (분석/생성 단계에 필요)

## 설치

### 1. 백엔드

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -e .
playwright install chromium   # 필수 — 브라우저 바이너리를 내려받습니다
```

### 2. 데스크톱 앱

```bash
cd flutter_app
flutter pub get
flutter run -d macos
```

앱이 백엔드를 자동 실행합니다. 직접 실행하려면: `cd backend && .venv/bin/python main.py`.

### 3. API 키

**Settings** 탭에서 Anthropic API 키를 입력하거나, 백엔드 실행 전 환경변수로 지정하세요:

```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

## 사용법

1. **Record** 탭에서 대상 URL을 입력하고 녹화를 시작합니다.
2. 사이트를 직접 탐색·조작합니다 — 로그인, 이동, 원하는 API 호출 발생.
3. 녹화를 중지하고 세션을 **Analyze**(분석) → **Generate**(코드 생성).
4. 생성된 프로젝트는 `backend/output/` 아래에 기록됩니다 (gitignore 처리됨).

## 보안 메모

- 백엔드는 **127.0.0.1** 에만 바인딩되며, 교차 출처(cross-origin) 브라우저 요청과 비로컬 `Host` 헤더를 거부합니다(드라이브-바이·DNS 리바인딩 방어). 비로컬 출처의 WebSocket 연결도 거부합니다.
- `http://`·`https://` 대상만 허용합니다.
- Anthropic API 키는 `backend/storage/settings.json` 에 **평문**으로 저장됩니다(파일 권한 `600`). 캡처 세션은 `backend/storage/` 아래에 저장되며 둘 다 gitignore 처리됩니다. 저장이 꺼려지면 `ANTHROPIC_API_KEY` 환경변수를 사용하세요.
- 트래픽을 Claude API로 보내기 전에, 인증 관련 헤더(Authorization, Cookie 등)의 **값**은 마스킹되어 존재·구조만 전달됩니다.
- **생성된 코드는 신뢰할 수 없는 사이트 트래픽에서 나온 AI 산출물입니다. 실행 전 반드시 검토하세요.** 가능하면 컨테이너나 VM에서 실행하세요.

## 라이선스

[Apache License 2.0](./LICENSE).
