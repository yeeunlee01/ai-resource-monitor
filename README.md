# AI Monitor

Mac에서 AI 도구가 사용하는 CPU와 메모리를 한눈에 확인하는 작은 메뉴 막대 앱입니다.

<img src="docs/cpu-preview.png" width="360" alt="CPU 탭 예시" /> <img src="docs/memory-preview.png" width="360" alt="메모리 탭 예시" />

미리보기 이미지는 예시 데이터이며 실제 사용량이 아닙니다.

- CPU / 메모리 탭
- Codex · Cursor · Claude · 그 외 카테고리별 합산
- 카테고리를 클릭하면 프로세스 이름, PID, 개별 사용량 표시
- 2초 간격 갱신과 최근 1분 CPU 그래프
- 앱을 열면 첫 창 표시, 창을 닫아도 메뉴 막대에서 계속 확인
- 네트워크 요청이나 사용량 저장 없음

## 다운로드 및 설치

**[AI Monitor v0.1.0 다운로드 · Apple Silicon Mac](https://github.com/yeeunlee01/ai-resource-monitor/releases/download/v0.1.0/AI-Monitor-0.1.0-macos-arm64.zip)**

- **지원 환경:** Apple Silicon(M 시리즈) Mac, macOS Sonoma 14 이상
- 다운로드한 앱을 실행할 때는 Xcode나 Swift를 별도로 설치할 필요가 없습니다.
- 현재 배포 파일은 Apple Silicon 전용입니다. Intel Mac용 실행 파일은 제공하지 않습니다.
- v0.1.0은 미리보기 버전으로, Developer ID 서명과 Apple 공증을 받지 않은 로컬 서명 앱입니다. 처음 실행할 때 macOS가 차단할 수 있습니다.

1. 위 다운로드 링크에서 `AI-Monitor-0.1.0-macos-arm64.zip`을 받습니다. [릴리스 페이지](https://github.com/yeeunlee01/ai-resource-monitor/releases/tag/v0.1.0)의 **Assets**에서도 같은 파일을 받을 수 있습니다. `Source code` 파일은 실행 앱이 아닌 소스 코드입니다.
2. 다운로드한 ZIP 파일을 더블 클릭해 압축을 풉니다.
3. `AI Monitor.app`을 Finder의 **응용 프로그램** 폴더로 옮깁니다.
4. 응용 프로그램 폴더에서 **AI Monitor**를 더블 클릭합니다.

### 처음 실행할 때 차단되는 경우

개발자를 확인할 수 없거나 Apple이 악성 소프트웨어 여부를 확인할 수 없다는 메시지가 나올 수 있습니다. 이 저장소의 릴리스에서 받은 파일이며 출처를 신뢰하는 경우에만 다음 절차로 해당 앱의 실행을 허용하세요.

1. 앱을 한 번 실행해 차단 메시지를 확인한 뒤 닫습니다.
2. **시스템 설정 → 개인정보 보호 및 보안**을 엽니다.
3. 아래쪽 **보안** 영역에서 AI Monitor에 대한 **그래도 열기**를 누릅니다.
4. macOS가 요청하면 인증하고, 확인 창에서 **열기**를 누릅니다.

macOS 버전에 따라 버튼 이름과 위치가 다를 수 있습니다. [Apple의 앱 실행 안내](https://support.apple.com/ko-kr/102445)를 참고하세요. 회사에서 관리하는 Mac은 관리자 정책으로 실행이 제한될 수 있습니다. 악성 소프트웨어로 판정되었다는 경고는 이 절차로 우회하지 마세요.

## 사용 방법

1. 앱을 실행하면 사용량 창이 열립니다. 최초 CPU 수치는 다음 측정까지 약 2초 동안 `—`로 표시될 수 있습니다.
2. **CPU** 탭에서는 전체 CPU 사용률과 Codex·Cursor·Claude·그 외의 사용률을 확인합니다. Mac 전체 성능을 100%로 계산합니다.
3. **메모리** 탭에서는 전체 메모리 사용량 추정치, 스왑 사용량과 카테고리별 메모리 점유량을 확인합니다.
4. 카테고리를 클릭하면 소속 프로세스 이름, PID와 개별 사용량이 펼쳐집니다. 다시 클릭하면 접힙니다.
5. 창을 닫아도 앱은 계속 실행됩니다. 화면 위쪽 **메뉴 막대의 파형 아이콘**을 클릭하면 다시 확인할 수 있습니다. Dock에 아이콘이 표시되지 않는 것이 정상입니다.
6. 앱을 완전히 끝내려면 화면 아래 **종료**를 누릅니다.

사용량은 **2초마다 자동 갱신**됩니다. 계정이나 API 키는 필요하지 않습니다. 재부팅 후 자동으로 실행하는 기능은 아직 없으므로 앱을 다시 열어주세요.

카테고리에는 해당 앱과 하위 프로세스가 함께 묶입니다. 읽기 권한이 없는 프로세스는 합계에서 제외하고 화면에 안내합니다. 메모리는 압축·스왑·공유 등의 영향으로 카테고리 합계가 전체 RAM 사용량과 다를 수 있습니다. 자세한 기준은 아래 **수치 읽는 법**을 참고하세요.

### 업데이트 및 삭제

- **업데이트:** 앱의 **종료**를 누른 뒤 [릴리스 목록](https://github.com/yeeunlee01/ai-resource-monitor/releases)에서 새 버전을 받아 응용 프로그램 폴더의 기존 앱을 교체합니다. 자동 업데이트는 지원하지 않습니다.
- **삭제:** 앱을 종료하고 응용 프로그램 폴더의 `AI Monitor.app`을 휴지통으로 옮깁니다.

## 개발자용: 소스에서 빌드

직접 빌드하려면 macOS 14 이상, Git, Swift 6 이상을 포함한 Xcode 또는 Command Line Tools가 필요합니다. 외부 패키지는 사용하지 않습니다.

```sh
git clone https://github.com/yeeunlee01/ai-resource-monitor.git
cd ai-resource-monitor
bash scripts/build-app.sh
open "dist/AI Monitor.app"
```

`dist/AI Monitor.app`이 생성됩니다. 현재 Mac의 아키텍처용으로 빌드하며 로컬 개발용 서명을 사용합니다. Gatekeeper 경고 없이 일반 사용자에게 배포하려면 Developer ID 서명과 Apple 공증이 별도로 필요합니다. Intel Mac에서의 소스 빌드는 아직 검증하지 않았습니다.

테스트 실행:

```sh
bash scripts/test.sh
```

## 수치 읽는 법

**CPU:** Mach 시간 카운터를 나노초로 변환한 뒤, 두 측정 사이 프로세스 CPU 시간 차이를 경과 시간과 논리 코어 수로 나눕니다. Mac 전체를 100%로 표시합니다. 활성 상태 보기의 프로세스별 CPU는 코어 하나를 100%로 표시하므로 숫자가 다릅니다. 첫 측정이나 새 프로세스는 다음 측정까지 `—`로 표시합니다.

**메모리:** 프로세스의 `ri_phys_footprint`를 합산합니다. 전체 사용량은 macOS VM 통계로 계산한 추정치이며 활성 상태 보기와 정확히 일치하지 않을 수 있습니다. 공유·압축·스왑 메모리와 읽기 권한 차이 때문에 카테고리 합계는 시스템 전체 수치와 일치하지 않으며 장착 RAM보다 클 수도 있습니다. 막대는 장착 RAM 대비 비율이며 100%에서 표시를 제한합니다. macOS의 메모리 표기 관례에 따라 1 GB = 1,024³ 바이트로 표시합니다.

**분류:** 실행 파일 이름과 정확한 `.app` 경로로 AI 도구를 찾고, 인식되지 않은 자식 프로세스는 가장 가까운 AI 도구 부모를 따릅니다. 다른 AI 도구로 직접 인식된 자식은 자기 카테고리에 들어갑니다. 그 외에는 다른 앱, 시스템 프로세스와 AI Monitor 자체가 포함됩니다. 부모가 종료되어 연결이 끊어진 프로세스, 별도로 실행한 공용 서버, 브라우저 안의 AI 서비스는 정확히 연결하지 못할 수 있습니다.

**읽기 제한:** 권한이 없거나 측정 중 종료된 프로세스는 읽기 불가로 표시하고 합계에서 제외합니다. 전체 CPU는 시스템 통계에서 별도로 읽습니다. 관리자 권한을 요구하거나 보안 설정을 변경하지 않습니다.

## 구조

- `SystemProbe`: macOS libproc / Mach 통계 수집
- `ResourceCore`: 프로세스 분류와 사용량 계산
- `AIResourceMonitor`: SwiftUI 화면과 메뉴 막대
- `ResourceCoreTests`: 분류, 합산, PID 재사용, 읽기 실패, 실제 시스템 측정, POSIX 시계와 CPU 시간 단위 교차 검증

## 참고

- [Apple MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)
- [Apple resource.h](https://github.com/apple/darwin-xnu/blob/main/bsd/sys/resource.h)

현재는 로컬 개발용 첫 버전입니다. libproc 인터페이스는 macOS 버전에 따라 바뀔 수 있습니다.
