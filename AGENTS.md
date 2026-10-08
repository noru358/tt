# Gate 1 작업 규칙

- 먼저 `C:/Users/User/Documents/Codex/WORK_MEMORY.md`, 이 파일, `docs/WORK_LOG.md`, `docs/GATE1_SPEC.md`를 읽는다.
- 새 독립 Godot 4.6 / typed GDScript 프로젝트다. 이전 게임 프로젝트와 합치지 않는다.
- 한 번에 한 단계만 구현한다. 현재 사용자 지시에 따라 Step 3까지 구현·검증 완료. 사용자 다음 지시 전 Step 4 시작 금지.
- 플레이어/연습 아레나/피드백/7탭 조작감 패널은 구현됐다. **사용자는 F키를 쓸 수 없다. F1~F6 의존을 재도입하지 않는다.** 화면 버튼·Tab/Esc/패드 Start로 조작한다. 범용 보스 실행기·골렘·전투 결과가 구현됐다. 허브/진행 세이브는 Step 3에서 구현됐고 텔레메트리는 후속 단계다.
- 보스·무기·장비·재료·조작감의 런타임 수치는 `data/` JSON에 둔다.
- JSON 계약의 상세 보충은 `docs/DATA_CONTRACT.md`. 새 필드는 검증 코드와 함께 변경한다.
- 검증 실패 시 전체 오류 화면과 진행 차단을 유지한다. 운영 JSON을 깨뜨리는 테스트 대신 외부 scratch fixture를 쓴다.
- 매 단계 종료 전 `docs/WORK_LOG.md`를 누적 갱신하고 실제 테스트와 사용자 체감 검증을 구분한다.
- Step 1 테스트는 `tests/PlayerSuite.tscn`, `RegistrySuite.tscn`, `PersistenceProbe.tscn`. 실물 패드 연결 없이 주입한 이벤트 검증을 패드 실기 검증으로 보고하지 않는다.
- `data/tuning_defaults.json`는 공장 기본값이다. 패널 저장은 이 파일을 덮어쓰지 않는다. 무기·허수아비·선택 무기도 함께 저장한다.
- 최신 사용자 피드백: 8방향 대시, 공격 자동 전진0, 즉시 이동/정지/반전, 공격 중 이동·점프/대시 취소, 시간 제한 없는 공격 예약 제거. 최신 계약은 `docs/CONTROLS_REVISION.md`를 읽는다. `ControlsRevisionSuite.tscn`이 입력 잔류·대시 관성·빠른 탭·마우스 UI 회귀를 검증한다.

- 최신 작업은 `docs/STEP_2_REPORT.md`. 새 공격 유지 방향 연계는 공격 반응 패널에서 변경. Step 2 검증: BossSuite/BattleFlowSuite 및 기존 회귀. 실물 패드는 아직 미검증. 기본 실행은 BattleArena, `-- --training`은 연습. 재료/드롭/성장/날개 전투는 다음 단계 범위.

- 최신 사용자 조작감 수정은 docs/COMBAT_FEEL_REVISION.md 우선. 대시 중 공격·공격 유지 대시·선딜 조준·키유지 연속공격·포고 공중대시 회복. 대시480/.18/무적.28/쿨.30, 골렘 상시접촉0, 세 무기 빠른선택/미리설정. CombatFeelSuite31 포함372 PASS. Step 3 성장루프는 아직 미착수.

- 최신 계약: docs/STEP_3_REPORT.md. 공격보다 방어 우선, 대시+패리 동시, 0.10초 방어 버퍼·거부 이유·history_version 경계. 허브/드롭/제작/3슬롯/StatCalc/4효과/진행저장 구현. 기본 Boot는 허브, progression_run 전투는 장착 무기, training은 자유 미리 사용. 테스트는 반드시 GATE1_TEST_SAVE 외부 scratch 경로 사용. 452 PASS. 이전 Step 2 대기·성장 미구현 기록은 최신 기록으로 정정. 날개 해금만, Step4 전투 금지.

