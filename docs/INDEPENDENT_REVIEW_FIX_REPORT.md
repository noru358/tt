# 2026-10-08 독립 검수 반영

기준: Gate1_Claude_Fixes_2026-10-07.zip. 검수 문서의 H1–H4, M1–M6, L1–L6을 Step 3 범위에서 수정했다. 문서의 제안은 코드와 대조했고, 특수 공격 후 콤보 초기화와 패리 성공 때만 예약 반격하는 정책은 사용자가 직접 선택했다.

## 동작 변경

| 항목 | 반영 내용 |
|---|---|
| H1 | 공격 중 새 탭은 현재 동작의 연계 시점까지 1슬롯에 보존한다. 소비 후 반복하지 않으며 취소·피격·메뉴·포커스·장치 경계에서 지운다. 공격 밖의 예약은 기존 게임 시간 수명을 사용한다. |
| H2 | 선딜의 현재 세로 입력이 0이면 기존 위/아래 방향을 유지한다. 좌우 조준 변경은 별도로 허용한다. |
| H3 | 중립 스냅샷은 소비 tick의 방향을 다시 읽는다. 끝까지 중립이면 바라보는 방향으로 시작하고 0.05초 안의 첫 방향 입력을 수용한 후 고정한다. 패널에서 유예를 조절할 수 있다. |
| H4 | 공격 중 대시는 기존 공격과 판정을 취소한다. 누르고 있던 공격도 새 의도 없이 재시작하지 않는다. 대시 중 새로 시작한 공격만 별도 옵션에 따라 대시 종료 후 이어간다. |
| M1 | 착지 버퍼/코요테 점프 실행 시 점프 버튼이 이미 떼어졌으면 즉시 숏홉 배율을 적용한다. |
| M2 | 지상 점프+대시 동시 입력은 대시를 시작한 다음 tick에 남은 점프 버퍼로 대시를 취소하고 점프한다. 공중 추가 점프는 주지 않는다. |
| M3 | 결과 화면은 0.5초 이상 잠그고, 게임 입력과 확인/재시도 버튼이 모두 해제된 뒤 활성화한다. 버튼, 마우스 클릭, 키보드/패드 확인, 아레나 재시도 단축키를 함께 차단한다. |
| M4 | 숫자의 int/float 표현 차이를 무시하는 재귀 비교로 실제 변경 여부를 산출한다. 정상 저장의 반복 로드는 이전 백업을 만들지 않는다. 추가 이전 백업은 Unix 마이크로초와 충돌 회피 접미사를 쓴다. |
| M5 | 전투 시작 시 player/weapons를 운영 data와 비교한다. 전투 밖에서 적용한 변경도 디버그 런으로 표시하고 최고 기록에서 제외한다. |
| M6 | 허수아비는 Tuning 값으로 끄고, 테스트는 물리 tick 완료 신호를 센다. 일시정지 중에도 테스트 관찰자는 진행한다. 실행기는 fresh 저장/튜닝/fixture 경로를 만들고 --fixed-fps 60으로 순차 실행한다. BalanceProbe는 인자 없이도 검사한다. |
| L1 | 효과가 없던 input_edge_lifetime 슬라이더와 스키마를 제거했다. 받은 edge는 다음 물리 tick에 한 번 소비한다. 구 override에서는 해당 필드를 제거해 호환한다. |
| L2 | 특수 공격이 일반 콤보 순서와 표시를 지운다. 다음 일반 공격은 1타다. |
| L3 | 패리와 공격 동시 입력은 1회 반격을 예약한다. 성공 시 즉시 소비하고, 실패 시 삭제하며 held 공격도 자동 발동하지 않는다. |
| L4 | 포커스 복귀와 장치 변경 시 이미 눌린 상태를 초기화해 가짜 just_pressed가 생기지 않게 했다. 전환을 일으킨 실제 새 이벤트는 처리한다. |
| L5 | 보스가 공중에서 무력화되어도 중력과 바닥 위치 처리는 계속한다. |
| L6 | 본 저장이 없으면 유효한 .tmp, 다음 .bak 순으로 복원한다. 후보가 있으나 모두 손상되었거나 복원에 실패하면 새 저장을 쓰지 않고 차단한다. 같은 상태를 저장할 때는 기존 .bak를 회전시키지 않는다. |

## 입력 우선순위

