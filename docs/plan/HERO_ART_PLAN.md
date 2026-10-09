# 주인공 그림 작업 계획

2026-10-09 사용자 결정: 주인공 디자인 작업을 시작한다. **Claude가 설계·검수·리그, Codex가 이미지 생성**(내장 image_gen, 배경 그림 때와 같은 방식). 사용자는 단계마다 고르고 플레이로 판정한다.

생김새와 수치의 기준은 `docs/plan/HERO_SPEC.md`(크림색 털, 남색 철릭, 철부채, 판정 30×46). 이 문서는 **무엇을 어떤 순서로, 누가** 하는지다.

## 왜 이 순서인가

- new-game·game2에서 GPT로 프레임을 한 장씩 뽑으면 다리·옷·꼬리가 장마다 달라져 계속 기각됐다. 그래서 **움직임은 그림이 아니라 코드**로 만든다(골렘과 같은 부품 리그). 이미지는 "정지된 부품 한 벌"만 받는다.
- 화면 속 주인공은 귀까지 약 128px다. 원화(384px)의 토시 무늬·옷 주름은 거의 안 보인다. 그래서 디자인 판단은 항상 **게임 크기로 줄여서** 한다.
- 부품을 뽑은 뒤 디자인을 바꾸면 부품 시트를 다시 뽑아야 한다. 그래서 **디자인 확정 → 부품 시트** 순서를 지킨다.

## 화풍 기준 — 골렘에 맞춘다 (사용자 요청)

지금 여우 원화와 골렘은 그림체가 다르다(`hero_refs/style_compare.png`: 왼쪽 원화, 오른쪽 굵은 외곽선·색 단순화를 기계적으로 흉내 낸 것, 게임 크기).

| | 골렘 (기준) | 지금 여우 원화 |
|---|---|---|
| 외곽선 | 굵고 짙은 거의 검정 갈색, 두께 일정 | 가늘고 주황·갈색, 털 끝마다 끊김 |
| 칠 | 면마다 2~3단 명암, 경계 또렷 | 부드러운 그라데이션, 털 가닥 묘사 |
| 색 | 탁하고 차분함 | 밝고 맑음 |
| 디테일 | 큰 덩어리 위주 | 잔털·주름 많음 |

맞추는 규칙:

