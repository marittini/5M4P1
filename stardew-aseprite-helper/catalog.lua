-- 바닐라 재질 카탈로그
-- 각 항목: 이름, 타일시트(Content/Maps 안의 파일 이름), 타일 좌표(x, y, 너비, 높이 / 1타일 = 16px), 메모
-- 자유롭게 추가/수정하세요. 좌표는 타일 단위입니다. 예) Maps/spring_town.png 의 (15,16) 타일 = 픽셀 (240,256)
local C = {
  { name = "벽돌 - 노랑 (살롱 벽)", short = "노란 벽돌",      sheet = "spring_town", x = 16, y = 16, w = 1, h = 1,
    note = "벽돌 한 줄은 4칸 높이. 맨 윗줄은 밝게, 맨 아랫줄은 진하게(틈). 8칸마다 세로 틈, 줄마다 반 칸씩 엇갈리게" },
  { name = "벽돌 - 붉은 (집 굴뚝)", short = "굴뚝 벽돌",      sheet = "spring_town", x = 7,  y = 11, w = 1, h = 1,
    note = "벽돌 사이 틈은 진한 적갈색. 벽돌 윗면에 밝은 줄 1칸" },
  { name = "석재 - 담장", short = "돌담",                sheet = "spring_town", x = 12, y = 29, w = 9, h = 3,
    note = "큰 돌 하나하나 윗면은 밝게, 아래는 2칸 정도 그림자" },
  { name = "석재 - 집 기초", short = "돌 기초",             sheet = "spring_town", x = 3,  y = 8,  w = 3, h = 1,
    note = "건물 맨 아랫단에 까는 돌" },
  { name = "바닥 - 원형 광장 벽돌", short = "돌바닥",      sheet = "spring_town", x = 26, y = 26, w = 6, h = 6,
    note = "바닥 돌 포장 무늬" },
  { name = "지붕 - 주황 기와", short = "주황 지붕",           sheet = "spring_town", x = 1,  y = 1,  w = 3, h = 3,
    note = "기와 줄은 지붕 경사를 따라 비스듬히. 빛 받는 쪽은 밝게, 반대쪽은 어둡게" },
  { name = "지붕 - 보라 기와", short = "보라 지붕",           sheet = "spring_town", x = 9,  y = 3,  w = 2, h = 2,
    note = "보라색 기와 지붕" },
  { name = "지붕 - 살롱 (어두운 슬레이트)", short = "어두운 지붕", sheet = "spring_town", x = 15, y = 12, w = 3, h = 3,
    note = "어두운 돌판 지붕. 군데군데 밝은 반사 점" },
  { name = "벽 - 크림 가로판자", short = "크림 판자",         sheet = "spring_town", x = 3,  y = 6,  w = 1, h = 2,
    note = "가로 판자. 판자마다 윗줄은 밝게, 아랫줄은 어둡게" },
  { name = "벽 - 파란 세로판자", short = "파란 판자",         sheet = "spring_town", x = 9,  y = 6,  w = 2, h = 2,
    note = "세로 판자 벽" },
  { name = "창문 - 살롱", short = "창문",                sheet = "spring_town", x = 16, y = 17, w = 1, h = 1,
    note = "창틀은 진하게, 유리 맨 윗줄은 그늘, 반짝이는 점 1칸, 아래에 창턱" },
  { name = "문 - 살롱", short = "나무 문",                  sheet = "spring_town", x = 20, y = 17, w = 1, h = 2,
    note = "세로 판자 문. 손잡이에 밝은 점" },
  { name = "분수", short = "분수",                       sheet = "spring_town", x = 16, y = 32, w = 5, h = 5,
    note = "돌 테두리와 물" },
  { name = "벤치", short = "벤치",                       sheet = "spring_town", x = 2,  y = 10, w = 2, h = 1,
    note = "나무 벤치" },
  { name = "가로등", short = "가로등",                     sheet = "spring_town", x = 11, y = 28, w = 1, h = 4,
    note = "철제 가로등" },
  { name = "나무 - 참나무", short = "나뭇잎",              sheet = "spring_outdoorsTileSheet", x = 0,  y = 0, w = 3, h = 4,
    note = "잎 덩어리 윗면은 밝게, 아랫면은 어둡게. 잎 모양 작은 덩어리로" },
  { name = "나무 - 벚꽃", short = "벚꽃",                sheet = "spring_outdoorsTileSheet", x = 16, y = 0, w = 5, h = 4,
    note = "분홍 꽃잎 덩어리" },
  { name = "덤불", short = "덤불",                       sheet = "spring_outdoorsTileSheet", x = 13, y = 0, w = 3, h = 3,
    note = "둥근 덤불" },
  { name = "잔디", short = "잔디",                       sheet = "spring_outdoorsTileSheet", x = 0,  y = 7, w = 1, h = 1,
    note = "기본 잔디 (마을에서 가장 많이 쓰이는 타일)" },
}

-- ③ 재질 탭: 벽·바닥 무늬 (px = 이음새 없이 반복되는 영역, 픽셀 단위 x, y, 너비, 높이)
-- 바닐라 건물 벽 한가운데(그림자·창문·테두리 없는 곳)에서 골라 반복해도 이어지는지 확인한 영역입니다.
C.fills = {
  { name = "노란 벽돌", sheet = "spring_town", px = { 263, 294, 16, 16 }, from = "살롱 벽" },
  { name = "붉은 벽돌", sheet = "spring_town", px = { 263, 294, 16, 16 }, hue = -20, from = "살롱 벽 (색만 붉게)" },
  { name = "돌벽", sheet = "spring_town", px = { 428, 88, 16, 8 }, from = "대장간 벽" },
  { name = "크림 판자", sheet = "spring_town", px = { 54, 93, 16, 16 }, from = "주황 지붕 집 벽" },
  { name = "하늘색 벽", sheet = "spring_town", px = { 18, 261, 24, 8 }, from = "병원 벽" },
  { name = "파란 판자", sheet = "spring_town", px = { 194, 109, 24, 16 }, from = "파란 집 벽" },
  { name = "돌바닥", sheet = "spring_town", px = { 416, 416, 16, 16 }, from = "광장 바닥" },
  { name = "잔디", sheet = "spring_outdoorsTileSheet", px = { 0, 112, 16, 16 }, from = "기본 잔디" },
}

-- 지붕: 왼쪽 경사(그늘 면) / 오른쪽 경사(빛 받는 면)를 따로 반복
C.roofs = {
  { name = "주황 지붕", sheet = "spring_town", left = { 12, 56, 8, 16 }, right = { 37, 25, 8, 16 }, from = "주황 지붕 집" },
  { name = "보라 지붕", sheet = "spring_town", left = { 155, 49, 16, 12 }, right = { 220, 58, 12, 12 }, from = "파란 집" },
  { name = "어두운 지붕", sheet = "spring_town", left = { 256, 223, 12, 12 }, right = { 305, 188, 12, 12 }, from = "살롱" },
}

return C