| 입력 | 결과 |
|---|---|
| 공격 도중 새 공격 탭 | 현재 공격 뒤 1회 연계 |
| 공격 도중 대시 | 공격 취소 후 대시 이탈 |
| 대시 도중 새 공격 | 대시 방향과 독립적인 공격 |
| 지상에서 점프+대시 | 대시 시작 → 다음 tick 점프로 취소 |
| 패리+공격 | 패리 우선, 성공 때만 예약 반격 |
| 패리+공격+점프 | 패리 우선, 성공 때만 예약 반격; 점프가 패리를 취소하지 않음 |
| 결과 직후 확인/점프/재시도 | 잠금 시간과 모든 버튼 해제 후 새 입력 필요 |

## 설정 및 호환

- `player.dash_direction_grace`: 기본 0.05초, 음수 금지, 대시 패널에 노출.
- `player.dash_attack_continues_after_dash`: 기본 true. 기존 `dash_keeps_attack`의 값을 override 로드 시 이전한다. 공격 중 대시 취소에는 관여하지 않는다.
- `battle.result_input_delay`: 기본 0.5초, 음수 금지.
- `input_edge_lifetime` 제거. 기존 override는 읽을 때 제거한다.
- 운영 JSON, 공장 기본값, 검증 스키마를 함께 갱신했다.

## 검증

Godot 4.6 stable 공식 macOS 실행 파일로 실행. 운영 저장은 사용하지 않았다.

| 스위트 | 검사 수 |
|---|---:|
| PlayerSuite | 56 |
| ControlsRevisionSuite | 52 |
| CombatFeelSuite | 31 |
| DefenseInputSuite | 23 |
| InputComboSuite | 49 |
| ReviewFixSuite | 43 |
| ReviewBalanceProbe | 4 |
| RegistrySuite | 212 |
| GrowthSuite | 48 |
| BossSuite | 41 |
| BattleFlowSuite | 17 |
| IndependentReviewSuite | 62 |
| 합계 | 638 |

전체 PASS, 실패 0. RegistrySuite는 외부 scratch의 58개 fixture를 사용한다. 신규 62개 검사는 세 무기 네 타수의 연계 예약, 짧은 방향 탭, 대시 방향 유예/고정, 이탈, 착지 숏홉, 점프+대시, 콤보 초기화, 성공/실패 반격, 포커스/장치 경계, 구 옵션 이전, 저장 복구, 결과 화면 잠금을 포함한다.

BalanceProbe의 180 tick 고정 표적 측정: 검 유지/연타 120/120, 대검 132/132, 단검 126/126. 세 무기 차이 0%. 대시 연타 무적 비율 50%. 히트스톱을 끈 테스트 수치로 실제 전투 DPS/체감을 뜻하지 않는다.

추가 검증: 새 프로세스에서 성장 저장 복원 및 튜닝 쓰기→읽기 3개 프로브 성공. 신규 스위트의 실제 렌더링 실행도 62개 PASS. 결과 화면 PNG를 열어 한글·버튼·레이아웃을 확인했다. `docs/evidence/independent_review/`에 로그와 화면을 포함했다.

재실행:

```sh
python3 tests/run_suites.py --godot /path/to/Godot --output /scratch/gate1-review
```

동일 output 경로를 재사용해도 각 suite의 저장/튜닝 경로는 새 임시 폴더다. Windows에서는 Python과 Godot 실행 파일 경로를 지정하면 된다.

## 변경 파일과 검증 한계

- `scripts/player/Player.gd`, `scripts/input/PlayerInput.gd`: 입력·예약·취소·콤보·반격.
- `autoload/GameState.gd`, `autoload/Tuning.gd`: 실제 변경 판단, 복구, 옵션 이전, 시작 전 튜닝 감지.
- `scripts/arena/BattleArena.gd`, `scripts/ui/ResultScreen.gd`: 결과 잠금과 디버그 런.
- `scripts/boss/Boss.gd`: 무력화 중 중력.
- `scripts/ui/DebugPanel.gd`, `scripts/data/DataSchema.gd`, `data/battle.json`, `data/tuning/player.json`, `data/tuning_defaults.json`: 새 설정과 검증.
- 기존 회귀 스위트·fixture 생성기·PersistenceProbe: 새 계약에 맞춘 기대값, tick 관찰, 허수아비 격리.
- 신규 `tests/IndependentReviewSuite.gd/.tscn`, `tests/run_suites.py`: 재현 회귀와 재현 가능한 순차 실행.

실물 키보드 롤오버·패드 조작·사람 손맛·Windows 파일 시스템에서의 실제 강제 종료는 미검증이다. 저장 복구는 macOS에서 본 파일 삭제와 tmp/bak 조합으로 검증했다. Step 4/5 추가 콘텐츠는 구현하지 않았다. 과거 evidence와 문서는 당시 기록이며 이번 결과는 이 보고서가 기준이다.
