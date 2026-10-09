# 인수인계 — 여기서부터 읽는다

이 저장소가 게임 프로젝트의 기지다. 기획(Claude)과 구현(Codex) 모두 세션을 시작하면 이 파일을 가장 먼저 읽고, 세션을 끝낼 때 "현재 상태"와 "다음 할 일"을 갱신한다. 이 파일과 다른 문서가 충돌하면 이 파일과 가장 최근 사용자 결정이 우선이다.

## 역할

- 사용자: 방향 결정, 손맛·수치 튜닝, 맵(방) 직접 제작, 재미 판정.
- Claude: 기획, 단계별 설계서 작성(`docs/plan/`), 결과 검토.
- Codex: 코딩 전부. 설계서 하나씩 구현하고 보고서(`docs/*_REPORT.md`)와 `docs/WORK_LOG.md`를 남긴다.

## 세션 넘길 때 규칙

1. 시작: 이 파일 → `docs/plan/DIRECTION.md` → 지금 진행 중인 설계서 순서로 읽는다.
2. 끝: 이 파일의 "현재 상태"·"다음 할 일"을 고친다. 새로 정해진 것과 거부된 것은 `docs/plan/DIRECTION.md`에 한 줄씩 추가한다.
3. 사용자는 F키를 쓸 수 없다. 디버그 기능은 화면 버튼·Tab/Esc·패드 Start로만.
4. 확인한 것과 확인 못 한 것을 구분해서 쓴다. 자동 테스트 통과를 사람 손맛 판정으로 쓰지 않는다.

## 현재 상태 (2026-10-09)

- 엔진: Godot 4.6 / GDScript. 기본 실행은 움직임 장난감(점프 게임)이다. 기존 허브·골렘 전투는 보존되어 있다.
- 보스 러시 판정 결과: 골렘 하나 잡는 건 괜찮지만 "왜 이어서 해야 하는지"가 없음. 보상(장비·기술)을 더 붙이는 방향은 "테라리아 보스런 따라 한 느낌"이라 거부. 루프를 다시 찾는 중.
- 움직임 장난감(`toys/movement/`, 실행: `RunMovement.command`/`RunMovement.cmd` 또는 `toys/movement/movement_toy.tscn`): 튕기기(오리 배시 계열)·벽 점프·텍스트 방 파일. 사용자가 1시간 넘게 수치를 다듬으며 놀았고 튕기기 체감 승인. **현재 가장 강한 재미 신호.**
- 방 1~4는 Claude 초안. Codex가 만든 옛 5~8(패턴 반복)은 사용자 요청으로 삭제하고, Claude가 "방 하나에 순간 하나" 컨셉으로 새 5~8을 제작. Codex가 4방 무적 없는 자동 경로 완주와 로딩을 확인했다. 5·8 굴뚝은 벽 점프 없이, 8 탄환 방은 탄환 없이 우회 가능. 맵/수치는 유지. `docs/ROOM_SET_02_REPORT.md` 참조. 사람 체감은 미검증.
- **기본 실행은 한 판**(프로젝트 기본 씬 `toys/run/run_toy.tscn`, `Run.command`/`Run.cmd`/F5): 방 1~8 → 골렘. 점프만은 `RunMovement`, 골렘만은 `RunGolemBash`.
- 한 판(`toys/run/`, 실행 `RunOneRun.command`/`RunOneRun.cmd`): 2026-10-09 사용자 결정 "한 판으로 합치기"로 Claude 구현. `run.json`의 점프 방(기본 01·05·06)을 지나면 골렘 방, 골렘 사망은 골렘부터 재시작. 이동 수치는 사용자 결정으로 점프맵·보스방 중간값 하나로 통일(`movement_tuning.json` 변경, 대시 후 속도 65%), 그에 맞춰 5·7번 방 수정. `docs/RUN_REPORT.md`.
- 골렘 튕기기 장난감(`toys/golem_bash/`, 실행 `RunGolemBash.command`/`RunGolemBash.cmd`): 2026-10-09 Claude 구현, 같은 날 사용자 1차 플레이 피드백 7개 반영(약점을 어깨 위 결정으로 옮김·자동 조준·상황 안내, 피격 무적 1.2초와 깜빡임, 몸 닿음 0.25초 유예, 대시 무적, 쿵쿵 걷기, 앞으로 쓰러지는 무릎 자세, 멈칫·파편·숫자). 약점은 튕긴 직후 2초와 쓰러졌을 때만 열림. 자동 검사 통과, 무적 OFF 봇은 여전히 승리 못 함, 2차 판정에서 이동이 보스전엔 과하다고 해서 보스전 전용 이동 수치(느리고 무겁게, 공중 대시 2회 유지, 대시 후 속도 30%)와 포고 320, 팔 흔들림 축소. 3차 사람 판정 전. `docs/GOLEM_BASH_REPORT.md`.
- 효과음(2026-10-09, Claude): 자체 합성 25개를 한 판 전체(점프 방·골렘)에 연결. 음량 조절은 `autoload/Sfx.gd`의 `MIX`. 사람 귀 판정 전. `docs/SFX_REPORT.md`.
- 주인공(2026-10-09 사용자 결정): new-game(`codex/fennec-idle-sample-v1`)의 사막여우 전투형 문관(남색 철릭), 털만 game2 여우의 크림색으로 바꿈. 디자인은 확정 아님, 사용자와 같이 맞춰 감. Claude가 설계·검수·리그, **Codex가 이미지 생성**(내장 image_gen), 골렘처럼 부품(컷아웃) 리그. 작업 계획과 Codex 지시: `docs/plan/HERO_ART_PLAN.md`. 크기 적용됨: 카메라는 예전 800×384 그대로, 대신 주인공 판정 30×46(그림의 몸에 맞춤)·골렘 0.43·골렘 공격 시작 265·주인공 공격 66×56으로 맵 안에서 키움(1차로 카메라를 당겼더니 사용자가 답답하다고 함). 무기는 철부채. `docs/plan/HERO_SPEC.md`.
- 스토리·UI·아트 확장은 보류.

