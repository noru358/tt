# 주인공 화풍 시안 생성 기록

2026-10-10 — HERO_ART_PLAN 1a. 내장 image_gen으로 각각 1회 생성. 생성 PNG는 편집 없이 복사했다. 배경 옵션: transparent_background=false.

## 공통 첨부 (순서대로)

1. `docs/plan/hero_refs/side.png`
2. `assets/bosses/golem/parts/torso.png`
3. `assets/bosses/golem/parts/head.png`

## A — assets/hero/raw/style_A.png

```text
Redraw the attached fennec fox character (first image) in the art style of the attached stone golem parts (other images): thick even dark brown-black outlines, simple cel shading with two or three tone steps and crisp edges, slightly muted colors, large readable shapes instead of fine detail. Keep the character design exactly: pale cream fur with lighter chest, muzzle and tail tip, huge ears, navy cheollik coat with cream collar, rust-orange sash, small black leather shoulder pads and bracers, black trousers, white leg wraps, black shoes, cute proportions about three heads tall without ears. Fur drawn as a few big tufts, not strands. Strict side view facing right, standing idle, full body, flat light gray background, no text.
```

## B — assets/hero/raw/style_B.png

```text
Redraw the attached fennec fox character (first image) in the art style of the attached stone golem parts (other images): thick even dark brown-black outlines, simple cel shading with two or three tone steps and crisp edges, slightly muted colors, large readable shapes instead of fine detail. Keep the character design exactly: pale cream fur with lighter chest, muzzle and tail tip, huge ears, navy cheollik coat with cream collar, rust-orange sash, small black leather shoulder pads and bracers, black trousers, white leg wraps, black shoes, cute proportions about three heads tall without ears. Fur drawn as a few big tufts, not strands. Strict side view facing right, standing idle, full body, flat light gray background, no text.

Slightly thinner outlines and a little softer shading, halfway between the two styles.
```

## 확인 및 다음 단계

두 이미지 모두 오른쪽을 보는 전신 대기 자세, 크림 털·남색 철릭·주홍 허리띠를 확인했다. A는 굵고 각진 외곽선, B는 더 가는 선과 부드러운 명암이다. 일부 명암과 가죽 장식은 기준 골렘보다 세밀하게 남아 있어 최종 화풍 승인은 아직 아니다. Claude의 골렘/128px 비교 검수와 사용자 A/B 선택 후 1b 디자인 시안판 진행. 게임 연결·리그·플레이 검증은 이 단계 범위가 아니다.


## 1b — assets/hero/raw/design_board.png (2026-10-10)

사용자 화풍 A 선택 후 내장 image_gen으로 1회 생성. 첨부 순서: assets/hero/raw/style_A.png, assets/bosses/golem/parts/torso.png, head.png. transparent_background=false. 원본 무편집 저장.

```text
Design exploration board for a 2D side-scrolling game hero, using the attached character exactly (same face, same pale cream fennec fur, huge ears, navy cheollik coat with cream collar, rust-orange sash, black leather shoulder pads and bracers, white leg wraps, black shoes). Match the golem art style: thick dark outlines, two to three tone cel shading. Same approved style A and outline as the first attached image. Flat light gray background, no text.
Top row: the character in strict right-facing side view holding three different Korean iron war fans (cheolseon), one per figure: A) closed black iron fan like a short baton with brass pivot rivet and rust-orange tassel; B) same fan half-open mid-swing showing dark navy silk with one cream cloud motif; C) a heavier fan with thicker iron outer ribs and a small brass cap on the tip.
Middle row: the same character small, with two floating fox-fire wisps behind the head, two styles: D) pale blue-white flame wisps; E) warm amber flame wisps with a faint fox-tail curl.
Bottom row: the same side pose in two fur tones: F) pale cream fur, G) warmer sandy beige fur. Chest, muzzle and tail tip stay lighter than the body in both.
All figures same scale, evenly spaced, nothing overlapping.
```

육안 확인: 부채 3종/여우불 2종/털색 2종이 3행으로 배치됨. 털색 차이는 작고 행 사이 캐릭터 크기는 일정하지 않아 게임 크기 비교 검수는 별도 필요. 사용자 디자인 선택 전.

## 2단계 — hero_side_final.png (2026-10-10)

