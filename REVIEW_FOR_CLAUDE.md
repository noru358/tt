# 최신: 전신 판정·이동·폐사원 배경

[2026-10-08 추가 변경·검증](docs/GOLEM_MOBILITY_WETLAND.md): 전신 12부위 피격, 몸박8, 추적 걷기, 동남아 습지 폐사원 배경, 작은 HUD와 활 입력 개선. 아래 과거 제자리 골렘 설명보다 우선합니다.

# 최신 검수 대상 — 2026-10-08

최신 추가 계약은 [골렘 이식 보고서](docs/GOLEM_PORT_REPORT.md), [자동조준 마법 활](docs/MAGIC_BOW.md), [독립 검수 수정](docs/INDEPENDENT_REVIEW_FIX_REPORT.md) 순으로 확인하세요. [워크스페이스 설정](docs/WORKSPACE.md)으로 clone 후 재현할 수 있습니다. 아래는 과거 Step 3 검수 안내이며 최신 상태를 대체하지 않습니다.

# Claude 검수 시작 안내

현재 버전: Godot 4.6 stable / GDScript, Step 3 및 F1~F11 검수 수정·추가 손맛 수치 반영본. 프로젝트를 독립적으로 검수해 주세요. 이 ZIP은 소스 검수용이며 Godot 실행기와 개인 진행 저장 파일은 포함하지 않습니다.

## 먼저 읽을 파일

1. README.md — 현재 실행/조작/모드 흐름.
2. docs/STEP3_REVIEW_FIX_REPORT.md — 최신 계약·수정 전후 프로브·검증 범위. docs/INPUT_COMBO_REVISION.md는 이전 작업.
3. docs/STEP_3_REPORT.md — 성장/제작/장착/저장.
4. docs/GATE1_SPEC.md 및 docs/DATA_CONTRACT.md — 원명세와 보충 계약.
5. docs/WORK_LOG.md — 누적 작업·재현·정정·미검증 기록.

AGENTS와 오래된 단계 문서에는 당시 상태가 남아 있습니다. 현재 기본 진입은 허브이며, Step 3까지 구현했습니다. 최신 계약은 STEP3_REVIEW_FIX_REPORT입니다. F2에 따라 해금된 날개의 기존 범용 전투 진입은 열었습니다. Step 4 전체/Step 5 배포·텔레메트리 구현과 인증은 진행하지 않았습니다.

## 사용자 요구

- F키 사용 불가. 화면 버튼/Tab/Esc/패드 Start로 조절.
- 조작감·모든 무기 공격 수치를 패널에서 조절/저장.
- 즉시 방향 반전·8방향 대시. 최신 요청은 공격 중 이동0.4배/히트스톱0.05초/지상 콤보 전진30px/대시300px이며 이전 전진0 기본값을 대체.
- 공격 중 패리/대시, 대시 중 방향을 유지한 상하 공격, 공격하다 빠르게 이탈.
- 빠른 연타/동시조작을 놓치지 않고 이전 입력이 오래 남지 않아야 함.
- 허브에서 연습(자유 무기/무보상)과 실제게임(장착/보상/진행 저장) 구분. 각 모드에서 허브 복귀.
- 세 무기 모두 시각적으로 구별되는 지상4타 콤보.

## 검수 요청

코드 수정 없이 우선 문제 목록을 작성해 주세요. 기존 PASS 기록만으로 정상이라고 결론짓지 말고, 수신→스냅샷→버퍼→상태 전환→판정→화면과 모드→결과→저장 흐름 전체를 살펴 주세요.

우선순위:

