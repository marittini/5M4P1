-- 핵심 기능 (Aseprite UI와 분리되어 있어 테스트 가능)
-- 모든 함수는 RGB 이미지를 다룹니다. pc = app.pixelColor
local M = {}

-- ---------------------------------------------------------------- 색 유틸
local function srgbToLinear(c)
  c = c / 255
  if c > 0.04045 then return ((c + 0.055) / 1.055) ^ 2.4 end
  return c / 12.92
end

local function labF(t)
  if t > 0.008856 then return t ^ (1 / 3) end
  return 7.787 * t + 16 / 116
end

function M.lab(r, g, b)
  local R, G, B = srgbToLinear(r), srgbToLinear(g), srgbToLinear(b)
  local x = (0.4124 * R + 0.3576 * G + 0.1805 * B) / 0.95047
  local y = (0.2126 * R + 0.7152 * G + 0.0722 * B)
  local z = (0.0193 * R + 0.1192 * G + 0.9505 * B) / 1.08883
  local fx, fy, fz = labF(x), labF(y), labF(z)
  return 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)
end

function M.luma(r, g, b) return (0.299 * r + 0.587 * g + 0.114 * b) / 255 end

local function key(r, g, b) return r * 65536 + g * 256 + b end
M.key = key

-- RGB <-> HSL (0..1)
function M.rgbToHsl(r, g, b)
  r, g, b = r / 255, g / 255, b / 255
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local l = (mx + mn) / 2
  if mx == mn then return 0, 0, l end
  local d = mx - mn
  local s = l > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
  local h
  if mx == r then h = (g - b) / d + (g < b and 6 or 0)
  elseif mx == g then h = (b - r) / d + 2
  else h = (r - g) / d + 4 end
  return h / 6, s, l
end

local function hue2rgb(p, q, t)
  if t < 0 then t = t + 1 end
  if t > 1 then t = t - 1 end
  if t < 1 / 6 then return p + (q - p) * 6 * t end
  if t < 1 / 2 then return q end
  if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
  return p
end

function M.hslToRgb(h, s, l)
  if s == 0 then local v = math.floor(l * 255 + 0.5); return v, v, v end
  local q = l < 0.5 and l * (1 + s) or l + s - l * s
  local p = 2 * l - q
  return math.floor(hue2rgb(p, q, h + 1 / 3) * 255 + 0.5),
         math.floor(hue2rgb(p, q, h) * 255 + 0.5),
         math.floor(hue2rgb(p, q, h - 1 / 3) * 255 + 0.5)
end