- **외곽선:** 골렘처럼 짙은 고동색(약 #26201c) 굵은 선. 기준은 **게임 화면에서 같은 두께로 보이는 것**. 주인공 그림이 골렘보다 약 2.4배 작게 줄어드니, 원화 기준 외곽선이 골렘 부품 원본보다 2배 이상 굵어야 한다(384px 키 원화면 8~10px).
- **칠:** 2~3단 명암, 털은 가닥 대신 큰 털 뭉치 몇 개로. 꼬리·귀 끝은 뭉치 실루엣으로 표현.
- **색:** 크림 털·남색 철릭은 유지하되 채도를 살짝 낮춰 배경(탁한 밀림)과 골렘 사이에서 튀지 않게. 대신 허리띠 주홍과 여우불은 강조색으로 남긴다.
- **비율:** 귀 포함 약 3등신 귀여운 비율은 유지(골렘의 둔중함과 대비가 됨).
- 배경은 사실적인 회화체라 앞쪽 캐릭터 둘이 굵은 외곽선으로 떠 보이는 게 맞다. 배경은 바꾸지 않는다.

Codex에 줄 때는 **골렘 부품 그림을 화풍 기준으로 함께 첨부**한다(`assets/bosses/golem/parts/torso.png`, `head.png`).

## 단계

| 단계 | 하는 일 | 누가 | 사용자가 할 일 |
|---|---|---|---|
| 0 | 지금 옆모습 한 장을 게임 속 네모 자리에 임시로 붙임(좌우 뒤집기만, 정수리=판정 윗변) | Claude | 플레이하며 크기·읽힘 확인 |
| 1a | 화풍 시안: 여우를 골렘 화풍으로 다시 그린 옆모습 2안 | Codex 생성 → Claude가 골렘과 게임 크기로 나란히 정리 | 하나 고르기 |
| 1b | 디자인 시안판: 철부채 3안, 여우불 2안, 털 톤 2안 (1a 화풍으로) | Codex 생성 → Claude가 128px 축소본과 같이 정리 | 하나씩 고르기 |
| 2 | 확정 디자인 옆모습 1장(철부채 든 대기 자세) | Codex | 승인 |
| 3 | 부품 시트 1장(19부품) | Codex | 없음(Claude 검수) |
| 4 | 부품 자르기·관절점·리그 씬 | Claude | 없음 |
| 5 | 동작(대기·달리기·점프·대시·벽·휘두르기 3종·피격·배시) + 코드 흔들림(귀·꼬리·옷자락·매듭) + 여우불 | Claude | 플레이 판정 |
| 6 | 효과: 부채 휘두르기 잔상, 대시 잔상, 배시 발사 | Claude(코드로 그림), 필요하면 Codex 소품 | 플레이 판정 |
| 7 | 앞·뒤모습은 이 게임(옆 화면)에선 안 씀. 컷신·초상화가 필요해지면 그때 | - | - |

0단계는 1~3단계와 동시에 할 수 있다. 판정 크기가 바뀌었으니 먼저 체감해 보는 게 가장 싸다.

## Codex 작업 지시

공통 규칙(모든 이미지):

- 도구: 내장 image_gen. 결과 PNG는 **편집하지 않고 원본 그대로** 저장하고, 쓴 프롬프트 전문을 `docs/HERO_ART_PROMPTS.md`에 남긴다(배경 때 `docs/BACKGROUND_PROMPT.md`처럼).
- 첨부 기준 그림: `docs/plan/hero_refs/side.png`(크림색 털 버전). 주황 원본을 쓰지 않는다.
- 저장 위치: `assets/hero/raw/` (게임이 아직 안 읽으니 `.gdignore`를 같이 둔다).
- 코드·수치·테스트는 건드리지 않는다. 완료되면 HANDOFF.md "현재 상태"에 파일 이름만 한 줄 추가.

### 1a단계 — 화풍 시안 `assets/hero/raw/style_A.png`, `style_B.png`

첨부: `docs/plan/hero_refs/side.png`(캐릭터), `assets/bosses/golem/parts/torso.png`와 `head.png`(화풍 기준).

```
Redraw the attached fennec fox character (first image) in the art style of the attached stone golem parts (other images): thick even dark brown-black outlines, simple cel shading with two or three tone steps and crisp edges, slightly muted colors, large readable shapes instead of fine detail. Keep the character design exactly: pale cream fur with lighter chest, muzzle and tail tip, huge ears, navy cheollik coat with cream collar, rust-orange sash, small black leather shoulder pads and bracers, black trousers, white leg wraps, black shoes, cute proportions about three heads tall without ears. Fur drawn as a few big tufts, not strands. Strict side view facing right, standing idle, full body, flat light gray background, no text.
```

스타일 A는 위 그대로, 스타일 B는 문장 끝에 `Slightly thinner outlines and a little softer shading, halfway between the two styles.`를 붙인다.

### 1b단계 — 디자인 시안판 `assets/hero/raw/design_board.png`

1a에서 고른 그림을 캐릭터 첨부로 쓰고 골렘 부품도 같이 첨부한다. 프롬프트 첫 문장 끝에 `Match the golem art style: thick dark outlines, two to three tone cel shading.`을 붙인다.

```
Design exploration board for a 2D side-scrolling game hero, using the attached character exactly (same face, same pale cream fennec fur, huge ears, navy cheollik coat with cream collar, rust-orange sash, black leather shoulder pads and bracers, white leg wraps, black shoes). Same painterly style and outline as the attached image. Flat light gray background, no text.
Top row: the character in strict right-facing side view holding three different Korean iron war fans (cheolseon), one per figure: A) closed black iron fan like a short baton with brass pivot rivet and rust-orange tassel; B) same fan half-open mid-swing showing dark navy silk with one cream cloud motif; C) a heavier fan with thicker iron outer ribs and a small brass cap on the tip.
Middle row: the same character small, with two floating fox-fire wisps behind the head, two styles: D) pale blue-white flame wisps; E) warm amber flame wisps with a faint fox-tail curl.
Bottom row: the same side pose in two fur tones: F) pale cream fur, G) warmer sandy beige fur. Chest, muzzle and tail tip stay lighter than the body in both.
All figures same scale, evenly spaced, nothing overlapping.
```

여러 장이 나오면 가장 일관된 1장만 쓰고 나머지는 `design_board_alt*.png`로 둔다.

### 2단계 — 확정 옆모습 `assets/hero/raw/hero_side_final.png`

1단계에서 사용자가 고른 안(부채 A/B/C, 여우불 D/E, 털 F/G)을 Claude가 HERO_SPEC에 적은 뒤 진행한다. 프롬프트는 그때 Claude가 HERO_SPEC에 추가한다.

### 3단계 — 부품 시트 `assets/hero/raw/parts_sheet.png`

2단계 그림을 첨부해 HERO_SPEC의 **프롬프트 B**를 쓴다. 골렘 때 자르기가 잘 됐던 조건을 지킨다:

- 배경은 **투명이 아니라 한 가지 단색**(밝은 초록 #00b140 같은, 캐릭터에 없는 색). 그라데이션·그림자·바닥 없음.
- 부품끼리 충분히 띄우고, 부품 번호·글자는 넣지 않는다(자르기를 방해함). 순서는 프롬프트의 번호 순서로 왼쪽→오른쪽, 위→아래.
- 관절 끝은 둥글게, 관절을 덮는 원판·볼트 같은 장식은 넣지 않는다.
- 엄격한 옆모습(오른쪽 보기), 모든 부품 같은 배율. 가능한 한 크게(긴 변 2048px 이상).

## Claude 검수 기준

- **1·2단계:** 골렘 부품과 **같은 게임 배율로 나란히 놓고** 외곽선 두께·명암 단계·채도가 같은 게임으로 보이는가. 128px(실제 화면 크기)로 줄인 그림에서 실루엣으로 여우·부채·방향이 읽히는가. 귀·꼬리·부채가 서로 겹쳐 덩어리지지 않는가.
- **3단계:** 부품을 다시 조립했을 때 2단계 그림과 겹쳐서 크게 어긋나지 않는가(얼굴·옷 색, 배율). 실패하면 무엇이 틀렸는지 적어서 Codex에 재생성 요청.
- **5단계:** 발이 미끄러지지 않는가, 판정 상자(30×46) 안에 몸이 들어오는가, 휘두르기 그림이 공격 판정(66×56)과 맞는가.

## 사용자에게 받을 결정

1. 0단계(임시 부착)를 먼저 할지 — 추천
2. 1a 화풍 A/B 고르기, 1b 시안판에서 부채·여우불·털 톤 고르기
3. 5단계 동작을 플레이로 판정
