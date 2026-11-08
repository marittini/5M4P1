-- Aseprite 확장 진입점: 편집(Edit) 메뉴에 "Stardew 도우미" 추가
function init(plugin)
  local function open()
    local ui = dofile(app.fs.joinPath(plugin.path, "ui.lua"))
    ui.open{ dir = plugin.path, prefs = plugin.preferences }
  end
  plugin:newMenuGroup{ id = "sdv_helper_menu", title = "Stardew 도우미", group = "edit_fx" }
  plugin:newCommand{
    id = "SdvHelperOpen",
    title = "도우미 창 열기",
    group = "sdv_helper_menu",
    onclick = open,
  }
  -- 찾기 쉽도록 도움말(Help) 메뉴 맨 위에도 하나 더
  plugin:newCommand{
    id = "SdvHelperOpenHelp",
    title = "Stardew 도트 도우미 열기",
    group = "help_readme",
    onclick = open,
  }
end

function exit(plugin) end