- 2026-10-07 최신 조작 계약은 docs/INPUT_COMBO_REVISION.md. 세 무기 지상4타, 기본 attack_buffer=.18/attack_release_clears_buffer=false(한 번만 유한 연계), 방향 edge 스냅샷, 패리 후딜 공격·점프 취소/패리 중 이동/지상대시 새 점프 취소. 키 release가 모든 연계를 지워야 한다는 이전 기본정책은 최신 사용자 연계 요구에 맞게 정정(패널로 이전 옵션 가능).
- 허브의 연습 모드/실제 게임을 명시적으로 구분. 연습 골렘은 무보상, 실제게임은 장착·진행저장. 모든 화면/결과의 기본 복귀는 허브.
- 테스트 실행 전에 GATE1_TEST_SAVE와 GATE1_TEST_TUNING을 모두 지정. PlayerSuite 기반 테스트는 누락 시 즉시 종료한다. 재사용 override가 테스트 초기값을 바꿀 수 있으므로 fresh 경로를 사용. BossSuite는 GATE1_TEST_REORDER도 필요. 기존 테스트의 선택무기 가정은 테스트에서 sword_basic으로 명시하며 사용자 선택을 덮어쓰지 않는다.

- 2026-10-07 최신 계약은 docs/STEP3_REVIEW_FIX_REPORT.md가 이전 조작감/입력 문서보다 우선. 사용자 요청으로 공격이동.4/히트스톱.05/지상콤보전진30/대시300으로 변경. chain_at 후딜 게이트를 모든 공격 연계에 공통 적용, 헛패리 기본 취소false, 물리 게임시간 버퍼. 이전 전진0/480거리/후딜즉시취소/벽시계 만료 규칙은 현재 기본값이 아님.
- F1~F11 수정 완료. 보스 initially_unlocked/order 기반·해금된 기존 범용 날개 전투 진입 허용. Step4 전체 구현/검증을 완료했다고 주장하지 않으며 Step4/5 추가 작업은 새 사용자 지시 필요. 운영JSON에 새 필드/무기를 넣을 때 tuning_defaults와 schema도 함께 갱신. 변경 저장은 원본 pre-migrate 백업 후 진행. 디버그 런 보상 허용/최고시간 제외.
- 567자동검사 및 ReviewFix43 GPU, 진행 새프로세스/튜닝4프로브 PASS. 실물키보드/패드/손맛은 별도. 최신 evidence/review_* 결과 참조.

- 2026-10-08 최신 계약: docs/INDEPENDENT_REVIEW_FIX_REPORT.md. 독립 검수 H1–H4/M1–M6/L1–L6 수정. 공격 슬롯은 현재 동작까지만 유지, 대시는 기존 공격 취소, 특수 공격 후 1타 초기화, 패리+공격 성공 때만 반격(사용자 선택). 새 설정/구 override 이전 포함. tests/run_suites.py로 격리·fixed-fps 순차 검증. 이전 문서의 조기 탭 만료/대시 공격 유지/특수 콤보 유지 계약보다 우선.

- 2026-10-08 사용자 승인으로 마법 활 보조 공격 추가. 최신 추가 계약 docs/MAGIC_BOW.md. U/RB hold→release, 강한 자동조준·유도, 이동/대시/근접과 독립. 점멸은 미래 계획이며 구현 금지. 패널은 마법 활 포함 8탭. 전투 수치는 player JSON/defaults/schema 동시 변경. MagicBowSuite40 포함 전체687검사.

- 2026-10-08 사용자 승인: 골렘 컷아웃 3패턴 이식, 원본 Lab 수정 금지, GitHub noru358/tt 업로드. 최신 계약 docs/GOLEM_PORT_REPORT.md. 패널은 골렘 포함 9탭. 컷아웃 제작 키트/점멸/미제공 모션은 다음 작업. Windows 절대경로 WORK_MEMORY는 원개발 환경의 역사적 참조이며 현재 checkout의 문서를 기준으로 한다.
