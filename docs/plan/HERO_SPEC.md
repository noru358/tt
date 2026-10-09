# 주인공 설계서 — 사막여우 전투형 문관 (철릭)

2026-10-09 사용자 결정: 주인공은 **new-game 저장소에서 잡아 둔 사막여우 전투형 문관(철릭)**. 작업 방식은 "Claude가 아이디어·구조 설계 → ChatGPT가 이미지 제작".

- 기준 그림: `docs/plan/hero_refs/side.png`, `front.png`, `back.png` (new-game `codex/fennec-idle-sample-v1` 브랜치 `game/fennec_idle/`, 각 384×448 투명 PNG, 발 기준점 약 (190, 416)). 당시 상태는 "시안 시험 승인"이고 최종 디자인 승인은 아님.
- 잘못 가져왔던 game2의 크림색 판타지 관복 시트는 기준이 아니다(2026-10-09 사용자 정정).
- 비교 페이지(실제 화면 크기, 카메라·골렘 크기 바꿔 보기): https://claude.ai/artifact/5KBz3NkyGcp3mf3GaYupcd

## 1. 생김새 (기준 그림 그대로)

| 부위 | 내용 |
|---|---|
| 털 | 주황, 가슴·주둥이·귀 안쪽·꼬리 끝은 크림 |
| 얼굴 | 갈색 눈(밝은 하이라이트), 짧은 목, 귀 제외 약 3등신 |
| 귀 | 아주 큼. 가장 높은 실루엣 |
| 옷 | 남색 철릭(앞섶 겹침), 크림색 깃, 녹슨 주홍 허리띠(매듭 끝이 늘어짐) |
| 무장 | 검은 가죽 견갑·토시(작게) |
| 아래 | 검은 바지, 흰 행전, 검은 가죽 신 |
| 꼬리 | 하나, 크고 풍성함. 뿌리는 허리띠 아래 등 중앙 |

## 2. 크기 문제 (사용자 피드백: "둘 사이즈가 너무 차이 나고 안 보인다")

지금 수치(카메라 세로 384, 판정 20×28, 골렘 배율 0.42)로 720p 화면에 세우면 주인공은 귀까지 약 83px(화면 높이 11%), 골렘은 약 530px(73%)로 **6배 넘게** 차이 난다(비교 페이지 측정, 골렘 다리는 곧게 세운 근사).

손볼 수 있는 손잡이 세 개:
1. **카메라 당기기** (`camera_view_height` 384 → 300 등): 둘 다 커짐. 대신 점프 방에서 앞이 덜 보임.
2. **골렘 줄이기** (`golem_scale` 0.42 → 0.34 등): 차이가 줄어듦. 골렘의 공격 판정 위치도 함께 줄어드니 골렘 수치 재확인 필요.
3. **주인공 그림만 키우기** (판정은 그대로, 그림 1.3배): 손맛·방 설계 영향 없음. 맞는 범위보다 그림이 커 보이는 게 단점.

조합은 사용자가 비교 페이지에서 고르고, 정해지면 Claude가 수치로 옮긴다.

## 3. 게임용 기능 (코드로 처리)

- **여우불 = 남은 공중 대시.** 머리 뒤를 따라다니는 작은 여우불 2개, 대시할 때마다 하나씩 꺼지고 착지하면 켜진다(new-game의 여우불 동행과 같은 뿌리). 지금 글자로만 보이는 정보를 그림으로 바꾼다.
- 귀·꼬리·철릭 자락·허리띠 매듭은 **코드가 흔든다**(속도 반대 방향으로 늘어짐). 그림은 정지 부품만 있으면 된다.
- 대시 무적 표시는 몸 외곽 빛, 피격 깜빡임은 지금 그대로.

## 4. 무기

지금 게임은 J로 근접 휘두르기(옆·위·아래 내려찍기). 기준 그림은 맨손이다. 기본값은 **짧은 환도**, 대안은 **철 부채** 또는 new-game처럼 **맨손 마력 충격**(칼 없이 손에서 문양·충격). 사용자 선택 대기, 정하기 전까지 환도.

## 5. 제작 방식

new-game·game2 모두 GPT로 방향·프레임을 한 장씩 뽑을 때 꼬리 위치·다리·옷이 장마다 달라지는 문제가 반복됐다. 그래서 **프레임 애니메이션이 아니라 골렘과 같은 부품(컷아웃) 방식**으로 간다.

1. 옆모습 원화는 이미 있다(`side.png`). 이걸 기준으로 **부품 시트 1장**만 GPT로 받는다(프롬프트 B).
2. Claude가 부품을 잘라 Godot에 뼈대를 세우고 대기·달리기·점프·대시·벽 매달리기·휘두르기·피격·튕기기 자세를 코드로 만든다.
3. 그 전에 지금 `side.png` 한 장을 네모 자리에 임시로 붙여서(좌우 뒤집기만) 크기와 여우불을 플레이로 먼저 확인할 수 있다.

### 프롬프트 B — 부품 시트

첨부: `side.png`

```
Create a cutout animation parts sheet of exactly this fennec fox character: same face, orange fur, cream chest and tail tip, huge ears, navy cheollik coat with cream collar, rust-orange sash, small black leather shoulder pads and bracers, black trousers, white leg wraps, black leather shoes. Same painterly style, outline, colors and scale as the attached image. Strict side view facing right.
Every part separated with empty space around it, transparent background, no overlaps, no shadows, no text except small gray part numbers.
Parts: 1 head without ears (eye open), 2 near ear, 3 far ear (slightly darker), 4 torso with coat top, collar and sash (no arms, no skirt flaps), 5 coat skirt hanging straight as one piece, 6 sash knot tails, 7 near upper arm with shoulder pad, 8 near forearm with bracer, 9 near paw (open), 10 far upper arm, 11 far forearm, 12 far paw, 13 near thigh, 14 near shin with leg wrap and shoe, 15 far thigh, 16 far shin with shoe, 17 tail as one piece pointing straight back, 18 short Korean sword (hwando) horizontal.
Limb parts need rounded joint ends so they can rotate at the joint. Keep one consistent pixel scale across all parts.
```

받은 그림은 `assets/hero/`에 원본 그대로 넣거나 스레드에 올리면 Claude가 자르고 등록한다.

## 6. 사람이 정할 것

- 크기 조합 (비교 페이지): 카메라 / 골렘 크기 / 주인공 그림 배율
- 무기: 환도(기본) / 철 부채 / 맨손 마력
- 임시로 `side.png`를 먼저 게임에 붙일지(추천)
