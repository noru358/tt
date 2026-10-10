# 주인공 리디자인 지시서 (2026-10-10)

## 왜

사용자 결정(2026-10-10): 복장 등을 Codex와 함께 리디자인한다. 게임 크기에서는 견갑·토시·술이 뭉개진다. **특징은 눈에 잘 보이게 살리되, 뭉개지지 않게** 다시 그린다.

사용자가 지적한 문제 두 가지도 이번 디자인에서 함께 막는다.
- **귀가 3개로 보인다.** 앞 1개와 뒤 2개로 읽힌다.
- **뒤쪽 팔이 부자연스럽다.** 계속 몸 뒤에 박혀 있고, 위치도 어색하다.

리디자인이 확정될 때까지 run 재생성(HERO_FRAMES_PLAN "2차")은 멈춘다. 확정되면 Claude가 새 그림으로 마네킹 치수를 다시 재고 나서 재생성한다.

## 남길 특징

1. 아주 큰 사막여우 귀 두 개
2. 크림색 털과 큰 꼬리
3. 남색 철릭(허리 아래로 퍼지는 치마폭)
4. 주홍 허리띠
5. 검은 철부채(놋쇠 끝, 주홍 술)
6. 차분한 문관 인상

## 규칙: 키 128px에서 읽히게

- **작은 장식은 없애거나 큰 덩어리 하나로 합친다.** 크기의 기준은 이렇다. 키 128px로 줄였을 때 5px(키의 약 4%)보다 작은 부품은 넣지 않는다. 그런 부품은 리벳, 가는 테두리, 얇은 끈, 작은 술 같은 것들이다.
  - 견갑: 없애거나, 어깨를 덮는 단순한 판 하나로 만든다. 판 테두리는 놋쇠 한 줄이고 리벳은 없다.
  - 토시: 팔뚝마다 어두운 띠 하나로 만든다. 장식 무늬는 넣지 않는다.
  - 술: 부채 술 하나만 남기고, 더 굵고 크게 만든다. 허리띠 끝은 넓은 천 두 가닥으로 한다.
  - 행전: 밝은 띠 하나로 만들거나 장화에 합친다.
- **실루엣이 먼저다.** 귀, 꼬리, 치마폭, 부채는 검은 실루엣만 봐도 알아볼 수 있어야 한다.
- **색은 바탕색 5~6개로 제한한다.** 털, 남색, 주홍, 검정/어두운 회색, 놋쇠, 흰 속옷이고, 색마다 밝은 단과 어두운 단을 하나씩 둔다.
- **외곽선 두께는 키의 약 2.5%로 통일한다.** 골렘과 같은 굵은 어두운 선이다.
- **움직일 때 따라다녀야 하는 작은 매달린 부품은 최소로 한다.** 칸마다 달라지기 쉬운 부분이라서다.

## 규칙: 귀는 딱 두 개

- 옆모습에서는 앞쪽 귀 하나가 크게 보이고, 뒤쪽 귀는 그 뒤로 **끝만 조금** 보인다. 뒤쪽 귀는 한 단 어둡게 칠한다.
- 귀 안쪽 무늬, 털 뭉치, 머리 위 털끝이 또 다른 귀 모양으로 읽히지 않게 한다.

## 규칙: 팔이 몸에 묻히지 않게

- **소매 색이 철릭 몸판과 달라야 한다.** 지금은 남색 팔이 남색 몸 위에 겹쳐서 팔이 사라진다. 소매에 흰 속옷이 드러나는 넓은 부분을 두거나, 팔뚝 띠를 밝은 색으로 바꾸는 식으로 처리한다.
- 뒤쪽 팔과 다리는 한 단 어둡게 칠한다(앞뒤 구분).
- 뒤쪽 어깨는 몸의 반대편에 있다. 팔을 앞으로 흔들면 손이 가슴 앞으로 나오고, 뒤로 흔들면 팔꿈치가 등 뒤로 보인다. **몸통 안에 숨은 채 고정하지 않는다.**

## Codex 작업 1: 리디자인 시안판

첨부: `assets/hero/raw/hero_side_final.png`(현재 확정 디자인), `docs/plan/hero_refs/golem_style.png`(게임 속 골렘, 화풍·선 굵기 기준).

저장: `assets/hero/raw/redesign_board.png`. 프롬프트는 `docs/HERO_ART_PROMPTS.md`에 추가한다.

```text
Character redesign sheet for a 2D platformer sprite, based on the attached fennec fox civil official (image 1). Same art style as the attached stone golem (image 2): thick dark outlines about 2.5% of the character height, two to three tone cel shading.
Keep the identity: two very large fennec ears, sandy cream fur, big fluffy tail, navy cheollik coat with a skirt that flares below the waist, rust-orange sash, black iron fan with brass tips and one rust tassel, calm scholarly expression.
Simplify for a sprite shown about 128 px tall: remove rivets, thin trims, thin cords and small tassels. Shoulder guard either removed or one simple plate with a single brass rim. Forearm guards are one dark band each. Leg wraps are one light band or merged into the boots. Keep one bold tassel on the fan and two broad sash tails. Limit the palette to six base colors with one light and one dark step each.
Exactly two ears: in side view the near ear is large and the far ear shows only its tip behind it, one shade darker. Nothing else on the head may read as an ear.
Sleeves must contrast with the navy coat body (for example a broad white under-sleeve showing), so the arms stay visible in front of the body. Far-side arm and leg one shade darker.
Show three variants side by side, labelled only A, B, C: A close to the original, B moderately simplified, C boldly simplified. Each variant: strict side view facing right, full body, standing, closed fan held down in the near paw. Under each variant, the same figure shrunk to 128 px tall and 64 px tall. Flat light grey background, no other text, no fox-fire wisps.
```

## 사용자 → Claude → Codex

1. 사용자가 A·B·C 중 하나를 고르거나 섞으라고 한다. 바꿀 점도 적는다.
2. Codex가 고른 안으로 확정 옆모습 `hero_side_final_v4.png`를 뽑는다. 첨부는 시안판과 현재 확정 그림이다. 규격은 지금 확정 그림과 같다. 엄격한 옆모습, 서 있는 자세, 부채는 접어서 아래로 든다.
3. Claude가 v4로 다시 잰다.
   - `tools/hero_art/mannequin.py`의 기준점 `P`를 v4에 맞춰 고친다.
   - 비교판으로 귀·팔 위치를 확인한다.
4. 그다음 HERO_FRAMES_PLAN "2차" 순서로 idle·run을 다시 뽑는다. 첨부는 v4와 마네킹이다.

## Claude 검수 기준 (시안판)

- 128px·64px 축소본에서 6개 특징이 다 보이는가.
- 귀가 두 개로만 읽히는가.
- 소매가 몸판과 구분되는가.
- 외곽선이 골렘과 비슷한 굵기인가.
- 원래 인상(차분한 문관 여우)이 남아 있는가.
