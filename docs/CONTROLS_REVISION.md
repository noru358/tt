# Step 1 사용자 조작감 피드백 반영 — 2026-10-07

이 문서가 이전 Step 1 보고의 F키·수평 대시·공격 이동 제한·기본값 설명을 대체한다. Step 2에는 착수하지 않았다.

## 1. 실제 변경

- **모두 화면 조작**: 상시 버튼으로 패널, 판정, 무적, 허수아비 공격, 속도, 회복, 초기화. F1~F6 입력 맵·처리 제거. 패널 대체 키는 Tab/Esc/패드 Start.
- **7탭 패널**: 이동·점프, 대시, 공격 반응, 무기 상세, 방어·회복, 연출, 허수아비. 모든 player/feedback 필드, 세 무기의 모든 콤보·상하·공중 공격 필드, 허수아비 공격 간격/경고/피해/판정·투사체 크기·속도 등. 슬라이더 + 직접 숫자 입력.
- **8방향 대시**: 방향키/스틱 + 대시, 무입력은 facing. 대각선은 정규화하여 더 빨라지지 않는다. 종료 때 대시 속도를 일반 이동에 넘기지 않는다.
- **공격 자동 전진 0**: 모든 무기 콤보의 lunge 기본값을0으로 바꿈. 패널에서 원할 때 다시 조절할 수 있다.
- **즉시 반응 기본값**: 즉시 이동/정지/방향 전환, 반대 키를 함께 누르면 최근 방향 우선, 공격 중 이동, 점프·대시로 공격 취소. 공격 예약 기본0, 일반 타격 히트스톱 기본0. 모든 항목은 패널로 변경 가능.
- **입력 경계**: 물리 tick 사이에 누르고 뗀 짧은 입력을 보존하되 실제 시간 수명이 지난 것은 폐기. 메뉴/포커스/장치 전환 시 입력 이력을 비움. 메뉴에서 누른 공격을 닫은 뒤 실행하지 않는다.
- **전체 저장**: player/feedback + 세 무기 + 연습 무기 선택 + 허수아비 수치를 저장·복원. factory defaults는 별도 유지. 실험 중 편집은 Player가 Tuning의 현행 데이터를 읽는다.

## 2. 원인과 수정 범위

관찰된 구현상 원인은 지상 공격이 velocity.x를 lunge 값으로 강제해 이동을 잠그는 구조, 공격 입력을 bool로 무기한 저장하던 구조, 대시 종료 시 높은 velocity가 감속 이동으로 넘어가던 구조였다. 추가로 physics tick 사이의 짧은 탭은 polling만으로 놓칠 수 있었다.

이를 전체 입력→행동 선택→속도 결정→충돌→종료 전환 흐름에서 수정했다. 공격 끝나는 바로 그 tick의 새 입력은 받아들이되 과거 입력을 무기한 다시 실행하지 않는다. 공격 예약을 켜도 wall-clock 만료와 release 삭제 옵션을 적용한다. 일반 이동은 선택한 즉시 모드 또는 별도 가속/감속을 사용하고, 대시 종료는 항상 해당 이동 속도로 복귀한다. 렌더 움직임에는 Godot physics interpolation을 켰다.

주관적인 답답함이 전부 해결됐다고 확정하지 않는다. 위 코드상 지연·잔류 원인을 재현 검사로 제거했으며 최종 체감은 사용자 재플레이가 필요하다.

## 3. 파일과 이유