사용자 선택: 화풍 A / 부채 C / 여우불 D / 털색 G. 내장 image_gen, transparent_background=false. 첨부 순서: style_A.png, design_board.png, 골렘 torso.png, head.png. 원본 PNG 무편집 저장.

```text
Create one final character design illustration for a 2D side-scrolling game, strict side view facing right, full body standing idle holding an iron war fan. Image 1 is the approved character and thick-outline style A; image 2 is the design board: use its TOP RIGHT fan C, MIDDLE LEFT blue-white fox-fire D, and BOTTOM RIGHT sandy beige fur G. Images 3 and 4 are supporting golem style references. Preserve the first image's face, huge ears, cute proportions, navy Korean cheollik coat with cream collar, rust-orange sash, small black leather shoulder pads and bracers, black trousers, white leg wraps, black shoes and single large fluffy tail. Change body fur to the warmer sandy beige of G; chest, muzzle and tail tip remain lighter off-white. Thick even very dark brown outlines, two to three crisp cel-shaded tones, large fur tufts, muted colors, no fine strands. Hold the heavier fan C in the near paw at waist height, slightly open as in the board, pointing forward: thick black iron outer ribs, small brass tips and brass pivot, rust-orange tassel. Keep its silhouette clear of the face and tail. Exactly two small pale blue-white fox-fire wisps float behind the head, separate from ears and tail. Calm idle pose, feet grounded, all character parts and accessories inside the canvas with margin. Flat light gray background, no floor shadow, no text, no labels, no additional views. This is a single final design, not a comparison board.
```

전신 오른쪽 옆모습, 두 청백색 여우불, 두꺼운 검은 철부채와 놋쇠 끝, 모래색 털 확인. 부채는 시안판보다 더 펼쳐짐. 최종 사용자 승인 및 게임 크기 검수 대기.

## 2단계 수정 v2 — 팔 내리기·중립 표정

2026-10-10 사용자 요청: 부채를 자연스럽게 내려 잡고, 웃는 입과 요염한 눈매 수정. 내장 image_gen 편집, 입력 hero_side_final_v1.png, transparent_background=false. 결과 hero_side_final_v2.png 및 hero_side_final.png. 원본 무편집 복사, SHA-256 동일 확인.

```text
Edit this exact character illustration. Change only the weapon-carrying arm pose and facial expression. Lower the near arm naturally from the shoulder, elbow relaxed and nearly straight, hand resting beside the outer thigh. Carry the same heavy black iron fan with brass tips and pivot and rust-orange tassel loosely but securely in that lowered hand, angled down toward the ground beside the leg, keeping its tip above the ground. Fold the fan mostly closed into a narrow compact shape for a natural resting carry; preserve its thick iron ribs and brass detailing. Do not hold it up in front of the torso. Replace the smile with a small simple neutral closed mouth, no upturned corner or smirk. Make the eye calm, straightforward and alert: a simple rounded natural eye opening, level relaxed upper lid, round brown iris, no winged eyeliner, no long lashes, no pointed swept-up outer eye corner, no half-lidded seductive expression. Relax the raised arched eyebrow into a subtle near-level neutral brow. The expression should be composed and earnest, neither angry nor sad nor smiling. Preserve the same cute fox identity, huge ears, warm sandy beige fur and light muzzle and tail tip, navy cheollik outfit, cream collar, rust sash, black leather armor, white leg wraps, black shoes, fluffy tail, exactly two blue-white wisps, thick dark outlines and crisp cel shading. Keep strict right-facing full-body side view, existing body proportions, background, composition and canvas. No text.
```

팔이 내려가고 부채가 아래를 향함, 입꼬리 미소 제거 및 눈 바깥쪽 날개 모양 축소 확인. 사용자 최종 승인 대기.

## 2단계 수정 v3 — 부채 길이 유지·내린 자세·잔잔한 미소

2026-10-10. 내장 image_gen 편집. 입력 hero_side_final_v1.png(부채 길이 기준), transparent_background=false. 출력 hero_side_final_v3.png 및 hero_side_final.png. 기존 v1/v2 보존.