-- ---------------------------------------------------------------- 팔레트 추출
-- img 의 (x,y,w,h) 픽셀 영역에서 불투명 색을 세어 count >= minCount 인 색 목록 반환 (밝기순)
function M.colorsInRect(img, pc, x0, y0, w, h, minCount)
  local counts, cols = {}, {}
  for y = y0, y0 + h - 1 do
    for x = x0, x0 + w - 1 do
      if x >= 0 and y >= 0 and x < img.width and y < img.height then
        local v = img:getPixel(x, y)
        if pc.rgbaA(v) == 255 then
          local r, g, b = pc.rgbaR(v), pc.rgbaG(v), pc.rgbaB(v)
          local k = key(r, g, b)
          if not counts[k] then counts[k] = 0; cols[#cols + 1] = { r = r, g = g, b = b, k = k } end
          counts[k] = counts[k] + 1
        end
      end
    end
  end
  local out = {}
  for _, c in ipairs(cols) do
    c.count = counts[c.k]
    if c.count >= (minCount or 1) then out[#out + 1] = c end
  end
  table.sort(out, function(a, b) return M.luma(a.r, a.g, a.b) < M.luma(b.r, b.g, b.b) end)
  return out
end

-- 색 목록에서 밝기 단계 n개 대표색 (자주 쓰인 색 우선) -> 명암 램프
function M.ramp(colors, n)
  n = n or 5
  if #colors <= n then return colors end
  local out = {}
  for i = 1, n do
    local lo = math.floor((i - 1) * #colors / n) + 1
    local hi = math.floor(i * #colors / n)
    local best
    for j = lo, hi do
      if not best or colors[j].count > best.count then best = colors[j] end
    end
    out[#out + 1] = best
  end
  return out
end

-- ---------------------------------------------------------------- 픽셀 접근 도우미
-- ctx = { img=Image, pc=pc, ox=, oy= (cel 위치), inSel=function(cx,cy) }
local function sel(ctx, x, y)
  if not ctx.inSel then return true end
  return ctx.inSel(x + (ctx.ox or 0), y + (ctx.oy or 0))
end

local function rgba(ctx, x, y)
  local v = ctx.img:getPixel(x, y)
  local pc = ctx.pc
  return pc.rgbaR(v), pc.rgbaG(v), pc.rgbaB(v), pc.rgbaA(v)
end

-- ---------------------------------------------------------------- 1) 팔레트에 맞추기 (Lab 최근접)
function M.snapToPalette(ctx, palette)
  local labs = {}
  for i, c in ipairs(palette) do
    local L, a, b = M.lab(c.r, c.g, c.b); labs[i] = { L, a, b }
  end
  local cache, changed = {}, 0
  local img, pc = ctx.img, ctx.pc
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do
      if sel(ctx, x, y) then
        local r, g, b, a = rgba(ctx, x, y)
        if a > 0 then
          local k = key(r, g, b)
          local best = cache[k]
          if not best then
            local L, A, B = M.lab(r, g, b)
            local bd = math.huge
            for i, l in ipairs(labs) do
              local d = (L - l[1]) ^ 2 + 0.8 * (A - l[2]) ^ 2 + 0.8 * (B - l[3]) ^ 2
              if d < bd then bd, best = d, palette[i] end
            end
            cache[k] = best
          end
          if best.r ~= r or best.g ~= g or best.b ~= b then
            img:drawPixel(x, y, pc.rgba(best.r, best.g, best.b, a)); changed = changed + 1
          end
        end
      end
    end
  end
  return changed
end

-- ---------------------------------------------------------------- 2) 검은 외곽선 -> 재질색 외곽선
-- 아주 어두운 '선' 픽셀(주변 어두운 픽셀이 적은 것)만 바꾸고, 문/유리처럼 넓은 어두운 면은 유지
function M.selout(ctx, opts)
  opts = opts or {}
  local thr = opts.darkness or 0.13
  local base = opts.outline or { r = 0x2b, g = 0x0a, b = 0x1f } -- 바닐라 살롱 외곽선 색
  local img, pc = ctx.img, ctx.pc
  local W, H = img.width, img.height
  local dark, op = {}, {}
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local r, g, b, a = rgba(ctx, x, y)
      local i = y * W + x
      op[i] = a > 0
      dark[i] = a > 0 and M.luma(r, g, b) < thr
    end
  end
  local changes = {}
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local i = y * W + x
      if dark[i] and sel(ctx, x, y) then
        local dn, edge, tally, best, bestN = 0, false, {}, nil, 0
        for dy = -1, 1 do
          for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
              local xx, yy = x + dx, y + dy
              if xx < 0 or yy < 0 or xx >= W or yy >= H then edge = true
              else
                local j = yy * W + xx
                if not op[j] then edge = true
                elseif dark[j] then dn = dn + 1
                else
                  local r, g, b = rgba(ctx, xx, yy)
                  local k = key(r, g, b)
                  tally[k] = (tally[k] or 0) + 1
                  if tally[k] > bestN then bestN, best = tally[k], { r, g, b } end
                end
              end
            end
          end
        end
        if dn < 6 and best then
          local k = edge and 0.30 or 0.45
          local r = base.r * (1 - k) + best[1] * k * 0.75
          local g = base.g * (1 - k) + best[2] * k * 0.75
          local b = base.b * (1 - k) + best[3] * k * 0.75
          local h, s, l = M.rgbToHsl(r, g, b)
          l = math.min(l, edge and 0.20 or 0.27)
          s = math.min(1, s * 1.1)
          local R, G, B = M.hslToRgb(h, s, l)
          local _, _, _, a = rgba(ctx, x, y)
          changes[#changes + 1] = { x, y, pc.rgba(R, G, B, a) }
        end
      end
    end
  end
  for _, c in ipairs(changes) do img:drawPixel(c[1], c[2], c[3]) end
  return #changes
end

-- ---------------------------------------------------------------- 3) 외톨이/삐죽 픽셀 제거
-- 실루엣에서 상하좌우 불투명 이웃이 1개 이하인 픽셀을 반복 제거
function M.despur(ctx)
  local img, pc = ctx.img, ctx.pc
  local W, H = img.width, img.height
  local total = 0
  local function opaque(x, y)
    if x < 0 or y < 0 or x >= W or y >= H then return false end
    return pc.rgbaA(img:getPixel(x, y)) > 0
  end
  while true do
    local kill = {}
    for y = 0, H - 1 do
      for x = 0, W - 1 do
        if opaque(x, y) and sel(ctx, x, y) then
          local n = (opaque(x - 1, y) and 1 or 0) + (opaque(x + 1, y) and 1 or 0)
                  + (opaque(x, y - 1) and 1 or 0) + (opaque(x, y + 1) and 1 or 0)
          if n <= 1 then kill[#kill + 1] = { x, y } end
        end
      end
    end
    if #kill == 0 then break end
    for _, p in ipairs(kill) do img:drawPixel(p[1], p[2], pc.rgba(0, 0, 0, 0)) end
    total = total + #kill
  end
  return total
end

-- ---------------------------------------------------------------- 4) 좌우대칭 (왼쪽 기준)
-- axis2 = 대칭축 x 좌표의 2배 (캔버스 기준). 예: 폭 248 캔버스 전체 => axis2 = 248
function M.mirrorLeft(ctx, axis2)
  local img = ctx.img
  local ox = ctx.ox or 0
  local n = 0
  local copy = {}
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do
      local cx = x + ox
      if cx * 2 < axis2 then
        local mx = (axis2 - 1 - cx) - ox
        if mx >= 0 and mx < img.width and sel(ctx, mx, y) then
          copy[#copy + 1] = { mx, y, img:getPixel(x, y) }
        end
      end
    end
  end
  for _, c in ipairs(copy) do
    if img:getPixel(c[1], c[2]) ~= c[3] then n = n + 1 end
    img:drawPixel(c[1], c[2], c[3])
  end
  return n
end

-- ---------------------------------------------------------------- 5) 벽돌 패턴 깔기
-- ramp: 어두운->밝은 5색 {r,g,b}. 선택 영역 안의 불투명 픽셀에 바닐라식 벽돌 패턴을 그림.
-- 원래 픽셀이 어두우면(그늘) 한 단계 어둡게 유지.
function M.brick(ctx, ramp, courseH, brickW)
  courseH, brickW = courseH or 4, brickW or 8
  local img, pc = ctx.img, ctx.pc
  local ox, oy = ctx.ox or 0, ctx.oy or 0
  local n = #ramp
  local function at(k)
    k = math.max(1, math.min(n, k)); local c = ramp[k]; return c.r, c.g, c.b
  end
  -- 원래 밝기 중앙값 → 그늘 판단 기준
  local ls = {}
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do
      if sel(ctx, x, y) then
        local r, g, b, a = rgba(ctx, x, y)
        if a > 0 then ls[#ls + 1] = M.luma(r, g, b) end
      end
    end
  end
  if #ls == 0 then return 0 end
  table.sort(ls)
  local med = ls[math.floor(#ls / 2) + 1]
  local cnt = 0
  local mid = math.ceil(n / 2) + (n >= 5 and 1 or 0) -- 5색 기준 4번째가 벽돌 기본색
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do
      if sel(ctx, x, y) then
        local r, g, b, a = rgba(ctx, x, y)
        if a > 0 then
          local cx, cy = x + ox, y + oy
          local course, ry = cy // courseH, cy % courseH
          local off = (course % 2 == 1) and (brickW // 2) or 0
          local bx, rx = (cx + off) // brickW, (cx + off) % brickW
          local base = mid
          if M.luma(r, g, b) < med - 0.08 then base = base - 1 end
          if (bx * 5 + course * 3) % 7 == 0 then base = base - 1 end
          local k
          if ry == courseH - 1 then k = base - 2
          elseif rx == brickW - 1 then k = (ry == 0) and base - 1 or base - 2
          elseif ry == 0 then k = base + 1
          elseif ry == courseH - 2 and rx == 0 then k = base - 1
          else k = base end
          local R, G, B = at(k)
          img:drawPixel(x, y, pc.rgba(R, G, B, a)); cnt = cnt + 1
        end
      end
    end
  end
  return cnt
end

-- ---------------------------------------------------------------- 6) 검사
-- 결과: { colors=고유색 수, offPalette=, black=, stray=, asym= , marks={ {x,y,kind}... } }
function M.check(ctx, palette, axis2)
  local img, pc = ctx.img, ctx.pc
  local W, H = img.width, img.height
  local ox = ctx.ox or 0
  local pal = {}
  if palette then for _, c in ipairs(palette) do pal[key(c.r, c.g, c.b)] = true end end
  local seen, ncol = {}, 0
  local res = { offPalette = 0, black = 0, stray = 0, asym = 0, marks = {} }
  local function opaque(x, y)
    if x < 0 or y < 0 or x >= W or y >= H then return false end
    return pc.rgbaA(img:getPixel(x, y)) > 0
  end
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local r, g, b, a = rgba(ctx, x, y)
      if a > 0 and sel(ctx, x, y) then
        local k = key(r, g, b)
        if not seen[k] then seen[k] = true; ncol = ncol + 1 end
        if palette and not pal[k] then
          res.offPalette = res.offPalette + 1; res.marks[#res.marks + 1] = { x, y, "off" }
        end
        if r + g + b < 30 then res.black = res.black + 1; res.marks[#res.marks + 1] = { x, y, "black" } end
        local nb = (opaque(x - 1, y) and 1 or 0) + (opaque(x + 1, y) and 1 or 0)
                 + (opaque(x, y - 1) and 1 or 0) + (opaque(x, y + 1) and 1 or 0)
        if nb <= 1 then res.stray = res.stray + 1; res.marks[#res.marks + 1] = { x, y, "stray" } end
        if axis2 then
          local mx = (axis2 - 1 - (x + ox)) - ox
          if (x + ox) * 2 < axis2 and mx >= 0 and mx < W then
            if img:getPixel(mx, y) ~= img:getPixel(x, y) then
              res.asym = res.asym + 1; res.marks[#res.marks + 1] = { mx, y, "asym" }
            end
          end
        end
      end
    end
  end
  res.colors = ncol
  return res
end

return M
