# Step 1 보고 — 2026-10-07

## 1. 이번 단계에서 한 것

- 48×96 도형 플레이어. idle/run/jump/fall/dash/attack/parry/hurt/potion/dead 상태.
- 가속·가변 높이 점프·코요테/버퍼·공중 대시 제한·대시 무적·완벽 회피 이벤트.
- JSON 콤보·선딜/활성/후딜·상하/공중 공격·포고·단검 dash_cancel 해석.
- 패리 성공/헛패리 후딜, 투사체 반사와 타깃 피해, 허수아비 스태거 누적. 보스 스태거 상태 머신은 Step 2 범위.
- 피격·넉백·피격 무적·포션 채널과 취소·사망 및 연습 재시작.
- 바닥·단방향 발판 2개·무한 HP 허수아비. 3초 간격으로 패리 가능한 근접/투사체 공격 교대.
- 히트스톱(실시간 타이머, 긴 요청 우선, 기존 느린 속도 복원), 감쇠 카메라 흔들림·숫자·섬광.
- F1 튜닝·저장·초기값 복원, F2 판정, F5 무적, F6 속도 순환. F3/F4는 아직 미구현.
- 키보드/패드 자동 전환 및 장치 고정 지원. Player는 PlayerInput을 통해서만 입력을 읽는다.

## 2. 수정·생성 파일과 이유

| 파일 | 변경 이유 |
|---|---|
| `project.godot` | Step 1 명칭, 안정된 user 디렉터리, LB의 실제 Godot 버튼 인덱스 9로 정정 |
| `autoload/Tuning.gd` | 실시간 수치·공장 기본값·원본 JSON/override 저장 및 override 시작 검증 |
| `autoload/Feedback.gd` | 중첩 히트스톱·속도 복원·카메라 흔들림·디버그 상태 |
| `autoload/DataRegistry.gd`, `scripts/data/DataSchema.gd` | 새 데이터 2개와 추가 필드 검증, F1의 0값 허용 |
| `data/tuning/player.json` | `hurt_recovery=0.20`, `air_dash_count=1` 추가 |
| `data/tuning/feedback.json` | `hitstop_time_scale=0.05` 추가 |
| `data/tuning_defaults.json` | F1 저장으로 바뀌지 않는 공장 기본값 |
| `data/training.json` | 플레이어 크기/색/배치, 바닥/발판, 허수아비/연습 공격, 텍스트 효과 수치 |
| `scripts/input/PlayerInput.gd` | physics tick별 입력 갱신, 장치 자동 전환, 패널 입력 차단 |
| `scripts/player/Player.gd`, `scenes/player/Player.tscn` | 플레이어 전체 동작 |
| `scripts/combat/Hitbox.gd`, `Hurtbox.gd`, `Projectile.gd`, 해당 `.tscn` | 팀/수신자별 판정·한 공격의 중복 피해 방지·반사 |
| `scripts/combat/FloatingText.gd` | 피해 숫자·완벽 회피·패리·회복 표시 |
| `scripts/arena/TrainingDummy.gd` | 가장 가까운 살아있는 players 대상 공격·피격 연습 |
| `scripts/arena/TrainingArena.gd`, `scenes/arena/Arena.tscn` | 고정 카메라·바닥/발판·연습 HUD·재시작 |
| `scripts/ui/DebugPanel.gd`, `scenes/ui/DebugPanel.tscn` | F1 슬라이더/스위치/저장 및 F2/F5/F6 입력 |
| `scripts/Boot.gd` | 검증 성공 시 연습 아레나로 진입, 오류 차단 유지 |
| `tests/PlayerSuite.gd/.tscn` | 키보드/패드 이벤트를 실제 physics 흐름에 주입하는 동작 검사 |
| `tests/PersistenceProbe.gd/.tscn` | 별도 프로세스 저장/재로딩 검증 |
| `tests/RegistrySuite.gd`, `make_fixtures.py` | 표준 패드 enum 대조 및 0값 튜닝 계약 반영 |
| `README.md`, `AGENTS.md`, `docs/DATA_CONTRACT.md`, 본 보고, `WORK_LOG.md`, `docs/evidence/step1_*` | 실행법·인계·계약·검증 근거 |

Step 0의 골렘/날개/무기/장비/재료 JSON은 변경하지 않았다. 실제 보스 실행·성장 루프·Telemetry는 시작하지 않았다.

## 3. 완료 조건별 확인

