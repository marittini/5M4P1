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
end

function exit(plugin) end
