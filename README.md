# UsageBar

Claude Code와 Codex의 **남은 사용량**을 화면 구석의 작은 링 위젯으로 보여주는 macOS 앱. 무료, 오픈소스(MIT).

링 안의 숫자는 남은 %, 아래에는 한도가 리셋되기까지 남은 시간이 표시됩니다.
남은 양에 따라 초록 → 주황 → 빨강으로 바뀝니다.

## 설치
1. [Releases](../../releases)에서 `UsageBar.zip`을 받아 압축을 풀고 `UsageBar.app`을 응용 프로그램 폴더로 옮깁니다.
2. **처음 한 번만** 앱을 우클릭 → **열기** → **열기**. (Apple 서명이 없는 앱이라 더블클릭하면 경고가 뜹니다.)
3. 화면 오른쪽 위에 위젯이 뜹니다. 끌어서 옮길 수 있고, 우클릭하면 새로고침 / 로그인 시 자동 실행 / 종료.

요구사항: macOS 13 이상 (Apple Silicon, Intel 모두 지원)

## 누가 쓸 수 있나요
- **Claude**: Claude Code로 로그인한 적이 있어야 합니다. (CLI든 데스크톱 앱의 Code 탭이든 상관없음. 웹/일반 채팅만 쓰는 경우는 해당 없음)
- **Codex**: Codex를 한 번이라도 사용한 적이 있어야 합니다.
- 데이터가 있는 도구만 표시됩니다. 하나만 써도 됩니다.

## 동작 방식과 개인정보
- **Codex**: `~/.codex/sessions`의 로컬 로그에서 사용률과 리셋 시각을 읽습니다. 네트워크 사용 없음.
- **Claude**: Claude Code가 키체인에 저장한 로그인 토큰을 읽어 Anthropic 사용량 API(`api.anthropic.com`)를 5분마다 조회합니다. 처음에 키체인 접근 팝업이 뜨면 **항상 허용**을 누르세요.
- 토큰은 `api.anthropic.com` 외 어디에도 전송·저장되지 않습니다. 코드는 `Sources/UsageBar.swift` 하나라 직접 확인할 수 있습니다.
- 진단 로그는 `~/Library/Logs/UsageBar.log`에 남으며 토큰은 기록하지 않습니다.

## 알려진 한계
- Claude 조회는 **비공식 API**를 사용합니다. Anthropic이 바꾸면 동작하지 않을 수 있습니다.
- Claude 로그인 토큰은 몇 시간 뒤 만료됩니다. 만료되면 위젯에 안내가 뜨고, Claude Code를 한 번 쓰면 자동으로 다시 표시됩니다.
- 구독 종류에 따라 5시간 한도가 없는 경우 주간 한도만 표시됩니다.
- Google Antigravity(agy)는 로컬에서 쿼터를 읽을 방법이 없어 지원하지 않습니다.

## 직접 빌드
```bash
./build.sh   # UsageBar.app, UsageBar.zip 생성
```

이 프로젝트는 Anthropic, OpenAI와 무관한 비공식 도구입니다.