```text
Edit the attached fennec fox final character illustration. Make only these two changes: (1) Keep the iron war fan exactly the same physical length from pivot to tips, size, construction, slightly open spread, black iron ribs, brass tips and rust-orange tassel. Relax the near shoulder and lower the arm and hand naturally into a resting idle position beside the hip/thigh. Rotate the fan downward so it points diagonally forward and down toward the ground, held comfortably in the lowered hand with a natural wrist angle. Do not shorten or shrink the fan. Keep the fan and tassel clear of the feet and entirely inside the canvas; expand background margins if needed rather than shrinking the character or weapon. The tassel hangs vertically under gravity. (2) Reduce the smile slightly to a calm, gentle, composed expression: a much subtler mouth curve and relaxed eyes, without making the character sad or stern. Preserve everything else: strict right-facing side view, face identity and proportions, huge ears, sandy beige fur with lighter muzzle and tail tip, single fluffy tail, navy cheollik with cream collar, rust-orange sash, leather shoulder pad and bracer, black trousers, white leg wraps, black shoes, exactly two pale blue-white fox-fire wisps behind the head, thick dark brown outline and crisp cel shading. Full body, flat light gray background, no text.
```

육안 확인: 원안과 비슷한 부채 길이, 허벅지 옆으로 내린 손과 아래로 향한 부채, 줄어든 입 곡선. 최종 사용자 승인 대기.

## 3단계 부품 시트 — 2026-10-10

사용자 v3 최종 승인 후 내장 image_gen 생성. 입력 hero_side_final_v3.png, transparent_background=false. 원본 무편집 보존. 초안 parts_sheet_alt1.png, 수정본 parts_sheet.png.

### HERO_PARTS_PROMPT.txt

```text
Create a production cutout animation parts sheet of exactly the attached approved fennec fox character. Preserve its face and small calm smile, warm sandy beige fur with lighter off-white muzzle and tail tip, huge ears, navy cheollik with cream collar, rust-orange sash, small black leather shoulder pad and bracer, black trousers, white leg wraps and black leather shoes. Thick even dark brown outlines, crisp two to three tone cel shading. Strict right-facing side view. Exactly 19 separated parts, all at the SAME anatomical pixel scale so they can be assembled into the reference character. Do not normalize every part to the same size. High resolution, long edge at least 2048 pixels. Flat solid bright green #00b140 background, no gradients, floor, shadows, text, numbers, labels or grid lines. Wide empty green gaps around every part, no touching or overlap. Rounded hidden joint ends for animation, no added joint discs, bolts or caps. No assembled character and no fox-fire wisps on this sheet.
Arrange in these rows, left to right:
Row 1 (3 parts): head WITHOUT either ear, eye open and subtle calm smile; near ear; far ear slightly darker.
Row 2 (3 parts): torso with coat top, cream collar and sash band, NO arms and NO skirt; coat skirt hanging straight as one piece; separate sash knot tails.
Row 3 (6 parts): near upper arm with shoulder pad; near forearm with bracer; near paw open; far upper arm; far forearm; far paw. Hands completely separate from forearms.
Row 4 (4 parts): near thigh in black trousers; near shin with white leg wrap and attached shoe; far thigh; far shin with white leg wrap and attached shoe. Each shoe points right. No hands on legs.
Row 5 (3 parts): single fluffy tail pointing straight back (left); closed heavy Korean iron war fan horizontal with thick black iron ribs, brass pivot and brass tip caps, rust-orange handle tassel; the SAME fan fully opened in a half circle with dark charcoal surface, thick black ribs, brass tip caps and pivot, rust-orange tassel. Preserve the approved fan length relative to the body, equal pivot-to-tip radius for closed and open forms. No cloud motif. Exactly these 19 components, no extras, no duplicates.
```

### HERO_PARTS_REPAIR_PROMPT.txt

```text
Correct this cutout parts sheet, preserving all 19 components, their row order and the approved character design. Fix these specific defects: row 2 left torso MUST have absolutely no arm, sleeve or shoulder armor attached; remove the entire attached near arm from torso and fill the hidden torso area with plain navy coat. Keep the separate shoulder/upper-arm component in row 3 unchanged. Row 2 right must contain only the sash knot and hanging tails, not a second horizontal waist belt. Row 5 middle fan must be FULLY CLOSED, all ribs stacked into one narrow baton, not a wedge or partially opened fan. Row 5 right fully open fan must have exactly the SAME pivot-to-tip length as that closed baton (about 245 pixels in current image scale); increase its radius to match, allowing more canvas space instead of shrinking other parts. Preserve black iron, brass tip caps and pivot, rust tassel. Background must be completely uniform solid RGB 0,177,64 (#00b140), no texture or variations. All components separated with wide gaps. No text, no extra components, no assembled figure. Output high resolution, at least 2048 pixels tall. Keep all other components and face unchanged.
```

