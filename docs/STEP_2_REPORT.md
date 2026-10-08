# Step 2 구현 및 공격 방향 연계 수정 — 2026-10-07

## 구현 결과

- 앞↔위↔공중 아래 공격의 공통 연계 경로. 공격을 유지하며 방향을 바꾸면 기존 타격의 active가 끝나는 시점에 후딜을 생략하고 새 방향 공격을 시작한다. 후딜 중 새 공격 입력도 즉시 받는다. 상하 동시 입력은 최근 방향 우선. 공격을 놓으면 자동 방향 연계는 남지 않는다. 임의의 오래된 탭을 재실행하지 않는 기존 정책은 유지한다.
- `attack_direction_chain=true`를 조작감 패널의 공격 반응 탭에 추가. 기존 user override에는 이 필드만 보충하여 저장한 다른 수치를 유지한다. 자동 전진0·즉시 이동·8방향 대시·F키 배제도 유지.
- 범용 Boss 씬과 PatternRunner, 12개 primitive 파일, 가중 선택·거리·쿨다운·직전 패턴 제외, 2페이즈 전환·포효, 패리/강공격 스태거·피해 배율·중단 정리.
- 골렘의 slam/charge/rock_drop/punch/roar/double_slam. 반복 사이 반대편 점프는 한 번만 실행. slam의 접근은 JSON `stop_distance=250`을 사용해 상대를 관통해서 공격 위치를 놓치는 것을 방지한다.
- 플레이어 HP·포션·대시 쿨다운, 보스 HP·페이즈 눈금·스태거, 0.8초 이름 소개, 사망·승리 결과·R/패드 A 즉시 재시작, 일시정지·연습 복귀.
- 화면 버튼으로 판정·무적·0.25/0.5/1배속, 기존 전체 튜닝. **F키 없음**.

## 파일과 이유

| 파일 | 변경 이유 |
|---|---|
| scripts/player/Player.gd | 공격 종류에 관계없는 후딜 연계, 유지 중 최신 방향 반영 |
| scripts/ui/DebugPanel.gd, autoload/Tuning.gd | 새 정책 패널 표시·기존 override 필드 보충 |
| data/tuning/player.json, data/tuning_defaults.json | 방향 연계 기본값 |
| scripts/boss/Boss.gd, scenes/boss/Boss.tscn | 데이터 기반 상태·선택·페이즈·스태거·공격 생성 |
| scripts/boss/PatternRunner.gd | JSON 순서 실행·반복 펼치기·중단 수명 관리 |
| scripts/boss/steps/Step.gd | 공통 단계 생명주기 |
| scripts/boss/steps/{wait,face_target,telegraph,move_to,dash,jump,hitbox,shockwave,projectile,falling,set_vulnerable,repeat}.gd | 각각의 명세 primitive |
| scripts/combat/Telegraph.gd, scenes/combat/Telegraph.tscn | 피해 없는 경고 도형 |
| scripts/combat/Projectile.gd | 중력·반사 피해/스태거·아레나 경계 만료 |
| scripts/arena/BattleArena.gd, scenes/arena/BattleArena.tscn | 골렘 전투·HUD·소개·일시정지·결과 흐름 |
| scripts/ui/ResultScreen.gd, scenes/ui/ResultScreen.tscn | 재시작·연습 복귀 버튼 |
| scripts/arena/TrainingArena.gd, scripts/Boot.gd | 연습↔전투 진입·기본 실행 변경 |
| data/battle.json, data/bosses/golem.json | 공통 전투 설정·접근 정지 거리 |
| scripts/data/DataSchema.gd, autoload/DataRegistry.gd | 신규 데이터·참조 검증, 오류 시 차단 유지 |
| tests/BossSuite.gd/.tscn, BattleFlowSuite.gd/.tscn, make_fixtures.py | 방향 연계·보스·전투 흐름·신규 오류 fixture |
| project.godot, Run.cmd, README.md, AGENTS.md, docs 문서·evidence | 단계명·실행·인계·검증 근거 |

## 완료 조건 확인

- 기존 플레이어 56/56, 조작감 회귀52/52, 데이터176/176(46개 fixture), 보스/연계40/40, 전투 흐름17/17: **341개 통과**. 저장 프로브4개도 true. 정상 실행에서 script error 없음. malformed JSON fixture의 구문 오류는 의도된 진단.
- 보스 6개 패턴 각각 종료 확인 및 자연 가중 선택에서도 6개 모두 관찰. 거리·쿨다운·단독 후보 반복·후보 없음0.3초 대기·페이즈 진입1회·중단 시 경고 제거 확인.
- 실제 hitbox→hurtbox 경로로 피해18 단발, 중복 피격 없음, 패리 시 HP 유지와 스태거25 증가 확인. 4회 패리로 무력화, 피해1.25배, 강공격18 스태거, 반사 투사체80 피해/80 스태거 확인. 투사체 parriable_indices의 JSON float/int 비교 문제를 발견해 정수화 후 수정.
- GPU 창에서 실제 픽셀 캡처 확인. 경고→활성 판정의 정확한 경계 일치, 0.25배속에서 경고 유지 후 판정 전환. 새 경고의 첫 프레임 원점 표시를 interpolation reset으로 수정. 낙석 경고가 HUD를 방해하지 않게 HUD 배경 추가.
- GPU 실시간 재시작(고정 FPS 가속 없이) **R 813ms, 패드 A 이벤트800ms**, 0.8초 소개를 포함해 1초 이내. 기기 성능에 따른 보장은 아니며 이 환경 측정값이다.
- scratch `work/reordered_golem.json`에서 punch의 마지막 wait를 첫 번째로 옮겨 저장→재읽기→같은 runner로 실행. 실행 이력 첫 항목이 wait로 바뀜. 운영 JSON·runner 코드는 변경하지 않은 데이터 순서 실험이며 로그 `JSON_ORDER_PROOF`에 경로와 결과가 있다.
- 패드 입력과 focus는 이벤트 주입 검증. **실물 패드 플레이는 확인하지 않았다.** 사용자 체감·난이도·재도전 재미는 자동검사로 완료를 판정하지 않는다.

## 데이터와 코드 수치

새 전투 수치는 모두 JSON: intro0.8, 후보 재시도0.3, 투사체 수명8, 충격파 폭64, 낙석 경고 높이900, 발판 두께24, 시작 위치 플레이어[300,900]/골렘[1400,810], slam 정지거리250. 보스의 모든 공격·시간·속도·HP·스태거는 기존 보스 JSON을 읽는다. phase 배율은 duration/cooldown/stagger 시간을 나누고 이동·탄속을 곱한다. 투사체 중력은 시간축 변환에 맞춰 배율 제곱을 적용한다.

코드에는 화면/UI 좌표·글꼴/색·테두리 두께·1920×1080 캔버스, 비율/포물선의 수학 상수, 0 나눗셈 방어0.001, 이력 상한512, 화면 소수점 표시 자릿수만 남는다. Gameplay 데이터 fallback인 0은 생략된 offset/gravity/knockback/반사 옵션의 무효값이다. 이전 플레이어의 1 physics tick 안전 처리도 유지한다.

## 경계와 남은 결정

Step 2에서 멈춘다. 드롭 지급·재료 저장·제작·허브는 Step 3이므로 결과 화면은 전투 결과와 시간·재시작·연습 복귀까지만 제공한다. 날개 전투는 노출하지 않으며 일반 projectile primitive 검증에 날개 JSON 일부만 사용했다. 사용자에게 남은 확인은 새 방향 연계 체감과 골렘 공격 속도/회피 여유, 패리 사용 여부다.
