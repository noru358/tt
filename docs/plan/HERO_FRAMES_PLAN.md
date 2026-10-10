# 주인공 동작 — 통그림 프레임으로 다시 (2026-10-10)

## 왜 바꾸나

사용자 플레이 판정(2026-10-10): 부품 리그(PR #14)가 전부 어색하다.
- 흐느적거리는 종이인형 같다.
- 귀·꼬리가 이상하게 붙어 있다.
- 공격이 제자리에서 팔만 붕붕 돈다.
- 배시로 날아갈 때 슈퍼맨 자세다.
- 여우불이 어색하다.
- 착지 먼지가 안 맞는다.

원인은 방식이다. 19조각을 각도로 돌리면 관절마다 그림이 끊기고, 귀·꼬리처럼 모양이 바뀌어야 하는 부위를 회전으로만 흉내 낸다. 사용자 결정: **에셋은 만들면 된다.** 그래서 **동작마다 몸 전체를 한 장씩 그린 프레임**으로 바꾼다. 코드는 프레임을 순서대로 넘기기만 하고, 몸을 구부리거나 흔들지 않는다.

예전(new-game·game2)에 장마다 따로 뽑다가 다리·옷·꼬리가 달라져 실패한 적이 있다. 이번에는 다음 세 가지로 막는다.
1. 한 동작의 프레임을 **한 번에 한 장(가로 띠)**으로 뽑는다.
2. 매번 확정 그림과 이미 통과한 띠를 첨부한다.
3. Claude가 겹쳐 보기로 검수한다.

## 형식 (모든 띠 공통)

- 첨부 순서:
  1. `assets/hero/raw/hero_side_final.png`: 확정 디자인.
  2. 이미 통과한 띠 하나(첫 띠는 없음): 크기·화풍 기준.
- 가로 띠 한 장에 프레임 N칸. 칸은 정사각형이고 칸 사이에 넓은 빈 간격을 둔다. 칸 테두리·번호·글자는 넣지 않는다.
- 배경은 고른 단색 초록 `#00B140`이다. 그림자나 바닥선도 넣지 않는다.
- 엄격한 옆모습으로 오른쪽을 본다.
  - 모든 칸에서 **같은 키**(정수리~발바닥)와 **같은 발 바닥선**을 지킨다.
  - 공중 동작은 몸 중심 높이를 맞춘다.
- 화풍은 확정 그림 그대로다. 굵은 어두운 외곽선, 2~3단 셀 명암, 모래빛 크림 털, 남색 철릭, 주홍 허리띠, 검은 철부채(놋쇠 장식, 주홍 술)를 지킨다.
- 귀·꼬리는 **몸에 자연스럽게 붙은 채** 동작에 맞게 모양까지 바뀐다(접힘·휘날림).
- 철부채는 항상 **앞쪽(오른쪽) 손**에 있다. 꼬리는 항상 등 뒤에 있다.
- 여우불은 그리지 않는다.
- 저장은 `assets/hero/frames/raw/<동작>.png`, 프롬프트는 `docs/HERO_ART_PROMPTS.md`에 추가한다.

## 동작 목록 (총 39칸)

| 순서 | 동작 | 칸 | 자세 |
|---|---|---|---|
| 1 | idle | 4 | 확정 그림 자세. 숨쉬기로 어깨가 살짝 오르내리고, 3칸째 귀 끝이 까딱, 꼬리 끝이 천천히 흔들림 |
| 2 | run | 6 | 접지→눌림→교차→뜀 ×2. 몸 앞으로 기울임, 부채는 접어서 몸 옆에 붙임, 꼬리는 뒤로 흐름, 귀는 살짝 뒤로 |
| 3 | jump | 3 | 도약 웅크림 → 상승(무릎 당김, 꼬리 아래로) → 꼭대기(몸 펴짐) |
| 4 | fall | 2 | 낙하(팔 살짝 벌림, 귀·꼬리 위로 날림) → 착지 직전(다리 뻗음) |
| 5 | land | 1 | 착지 눌림(무릎 굽힘, 꼬리 바닥 쪽) |
| 6 | dash | 2 | 낮게 앞으로 박차는 질주 자세(몸 약 30° 기울임, 수평 비행 아님). 부채 접어 앞으로 겨눔 |
| 7 | wall | 2 | 벽 미끄러짐. 벽은 등 뒤(왼쪽), 뒷손으로 벽 짚음, 한 발 벽에 댐, 얼굴은 벽 반대쪽 |
| 8 | attack_side | 4 | ① 몸을 뒤로 당기며 부채 반쯤 펼침 ② **한 걸음 내딛으며** 부채를 활짝 펴 수평으로 벰 ③ 휘두른 뒤 몸이 앞으로 쏠림 ④ 자세 회복, 부채 접힘 |
| 9 | attack_up | 3 | 웅크림 → 펼친 부채를 머리 위로 올려 벰(발끝 들림) → 회복 |
| 10 | attack_down | 3 | 공중: 부채 들어올림 → 아래로 내려침(몸 앞으로 숙임, 무릎 당김) → 회복 |
| 11 | hurt | 1 | 뒤로 젖히며 찡그림, 귀 뒤로 접힘 |
| 12 | down | 2 | 쓰러짐(무릎 꿇음 → 옆으로 누움) |
| 13 | bash_hold | 1 | 공중에서 몸을 공처럼 웅크려 힘 모음, 눈은 조준 방향 |
| 14 | bash_launch | 3 | **앞구르기 공중제비**: 웅크린 공 회전 3단계(0°·120°·240°). 슈퍼맨 자세 금지 |
| 15 | fx_land | 3 | 착지 먼지 3단계(작게→넓게→흩어짐). 발 폭의 약 2배, 바닥선에 붙음 |

칸 크기는 512×512, 키는 약 340px다(확정 그림 축소). `bash_launch`는 코드에서 날아가는 방향으로 회전시키지 않고 그대로 넘긴다.

## 순서

1. **idle + run 먼저.** 가장 많이 보이는 둘을 뽑아 Claude가 검수한 뒤 바로 게임에 넣는다. 사용자가 플레이로 판정하고 통과해야 나머지를 진행한다.
2. jump·fall·land·dash·wall.
3. 공격 3종.
4. hurt·down·bash·fx_land.

## Codex 첫 작업 프롬프트 (idle, run)

첨부: `assets/hero/raw/hero_side_final.png`. idle을 먼저 뽑고, run을 뽑을 때는 통과한 idle 띠도 첨부한다.

```text
Sprite animation strip of the attached fennec fox character (keep the design, colors and art style exactly: thick dark outlines, two to three tone cel shading, sandy cream fur, navy cheollik coat, rust-orange sash, black iron fan with brass caps and rust tassel). Strict side view facing right, full body, every frame the same character height and the same ground line. Ears and tail are attached naturally and change shape with the motion. The iron fan is always in the front (right) paw; the tail is always behind. One horizontal strip of N square frames with wide empty gaps between them, flat solid green background #00B140, no frame borders, no numbers, no text, no shadow, no ground line.
```

- idle: `N = 4`. 뒤에 붙인다: `Idle breathing loop: shoulders rise and fall slightly, ear tips twitch on frame 3, tail tip sways slowly. Fan held closed, pointing down.`
- run: `N = 6`. 뒤에 붙인다: `Run cycle: contact, down, passing, up, then the same with the other leg. Body leans forward, closed fan held close to the body, tail streams behind, ears slightly back. Legs clearly alternate near and far.`

## 검수 결과 1차 (2026-10-10, Claude) — idle·run 게임 적용

- **idle 4칸 통과.**
  - 발바닥선이 4칸 모두 같다(원본 y648).
  - 3칸째만 귀 끝이 내려가 정수리가 14px 낮다. 지시대로다.
  - 부채는 접힌 채 아래로, 꼬리는 크기 일정, 여우불 없음.
- **run 6칸 조건부 통과.**
  - 바닥선은 ±6px로 맞다. 4칸째는 28px 떠 있는 공중 보폭이다.
  - **배율이 idle의 약 0.76배**로 나왔다(얼굴 맞대기 측정). 코드에서 1/0.76배로 맞췄으므로 재생성은 필요 없다.
  - 아쉬운 점 둘:
    - 부채 쥔 앞팔이 6칸 내내 허리에 고정돼 있다.
    - 두 다리가 같은 검은 바지라 앞뒤 다리 교대가 잘 안 읽힌다.
  - 플레이 판정에서 어색하면 이 둘을 고쳐 다시 뽑는다.
- **칸 규격:** 512px 정사각이 아니고 띠 전체가 2172×724다. 상관없다. Claude가 초록 배경을 빼고 칸을 자동으로 나누며, 각 칸의 남색 철릭 중심과 바닥선을 기준점으로 맞춘다.
- **게임 연결:**
  - `scripts/player/HeroFrames.gd`가 부품 리그(`HeroRig`)를 대체했다. 부품 리그와 부품 PNG는 지웠다.
  - 프레임 PNG는 `assets/hero/frames/<동작>_<번호>.png`이다. 캔버스 아래 가운데가 발 기준점이다.
  - 아직 그림이 없는 동작은 이렇게 임시로 채운다:
    - 공중·대시: run 4칸째(공중 보폭)
    - 벽·공격·사망: idle
    - 피격: 빨간 깜빡임

## Claude 검수 기준

- 한 띠의 칸들을 바닥선 기준으로 겹쳐 본다.
  - 키 차이는 ±3% 이내여야 한다.
  - 털·철릭·허리띠 색이 같아야 한다.
  - 꼬리는 등 뒤, 부채는 앞손에 있어야 한다.
  - 귀 두 개가 다 보여야 한다.
- 다른 띠와 나란히 놓고 키와 외곽선 두께가 같은지 본다.
- 게임 크기(키 약 128px)로 줄여서 동작이 읽히는지 본다.
- 실패한 칸만 이유를 적어 다시 뽑게 한다. 원본은 편집하지 않는다.

## 코드 (Claude)

- `HeroRig`(부품 리그)를 프레임 재생기로 바꾼다. 상태에 따라 동작을 고르고 정해진 fps로 넘긴다. 몸을 흔드는 스프링은 없다.
- 발 바닥선을 판정 상자(30×46) 바닥에 맞춘다. 착지 먼지는 그 바닥선에 붙인다.
- 공격 프레임 ②가 공격 판정이 켜지는 순간과 같은 프레임에 오도록 맞춘다.
- 남은 공중 대시는 화면 글자("대시 n/m")로만 보여 준다. 여우불은 뺀다. 다른 표시가 필요하면 그때 정한다.
- 부품 리그는 프레임이 들어올 때까지만 임시로 쓴다. 지금 여우불과 착지 먼지는 껐다.

## 2차: 포즈 가이드 방식 (2026-10-10, 사용자 승인)

### 왜

사용자 판정: GPT가 뽑은 프레임이 "신체가 미묘하게 안 맞는다". Claude 측정(`tools/hero_art/measure.py`)으로 확인한 결과:
- run 꼬리 크기가 칸마다 -16%~+25% 흔들린다. 띠 전체로는 확정 그림보다 꼬리가 73% 크다.
- idle은 확정 그림보다 다리가 15% 길고 머리(귀 포함)가 작다.
- run은 머리(귀 포함) 크기가 칸마다 최대 6% 달라진다. 앞팔이 6칸 내내 허리에 고정돼 있고, 두 다리가 같은 검은색이라 교대가 안 읽힌다.

원인은 글 지시만으로는 뼈대가 고정되지 않는 데 있다. 그래서 **치수가 고정된 마네킹 포즈를 그림으로 함께 넘긴다.**

### 준비물 (Claude, 완료)

- `docs/plan/hero_refs/poses/proportion_sheet.png`: 확정 그림과 마네킹을 같은 키로 놓고 빨간 기준선(귀 끝·깃·허리띠·철릭 끝·발바닥)을 그은 비교판. 사람 검수용이며 Codex에 첨부하지 않는다.
- `docs/plan/hero_refs/poses/idle_pose.png`, `run_pose.png`: 512px 정사각 칸, 흰 배경, 글자 없음. 앞쪽 팔다리는 밝은 회색, 뒤쪽은 어두운 회색이다. 검은 막대는 접은 부채다.
  - run은 접지 → 교차 → 공중 순서이고, 4~6칸은 1~3칸에서 다리를 바꾼 것이다. 팔은 다리와 반대로 흔든다. 부채는 접어서 뒤쪽 아래로 든다.
- 다시 만들기: `python3 tools/hero_art/mannequin.py docs/plan/hero_refs/poses`. 다른 동작의 포즈도 이 파일의 `MOTIONS`에 추가한다.

### Codex 작업: run 6칸 다시 뽑기

첨부는 순서대로 세 장이다.
1. `assets/hero/raw/hero_side_final.png`
2. `assets/hero/frames/raw/idle.png`
3. `docs/plan/hero_refs/poses/run_pose.png`

```text
Sprite animation strip of the fennec fox character in image 1 (keep the design, colors and art style exactly: thick dark outlines, two to three tone cel shading, sandy cream fur, navy cheollik coat, rust-orange sash, black iron fan with brass caps and rust tassel). Draw the character at the same scale as image 2.
Image 3 is a pose guide: six grey mannequins drawn with the character's exact proportions. Copy each mannequin's pose, body proportions, head size, limb lengths, tail size and foot positions exactly, one frame per mannequin, in the same order and the same place inside each cell. Light grey limbs are the near side, dark grey limbs are the far side. The black bar is the closed fan, held in the near paw. Do not copy the mannequin colors or flat shapes; draw the real character.
Keep the head, ears and tail the same size in every frame. Ears lean slightly back; the tail streams behind with the same size as in image 1. Arms swing opposite to the legs. The near trouser leg is drawn slightly lighter than the far one so the alternating legs read clearly.
Outline thickness about 2.5% of the character height, so the lines stay bold when the sprite is shown about 128 px tall.
One horizontal strip of six square frames with wide empty gaps, flat solid green background #00B140, no frame borders, no numbers, no text, no shadow, no ground line, no fox-fire wisps.
```

- 저장: `assets/hero/frames/raw/run_v2.png`. 프롬프트는 `docs/HERO_ART_PROMPTS.md`에 추가한다. 원본은 편집하지 않는다.
- 첫 결과의 비율이 맞지 않으면 실패한 칸을 그대로 다시 뽑지 말고 "image 3의 n번 마네킹과 머리/꼬리/다리 길이를 맞춰라"고 수치를 넣어 다시 뽑는다.
- idle은 지금 띠를 그대로 쓴다. 다리가 15% 긴 것은 플레이에서 어색하다고 하면 `idle_pose.png`로 다시 뽑는다.

### Claude 검수 (뽑힌 뒤)

1. 초록 배경을 빼고 칸을 나눈다.
2. `python3 tools/hero_art/measure.py --ref assets/hero/raw/hero_side_final.png <칸들>`를 돌린다. 띠 안에서 머리 ±8%, 꼬리 ±15%, 확정 그림 대비 꼬리 ±20%를 넘으면 그 칸은 불합격이다. 서 있는 동작은 `--standing`을 붙여 철릭·다리 비율도 ±12% 안에서 본다.
3. 포즈 가이드와 겹쳐 보고 앞뒤 다리가 맞는지 확인한다.
4. **머리 고정:** 통과한 띠에서도 얼굴·귀가 칸마다 미세하게 다르면, 확정 그림의 머리를 잘라 각 칸의 목 위치에 붙이고 기울기만 맞춘다. 몸은 칸마다 그린 그림 그대로라서 종이인형처럼 보이지 않는다. 이 단계는 실제 띠가 나온 뒤 결과를 보고 만든다.
5. 게임 크기(키 약 128px)로 줄여 골렘 옆에 놓고 외곽선 두께를 비교한다.

### 보류: 디자인 단순화 (사용자 결정 필요)

게임 크기에서는 견갑·토시·술·행전 같은 작은 장식이 뭉개지고, 장식이 많을수록 칸마다 어긋난다. 줄일지는 사용자가 정한다. 정하기 전까지는 확정 디자인 그대로 간다.
