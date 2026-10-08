# 컷아웃 보스 키트 설계서 (Codex 구현용)

목적: 두 번째 보스부터 "부품 시트 1장 → 게임에 넣을 수 있는 리그 + 기본 동작"을 반나절 안에 끝낸다. 골렘 때 즉석으로 만든 파이썬 프로토타입(`tools_py/`)이 동작 근거다. 새로 설계하지 말고 이 동작을 정리·일반화한다.

## 결과물

본 게임 레포 안의 `tools/cutout_kit/` (위치는 레포 규칙 우선). 파이썬 CLI 4단계 + 보스별 설정 파일 1개.

```
cutout_kit/
  cut.py        시트 → 부품 PNG 분리
  pivots.py     부품별 관절 후보 자동 추정 + 확인용 이미지
  build.py      설정 → 부품 PNG 내보내기 + Godot 리그 씬(.tscn)
  moves.py      동작 라이브러리 → 보스 비율에 맞춰 IK로 자세 계산 → 애니메이션 추가
  bosses/golem/rig.json   (골렘 설정, tools_py/golem_rig.json 그대로)
```

## 1. cut.py

- 입력: 단색 배경 시트 PNG. 출력: `c0.png …` 투명 부품, `dbg.png`(부품마다 50px 눈금).
- 방법: 테두리 픽셀 중앙값을 배경색으로, 색 거리 < 28이고 테두리와 연결된 영역을 배경으로 판정 → 나머지 연결요소 중 면적 5000px 이상을 부품으로. 알파 가장자리는 색 거리 10~40 구간을 선형으로.
- 정렬: 행(세로 300px 단위) → x 순. 시트 레이아웃이 프롬프트 템플릿(아래)과 같으면 c0 몸통, c1 머리, c2 위팔, c3 아래팔, c4 허벅지, c5 종아리, c6 주먹.
- 참고 구현: `tools_py/cut.py`.

## 2. pivots.py

- 각 팔다리 부품: 위쪽 15% 알파 영역의 중심 = pivot 후보, 아래쪽 15% = dist(다음 관절) 후보.
- 몸통의 shoulder/neck/hip, 주먹 손목, 발 heel/toe, 주먹 바닥 edgeA/edgeB는 자동 추정 + 사람이 확인. `piv.png`에 빨간 점과 이름을 찍어 보여준다.
- 결과는 `rig.json` 초안으로 저장. 사람(또는 Claude)이 이미지 보고 숫자만 고친다.

## 3. build.py

`tools_py/rig3.py`의 다음 동작을 그대로 옮긴다.

- 팔다리 PNG를 pivot→dist 축이 수직이 되도록 회전해 내보낸다. 회전값이 실제 관절각이 되게 하는 핵심이다(골렘에서 팔꿈치가 역으로 꺾이던 원인).
- 노드 계층·이름은 골렘과 동일한 표준 이족 리그: `Torso`(Node2D) / `TorsoSkin` / `Head` / `Arm{Front,Back}_{Upper,Lower}` / `Fist{Front,Back}` / `Leg{Front,Back}_{Upper,Lower}`. 뒤쪽 부위 modulate 0.7, 아래팔 show_behind_parent.
- 리그 원점 = 발바닥(y=0). 기본자세는 발이 지면에 닿도록 Torso y를 계산.
- 검증: 골렘 설정으로 실행한 결과 `.tscn`이 현재 `scenes/golem.tscn`과 바이트 단위로 같아야 한다(프로토타입에서 확인됨).

## 4. moves.py — 동작 라이브러리

동작을 각도값이 아니라 "의도"로 정의하고, 보스 비율이 달라도 IK로 다시 푼다.

- 자세 정의 예: `slam.impact = {양발 고정, 앞주먹 바닥면이 발끝+105 지점 지면에 평평하게, 몸통 기울기 자유(0~1.05), 무릎 굽힘 ≤0.75}`.
- 제약(골렘에서 문제 됐던 것들, 반드시 유지): 무릎·팔꿈치는 앞쪽으로만 굽힘, 발은 지면에 평평, 복귀는 중간키 없이 직선, 예비동작 중 팔꿈치는 일찍 접기(transition 0.25), 내려칠 때 위팔 먼저(0.9)·아래팔/주먹 늦게(3.0).
- 풀이: scipy least_squares, 관절 범위 bounds, 여러 초기값 중 오차+무릎굽힘 최소 해 선택.
- 기본 라이브러리: idle, slam(+heavy, high), sweep, stomp. 키 시간은 `docs/GOLEM_BOSS_DESIGN.md`와 동일.
- 출력 검사: 발 미끄러짐(복귀 중 최대 px), 360px 미리보기 상단 잘림 프레임 수, 각 자세 IK 오차를 숫자로 출력하고 기준(미끄러짐 ≤10px, 잘림 0, 오차 ≤5px) 넘으면 실패 처리.
- 참고 구현: `tools_py/rig3.py`(make_poses, solve), `tools_py/moves.py`.

## 5. 시트 프롬프트 템플릿

`docs/PROMPTS.md` 3번(Sheet v2)을 `{creature}`, `{material}`, `{accent}` 자리표시로 일반화해 `cutout_kit/PROMPT_TEMPLATE.md`에 둔다. 레이아웃 문장(4열 2행, 부품 순서, STRICT SIDE PROFILE, 단색 배경, 관절 원판 금지)은 고정.

## 완료 기준

- 골렘 시트로 cut → pivots → build → moves 전체를 돌려 현재 `golem.tscn`과 같은 결과(동작 포함)가 나온다.
- 실행 방법이 README 한 장에 들어간다.
- 확인하지 않은 항목은 미확인으로 보고한다.
