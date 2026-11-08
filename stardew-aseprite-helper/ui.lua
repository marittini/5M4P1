-- Stardew 도트 도우미: 대화창(UI)
-- open(env): env = { dir=플러그인 폴더, prefs=저장 테이블(plugin.preferences 또는 일반 테이블) }
local U = {}

function U.open(env)
  local core = dofile(app.fs.joinPath(env.dir, "core.lua"))
  local catalog = dofile(app.fs.joinPath(env.dir, "catalog.lua"))
  local prefs = env.prefs
  local pc = app.pixelColor
  local sheetCache = {}

  -- ------------------------------------------------------------ 공통 도우미
  local function mapsDir() return prefs.mapsDir end

  local function loadSheet(name)
    if sheetCache[name] then return sheetCache[name] end
    local dir = mapsDir()
    if not dir then
      app.alert{ title = "Stardew 도우미", text = { "먼저 스타듀 게임 파일 위치를 지정해 주세요.",
        "'미리보기 / 설정' 탭에서 Maps 폴더 안의 spring_town.png 를 고르면 됩니다.",
        "(Content (unpacked)\\Maps 또는 Stardew Sim 의 web\\data\\img\\Maps)" } }
      return nil
    end
    local path = app.fs.joinPath(dir, name .. ".png")
    if not app.fs.isFile(path) then
      app.alert{ title = "Stardew 도우미", text = { "파일을 찾을 수 없어요:", path } }
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

  local names = {}
  for i, m in ipairs(catalog) do names[i] = m.name end
  local function material(name)
    for _, m in ipairs(catalog) do if m.name == name then return m end end
    return catalog[1]
  end

  local function materialColors(m, minCount)
    local img = loadSheet(m.sheet)
    if not img then return nil end
    return core.colorsInRect(img, pc, m.x * 16, m.y * 16, m.w * 16, m.h * 16, minCount or 1)
  end

  local function setSpritePalette(colors, append)
    local spr = app.activeSprite
    if not spr then app.alert("열린 그림이 없어요."); return end
    local list = {}
    if append then
      local old = spr.palettes[1]
      for i = 0, #old - 1 do
        local c = old:getColor(i)
        if c.alpha > 0 then list[#list + 1] = { r = c.red, g = c.green, b = c.blue } end
      end
    end
    local seen = {}
    for _, c in ipairs(list) do seen[core.key(c.r, c.g, c.b)] = true end
    for _, c in ipairs(colors) do
      local k = core.key(c.r, c.g, c.b)
      if not seen[k] then seen[k] = true; list[#list + 1] = c end
    end
    if #list > 255 then
      app.alert("색이 255개를 넘어서 앞에서부터 255개만 넣었어요.")
      while #list > 255 do table.remove(list) end
    end
    local pal = Palette(#list + 1)
    pal:setColor(0, Color{ r = 0, g = 0, b = 0, a = 0 })
    for i, c in ipairs(list) do pal:setColor(i, Color{ r = c.r, g = c.g, b = c.b, a = 255 }) end
    app.transaction("바닐라 팔레트 적용", function() spr:setPalette(pal) end)
    app.refresh()
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

  -- 현재 셀 이미지에 작업 적용 (되돌리기 한 번으로 취소 가능)
  local function withCel(title, fn)
    local spr, cel = app.activeSprite, app.activeCel
    if not spr or not cel then app.alert("편집할 레이어/셀을 선택해 주세요."); return end
    if spr.colorMode ~= ColorMode.RGB then
      app.alert("RGB 모드에서만 동작해요. (스프라이트 > 색상 모드 > RGB)"); return
    end
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

  local function axis2For(spr)
    local s = spr.selection
    if s and not s.isEmpty then return s.bounds.x * 2 + s.bounds.width end
    return spr.width
  end

  -- ------------------------------------------------------------ 대화창
  local dlg = Dialog{ title = "Stardew 도트 도우미" }

  local function shortPath(p)
    if #p > 48 then return "..." .. p:sub(-45) end
    return p
  end
  local function splitNote(t)
    t = t or ""
    if #t < 60 then return t, "" end
    local mid, best = #t // 2, nil
    for i = 1, #t do
      if t:sub(i, i) == " " and (not best or math.abs(i - mid) < math.abs(best - mid)) then best = i end
    end
    if not best then return t, "" end
    return t:sub(1, best - 1), t:sub(best + 1)
  end
  local hasTabs = false
  pcall(function() hasTabs = dlg.tab ~= nil end)
  local function tab(id, text) if hasTabs then dlg:tab{ id = id, text = text } end end
  local function endtabs() if hasTabs then dlg:endtabs{ id = "tabs", selected = "t_mat" } end end

  tab("t_mat", "재질 도감")
  dlg:separator{ text = "바닐라 재질 도감" }
  dlg:combobox{ id = "mat", label = "재질", option = names[1], options = names,
    onchange = function()
      local a, b = splitNote(material(dlg.data.mat).note)
      dlg:modify{ id = "note", text = a }; dlg:modify{ id = "note2", text = b }
    end }
  local n1, n2 = splitNote(catalog[1].note)
  dlg:label{ id = "note", text = n1 }
  dlg:newrow()
  dlg:label{ id = "note2", text = n2 }
  dlg:button{ text = "레퍼런스 열기", onclick = function()
    local m = material(dlg.data.mat)
    local img = loadSheet(m.sheet); if not img then return end
    local crop = Image(img, Rectangle(m.x * 16, m.y * 16, m.w * 16, m.h * 16))
    local spr = Sprite(crop.width, crop.height, ColorMode.RGB)
    spr:newCel(spr.layers[1], spr.frames[1], crop, Point(0, 0))
    spr.layers[1].name = m.name
    pcall(function() spr.filename = m.name end)
    spr.gridBounds = Rectangle(0, 0, 16, 16)
    setSpritePalette(core.colorsInRect(crop, pc, 0, 0, crop.width, crop.height, 1), false)
    pcall(function() app.command.FitScreen() end)
    pcall(function() app.command.ShowGrid() end)
  end }
  dlg:button{ text = "팔레트로 적용", onclick = function()
    local cols = materialColors(material(dlg.data.mat)); if cols then setSpritePalette(cols, false) end
  end }
  dlg:button{ text = "팔레트에 추가", onclick = function()
    local cols = materialColors(material(dlg.data.mat)); if cols then setSpritePalette(cols, true) end
  end }
  dlg:newrow()
  dlg:button{ text = "전체 바닐라 팔레트", onclick = function()
    local all, seen = {}, {}
    for _, m in ipairs(catalog) do
      local cols = materialColors(m, 3)
      if not cols then return end
      for _, c in ipairs(cols) do
        if not seen[c.k] then seen[c.k] = c; all[#all + 1] = c else seen[c.k].count = seen[c.k].count + c.count end
      end
    end
    table.sort(all, function(a, b) return a.count > b.count end)
    while #all > 255 do table.remove(all) end
    table.sort(all, function(a, b) return core.luma(a.r, a.g, a.b) < core.luma(b.r, b.g, b.b) end)
    setSpritePalette(all, false)
  end }

  tab("t_fix", "검사 / 보정")
  dlg:separator{ text = "검사 (현재 팔레트 기준)" }
  dlg:check{ id = "marks", text = "문제 위치 표시 레이어 만들기", selected = true }
  dlg:button{ text = "검사하기", onclick = function()
    local spr, cel = app.activeSprite, app.activeCel
    if not spr or not cel then app.alert("검사할 레이어/셀을 선택해 주세요."); return end
    if spr.colorMode ~= ColorMode.RGB then app.alert("RGB 모드에서만 동작해요."); return end
    local ctx = { img = cel.image, pc = pc, ox = cel.position.x, oy = cel.position.y }
    local s = spr.selection
    if s and not s.isEmpty then ctx.inSel = function(x, y) return s:contains(x, y) end end
    local res = core.check(ctx, spritePaletteColors(spr), axis2For(spr))
    if dlg.data.marks and #res.marks > 0 then
      local colors = { off = pc.rgba(255, 0, 255, 255), black = pc.rgba(255, 40, 40, 255),
                       stray = pc.rgba(255, 220, 0, 255), asym = pc.rgba(0, 220, 255, 255) }
      local mk = Image(cel.image.width, cel.image.height, ColorMode.RGB)
      for _, m in ipairs(res.marks) do mk:drawPixel(m[1], m[2], colors[m[3]]) end
      local orig = app.activeLayer
      app.transaction("검사 표시", function()
        local layer = spr:newLayer()
        layer.name = "검사 표시 (지워도 됨)"
        layer.opacity = 170
        spr:newCel(layer, app.activeFrame, mk, cel.position)
      end)
      app.activeLayer = orig  -- 보정 버튼이 표시 레이어가 아니라 원래 레이어에 적용되도록
      app.refresh()
    end
    app.alert{ title = "검사 결과", text = {
      "사용한 색: " .. res.colors .. "개  (바닐라 건물은 보통 재질당 3~5색)",
      "팔레트에 없는 색 픽셀: " .. res.offPalette .. "  (분홍 표시)",
      "검은 픽셀: " .. res.black .. "  (빨강 표시, 바닐라는 순검정 외곽선을 안 씀)",
      "외톨이/삐죽 픽셀: " .. res.stray .. "  (노랑 표시)",
      "좌우 비대칭 픽셀: " .. res.asym .. "  (하늘색 표시, 대칭 건물일 때만 참고)" } }
  end }

  dlg:separator{ text = "보정 (선택 영역이 있으면 그 안만)" }
  dlg:button{ text = "팔레트 색으로 맞추기", onclick = function()
    local spr = app.activeSprite; if not spr then return end
    local pal = spritePaletteColors(spr)
    if #pal == 0 then app.alert("팔레트가 비어 있어요."); return end
    local n = withCel("팔레트 색으로 맞추기", function(ctx) return core.snapToPalette(ctx, pal) end)
    if n then app.tip("바뀐 픽셀: " .. n) end
  end }
  dlg:button{ text = "검은 외곽선 → 재질색", onclick = function()
    local n = withCel("외곽선 색 정리", function(ctx, spr)
      local c = core.selout(ctx); addImageColorsToPalette(spr, ctx.img); return c
    end)
    if n then app.tip("바뀐 외곽선 픽셀: " .. n) end
  end }
  dlg:newrow()
  dlg:button{ text = "외톨이 픽셀 제거", onclick = function()
    local n = withCel("외톨이 픽셀 제거", function(ctx) return core.despur(ctx) end)
    if n then app.tip("지운 픽셀: " .. n) end
  end }
  dlg:button{ text = "왼쪽 기준 좌우대칭", onclick = function()
    local n = withCel("좌우대칭", function(ctx, spr) return core.mirrorLeft(ctx, axis2For(spr)) end)
    if n then app.tip("바뀐 픽셀: " .. n) end
  end }
  dlg:separator{ text = "벽돌 깔기 (선택한 재질의 명암 5단계 사용)" }
  dlg:number{ id = "courseH", label = "단 높이", text = "4", decimals = 0 }
  dlg:number{ id = "brickW", label = "벽돌 폭", text = "8", decimals = 0 }
  dlg:button{ text = "선택 영역에 벽돌 깔기", onclick = function()
    local spr = app.activeSprite
    if not spr then return end
    if spr.selection.isEmpty then app.alert("벽돌을 깔 영역을 먼저 선택해 주세요."); return end
    local cols = materialColors(material(dlg.data.mat), 2); if not cols then return end
    local ramp = core.ramp(cols, 5)
    local n = withCel("벽돌 깔기", function(ctx)
      local c = core.brick(ctx, ramp, math.max(2, dlg.data.courseH), math.max(3, dlg.data.brickW))
      addImageColorsToPalette(app.activeSprite, ctx.img)
      return c
    end)
    if n then app.tip("벽돌 픽셀: " .. n) end
  end }

  tab("t_etc", "미리보기 / 설정")
  dlg:separator{ text = "미리보기" }
  dlg:button{ text = "바닐라 건물 옆에 놓고 보기", onclick = function()
    local spr = app.activeSprite
    if not spr then app.alert("열린 그림이 없어요."); return end
    local town, outd = loadSheet("spring_town"), loadSheet("spring_outdoorsTileSheet")
    if not town or not outd then return end
    local mine = Image(spr)
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
    pv.layers[1].name = "미리보기 (왼쪽: 바닐라 살롱)"
    pcall(function() pv.filename = "미리보기" end)
    pcall(function() app.command.FitScreen() end)
  end }

  dlg:separator{ text = "스타듀 게임 파일 (Maps 폴더)" }
  dlg:file{ id = "town", label = "spring_town.png", open = true, filetypes = { "png" },
    filename = mapsDir() and app.fs.joinPath(mapsDir(), "spring_town.png") or "",
    onchange = function()
      local f = dlg.data.town
      if f and f ~= "" then
        prefs.mapsDir = app.fs.filePath(f)
        sheetCache = {}
        dlg:modify{ id = "status", text = shortPath(prefs.mapsDir) }
      end
    end }
  dlg:label{ id = "status", text = mapsDir() and shortPath(mapsDir()) or "아직 지정 안 됨" }

  endtabs()
  dlg:separator()
  dlg:button{ text = "닫기", onclick = function() dlg:close() end }
  dlg:show{ wait = false, autoscrollbars = true, bounds = env.bounds }
end

return U