| 완료 조건 | 확인 방법 / 결과 |
|---|---|
| 키보드로 모든 플레이어 동작 | 실제 InputEventKey→PlayerInput→physics→충돌/결과 경로. 이동, 점프 높이, 발판, 코요테, 버퍼, 대시 거리·공중 제한, 콤보, 상하 공격·포고, 패리·반사, 피해/무적, 포션·취소, 사망 검사 통과. |
| 패드로 모든 동작 | 실제 InputEventJoypadButton 주입으로 이동·점프·대시·공격·상하 공격·패리·포션 통과. 다른 device 입력의 분리 검사 통과. 연결 장치 `[]`로 **실물 패드 조작은 미검증**. |
| F1 변경 즉시 반영 | 실제 HSlider.value 변경 시그널로 move_speed=780 반영 검사. F1 열기/닫기의 정지/재개, F2/F5/F6 실제 키 이벤트 검사 통과. |
| 저장 후 재실행 유지 | 별도 프로젝트 복사본에서 실제 source JSON 저장 후 프로세스 종료→새 프로세스에서 move_speed=780, shake_on_hit=11 확인. override 경로도 별도 프로세스에서 유지 확인. 사용자 정본 수치는 520/6 유지. |
| 기본값으로 복원 | 공장 기본값 파일 기준 move_speed=520 복원 확인. 저장된 수치를 기본값으로 오인하지 않는다. |
| parry_enabled=false | 키 입력 무시, 안내·카운터·패리 관련 수치와 연출 조절 숨김 확인. 다시 켜는 스위치는 유지. 실제 OFF 화면 픽셀 확인. |
| 피드백 | 패리 성공 피해0·스태거 증가·반사 적중 검사, 중첩 히트스톱 후 F6 속도0.5 복원 검사. GPU 패리/포고 프레임·F1 화면을 캡처하여 가독성과 배치 확인. |

검증 합계: **플레이어 56 checks / 데이터·입력 152 checks, 실패 0**. 저장 프로브 3개 모두 true. 데이터 구문 오류 fixture 1개의 예상 parse error 외 정상 런타임 스크립트 오류 없음.

픽셀 증거: `step1_arena.png`, `step1_debug.png`, `step1_parry.png`, `step1_pogo.png`, `step1_parry_off.png`.
프로그램 검증 통과가 재미나 조작감 튜닝 완료를 의미하지 않는다. 사용자 직접 플레이와 실물 패드 검증이 남아 있다.

## 4. 데이터 외 코드 수치

- **플레이어·무기·허수아비의 콘텐츠/조작 수치는 JSON에 있다.** 현재 player27필드, feedback10필드이며 기존 초기값은 보존했다.
- 상태/인덱스/입력 세기 0·1·−1, 무한 시간 표식 INF, 좌표 중심 계산의 1/2, 초→밀리초 1000, hitbox별 1회 수신 처리는 알고리즘 계약이다.
- 0초 대시는 0 나눗셈을 피하기 위해 **1 physics tick**에 거리를 처리한다. 정확한 lunge/dash 거리는 마지막 tick의 남은 시간을 적분한다.
- 입력 처리 우선순위 −100, 디바이스 −1/0 이상, 초기 속도1 및 속도 목록의 초기 인덱스2는 입력/디버그 상태다. 실제 속도 목록은 training.json의 [0.25,0.5,1].
- 연습 화면 크기1920×1080·카메라(960,540)·바닥/벽의 화면 밖 두께100은 고정 화면 구성이다. 바닥 높이·좌우 제한·발판 위치/두께는 training.json.
- 도형/UI 표시 수치: 플레이어 방향 삼각형(12/14/9), 패리 원 외곽8·32분할·굵기4, 판정선2~4, 허수아비 경고 여백10/20·선 위치24·굵기5/6, 색상(흰/회색/청록/청색/빨강/초록/금색), 공격/피격 상태의 alpha0.3/0.5/0.6/0.65 등은 코드에 남아 있다. 외형/판정 시인성 표시이며 실제 판정 크기를 바꾸지 않는다.
- 텍스트/패널 레이아웃: 떠오르는 숫자 위치(−70,−45)·폰트29; HUD(44,28)·간격12·폰트24/36; 재시작 버튼(650,490)/(620,90)·폰트32; F1 패널(720,30)/(1160,1020)·layer10·여백20·폰트23·간격12·버튼(180,50)·행높이46·열너비275/550/115·실수 slider step0.001·정수 step1·범위배율3. 캡처 대기0.5초는 테스트 전용.
- 이러한 고정 UI/수학/장치 상수를 F1에 콘텐츠 수치로 노출하지 않는다. 필요하면 후속 UI 편집으로 조정할 수 있다.

## 5. 다음 단계 전에 사람이 결정할 것

연습 창에서 이동·점프·대시·공격·패리의 체감을 확인하고 F1에서 조정한 뒤 저장한다. 특히 패리 켬/끔, 대시 거리/쿨다운, 점프 높이와 공격 후딜의 체감을 확인한다. 공격 후딜은 weapons.json 데이터이며 이번 F1의 범위는 player/feedback 수치다.

**여기서 반드시 멈춘다.** 사람의 조작감 튜닝과 다음 지시 후 Step 2로 진행한다. 보스 구현이나 성장 루프를 미리 진행하지 않았다.
