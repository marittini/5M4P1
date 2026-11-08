-- Stardew 도트 도우미: 대화창 (초보자용)
-- open(env): env = { dir=플러그인 폴더, prefs=저장 테이블, bounds=창 위치(선택), tab=처음 열 탭(선택) }
local U = {}

local PRESETS = {
  { name = "작은 집 (6 x 7칸)",   w = 6,  h = 7,  gw = 16, gh = 16 },
  { name = "큰 건물 (12 x 9칸)",  w = 12, h = 9,  gw = 16, gh = 16 },
  { name = "나무 / 큰 소품 (3 x 6칸)",   w = 3,  h = 6,  gw = 16, gh = 16 },
  { name = "작은 소품 (1 x 2칸)",        w = 1,  h = 2,  gw = 16, gh = 16 },
  { name = "바닥 타일 (4 x 4칸)",        w = 4,  h = 4,  gw = 16, gh = 16 },
  { name = "NPC 초상화 (64 x 64)",        pw = 64, ph = 64,  gw = 16, gh = 16 },
  { name = "NPC 걷는 모습 (64 x 128)",          pw = 64, ph = 128, gw = 16, gh = 32 },
  { name = "직접 크기 정하기",                      custom = true, gw = 16, gh = 16 },
}

local HELP = {
  "■ 꼭 알아야 할 조작 (영어 자판 기준 단축키)",
  "B : 연필 (한 칸씩 찍기)          E : 지우개",
  "Alt + 클릭 : 그림에서 색 뽑기 (스포이드)",
  "마우스 휠 : 확대 / 축소           Space + 끌기 : 화면 이동",
  "Ctrl + Z : 되돌리기              Ctrl + Y : 다시 하기",
  "Ctrl + ' : 격자(칸) 보이기 / 숨기기",
  "M : 사각형 선택    Ctrl + C / Ctrl + V : 복사 / 붙여넣기",
  "",
  "■ 추천 순서",
  "① 시작 탭에서 그릴 것을 고르고 '새 그림 만들기'",
  "② 색 탭에서 색을 누르고 연필(B)로 칸을 찍기",
  "③ 재질 탭: 칠할 곳을 선택(M)하고 재질 버튼 → 바닐라 무늬로 채우기",
  "④ 다 그리면 다듬기 탭의 '자동으로 다듬기'",
  "⑤ 미리보기 탭에서 스타듀 건물과 비교 → PNG로 저장",
}

