# 주인공 설계서 — 사막여우 전투형 문관 (철릭)

2026-10-09 사용자 결정: 주인공은 game2에서 잡아 둔 **사막여우 전투형 문관**, 옷은 **철릭** 기반. 작업 방식은 "Claude가 아이디어·구조 설계 → ChatGPT가 이미지 제작".

참고 그림: `docs/plan/hero_refs/hero_turnaround_approved.png`(game2 승인 8방향 시트, 옷은 판타지 관복+갑주), `approved_side_view.png`(그중 옆모습). 이 시트의 **얼굴·털색·비율·색 배합은 유지**하고 **옷만 철릭으로 바꾼다**.

비교 페이지(코드 초안, 실제 크기·골렘 옆): https://claude.ai/artifact/5KBz3NkyGcp3mf3GaYupcd

## 1. 게임 속 크기에서 읽혀야 하는 것

- 판정은 20×28, 화면에서는 귀까지 약 70px. 원본 승인 시트를 이 크기로 줄이면 보석·문양·견갑 장식은 사라지고 **덩어리 다섯 개**만 남는다(비교 페이지 위쪽 참고).
  1. 큰 귀 두 개 (가장 높은 실루엣)
  2. 크림색 머리와 갈색 눈
  3. 짙은 청록 상의 (철릭 윗도리)
  4. 흰색 주름 치마 (철릭 아랫도리)
  5. 큰 꼬리
- 그래서 디자인 정보는 이 다섯 덩어리의 **모양과 색 구분**에 둔다. 1~2px로 사라질 자수·문양·장신구는 일러스트용으로만 쓰고 게임 판단 근거로 삼지 않는다(game2 ART_PRODUCTION_CONSTRAINTS와 같은 결론).
- 외곽선: 골렘처럼 진한 갈색-검정 외곽선, 회화풍 채색. 단, 주인공은 골렘보다 **밝고 채도 높게**(크림·청록·흰색)해서 돌 배경과 골렘 위에서 바로 보이게.

## 2. 철릭으로 바꿀 때

철릭은 윗도리와 주름 치마가 허리에서 붙은 조선 무관·문관의 활동복이다. 이 게임에서 좋은 점은 **치마 주름이 달리기·대시·튕기기 때 뒤로 퍼져서 속도가 그대로 보인다**는 것.