- 2026-10-09 최신 수정: 공중 두 번째 대시는 새 입력 방향으로 즉시 발동. 방향키와 Shift 입력 순서 차이를 0.06초 방향 입력 유예로 처리. 사용자 실플레이에서 작동 확인 후 tt 업로드 요청. 입력 주입 225검사, 기존 회귀 15개 모음 통과. 상세: `docs/MOVEMENT_INPUT_AUDIT.md`.

## 다음 할 일

1. 완료(2026-10-09): 새 방 5~8 사용자 플레이 판정 "나름 재밌었다". 5·8 굴뚝(벽 점프 없이 통과)·8 탄환 방(탄환 없이 통과) 우회는 남아 있음. 사용자가 불편을 말하면 Claude가 재설계하고 Codex가 경로 테스트를 고친다.
2. 사용자: 골렘 튕기기 장난감 2차 플레이 판정(피드백 반영본, PR #2). "시키지 않았는데 다시 붙고 싶은가", 기존 골렘전과 비교. 약점 열림 규칙과 난이도(창 길이) 의견. 구현 완료(Claude), `docs/GOLEM_BASH_REPORT.md`.
3. 사용자: 효과음 귀 판정(너무 큰/작은/거슬리는 소리, 빠진 순간). 말하면 Claude가 `MIX` 숫자나 `make_sfx.py` 합성식을 고친다.
4. 주인공 그림(`docs/plan/HERO_ART_PLAN.md`): **골렘과 화풍을 맞춘다(사용자 요청).** **Codex 다음 할 일 = 1a 화풍 시안 `assets/hero/raw/style_A.png`, `style_B.png` 생성(골렘 부품 첨부).** 0단계 임시 부착은 완료(네모 대신 여우 옆모습 한 장, 동작 없음). 사용자가 시안을 고르면 2단계 확정 옆모습 → 3단계 부품 시트 → Claude 리그·동작.
5. 둘 다 통과하면: 움직임 + 보스를 묶은 짧은 구간(방 몇 개 + 보스 하나)으로 다음 관문 설계.

## 문서 지도

- `docs/plan/DIRECTION.md` — 방향, 결정, 거부된 것, 이야기 메모. 기획의 누적 기록.
- `docs/plan/MOVEMENT_TOY_SPEC.md` — 움직임 장난감 원 설계서.
- `docs/plan/GOLEM_BASH_TOY_SPEC.md` — 골렘 튕기기 장난감 설계서. 구현 보고는 `docs/GOLEM_BASH_REPORT.md`.
- `docs/plan/ROOM_SET_02_SPEC.md` — 새 방 5~8 컨셉과 Codex 확인 항목.
- `docs/MOVEMENT_REPORT.md`, `MOVEMENT_README.md` — 움직임 장난감 구현 보고와 조작법.
- `docs/GATE1_SPEC.md`, `docs/GOLEM_MOBILITY_WETLAND.md` 외 — 보스 러시 1차 관문 시기의 설계·보고.
- `docs/plan/HERO_SPEC.md` — 주인공 설계와 GPT 이미지 프롬프트. 참고 그림은 `docs/plan/hero_refs/`.
- `docs/SFX_REPORT.md` — 효과음 목록, 합성·재생 구조.
- `docs/WORK_LOG.md` — Codex 누적 작업 기록.
- `AGENTS.md` — Codex 작업 규칙. `CLAUDE.md` — Claude 진입점.