| 파일 | 이유 |
|---|---|
| `scripts/input/PlayerInput.gd` | 짧은 입력 edge 보존·실시간 만료·최근 방향·메뉴/포커스 이력 정리 |
| `scripts/player/Player.gd` | 8방향 대시·종료 관성 제거·이동/취소 정책·유한 공격 예약 |
| `scripts/ui/DebugPanel.gd` | 7탭·숫자 입력·무기별 전체 편집·화면 도구 버튼·F키 제거 |
| `scripts/arena/TrainingArena.gd` | 안내 변경·회복·패널 입력 차단·초기 패널 열기·physics camera |
| `scripts/arena/TrainingDummy.gd` | 변경된 공격 수치를 실시간 참조 |
| `autoload/Tuning.gd` | 무기/연습 데이터 편집·전체 저장·복원·override 참조 검증 |
| `autoload/Feedback.gd` | 화면 속도 조작도 debug 사용 표시 |
| `autoload/DataRegistry.gd`, `scripts/data/DataSchema.gd` | 새 조작 정책·기본값/연습 무기 교차 참조·중복 검사 |
| `data/tuning/player.json`, `feedback.json`, `data/weapons.json`, `training.json`, `tuning_defaults.json` | 새 조작 옵션·기본 전진0·일반 타격 멈춤0·전체 복원 값 |
| `project.godot` | F키 action 제거, Tab action, physics interpolation 활성 |
| `tests/ControlsRevisionSuite.gd/.tscn` | 새 사용자 피드백의 재현·회귀·GUI 마우스 경로 |
| `tests/PlayerSuite.gd`, `RegistrySuite.gd`, `make_fixtures.py`, `PersistenceProbe.gd` | 화면 버튼 계약·새 스키마·전체 저장 재실행 검사 |
| `README.md`, `AGENTS.md`, `docs/WORK_LOG.md`, 본 문서, `docs/evidence/controls_*` | 현행 조작법·인계·근거 |

데이터 외 수치는 입력의 ms 변환1000, 1 physics tick의 0초 대시 처리, 정규화/중심 좌표 계산, UI 레이아웃/색·슬라이더 범위 및 정밀도뿐이다. 새 전투/입력 조절값은 모두 JSON이다. 패널 UI는 (100,60), 1720×960, toolbar(44,365), 화면 덮개1920×1080, label폭440/입력폭190, 범위 기본3배(0인 lunge는 최대300, 그 외0 기본값은1), 양수 전용 최소0.001. 테스트의 대기/기대값은 런타임 콘텐츠가 아니다.

## 4. 검증

- **ControlsRevisionSuite 52/52**: 즉시 속도/정지/반전, 대시 잔류 없음, 8방향과 대각선 속도, 제자리 공격 이동0, 공격 중 이동/점프·대시 취소, 과거 콤보 입력 폐기, 짧은 탭 보존과 만료, 메뉴 입력 누수 차단, 모든 무기 필드 패널 존재, 실시간 편집·전체 저장·마우스 열기/닫기.
- **PlayerSuite 56/56**: 기존 키보드/패드 이벤트, 점프/코요테/버퍼/포고/패리/반사/피격/포션 등 회귀. F키 검사만 화면 버튼·Tab 검사로 현행화.
- **RegistrySuite 161/161**: 오류 주입41종 포함 기존 스키마·입력 및 새 기본값/선택 무기 참조·중복 검사.
- **새 프로세스 저장 검사4개 true**: 소스 저장·새 프로세스 복원·일반 override 복원·무기/허수아비/선택 무기 포함 override 복원. 복사본과 scratch 경로로 검증하여 사용자 정본 수치는 보존.
- 실제 GPU 5개 화면을 확인. 첫 캡처의 toolbar/상태 줄 겹침을 수정하고 재캡처 확인. 버튼을 실제 mouse event와 GUI hit testing으로 눌러 열기/닫기 검증.
- 정상 실행에서 script error 없음. malformed JSON fixture의 parse error는 예상 진단.
- 실물 패드 없음: 패드 이벤트 검증만 수행. 실제 체감·실기 검수는 사용자에게 남아 있다.

## 5. 다음 행동

패널을 연 상태로 실행해 전달한다. `닫고 연습`으로 플레이하고 원하는 값을 조절한 뒤 `전체 저장`을 누른다. 사용자 다음 지시 전 Step 2는 시작하지 않는다. 사용자 메시지의 비어 있는 6번은 작업 내용으로 추정하지 않았다.
