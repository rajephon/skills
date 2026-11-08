# 시각화 표현 카탈로그

`assets/template.html`의 클래스와 토큰을 그대로 쓰는 코드 조각 모음이다. 필요한 항목만 읽는다.

예시 값은 모두 가상의 시나리오(동네 도서관이 무인 반납기를 도입하고 운영위원회에 결과를 발표)에서 지어낸 것이다. 실제 페이지에서는 원천의 값으로 바꾼다.

## 목차

1. 고르는 법과 안 그리는 법
2. 숫자 카드 (tiles)
3. 번호 단계 (steps)
4. 흐름 칩 (flowrow) — 순서, 전/후, 병목
5. 뼈대 칩 + 접힌 상세 (암기용 블록)
6. 세그먼트 막대 (전체 중 비율)
7. 막대 차트 (범주별 크기)
8. 선 차트 (시간에 따른 변화)
9. 덤벨 차트 (항목별 전→후)
10. 간트 타임라인 (기간 + 사건)
11. 박스-화살표 구조도 (메커니즘)
12. 나란한 비교도 (차이를 그린다)
13. 셀·격자 그림 (저수준 원리)
14. 점 매트릭스 (항목 × 범주)
15. 계산기 (독자가 실측값을 넣을 때)
16. 일정·체크리스트
17. SVG 좌표 어림 계산

---

## 1. 고르는 법과 안 그리는 법

- 그림을 넣기 전에 "독자가 이 그림으로 무엇을 한눈에 알게 되나?"를 한 문장으로 쓴다. 쓸 수 없으면 그리지 않는다.
- 같은 정보를 문장 한 줄로 말할 수 있으면 문장이 이긴다.
- 숫자 두 개를 비교할 때 측정 기준이 다르면(접수 기준 vs 처리 완료 기준, 별도 vs 연결) 같은 축에 놓지 않는다. 숫자 카드로 나란히 두고 단서를 붙인다.
- 축이 둘인 차트(이중 y축)는 만들지 않는다. 두 개의 차트로 나눈다.
- 계열 색은 정해진 순서(`--s1`→`--s5`)로 쓰고, 필터나 순위로 색이 바뀌지 않게 한다. 5개를 넘으면 "기타"로 묶거나 작은 차트 여러 개로 나눈다.
- 모든 차트는 마우스 없이도 값을 볼 수 있어야 한다: 직접 라벨 일부 + 툴팁 + "표로 보기".

## 2. 숫자 카드 (tiles)

핵심 숫자 2–4개. 값은 크게, 라벨은 무엇을 어떤 기준으로 쟀는지.

```html
<div class="tiles">
  <div class="tile"><div class="v">10% → 40%</div><div class="l">무인 반납 비율, 도입 전 → 1년 후</div></div>
  <div class="tile"><div class="v">4시간 → 30분</div><div class="l">반납부터 서가 복귀까지 평균 시간</div></div>
</div>
<p class="warn">두 숫자는 측정 기준이 다릅니다(…). 직접 비교 대신 "…"로 말하세요.</p>
```

## 3. 번호 단계 (steps)

순서 자체가 정보일 때만(동선, 절차, 진행 순서). 번호는 CSS 카운터가 붙인다.

```html
<ol class="steps">
  <li><div><span class="mono">09:40</span> <b>1층 안내데스크</b>에서 출입증 받기</div></li>
  <li><div><b>3층 세미나실</b>로 이동</div></li>
</ol>
```

## 4. 흐름 칩 (flowrow)

화살표로 이어지는 짧은 단계. 줄마다 `rowlbl`로 무엇의 흐름인지 쓴다. 핵심은 `key`, 문제·병목은 `hot`.

```html
<div class="flowrow"><span class="rowlbl">도입 전: 병목은 반납 접수</span>
  <span class="st hot">반납 접수</span><span class="arr">→</span><span class="st">분류</span><span class="arr">→</span><span class="st">서가 배치</span></div>
<div class="flowrow"><span class="rowlbl">도입 후: 병목이 서가 배치로 이동</span>
  <span class="st">반납 접수</span><span class="arr">→</span><span class="st">분류</span><span class="arr">→</span><span class="st hot">서가 배치</span></div>
```

전/후 비교는 이렇게 두 줄을 겹쳐 두면 "어디가 바뀌었는지"가 위치로 보인다. 변하지 않은 공통점을 보여 줄 때는 첫 줄에 `key` 칩 하나만 둔다.

