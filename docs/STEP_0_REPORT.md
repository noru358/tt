# Step 0 보고 — 2026-10-07

## 1. 이번 단계에서 한 것

- 독립 Godot 4.6 프로젝트, 1920×1080 논리 해상도, canvas_items / keep 설정.
- 오토로드 5개 등록, 키보드·패드 입력 맵, device ID 기반 PlayerInput 읽기 경계.
- 7개 JSON 작성: 조작감 25필드, 피드백 9필드, 무기 3, 제작 장비 5, 재료 4, 보스 2(각 6패턴, phase 2/3개).
- 전체 JSON 탐색·타입·필수 필드·수치 범위·중첩 스텝·교차 참조 검증. 오류가 있으면 전체 빨간 화면으로 시작 차단.
- 정상 화면, 오류 화면, 재현 가능한 오류 주입 테스트 및 실행기.
- Step 1은 시작하지 않았다.

## 2. 생성·수정 파일과 이유

새 프로젝트이므로 아래는 모두 신규 생성 파일이다. 생성 중 발견한 결함은 해당 부분만 수정했다.

| 파일 | 이유 |
|---|---|
| `project.godot` | 엔진·화면·메인 씬·오토로드·입력 맵 |
| `data/tuning/player.json`, `feedback.json` | 원문 조작감·연출 수치 |
| `data/weapons.json` | 기본 검·대검·쌍단검의 공격 데이터 |
| `data/equipment.json`, `materials.json` | 장비 5개·레시피·효과 및 재료 4개 |
| `data/bosses/golem.json`, `wing.json` | 모든 phase·패턴·드롭·해금 |
| `autoload/DataRegistry.gd` | fail-closed 로딩·검증·조회 API |
| `scripts/data/DataSchema.gd` | 파일·스텝·효과의 타입 계약 |
| `autoload/Tuning.gd` | 검증된 조작감 데이터의 런타임 복사 |
| `autoload/GameState.gd`, `Telemetry.gd`, `Feedback.gd` | 오토로드 등록용 골격, 기능 미구현 |
| `scripts/input/PlayerInput.gd` | device별 입력 경계; Player 직접 Input 호출 방지 준비 |
| `scripts/boss/PatternRunner.gd`, `scripts/stats/StatCalc.gd` | 후속 단계의 공유 구현 위치만 선언 |
| `scenes/Boot.tscn`, `scripts/Boot.gd` | 데이터 OK 화면과 시작 분기 |
| `scenes/ui/DataErrorScreen.tscn`, `scripts/DataErrorScreen.gd` | 빨간 오류 목록과 진행 차단 |
| `scenes/hub/Hub.tscn`, `arena/Arena.tscn`, `player/Player.tscn`, `boss/Boss.tscn` | 빈 씬 골격 |
| `scenes/combat/Hitbox.tscn`, `Hurtbox.tscn`, `Projectile.tscn`, `Telegraph.tscn` | 빈 전투 씬 골격 |
| `scenes/ui/DebugPanel.tscn`, `ResultScreen.tscn` | 빈 UI 씬 골격 |
| `tests/RegistrySuite.gd`, `RegistrySuite.tscn`, `make_fixtures.py` | 실제 Godot 로더에 정상/오류 fixture를 넣는 검증 |
| `Run.cmd`, `README.md`, `AGENTS.md`, `.gitignore` | 로컬 실행·사용법·인계·캐시 제외 |
| `docs/GATE1_SPEC.md`, `DATA_CONTRACT.md`, `STEP_0_REPORT.md`, `WORK_LOG.md` | 원문 보존·표현 보충·보고·누적 기록 |
| `docs/evidence/*.png`, `*.log` | 실제 엔진 화면 및 검증 근거 |
| 각 `.gd.uid` | Godot이 생성한 스크립트 식별 메타데이터 |

`work/`의 생성 스크립트·엔진·fixture는 중간 작업물이다. 이후 소스의 정본은 `outputs/Gate1`이며 초기 생성 스크립트로 덮어쓰지 않는다.