- PlayerInput의 빠른 press/release, 방향 스냅샷, Shift modifier, 같은tick 여러 행동, 장치전환·포커스·메뉴 경계.
- Player의 공격/대시/패리/점프 우선순위. 특히 같은tick 점프+대시, 공격+점프+방어, 패리 판정과 후딜 경계, 쿨다운/공중횟수 경계. 기존 검사가 다루지 않은 조합도 확인.
- 단일 .18초 공격 예약이 정확히 한 번 발동하고 게임 시간 만료/취소가 되는지. 유지·연타·방향 변경·특수공격을 섞어도 잔류하지 않는지.
- 4타 순서/리셋, 타격 판정과 궤적/타수 표시 일치, 무기 편집·장착/구override 이전.
- 연습/실제게임 진입과 재시작/승리/사망/일시정지 복귀에서 장비·보상·진행 모드가 섞이는지.
- 드롭·제작·장착·StatCalc·효과·자동저장의 중복/실패/손상 처리와 테스트 격리.

각 발견은 중요도, 파일/줄, 재현 입력 순서, 기대/실제 결과, 원인, 영향범위, 수정 방향으로 정리해 주세요. 확정 결함과 코드상 의심/실기 미검증을 구분해 주세요.

## 실행

Godot 4.6에서 project.godot를 열고 실행하면 허브입니다. Run.cmd는 제작 PC의 상대 경로에 있는 엔진을 사용하므로 다른 PC에서는 Godot에서 여세요.

압축 루트 기준 CLI 예시(실행기 이름/경로는 설치 위치에 맞게 변경):

```powershell
godot --headless --path Gate1 --editor --import --quit
New-Item -ItemType Directory -Force review-work | Out-Null
$reviewScratch = (Resolve-Path review-work).Path
$env:GATE1_TEST_SAVE = Join-Path $reviewScratch 'input-save.json'
$env:GATE1_TEST_TUNING = Join-Path $reviewScratch 'input-tuning.json'
godot --headless --path Gate1 res://tests/InputComboSuite.tscn
```

추가 회귀 ReviewFixSuite/ReviewBalanceProbe도 같은 격리 경로로 실행합니다.

다른 테스트는 두 격리 경로를 각각 새 파일명으로 바꾸고 씬을 지정합니다. PlayerSuite / ControlsRevisionSuite / CombatFeelSuite / DefenseInputSuite / InputComboSuite / GrowthSuite / BattleFlowSuite. BossSuite는 GATE1_TEST_REORDER에 scratch JSON 파일경로도 필요합니다. BattleFlowSuite는6패턴 자연선택까지 검사하므로 약2분 이상 걸릴 수 있습니다. `-- --retry-only`는 자연선택 부분을 생략하므로 전체검사와 구별하세요.

RegistrySuite는 다음과 같이 오류fixture를 생성합니다.

```powershell
python Gate1/tests/make_fixtures.py review-work/fixtures
$reviewManifest = Join-Path $reviewScratch 'fixtures/manifest.json'
godot --headless --path Gate1 res://tests/RegistrySuite.tscn -- "--manifest=$reviewManifest"
```

운영 data나 개인 user://save.json을 테스트 저장 대상으로 사용하지 마세요. 소스 저장과 override 저장은 서로 다른 검증 경로입니다. GPU 실행의 캡처 출력은 GATE1_TEST_CAPTURES에 scratch 폴더를 지정하면 됩니다.

## 기존 검증 증거와 한계

자동567검사와 ReviewFix43의 GPU검사, 새프로세스 성장복원, 튜닝저장4프로브를 보고했습니다. 최신 결과는 docs/evidence/review_*Suite.log, review_gpu.log, review_growth_persistence.log, review_tuning_persistence.log입니다. review_*.png는 실제 엔진 캡처입니다. 과거 로그/캡처도 함께 들어 있습니다.

입력 이벤트 주입과 GUI hit testing을 사용했으며 사용자 물리 키보드의 동시입력 제한, 실물 패드, 주관적 손맛은 검증하지 않았습니다. 성장 검사의 보스승리는 인위적 치명타를 사용한 기능검증입니다. 저장장치 실패 도중 앱을 닫으면 메모리에 보류한 보상 복구를 보장하지 않는 한계가 있습니다.
