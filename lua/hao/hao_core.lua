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

-- 由translator記録輸入串, 傳遞給filter
core.input_code = ''
-- 由translator計算暫存串, 傳遞給filter
core.stashed_text = ''

-- 開關枚舉
core.switch_names = {
  hao_embeded_cands = "hao_embeded_cands",
  hao_completion    = "hao_completion",
}

-- 從方案配置中讀取字符串
function core.parse_conf_str(env, path, default)
  local str = env.engine.schema.config:get_string(env.name_space .. "/" .. path)
  if not str and default and #default ~= 0 then
      str = default
  end
  return str
end

-- 從方案配置中讀取字符串列表
function core.parse_conf_str_list(env, path, default)
  local list = {}
  local conf_list = env.engine.schema.config:get_list(env.name_space .. "/" .. path)
  if conf_list then
      for i = 0, conf_list.size - 1 do
          table.insert(list, conf_list:get_value_at(i):get_string())
      end
  elseif default then
      list = default
  end
  return list
end

-- 構造開關變更回調函數
---@param option_names table
function core.get_switch_handler(env, option_names)
  env.option = env.option or {}
  local option = env.option
  local name_set = {}
  if option_names then
      for name in pairs(option_names) do
          name_set[name] = true
      end
  end
  -- 返回通知回調, 當改變選項值時更新暫存的值
  ---@param name string
  return function(ctx, name)
      if name_set[name] then
          option[name] = ctx:get_option(name)
          if option[name] == nil then
              -- 當選項不存在時默認爲啟用狀態
              option[name] = true
          end
          -- 刷新, 使 lua 組件讀取最新開關狀態
          ctx:refresh_non_confirmed_composition()
      end
  end
end

---通過 unicode 編碼輸入字符 @lost-melody
function core.unicode()
  local space = utf8.codepoint(" ")
  return function(args)
    local code = tonumber(string.format("0x%s", args[1] or ""))
    return utf8.char(code or space)
  end
end

return core