검수: 19개 분리된 덩어리 확인. 수정본에서 몸통에 붙은 팔 제거됨. 남은 사항: 접은 부채가 완전히 닫히지 않음, 부채 두 형태 반경 차이, 매듭에 허리띠 일부 잔존. 출력 1160×1355로 요청한 긴 변 2048 미달. 원화 재조립/배율 검수 미완료. 리그 준비 완료로 간주하지 않으며 Claude 검수 후 보정/재생성 필요.

# 3b 추가 생성 프롬프트 (2026-10-10)

기준 커밋 02917d4. 내장 image_gen, transparent_background=false. A/B 첨부 순서: hero_side_final.png, parts_sheet.png. A 수정 첨부: 첫 생성 결과, parts_sheet.png.

## A 최초 생성

```text
Create a supplementary cutout parts sheet for exactly the attached fennec fox character (first image), matching the attached parts sheet (second image) in art style, thick dark brown outlines, crisp two to three tone cel shading, colors and EXACT pixel scale: every head below must be the same size as the head in the second image, every paw the same size as its paws, the fan the same size as its fans. Strict right-facing side view. Flat solid bright green #00b140 background, no gradient, floor, shadows, text, numbers, labels or grid. Wide empty gaps, nothing touching or overlapping. No assembled character, no ears on the heads, no fox-fire.
Row 1 (4 heads, same shape and outline as the sheet's head, ears removed, only the face changes): 1) eyes fully closed in a calm blink, small neutral mouth; 2) hurt wince, eye squeezed shut, mouth slightly open with gritted teeth, brow pinched; 3) battle shout, eye wide and fierce, mouth open wide; 4) focused determined look, eye narrowed and alert, mouth closed in a firm line.
Row 2 (4 parts): 5) near paw (black fingerless glove) clenched in a fist gripping around a vertical bar, with an empty round hole through the grip where a fan handle passes; 6) far paw clenched in a plain fist; 7) near paw open with fingers spread flat, palm facing right, as if pressed against a wall; 8) the same heavy iron war fan half open, about a 70 degree wedge, thick black iron ribs, brass tip caps and brass pivot, rust-orange tassel, same pivot-to-tip length as the sheet's closed fan.
```

## A 손 분리 수정

```text
Correct only the three hands in the bottom row of image 1, using image 2 as the exact hand size reference. They must be isolated PAWS ONLY with short wrist attachment ends, absolutely NO forearms, bracers, armor, elbow or white fur arm segments. Match the original sheet's paws at about 100 pixels wide in this 1160 pixel wide canvas, not enlarged to fill the row. Preserve their black fingerless gloves and respective poses: empty round grip hole, plain closed fist, open fingers for wall contact. Keep every other part including all four heads and the fan, canvas dimensions, colors and positions unchanged. Flat green background, no text.
```

## B 효과 시트

```text
Create a 2D game effects sheet in the same art style as the attached character (thick dark outlines where appropriate, crisp cel shading, muted palette): 1) a crescent wind-slash arc left by a swung iron fan, pale blue-white with a darker edge, about 120 degrees of arc; 2) a small round dust puff seen from the side, sandy grey; 3) a flat landing dust burst spreading left and right along the ground; 4) a small star-shaped hit spark, white and pale yellow; 5) a single blue-white fox-fire wisp matching the character's fox-fire, flame tip up. Flat solid bright green #00b140 background, no text, wide gaps, each effect separate.
```


## 3b 확인 결과

보충 시트는 귀 없는 머리 4개·팔 없는 손 3개·반쯤 편 부채 1개로 분리됨. 최초 결과에 붙은 팔·토시는 수정 생성으로 제거. 손은 기존 시트보다 커서 정확한 동일 픽셀 배율 조건은 미충족: 조립 시 손 배율 보정 필요. 집중 표정 입에 약한 미소가 남고, 부채 펼침각은 70도보다 넓어 보여 검수 대상. 효과는 바람 베기·둥근 먼지·착지 먼지·타격 불꽃·여우불 5종 확인. 바람 호는 지시의 120도보다 넓게 표현됨. 효과별 떨어진 작은 조각은 본체와 함께 잘라야 함. 원본 PNG 무편집, 복사본 바이트 동일 확인. 제작 적용·재조립 검수는 Claude 단계.