## 3. 완료 조건별 확인

| 조건 | 방법 / 결과 |
|---|---|
| 실행하면 데이터 OK | Godot 4.6 stable 공식 빌드의 GPU 실행, 정상 화면 픽셀 확인. PASS. |
| 각 파일 항목 수 표시 | 7개 파일의 필드·항목·보스 패턴/phase 수 표시, `data_ok.png` 확인. PASS. |
| 레시피 ID 오류의 정확한 위치 | scratch 복사본에서 `golem_shard`→`golem_shrad`로 변경하여 실제 Boot 실행. 빨간 화면에 `equipment.json:$[0].recipe.golem_shrad:존재하지 않는 materials id: golem_shrad`. PASS. 정본 데이터는 정상 유지. |
| 전체 검증과 차단 | 정상 포함 fixture 38종, 조회 API·입력 맵·설정 포함 **146 checks / 0 failures**. 오류 시 장비 조회 목록도 차단. PASS. |
| 복수 오류 | 같은 파일의 타입 오류+잘못된 참조, 여러 파일 오류를 함께 보고. PASS. |
| 입력 맵 | Godot Key/Joypad 객체와 enum을 대조하여 키보드+패드 등록 확인. PASS. 실제 패드 실기 조작은 미검증. |
| 조작감·전투 재미 | 구현 전. 검증하지 않았음. |

정상 import/run에서 스크립트 파싱 오류 없음. malformed JSON fixture의 `JSON.parse_string` parse error 로그는 의도된 오류 주입 결과다.

## 4. 코드에 남은 수치

**현재 구현한 런타임 콘텐츠/전투 수치 하드코딩은 없다.** 아래는 콘텐츠가 아닌 설정·표시·검증·입력 계약 수치다.

- `project.godot`: 논리 1920×1080, 표시 창 1280×720, 입력 deadzone 0.2, 키/버튼/축 enum, 기본 배경 RGBA(0.035,0.045,0.065,1).
- `PlayerInput`: keyboard ID -1, pad ID 0 이상, process priority -100, 입력 세기 0~1, 좌우·상하 축 방향 ±1. 성능/플레이 수치가 아니라 장치 식별과 입력 정규화 값이다.
- `DataSchema/DataRegistry`: 수치 유효 범위의 0/1, 정수 검사, 배열 최소 길이 0/1, vector/size 길이 2·색 길이 4, modifier mul 하한 -1, phase 시작 상한 1·마지막 하한 0, enum 타입/타깃/효과/flag 문자열. 스키마 계약이다.
- `Boot`: UI 여백 80, 간격 26, 2열·열간격 120·행간격 17, 글자 58/30/27/25, 제목 RGBA(0.36,0.94,0.70,1), 설명 RGBA(0.65,0.72,0.82,1). 검증 화면 전용이다.
- `DataErrorScreen`: 여백 64, 간격 24, 글자 42/25/26, 배경 RGBA(0.23,0.015,0.025,1), 제목(1,0.38,0.38,1), 본문(1,0.72,0.72,1). 오류 표시 전용이다.
- 캡처 도구는 렌더 완료 2프레임 후 저장, 종료 코드 0/1. 테스트의 HP 900·콤보 3·피해 10 등의 숫자는 JSON 계약 검증용 기대값이며 게임에서 읽지 않는다.
- 보스 세부 초기값·낙하 속도·반사 피해·스태거 증가량·무기 공격 수치는 모두 JSON에 있다. 미구현 단계의 값이 전부 구현됐다는 의미는 아니다.

## 5. 다음 단계 전에 사람이 결정할 것

필수 설계 결정은 없다. 다음 지시가 오면 Step 1로 진행한다. 입력 배치와 `DATA_CONTRACT.md`의 표현 보충은 다음 단계에서 변경 가능하다. Step 1 완료 시에는 반드시 멈추고 사람이 실제 조작감을 튜닝한다.
