--[[
Name: hao_core.lua
名称: 好码方案核心函数
Version: 20250716
Author: 荒
Purpose: 好码方案的 RIME lua 提供核心函数

Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
-------------------------------------
]]

local core = {}

---通過 unicode 編碼輸入字符 @lost-melody
function core.unicode()
  local space = utf8.codepoint(" ")
  return function(args)
    local code = tonumber(string.format("0x%s", args[1] or ""))
    return utf8.char(code or space)
  end
end

return core