## 5. 뼈대 칩 + 접힌 상세 (암기용 블록)

질문 블록의 표준 형태. 암기 모드에서는 `.q-head`만 보이고 눌러야 나머지가 열린다.

```html
<article class="q" id="q-why">
  <div class="q-head"><span class="qid">§2</span><span class="pri">★★★</span><h3>왜 지금 무인 반납기를 늘리려고 하나요?</h3></div>
  <p class="intent">질문 의도: …</p>
  <ol class="bone"><li><span>뼈대 1</span></li><li><span>뼈대 2</span></li><li><span>뼈대 3</span></li></ol>
  <!-- 그림이 있으면 여기 -->
  <details class="ans"><summary>답변</summary><div class="say">
    <p>실제로 말할 문장. <mark class="key">핵심 문장</mark>은 표시.</p>
  </div></details>
  <dl class="tails"><dt>꼬리질문</dt><dd>답</dd></dl>
  <ul class="notes"><li>메모, 출처, <span class="todo">✍️ 채울 것</span></li></ul>
</article>
```

암기 모드에서 숨길 요소는 블록 안에 둔다. 블록 밖(섹션 상단)의 그림은 암기 모드에서도 보인다. 질문과 무관하게 늘 보여야 하는 지도 그림은 블록 밖에 둔다.

## 6. 세그먼트 막대 (전체 중 비율)

템플릿의 `renderSeg`가 그린다. `data-seg`에 JSON을 넣으면 막대, 범례, 표로 보기, 툴팁이 생긴다. 칸이 좁으면 안쪽 라벨은 자동으로 숨는다.

```html
<div class="seg-wrap" data-seg='{"unit":"%","parts":[{"n":"문자 알림","v":50},{"n":"앱 알림","v":30},{"n":"이메일","v":20}]}'></div>
```

부분이 5개를 넘으면 "기타"로 묶는다. 합이 의미 없는 값(서로 다른 기준)은 세그먼트로 그리지 않는다. 칸 안 글자색은 템플릿이 정한다(c1은 `--on-s1`, c2–c5는 진한 글자). 흰 글자로 바꾸지 않는다. 라이트 모드에서 c2·c3·c5 위의 흰 글자는 3.2:1 이하로 읽기 어렵다.

## 7. 막대 차트 (범주별 크기)

막대 두께 ≤ 24px, 바닥은 각지고 끝은 4px 둥글게, 값은 막대 끝에. 단일 계열이면 범례 없이 제목이 설명한다.

좌표: 바닥 `B`, 막대 왼쪽 `x`, 너비 `w`(=24), 값 높이 `h` → 위쪽 `t = B - h`.

```
d = "M{x} {B} V{t+4} Q{x} {t} {x+4} {t} H{x+w-4} Q{x+w} {t} {x+w} {t+4} V{B} Z"
```

```html
<figure><div class="fig-scroll">
<svg class="chart bars" viewBox="0 0 380 206" style="max-width:440px" role="img" aria-label="무인 반납 비율: 10%, 25%, 40%">
  <line class="gl" x1="60" y1="50" x2="370" y2="50"/><line class="base" x1="60" y1="170" x2="370" y2="170"/>
  <text x="52" y="54" text-anchor="end">50%</text><text x="52" y="174" text-anchor="end">0%</text>
  <g><path class="f1" d="M108 170 V150 Q108 146 112 146 H128 Q132 146 132 150 V170 Z"/>
     <text class="val" x="120" y="138" text-anchor="middle">10%</text>
     <rect class="hit" x="90" y="40" width="60" height="134" tabindex="0" data-tip="10%|도입 전"/></g>
  <text class="lbl" x="120" y="192" text-anchor="middle">도입 전</text>
</svg></div>
<figcaption>주장 한 문장.</figcaption></figure>
```

`hit`은 투명한 넓은 영역이라 마우스·키보드로 툴팁을 띄운다. `data-tip="값|설명"`.

## 8. 선 차트 (시간에 따른 변화)

선 2px, 면은 같은 색 10%(`area1`), 점은 **실제 데이터가 있는 시점에만**. 간격이 불균등하면 x를 실제 시간 비율로 계산한다(빈 해가 있으면 점을 찍지 않고 캡션에 "자료 없음"). 라벨은 처음과 끝만, 나머지는 툴팁과 표로.

