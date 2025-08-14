-- single_char_only.lua
-- Comes from @hchuihui the author of librime-lua
--    https://github.com/rime/librime/issues/248#issuecomment-468924677

local function filter(input, env)
    b = env.engine.context:get_option("hao_single_char")
    c = string.len(env.engine.context.input)
    for cand in input:iter() do
      if (b or utf8.len(cand.text) == 1) then
        yield(cand)
      end
    end
  end
  
  return filter