| 부위 | 정하는 것 | 이유 |
|---|---|---|
| 윗도리 | 짙은 청록(#1f4a5e 근처), 흰 곧은 깃이 가슴에서 교차 | 승인 시트 색 유지, 깃이 몸 방향을 알려 줌 |
| 소매 | 통이 좁은 소매 + 손목 토시(검정·금 테) | 큰 소매는 칼 휘두를 때 팔 판정과 헷갈림 |
| 허리 | 금색 광다회(꼰 띠) + 매듭 술 하나가 뒤로 늘어짐 | 상하 분리선, 술은 작은 흔들림 요소 |
| 주름 치마 | 흰색, 촘촘한 세로 주름, 무릎 아래까지, 밑단에 청록 띠 | 다섯 덩어리 중 가장 큰 움직임 신호 |
| 흉배 | 가슴에 작은 정사각 자수판 하나(금색 테 + 파란 점) | 문관이라는 표시. 게임 크기에선 점 하나 |
| 머리 장식 | 승인 시트의 파란 보석 관을 작게, 귀 사이 | 귀가 모자를 대신하므로 갓·전립은 쓰지 않음 |
| 신발 | 검은 목화(관리 장화), 금 테 | 승인 시트 유지 |
| 갑주 | 한쪽 어깨에만 작은 견갑 | "전투형" 표시, 실루엣을 무겁게 만들지 않음 |

## 3. 게임용 기능 (코드로 처리)

- **여우불 = 남은 공중 대시.** 머리 뒤를 따라다니는 파란 여우불 2개, 대시할 때마다 하나씩 꺼지고 착지하면 다시 켜진다. 지금 글자로만 나오는 정보를 그림으로 바꾼다. (new-game의 여우불 동행 아이디어와 같은 뿌리)
- 귀·꼬리·치마·술은 **코드가 흔든다**(속도 방향 반대로 늘어짐). 그림은 정지 부품만 있으면 된다.
- 대시 무적 표시(지금 청록 테두리)는 몸 외곽 빛으로, 피격 깜빡임은 그대로.

## 4. 무기

지금 게임은 J로 근접 휘두르기(옆·위·아래 내려찍기)다. 기본값은 **짧은 환도(조선 칼)** 하나. 대안은 문관답게 **철 부채**(접으면 막대, 휘두르면 펼쳐짐). 사용자 선택 대기, 정하기 전까지 환도로 진행.

## 5. 제작 방식

game2에서는 GPT로 걷기·달리기 프레임을 한 장씩 뽑다가 다리 좌우·옷·꼬리가 프레임마다 달라져서 여러 번 기각됐다. 그래서 이번엔 **프레임 애니메이션이 아니라 골렘과 같은 부품(컷아웃) 방식**으로 간다. GPT에게는 "같은 그림 한 벌"만 받는다.

1. **옆모습 원화 1장** (GPT): 아래 프롬프트 A. 사용자 승인까지 반복.
2. **부품 시트 1장** (GPT): 승인된 원화를 붙여 넣고 프롬프트 B. 부품마다 따로 떨어진 투명 배경.
3. **리그** (Claude): 부품을 잘라 Godot에 골렘처럼 뼈대를 세우고, 대기·달리기·점프·대시·벽 매달리기·휘두르기·피격·튕기기 자세를 코드로 만든다. 귀·꼬리·치마는 코드 흔들림.
4. 그 전에 **코드로 그린 임시 여우**(비교 페이지의 ★)를 게임에 먼저 넣어 크기·여우불·치마 펄럭임이 손맛을 해치지 않는지 플레이로 확인할 수 있다.

### 프롬프트 A — 옆모습 원화

첨부: `hero_turnaround_approved.png`

```
Use the attached fennec fox character as the identity reference: keep the face, cream fur, brown eyes, huge ears, big fluffy tail, body proportions and color palette (cream, deep teal, white, gold, small blue gems).
Redesign only the outfit as a Korean Joseon "cheollik" (철릭): a deep teal upper coat with a white straight crossed collar and narrow sleeves with black-and-gold wrist guards, joined at the waist to a long white skirt with dense vertical knife pleats reaching below the knee, teal band at the hem. A gold braided waist cord with one knotted tassel. A small square embroidered rank badge on the chest. One small shoulder guard on the far shoulder only. Black official boots with gold trim. A small blue-gem crown ornament between the ears, no hat.
Single character, full body, strict side view facing right, standing, neutral pose, arms relaxed.
Painterly 2D game art with clean dark brown outlines, same rendering style as the reference, flat light from upper left, transparent or plain light background.
Readability first: the character will be shown about 70 pixels tall, so keep shapes big and simple, strong color separation between ears, head, teal coat, white pleated skirt and tail. No tiny ornaments that would vanish at small size.
```

### 프롬프트 B — 부품 시트

첨부: 승인된 원화(프롬프트 A 결과)

```
Create a cutout animation parts sheet of exactly this character (same style, colors, outline and scale), strict side view facing right, every part separated with empty space around it on a transparent background, no overlaps, no shadows.
Parts: 1 head without ears (eye open), 2 near ear, 3 far ear (slightly darker), 4 upper body coat with collar and rank badge (no arms, no skirt), 5 pleated skirt as one piece hanging straight, 6 near upper arm, 7 near forearm with wrist guard, 8 near hand (paw, open), 9 far upper arm, 10 far forearm, 11 far hand, 12 near thigh, 13 near shin with boot, 14 far thigh, 15 far shin with boot, 16 tail as one piece pointing straight back, 17 waist cord tassel, 18 shoulder guard, 19 short Korean sword (hwando) in a horizontal pose.
Each limb part should have rounded joint ends so it can rotate at the joint. Keep the same pixel scale for all parts. Label each part with its number in small gray text below it.
```

받은 그림은 `assets/hero/`에 원본 그대로 넣어 주면 Claude가 자르고 등록한다.

## 6. 사람이 정할 것

- 무기: 환도(기본) / 철 부채
- 프롬프트 A 결과 원화 승인
- 임시 코드 여우를 먼저 게임에 넣을지(추천), 원화부터 받을지