```html
<svg class="chart" viewBox="0 0 560 210" role="img" aria-label="…">
  <line class="gl" x1="60" y1="50" x2="540" y2="50"/> … <line class="base" x1="60" y1="170" x2="540" y2="170"/>
  <path class="area1" d="M70 170 L70 158 L259 122 L353.5 98 L511 74 L511 170 Z"/>
  <polyline class="ln1" points="70,158 259,122 353.5,98 511,74"/>
  <circle class="f1 ring" cx="70" cy="158" r="4.5"/> …
  <text class="val" x="78" y="150">5%</text><text class="val" x="511" y="61" text-anchor="middle">40%</text>
  <rect class="hit" x="471" y="40" width="80" height="135" tabindex="0" data-tip="40%|도입 14개월 차"/>
</svg>
<details class="tv"><summary>표로 보기</summary><div class="tbl"><table>…</table></div></details>
```

## 9. 덤벨 차트 (항목별 전→후)

같은 지표가 여러 항목에서 어떻게 바뀌었는지. 이전 점은 `fm`(회색), 이후 점은 `f1`, 사이는 `dumb` 선. 범례로 이전/이후를 밝힌다.

```html
<line class="dumb" x1="158" y1="40" x2="386" y2="40"/>
<circle class="fm ring" cx="158" cy="40" r="5"/><circle class="f1 ring" cx="386" cy="40" r="5.5"/>
<text x="158" y="29" text-anchor="middle">10%</text><text class="val" x="397" y="44">70%</text>
…
<div class="legend"><span><i class="dot" style="background:var(--muted)"></i>이전</span><span><i class="dot c1"></i>이후</span></div>
```

## 10. 간트 타임라인 (기간 + 사건)

`x(t) = x0 + (t - 시작연도) × 연도당px`. 막대는 양끝 둥근 `rx="4"`(바닥이 없는 기간 표시). 라벨은 막대 안(`text.in`: `f1` 막대이고 공간이 충분할 때만) 또는 밖(빈 쪽). `f2`–`f5` 막대의 라벨은 밖에 둔다. 사건은 `ev` 세로선 + `evl` 라벨을 맨 위 줄에, 서로 겹치지 않게 `text-anchor="end"`로 선 왼쪽에 둔다.

```html
<rect class="f1" x="100" y="76" width="240" height="16" rx="4"/>
<text class="in" x="108" y="88">본관 무인 반납기 · 4년</text>
<rect class="hit" x="96" y="70" width="248" height="28" tabindex="0" data-tip="4년|1년 차–4년 차"/>
<line class="ev" x1="340" y1="22" x2="340" y2="160"/>
<text class="evl" x="335" y="16" text-anchor="end">5년 차 · 분관으로 확대</text>
```

사건 선이 다른 줄의 라벨을 가로지르면 그 라벨을 줄이거나 반대편으로 옮긴다.

## 11. 박스-화살표 구조도 (메커니즘)

- 박스는 `rect.box`(핵심은 `.box key`), 두 줄 라벨은 굵은 제목(`text.b`) + 보조(`text.t2`).
- 선은 `path.edge`를 직각으로(`H`, `V`) 그리고 박스를 관통시키지 않는다. 같은 박스에서 두 선이 나가면 출발 y를 6–12px 띄운다.
- 화살표 라벨(`text.el`)은 "무엇이 오가는지"를 동사로(조회, 요청, 판정 = 라벨). 선 위쪽 6px, 박스와 겹치지 않는 빈 칸에.
- 피드백 루프(결과 → 개선)는 아래쪽으로 돌려 출발점으로 되돌린다.
- 그림마다 고유한 마커 id.

```html
<svg class="dg" viewBox="0 0 760 300" role="img" aria-label="구조도가 보여 주는 주장">
  <defs><marker id="ah-flow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path class="ahp" d="M0 0 L10 5 L0 10 z"/></marker></defs>
  <rect class="box" x="10" y="110" width="100" height="44" rx="6"/>
  <text x="60" y="128" text-anchor="middle" class="b">입력</text><text x="60" y="144" text-anchor="middle" class="t2">보조 설명</text>
  <rect class="box key" x="500" y="110" width="100" height="44" rx="6"/>
  <text x="550" y="137" text-anchor="middle" class="b">핵심 단계 ★</text>
  <path class="edge" d="M110 132 H498" marker-end="url(#ah-flow)"/>
  <text class="el" x="300" y="126" text-anchor="middle">요청</text>
</svg>
```

양방향은 `marker-start`와 `marker-end`를 함께. 강조 선은 `edge acc` + `ahp acc` 마커, 선택되지 않은 길은 `edge dash` + `ahp mut` 마커.