function U.open(env)
  local core = dofile(app.fs.joinPath(env.dir, "core.lua"))
  local catalog = dofile(app.fs.joinPath(env.dir, "catalog.lua"))
  local prefs = env.prefs
  local pc = app.pixelColor
  local sheetCache = {}
  local REF_NAME = "참고 그림 (잠김)"
  local MARK_NAME = "문제 표시 (지워도 됨)"
  local DRAW_NAME = "그림"

  -- ------------------------------------------------------------ 공통 도우미
  local function mapsDir() return prefs.mapsDir end

  local function shortPath(p)
    if not p then return "아직 지정 안 됨" end
    if #p > 48 then return "..." .. p:sub(-45) end
    return p
  end

  local function loadSheet(name, quiet)
    if sheetCache[name] then return sheetCache[name] end
    local dir = mapsDir()
    local path = dir and app.fs.joinPath(dir, name .. ".png")
    if not path or not app.fs.isFile(path) then
      if not quiet then
        app.alert{ title = "Stardew 도우미", text = {
          "스타듀 그림 폴더가 아직 지정되지 않았어요.",
          "'⑥ 설정' 탭에서 Maps 폴더 안의 spring_town.png 를 골라 주세요.",
          "(Content (unpacked)\\Maps 또는 Stardew Sim 의 web\\data\\img\\Maps)" } }
      end
      return nil
    end
    local img = Image{ fromFile = path }
    if img.colorMode ~= ColorMode.RGB then
      local rgb = Image(img.width, img.height, ColorMode.RGB)
      rgb:drawImage(img)
      img = rgb
    end
    sheetCache[name] = img
    return img
  end

  local function materialColors(m, minCount, quiet)
    local img = loadSheet(m.sheet, quiet)
    if not img then return nil end
    return core.colorsInRect(img, pc, m.x * 16, m.y * 16, m.w * 16, m.h * 16, minCount or 1)
  end

  local function allVanillaColors(quiet)
    local all, seen = {}, {}
    for _, m in ipairs(catalog) do
      local cols = materialColors(m, 3, quiet)
      if not cols then return nil end
      for _, c in ipairs(cols) do
        if not seen[c.k] then seen[c.k] = c; all[#all + 1] = c else seen[c.k].count = seen[c.k].count + c.count end
      end
    end
    table.sort(all, function(a, b) return a.count > b.count end)
    while #all > 254 do table.remove(all) end
    table.sort(all, function(a, b) return core.luma(a.r, a.g, a.b) < core.luma(b.r, b.g, b.b) end)
    return all
  end

  local function setSpritePalette(spr, colors)
    local pal = Palette(#colors + 1)
    pal:setColor(0, Color{ r = 0, g = 0, b = 0, a = 0 })
    for i, c in ipairs(colors) do pal:setColor(i, Color{ r = c.r, g = c.g, b = c.b, a = 255 }) end
    spr:setPalette(pal)
  end

  local function spritePaletteColors(spr)
    local out, pal = {}, spr.palettes[1]
    for i = 0, #pal - 1 do
      local c = pal:getColor(i)
      if c.alpha > 0 then out[#out + 1] = { r = c.red, g = c.green, b = c.blue } end
    end
    return out
  end

  -- 보정으로 새로 생긴 색을 팔레트 끝에 추가
  local function addImageColorsToPalette(spr, img)
    local pal = spr.palettes[1]
    local have = {}
    for i = 0, #pal - 1 do local c = pal:getColor(i); have[core.key(c.red, c.green, c.blue)] = true end
    local new = {}
    for y = 0, img.height - 1 do
      for x = 0, img.width - 1 do
        local v = img:getPixel(x, y)
        if pc.rgbaA(v) > 0 then
          local r, g, b = pc.rgbaR(v), pc.rgbaG(v), pc.rgbaB(v)
          local k = core.key(r, g, b)
          if not have[k] then have[k] = true; new[#new + 1] = Color{ r = r, g = g, b = b, a = 255 } end
        end
      end
    end
    if #new == 0 or #pal + #new > 256 then return end
    local np = Palette(#pal + #new)
    for i = 0, #pal - 1 do np:setColor(i, pal:getColor(i)) end
    for i, c in ipairs(new) do np:setColor(#pal + i - 1, c) end
    spr:setPalette(np)
  end

  local function isHelperLayer(layer)
    return layer.name == REF_NAME or layer.name == MARK_NAME
  end

  -- 그림 그릴 레이어: 지금 레이어가 참고/표시 레이어면 다른 레이어로
  local function drawingLayer(spr)
    local l = app.activeLayer
    if l and l.sprite and l.sprite.id == spr.id and not isHelperLayer(l) and not l.isGroup then return l end
    for i = #spr.layers, 1, -1 do
      local layer = spr.layers[i]
      if not isHelperLayer(layer) and not layer.isGroup then return layer end
    end
    return nil
  end

  -- 현재 그림 레이어에 작업 적용 (Ctrl+Z 한 번으로 취소)
  local function withCel(title, fn)
    local spr = app.activeSprite
    if not spr then app.alert("먼저 그림을 열거나 '① 시작' 탭에서 새 그림을 만들어 주세요."); return end
    if spr.colorMode ~= ColorMode.RGB then
      app.alert{ title = "Stardew 도우미", text = { "이 그림은 RGB 모드가 아니라서 다듬을 수 없어요.",
        "위 메뉴 Sprite(스프라이트) > Color Mode(색상 모드) > RGB 로 바꾼 뒤 다시 눌러 주세요." } }
      return
    end
    local layer = drawingLayer(spr)
    local cel = layer and layer:cel(app.activeFrame)
    if not cel then app.alert("아직 그린 게 없어요. 먼저 그림을 그려 주세요."); return end
    app.activeLayer = layer
    local img = cel.image:clone()
    local selection = spr.selection
    local ctx = { img = img, pc = pc, ox = cel.position.x, oy = cel.position.y }
    if selection and not selection.isEmpty then
      ctx.inSel = function(x, y) return selection:contains(x, y) end
    end
    local result
    app.transaction(title, function()
      result = fn(ctx, spr, cel)
      cel.image = img
    end)
    app.refresh()
    return result
  end

  -- 그림 레이어를 캔버스 크기 이미지로 펼쳐서 작업 (빈 곳에도 칠할 수 있게)
  local function withCanvasCel(title, fn)
    local spr = app.activeSprite
    if not spr then app.alert("먼저 그림을 열거나 '① 시작' 탭에서 새 그림을 만들어 주세요."); return end
    if spr.colorMode ~= ColorMode.RGB then
      app.alert{ title = "Stardew 도우미", text = { "이 그림은 RGB 모드가 아니라서 칠할 수 없어요.",
        "위 메뉴 Sprite(스프라이트) > Color Mode(색상 모드) > RGB 로 바꾼 뒤 다시 눌러 주세요." } }
      return
    end
    local layer = drawingLayer(spr)
    if not layer then app.alert("그림 레이어가 없어요."); return end
    if not layer.isEditable then app.alert("이 레이어는 잠겨 있어요. 레이어 이름 옆 자물쇠를 풀어 주세요."); return end
    app.activeLayer = layer
    local frame = app.activeFrame
    local cel = layer:cel(frame)
    local full = Image(spr.width, spr.height, ColorMode.RGB)
    if cel then full:drawImage(cel.image, cel.position) end
    local selection = spr.selection
    local ctx = { img = full, pc = pc, ox = 0, oy = 0 }
    if selection and not selection.isEmpty then
      ctx.inSel = function(x, y) return selection:contains(x, y) end
    end
    local result
    app.transaction(title, function()
      result = fn(ctx, spr)
      if cel then cel.image = full; cel.position = Point(0, 0)
      else spr:newCel(layer, frame, full, Point(0, 0)) end
    end)
    app.refresh()
    return result
  end

  local function axis2For(spr)
    local s = spr.selection
    if s and not s.isEmpty then return s.bounds.x * 2 + s.bounds.width end
    return spr.width
  end

  local function setupDrawing(spr, gw, gh)
    spr.gridBounds = Rectangle(0, 0, gw or 16, gh or 16)
    pcall(function() app.preferences.document(spr).show.grid = true end)
    pcall(function() app.tool = "pencil" end)
    pcall(function() app.brush = Brush(1) end)
    pcall(function() app.preferences.tool("pencil").freehand_algorithm = 1 end) -- 픽셀 퍼펙트
    pcall(function() app.command.FitScreen() end)
  end

  -- 참고/표시 레이어를 빼고 한 장으로 합친 그림
  local function flatten(spr)
    local hidden = {}
    for _, layer in ipairs(spr.layers) do
      if isHelperLayer(layer) and layer.isVisible then layer.isVisible = false; hidden[#hidden + 1] = layer end
    end
    local img = Image(spr)
    for _, layer in ipairs(hidden) do layer.isVisible = true end
    return img
  end

  local function splitNote(t)
    t = "요령: " .. (t or "")
    if #t < 50 then return t, "" end
    local mid, best = #t // 2, nil
    for i = 1, #t do
      if t:sub(i, i) == " " and (not best or math.abs(i - mid) < math.abs(best - mid)) then best = i end
    end
    if not best then return t, "" end
    return t:sub(1, best - 1), t:sub(best + 1)
  end

  -- 파일 선택 칸은 '상대 경로'를 돌려줄 수 있어서, 여러 기준 폴더로 실제 파일을 찾아봄
  local function resolveFile(p)
    if not p or p == "" then return nil end
    if app.fs.isFile(p) then return p end
    local bases = { app.fs.currentPath, app.fs.userDocsPath }
    local spr = app.activeSprite
    if spr and spr.filename and spr.filename ~= "" then table.insert(bases, 1, app.fs.filePath(spr.filename)) end
    for _, b in ipairs(bases) do
      if b and b ~= "" then
        local q = app.fs.normalizePath(app.fs.joinPath(b, p))
        if app.fs.isFile(q) then return q end
      end
    end
    return nil
  end

  local function fontPath(name) return app.fs.joinPath(env.dir, "fonts", name) end

  -- ------------------------------------------------------------ 대화창
  local dlg = Dialog{ title = "Stardew 도트 도우미" }
  local hasTabs = false
  pcall(function() hasTabs = dlg.tab ~= nil end)
  local function tab(id, text)
    if hasTabs then dlg:tab{ id = id, text = text } else dlg:separator{ text = text } end
    dlg:newrow()
  end
  local function reopen(tabId)
    local b = dlg.bounds
    dlg:close()
    env.bounds = b
    env.tab = tabId
    U.open(env)
  end

  -- ① 시작하기 --------------------------------------------------
  tab("t_start", "① 시작")
  local presetNames = {}
  for i, p in ipairs(PRESETS) do presetNames[i] = p.name end
  local function preset(name) for _, p in ipairs(PRESETS) do if p.name == name then return p end end return PRESETS[1] end

  dlg:label{ text = "무엇을 그릴까요? (1칸 = 16 x 16 픽셀)" }
  dlg:combobox{ id = "kind", option = presetNames[1], options = presetNames,
    onchange = function()
      local c = preset(dlg.data.kind).custom == true
      dlg:modify{ id = "cw", visible = c }; dlg:modify{ id = "ch", visible = c }
    end }
  dlg:number{ id = "cw", label = "가로 칸 수", text = "8", decimals = 0, visible = false }
  dlg:number{ id = "ch", label = "세로 칸 수", text = "8", decimals = 0, visible = false }
  dlg:check{ id = "useRef", text = "참고 그림 깔고 따라 그리기",
    selected = false, onclick = function() dlg:modify{ id = "refFile", visible = dlg.data.useRef } end }
  dlg:file{ id = "refFile", open = true, filetypes = { "png", "jpg", "jpeg", "webp" }, visible = false }
  dlg:button{ id = "newBtn", text = "새 그림 만들기", onclick = function()
    local p = preset(dlg.data.kind)
    local W, H
    if p.custom then W, H = math.max(1, dlg.data.cw) * 16, math.max(1, dlg.data.ch) * 16
    elseif p.pw then W, H = p.pw, p.ph
    else W, H = p.w * 16, p.h * 16 end
    local refPath = dlg.data.useRef and resolveFile(dlg.data.refFile)
    if dlg.data.useRef and not refPath then
      app.alert("참고 그림 파일을 찾지 못했어요. 'Select File' 버튼으로 다시 골라 주세요.")
      return
    end
    local spr = Sprite(W, H, ColorMode.RGB)
    local cols = allVanillaColors(true)
    app.transaction("새 그림 준비", function()
      if cols then setSpritePalette(spr, cols) end
      spr.layers[1].name = DRAW_NAME
      local rf = refPath
      if rf then
        local src = Image{ fromFile = rf }
        local s = math.min(W / src.width, H / src.height)
        local rw, rh = math.max(1, math.floor(src.width * s)), math.max(1, math.floor(src.height * s))
        src:resize(rw, rh)
        local ref = spr:newLayer()
        ref.name = REF_NAME
        spr:newCel(ref, 1, src, Point((W - rw) // 2, (H - rh) // 2))
        ref.opacity = 110
        ref.stackIndex = 1
        ref.isEditable = false
      end
    end)
    for _, l in ipairs(spr.layers) do if l.name == DRAW_NAME then app.activeLayer = l end end
    setupDrawing(spr, p.gw, p.gh)
    app.alert{ title = "새 그림을 만들었어요", text = {
      string.format("크기: %d x %d 픽셀 (격자 한 칸 = %d x %d)", W, H, p.gw, p.gh),
      "연필(B)이 1픽셀 크기로 준비돼 있어요. 바로 칸을 찍어 보세요.",
      "색은 '② 색' 탭에서 누르면 바뀌어요.",
      cols and "팔레트(왼쪽 색 목록)에 스타듀 바닐라 색을 넣어 뒀어요." or
        "(스타듀 그림 폴더를 지정하면 바닐라 색이 팔레트에 들어가요 - ⑥ 설정 탭)" } }
  end }
  dlg:separator{ text = "이미 열린 그림에서 시작하기" }
  dlg:button{ text = "격자 + 연필 + 바닐라 색 준비", onclick = function()
    local spr = app.activeSprite
    if not spr then app.alert("열린 그림이 없어요."); return end
    local cols = allVanillaColors(false)
    if cols then app.transaction("그리기 준비", function() setSpritePalette(spr, cols) end) end
    setupDrawing(spr, 16, 16)
    app.refresh()
  end }
  dlg:button{ text = "처음이라면: 기본 조작법 보기", onclick = function() app.alert{ title = "기본 조작법", text = HELP } end }

  -- ② 색 고르기 --------------------------------------------------
  tab("t_color", "② 색")
  if loadSheet("spring_town", true) then
    dlg:label{ text = "색을 누르면 그 색으로 그려져요" }
    local shown = 0
    for _, m in ipairs(catalog) do
      if m.short and shown < 12 then
        local cols = materialColors(m, 2, true)
        if cols and #cols > 0 then
          local ramp = core.materialRamp(cols, 6)
          local list = {}
          for _, c in ipairs(ramp) do list[#list + 1] = Color{ r = c.r, g = c.g, b = c.b } end
          dlg:shades{ label = m.short, colors = list, onclick = function(ev)
            if ev.button == MouseButton.RIGHT then app.bgColor = ev.color
            else app.fgColor = ev.color; pcall(function() app.tool = "pencil" end) end
          end }
          shown = shown + 1
        end
      end
    end
    dlg:separator{ text = "스타듀 예시 보기" }
    local names = {}
    for i, m in ipairs(catalog) do names[i] = m.short or m.name end
    local function mat(n) for _, m in ipairs(catalog) do if (m.short or m.name) == n then return m end end return catalog[1] end
    dlg:combobox{ id = "mat", option = names[1], options = names,
      onchange = function()
        local a, b = splitNote(mat(dlg.data.mat).note)
        dlg:modify{ id = "note", text = a }; dlg:modify{ id = "note2", text = b }
      end }
    local n1, n2 = splitNote(catalog[1].note)
    dlg:label{ id = "note", text = n1 }
    dlg:newrow()
    dlg:label{ id = "note2", text = n2 }
    dlg:button{ text = "예시 열기 (새 탭)", onclick = function()
      local m = mat(dlg.data.mat)
      local img = loadSheet(m.sheet); if not img then return end
      local crop = Image(img, Rectangle(m.x * 16, m.y * 16, m.w * 16, m.h * 16))
      local spr = Sprite(crop.width, crop.height, ColorMode.RGB)
      spr:newCel(spr.layers[1], spr.frames[1], crop, Point(0, 0))
      spr.layers[1].name = m.name
      pcall(function() spr.filename = "예시 - " .. (m.short or m.name) end)
      setSpritePalette(spr, core.colorsInRect(crop, pc, 0, 0, crop.width, crop.height, 1))
      setupDrawing(spr, 16, 16)
      pcall(function() app.tool = "eyedropper" end)
      app.tip("확대해서 보고, 필요한 색은 클릭해서 뽑아 쓰세요 (스포이드)")
    end }
  else
    dlg:label{ text = "아직 스타듀 그림 폴더가 지정되지 않았어요." }
    dlg:label{ text = "'⑥ 설정' 탭에서 지정하면 여기에 바닐라 색이 나와요." }
  end

  -- ③ 재질 입히기 ----------------------------------------------
  tab("t_tex", "③ 재질")
  dlg:label{ text = "칠할 곳을 선택한 뒤 재질을 누르세요" }
  dlg:label{ text = "(M: 사각형 선택, Q: 올가미 선택)" }
  dlg:combobox{ id = "fillMode", option = "선택한 곳 전부", options = { "선택한 곳 전부", "이미 그린 부분만" } }
  dlg:check{ id = "keepShade", text = "그린 명암 살리기 (밝게 칠한 곳은 밝게)", selected = false }
  if loadSheet("spring_town", true) then
    local count = 0
    for _, m in ipairs(catalog) do
      if m.tile then
        if count > 0 and count % 3 == 0 then dlg:newrow() end
        dlg:button{ text = m.short or m.name, onclick = function()
          local img = loadSheet(m.sheet); if not img then return end
          local t = m.tile
          local crop = Image(img, Rectangle(t.x * 16, t.y * 16, t.w * 16, t.h * 16))
          local tex = { w = crop.width, h = crop.height, get = function(x, y)
            local v = crop:getPixel(x, y)
            return pc.rgbaR(v), pc.rgbaG(v), pc.rgbaB(v), pc.rgbaA(v)
          end }
          local onlyPainted = dlg.data.fillMode == "이미 그린 부분만"
          local spr = app.activeSprite
          if spr and spr.selection.isEmpty and not onlyPainted then
            app.alert{ title = "재질 입히기", text = { "먼저 칠할 곳을 선택해 주세요. (M: 사각형, Q: 올가미)",
              "또는 '이미 그린 부분만'을 고르면 대충 칠해 둔 모양에 무늬를 입혀요." } }
            return
          end
          local ramp = nil
          if dlg.data.keepShade then
            ramp = core.materialRamp(core.colorsInRect(crop, pc, 0, 0, crop.width, crop.height, 1), 6)
          end
          local n = withCanvasCel("재질 입히기: " .. (m.short or m.name), function(ctx, s)
            local c = core.textureFill(ctx, tex, onlyPainted, ramp)
            addImageColorsToPalette(s, ctx.img)
            return c
          end)
          if n then app.tip((m.short or m.name) .. " 무늬로 " .. n .. "칸을 채웠어요 (되돌리기: Ctrl+Z)") end
        end }
        count = count + 1
      end
    end
    dlg:newrow()
    dlg:label{ text = "팁: 먼저 아무 색으로 모양을 대충 칠하고" }
    dlg:newrow()
    dlg:label{ text = "'이미 그린 부분만'으로 무늬를 입히면 편해요" }
  else
    dlg:label{ text = "'⑥ 설정' 탭에서 스타듀 그림 폴더를 먼저 지정해 주세요." }
  end

  -- ④ 다듬기 --------------------------------------------------
  tab("t_fix", "④ 다듬기")
  dlg:label{ text = "다 그렸으면 눌러 보세요 (되돌리기: Ctrl+Z)" }
  dlg:check{ id = "sym", text = "좌우대칭 건물이에요", selected = false }
  dlg:button{ text = "자동으로 다듬기", onclick = function()
    local doSym = dlg.data.sym
    local r = withCel("자동으로 다듬기", function(ctx, spr)
      local a = core.selout(ctx)
      local b = core.despur(ctx)
      local c = doSym and core.mirrorLeft(ctx, axis2For(spr)) or 0
      addImageColorsToPalette(spr, ctx.img)
      return { a, b, c }
    end)
    if r then
      app.alert{ title = "다듬기 완료", text = {
        "· 까만 테두리 " .. r[1] .. "칸을 옆 색에 어울리는 진한 색으로 바꿨어요.",
        "· 튀어나온 점 " .. r[2] .. "개를 지웠어요.",
        doSym and ("· 좌우대칭으로 " .. r[3] .. "칸을 맞췄어요.") or "· 좌우대칭은 건드리지 않았어요.",
        "마음에 안 들면 Ctrl+Z 한 번으로 전부 되돌아가요." } }
    end
  end }
  dlg:button{ text = "문제 있는 곳 보기", onclick = function()
    local spr = app.activeSprite
    if not spr then return end
    local layer = drawingLayer(spr)
    local cel = layer and layer:cel(app.activeFrame)
    if not cel then app.alert("아직 그린 게 없어요."); return end
    if spr.colorMode ~= ColorMode.RGB then app.alert("RGB 모드에서만 검사할 수 있어요."); return end
    local ctx = { img = cel.image, pc = pc, ox = cel.position.x, oy = cel.position.y }
    local res = core.check(ctx, nil, dlg.data.sym and axis2For(spr) or nil)
    local colors = { black = pc.rgba(255, 40, 40, 255), stray = pc.rgba(255, 220, 0, 255), asym = pc.rgba(0, 220, 255, 255) }
    local mk = Image(cel.image.width, cel.image.height, ColorMode.RGB)
    local n = 0
    for _, m in ipairs(res.marks) do
      if colors[m[3]] then mk:drawPixel(m[1], m[2], colors[m[3]]); n = n + 1 end
    end
    app.transaction("문제 표시", function()
      for _, l in ipairs(spr.layers) do if l.name == MARK_NAME then spr:deleteLayer(l) break end end
      if n > 0 then
        local ml = spr:newLayer()
        ml.name = MARK_NAME
        ml.opacity = 200
        spr:newCel(ml, app.activeFrame, mk, cel.position)
      end
    end)
    app.activeLayer = layer
    app.refresh()
    local lines = {
      "· 빨강: 새까만 테두리 " .. res.black .. "칸 (스타듀는 테두리를 진한 갈색 계열로 그려요)",
      "· 노랑: 혼자 튀어나온 점 " .. res.stray .. "개",
    }
    if dlg.data.sym then lines[#lines + 1] = "· 하늘색: 좌우가 다른 곳 " .. res.asym .. "칸" end
    lines[#lines + 1] = "· 쓴 색 개수: " .. res.colors .. "개 (스타듀 건물은 재질마다 3~5색 정도)"
    lines[#lines + 1] = n > 0 and "'문제 표시' 레이어로 위치를 보여 드렸어요. '표시 지우기'로 없앨 수 있어요."
                              or "고칠 곳이 없어요!"
    app.alert{ title = "검사 결과", text = lines }
  end }
  dlg:button{ text = "표시 지우기", onclick = function()
    local spr = app.activeSprite; if not spr then return end
    for _, l in ipairs(spr.layers) do
      if l.name == MARK_NAME then app.transaction("표시 지우기", function() spr:deleteLayer(l) end) break end
    end
    app.refresh()
  end }
  dlg:check{ id = "adv", text = "고급 기능 보기", selected = false, onclick = function()
    local v = dlg.data.adv
    for _, id in ipairs{ "a1", "a2", "a3", "a4", "a5", "courseH", "brickW", "a6" } do dlg:modify{ id = id, visible = v } end
  end }
  dlg:button{ id = "a1", text = "팔레트 색으로만 칠하기", visible = false, onclick = function()
    local spr = app.activeSprite; if not spr then return end
    local pal = spritePaletteColors(spr)
    local n = withCel("팔레트 색으로 맞추기", function(ctx) return core.snapToPalette(ctx, pal) end)
    if n then app.tip("바뀐 칸: " .. n) end
  end }
  dlg:button{ id = "a2", text = "까만 테두리만 바꾸기", visible = false, onclick = function()
    local n = withCel("테두리 색 정리", function(ctx, spr)
      local c = core.selout(ctx); addImageColorsToPalette(spr, ctx.img); return c
    end)
    if n then app.tip("바뀐 칸: " .. n) end
  end }
  dlg:button{ id = "a3", text = "튀어나온 점만 지우기", visible = false, onclick = function()
    local n = withCel("튀어나온 점 지우기", function(ctx) return core.despur(ctx) end)
    if n then app.tip("지운 점: " .. n) end
  end }
  dlg:button{ id = "a4", text = "좌우대칭만 맞추기", visible = false, onclick = function()
    local n = withCel("좌우대칭", function(ctx, spr) return core.mirrorLeft(ctx, axis2For(spr)) end)
    if n then app.tip("바뀐 칸: " .. n) end
  end }
  dlg:label{ id = "a5", text = "벽돌: 벽을 사각형 선택(M) 후 누르기", visible = false }
  dlg:number{ id = "courseH", label = "벽돌 한 줄 높이", text = "4", decimals = 0, visible = false }
  dlg:number{ id = "brickW", label = "벽돌 한 장 너비", text = "8", decimals = 0, visible = false }
  dlg:button{ id = "a6", text = "선택한 곳에 벽돌 깔기", visible = false, onclick = function()
    local spr = app.activeSprite
    if not spr then return end
    if spr.selection.isEmpty then app.alert("먼저 사각형 선택(M)으로 벽돌을 깔 곳을 골라 주세요."); return end
    local m = catalog[1]
    if dlg.data.mat then for _, x in ipairs(catalog) do if (x.short or x.name) == dlg.data.mat then m = x end end end
    local cols = materialColors(m, 2); if not cols then return end
    local ramp = core.materialRamp(cols, 5)
    local n = withCel("벽돌 깔기", function(ctx, s)
      local c = core.brick(ctx, ramp, math.max(2, dlg.data.courseH), math.max(3, dlg.data.brickW))
      addImageColorsToPalette(s, ctx.img)
      return c
    end)
    if n then app.tip("벽돌 칸: " .. n) end
  end }

  -- ④ 게임에서 보기 ----------------------------------------------
  tab("t_view", "⑤ 미리보기")
  dlg:label{ text = "스타듀 살롱 옆에 같은 크기로 놓아 봐요" }
  dlg:button{ text = "스타듀 건물 옆에 놓고 보기", onclick = function()
    local spr = app.activeSprite
    if not spr then app.alert("열린 그림이 없어요."); return end
    local town, outd = loadSheet("spring_town"), loadSheet("spring_outdoorsTileSheet")
    if not town or not outd then return end
    local mine = flatten(spr)
    local van = Image(town, Rectangle(15 * 16, 11 * 16, 7 * 16, 9 * 16))
    local grass = Image(outd, Rectangle(0, 7 * 16, 16, 16))
    local W = van.width + mine.width + 48
    local H = math.max(van.height, mine.height) + 32
    W, H = math.ceil(W / 16) * 16, math.ceil(H / 16) * 16
    local canvas = Image(W, H, ColorMode.RGB)
    for y = 0, H - 1, 16 do for x = 0, W - 1, 16 do canvas:drawImage(grass, Point(x, y)) end end
    canvas:drawImage(van, Point(16, H - van.height - 16))
    canvas:drawImage(mine, Point(van.width + 32, H - mine.height - 16))
    local pv = Sprite(W, H, ColorMode.RGB)
    pv:newCel(pv.layers[1], pv.frames[1], canvas, Point(0, 0))
    pv.layers[1].name = "미리보기"
    pcall(function() pv.filename = "미리보기 (왼쪽: 스타듀 살롱)" end)
    pcall(function() app.command.FitScreen() end)
  end }
  dlg:separator{ text = "모드에 넣을 PNG로 저장" }
  dlg:label{ text = "참고·표시 레이어는 빼고 저장해요" }
  dlg:file{ id = "savePath", save = true, filetypes = { "png" }, filename = "" }
  dlg:button{ text = "PNG로 저장", onclick = function()
    local spr = app.activeSprite
    if not spr then app.alert("열린 그림이 없어요."); return end
    local path = dlg.data.savePath
    if path and path ~= "" and not path:match("^/") and not path:match("^%a:[\\/]") then
      local spr0 = app.activeSprite
      local base = (spr0 and spr0.filename and spr0.filename ~= "" and app.fs.filePath(spr0.filename)) or app.fs.userDocsPath
      path = app.fs.joinPath(base, path)
    end
    if not path or path == "" then app.alert("먼저 위 칸의 버튼으로 저장할 위치와 이름을 골라 주세요."); return end
    if not path:lower():match("%.png$") then path = path .. ".png" end
    flatten(spr):saveAs(path)
    app.alert{ title = "저장했어요", text = { path } }
  end }

  -- ⑥ 설정 / 도움말 ----------------------------------------------
  tab("t_set", "⑥ 설정")
  dlg:button{ text = "기본 조작법 보기", onclick = function() app.alert{ title = "기본 조작법", text = HELP } end }
  dlg:separator{ text = "스타듀 그림 폴더 (처음 한 번)" }
  dlg:label{ text = "Maps 폴더의 spring_town.png 선택" }
  dlg:file{ id = "town", open = true, filetypes = { "png" },
    filename = mapsDir() and app.fs.joinPath(mapsDir(), "spring_town.png") or "",
    onchange = function()
      local f = resolveFile(dlg.data.town)
      if f then
        prefs.mapsDir = app.fs.filePath(f)
        sheetCache = {}
        reopen("t_color")
      end
    end }
  dlg:label{ id = "status", text = "지금: " .. shortPath(mapsDir()) }
  dlg:separator{ text = "한글 글꼴" }
  dlg:button{ text = "갈무리9 글꼴로 바꾸기", onclick = function()
    local f9 = fontPath("Galmuri9.ttf")
    if not app.fs.isFile(f9) then app.alert("글꼴 파일을 찾을 수 없어요: " .. f9); return end
    local ok = pcall(function()
      app.preferences.theme.font = "file=" .. f9 .. ",size=10"
      app.preferences.theme.mini_font = "file=" .. f9 .. ",size=10"
    end)
    app.alert{ title = "글꼴", text = ok and { "갈무리9 글꼴로 설정했어요.", "Aseprite를 껐다 켜면 적용돼요." }
      or { "이 버전의 Aseprite에서는 글꼴을 바꿀 수 없어요." } }
  end }
  dlg:button{ text = "원래 글꼴로", onclick = function()
    pcall(function() app.preferences.theme.font = ""; app.preferences.theme.mini_font = "" end)
    app.alert("원래 글꼴로 되돌렸어요. Aseprite를 껐다 켜면 적용돼요.")
  end }

  if hasTabs then dlg:endtabs{ id = "tabs", selected = env.tab or "t_start" } end
  dlg:separator()
  dlg:button{ text = "닫기", onclick = function() dlg:close() end }
  dlg:show{ wait = false, autoscrollbars = true, bounds = env.bounds }

  -- 처음 열 때 한 번만 안내
  if not prefs.seenIntro then
    prefs.seenIntro = true
    app.alert{ title = "Stardew 도트 도우미에 오신 걸 환영해요", text = {
      "탭을 왼쪽부터 순서대로 쓰면 돼요.",
      "① 시작: 그릴 것 고르고 새 그림 만들기",
      "② 색: 스타듀 바닐라 색을 눌러서 칠하기",
      "③ 재질: 고른 곳을 바닐라 벽돌·지붕·판자 무늬로 채우기",
      "④ 다듬기: 까만 테두리, 튀어나온 점, 좌우대칭 자동 정리",
      "⑤ 미리보기: 스타듀 건물 옆에 놓고 비교, PNG 저장",
      "",
      "처음이라면 '⑥ 설정' 탭에서",
      "스타듀 그림 폴더 지정 + 갈무리9 글꼴 + 기본 조작법부터 보세요." } }
  end
end

return U
