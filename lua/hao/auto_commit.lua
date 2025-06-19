--[[
Name: auto_commit.lua
名称: 自动上屏首选（松烟专用）
Version: 20250618
Author: 荒
Purpose: 当输入到第五个编码时，忽略重码直接上屏首选字；
         当末键是 weruio 中的任意一键时，忽略重码自动上屏首选。

Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International
-------------------------------------

使用方法:
(1) 需要將此 lua 文件放在 lua 文件夾下.
(2) 需要在 engine/processors 添加:
- lua_processor@*hao.auto_commit
(3) 需要在 switches 添加狀態:
- name: leosy_auto_commit
  reset: 1
  states: [关闭, 开启]
]]

local kRejected = 0 -- 拒: 不作響應, 由操作系統做默認處理
local kAccepted = 1 -- 收: 由rime響應該按鍵
local kNoop     = 2 -- 無: 請下一個processor繼續看

--取消默认值设置
--local function init(env)
--    env.engine.context:set_option("leosy_auto_commit", true)
--end

local function func(key_event, env)
    local context = env.engine.context
    
    -- 检查是否开启自动上屏功能
    if not context:get_option("leosy_auto_commit") then
        return kNoop
    end
    
    -- 只接受字母键
    if key_event:release() or key_event:alt() or key_event:ctrl() or key_event:shift() or key_event:caps() then
        return kNoop
    end
    
    local ch = key_event.keycode
    if ch < ('a'):byte() or ch > ('z'):byte() then
        return kNoop
    end
    
    local current_char = string.char(ch)
    local input = context.input
    
    -- 检查是否是第五个编码
    if #input == 4 then
        -- 先让按键输入
        context:push_input(current_char)
        
        -- 获取当前正在翻译的部分
        local segment = context.composition:toSegmentation():back()
        if not segment then
            return kNoop
        end
        
        -- 获取首选候选
        local first_candidate = segment:get_candidate_at(0)
        if not first_candidate then
            return kNoop
        end
        
        -- 自动上屏首选
        env.engine:commit_text(first_candidate.text)
        context:clear()
        return kAccepted
    end
    
    -- 检查当前按键是否是 weruio 中的任意一个
    if current_char:match("[weruio]") then
        -- 先让按键输入
        context:push_input(current_char)
        
        -- 获取当前正在翻译的部分
        local segment = context.composition:toSegmentation():back()
        if not segment then
            return kNoop
        end
        
        -- 获取首选候选
        local first_candidate = segment:get_candidate_at(0)
        if not first_candidate then
            return kNoop
        end
        
        -- 自动上屏首选
        env.engine:commit_text(first_candidate.text)
        context:clear()
        return kAccepted
    end
    
    return kNoop
end

return {
    init = init,
    func = func
} 