박스와 선 밑에 "핵심 결정"과 "예상 꼬리질문"을 `ul.notes`로 붙이면 말로 설명하는 연습 자료가 된다.

## 12. 나란한 비교도 (차이를 그린다)

두 선택지를 같은 배치로 좌우에 그리고, 가운데 `line.sep`으로 나눈다. **두 그림에서 달라지는 선이나 박스 하나**를 `acc`/`key`로 강조하고 캡션에 "차이는 이 선 하나"라고 쓴다. 각 패널 아래에 `+ 장점 / − 단점`을 `text.t2` 두 줄로.

선택지마다 따로 떠 있는 박스만 그리면 비교가 아니라 목록이다. 시스템의 같은 부분에 붙여서 그린다.

## 13. 셀·격자 그림 (저수준 원리)

메모리 배치, 패킷 필드, 비트 플래그처럼 "칸"이 원리인 것. 위에 인덱스(`text.t2`), 필드는 칸을 이어 붙인 `rect`, 규칙을 보여 주는 경계선(예: 8의 배수)은 `style="stroke:var(--accent)"` 세로선. 결과는 상태색 원 + 아이콘(✓/✕) + 글자 라벨.

```html
<rect x="178" y="44" width="271" height="36" rx="3" class="f1"/>
<text x="313.5" y="66" text-anchor="middle" style="fill:var(--on-s1)">반납 시각: uint64 · offset 2</text>
<circle cx="322" cy="98" r="7" class="st-crit"/><text x="322" y="102" text-anchor="middle" style="fill:#fff;font-size:10px">✕</text>
<text x="334" y="102">8바이트 경계를 넘음: 두 번 읽기</text>
```

실제 값이 확실하지 않은 예시 구조라면 캡션에 "예시 구조"라고 밝힌다.

## 14. 점 매트릭스 (항목 × 범주)

"이 지표를 어떤 예상 질문에 쓰나", "이 기능이 어떤 요구를 채우나" 같은 대응. ● 대표, ○ 보조. 첫 열은 항목 이름 + 핵심 숫자.

```html
<div class="tbl"><table class="matrix">
  <thead><tr><th>항목 (핵심 숫자)</th><th>범주 A</th><th>범주 B</th></tr></thead>
  <tbody><tr><td>항목 1 (10% → 40%)</td><td class="dot-main">●</td><td class="dot-sub">○</td></tr></tbody>
</table></div>
<p class="small muted">● 대표 · ○ 보조</p>
```

## 15. 계산기 (독자가 실측값을 넣을 때)

독자가 현장에서 잰 값으로 판단해야 할 때만. 처음 값은 예시로 채우고 `tag-ex`로 "예시 숫자"를 표시한다. 사용자가 값을 바꾸면 태그를 숨긴다. 결과는 세그먼트 막대 + 한 줄 판정("가장 큰 단계: …"). 값은 `localStorage`에 저장.

템플릿의 `calc` 예시 블록과 스크립트를 복사해 단계 이름과 예시 값만 바꾼다.

## 16. 일정·체크리스트

- 일정: `.days > .day[data-from][data-to]`. 스크립트가 오늘(지정한 시간대 기준)을 `today`, 지난 날을 `past`로 표시한다.
- 체크리스트: `ul.check > li > input[type=checkbox][id][data-key] + label[for]`. `data-key`로 저장된다. id는 페이지 안에서 고유하게.
- 남은 빈칸 목록은 체크리스트로 두고, 각 항목에서 해당 섹션으로 링크한다.

## 17. SVG 좌표 어림 계산

- 글자 폭: 한글 ≈ 글자 크기 × 1.0, 라틴·숫자 ≈ × 0.6, 공백 ≈ × 0.3, 가운뎃점 ≈ × 0.5. 12px 한글 6자 ≈ 72px.
- 박스 너비 = 가장 긴 줄 폭 + 좌우 12px 이상.
- 두 줄 박스: 높이 44, 첫 줄 y = 위 + 18, 둘째 줄 y = 위 + 34 (12px/11px 기준).
- 선 라벨: 수평선 y보다 6px 위. 수직선 옆 라벨은 선에서 6px 띄우고 반대편 박스와도 4px 이상.
- 막대·선 차트의 y 눈금은 깔끔한 값(0, 25, 50 / 0, 10, 20…)으로, 차트가 실제로 닿는 범위만.
- viewBox 바깥 여백: 가장 바깥 라벨이 잘리지 않게 좌우 10px, 아래 20px 이상.
