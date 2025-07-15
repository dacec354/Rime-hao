--[[
Name: auto_commit.lua
名称: 自动上屏首选（松烟专用）+ 字数统计
Version: 20250618
Author: 荒
Purpose: 当输入到第五个编码时，忽略重码直接上屏首选字；
         当末键是 weruio 中的任意一键时，忽略重码自动上屏首选。
         同时记录字数统计到CSV文件。

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

-- 字数统计相关变量
local csv_path = "/Users/bennett/workspace/rime/py_wordscounter/words_input.csv" -- 改为实际的CSV文件路径

-- 判断文本是否包含至少一个汉字
function is_valid_text(text)
    for _, c in utf8.codes(text) do
        if c >= 0x4E00 and c <= 0x9FFF then
            return true
        end
    end
    return false
end

-- 获取当前时间戳（格式：YYYY-MM-DD HH:MM:SS）
function get_timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- 计算文本中的汉字个数
function count_chinese_characters(text)
    local count = 0
    for _, c in utf8.codes(text) do
        if c >= 0x4E00 and c <= 0x9FFF then
            count = count + 1
        end
    end
    return count
end

-- 记录字数统计
function record_word_count(text)
    if is_valid_text(text) then
        local chinese_count = count_chinese_characters(text)
        local file, err = io.open(csv_path, "a")
        if file then
            -- CSV 格式：时间戳,汉字个数,文本
            local csv_line = string.format(
                '"%s","%d","%s"\n',
                get_timestamp(),
                chinese_count,
                text:gsub('"', '""')
            )
            file:write(csv_line)
            file:close()
        else
            log.error("无法写入CSV文件: " .. err)
        end
    end
end

-- 自动上屏并记录字数统计
function auto_commit_with_counter(env, candidate_text)
    -- 自动上屏首选
    env.engine:commit_text(candidate_text)
    -- 记录字数统计
    record_word_count(candidate_text)
end

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
        local composition = context.composition
        if not composition or composition:empty() then
            return kNoop
        end
        
        local segment = composition:back()
        if not segment then
            return kNoop
        end
        
        -- 获取首选候选
        local first_candidate = segment:get_selected_candidate()
        if not first_candidate then
            return kNoop
        end
        
        -- 自动上屏首选并记录字数统计
        auto_commit_with_counter(env, first_candidate.text)
        context:clear()
        return kAccepted
    end
    
    -- 检查当前按键是否是 weruio 中的任意一个
    if current_char:match("[weruio]") then
        -- 先让按键输入
        context:push_input(current_char)
        
        -- 获取当前正在翻译的部分
        local composition = context.composition
        if not composition or composition:empty() then
            return kNoop
        end
        
        local segment = composition:back()
        if not segment then
            return kNoop
        end
        
        -- 获取首选候选
        local first_candidate = segment:get_selected_candidate()
        if not first_candidate then
            return kNoop
        end
        
        -- 自动上屏首选并记录字数统计
        auto_commit_with_counter(env, first_candidate.text)
        context:clear()
        return kAccepted
    end
    
    return kNoop
end

-- 初始化函数
local function init(env)
    -- 初始化CSV文件（如果不存在）
    local header_file = io.open(csv_path, "r")
    if not header_file then
        header_file = io.open(csv_path, "w")
        if header_file then
            header_file:write('"timestamp","chinese_count","text"\n')
            header_file:close()
        end
    end
end

return {
    init = init,
    func = func
} 