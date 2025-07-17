local radstr = ''
--local radstr = '\z
--    一不了人大也可之自而生子里用小行方心无面\z
--    已又两日长三十力高手身老见民工二由文业几\z
--    走西月儿门女己立四水王各口气目入金及山马\z
--    白至五光非飞象且干未言士车石火夫黑支九八\z
--    片六黄示古七广土足千云龙母巴革音衣斗米毛\z
--    句止木食习田皮刀尚耳户鱼鬼齐雨乡牛虎乃臣\z
--    谷予亡麻厂丁骨牙尤束甲曲川乌贝丰页瓦鸟尸\z
--    甘弗羊虫吕辛竹井曰氏韦册羽戈鼠豆斤寸弓欠\z
--    齿乙瓜穴舌卜鹿夕爪卵甫辟巾舟辰龟兔仑丸囚\z
--    犬矢乍歹匕毋敖亥巳戊廿禾聿卯酉皿卅臼弋幺\z
--    艮豕頁黾缶殳隹肀髟耒芈爿疋鬲豸艹艸丌龠彳\z
--    氵钅見車長黃門馬風飛鳥魚戶麥貝鬥烏韋冊龜\z
--    齒乚旡覀靣亍厶宀扌糸釒〇㠯㡀丨丬丶丿乀乂\z
--    乛亅亠亻亾侖兎冂円冖冫凵刂勹匚卌卩囗壴夂\z
--    尢屮巛廴廾彐彡忄攴攵朩毌灬爫牜犭疒礻禸纟\z
--    罒耂虍衤讠辶阝饣龵𠂉𠄏㐄丗丩丯丱丷乁亀亼\z
--    亽僉兦冎卝卪吅巜彑戉戸斉歯歺氺癶竜糹襾镸\z
--    飠髙黒黽鼡龰龱龴龶龷龸𠂇㔾㸦䒑𠀍𠁣𠂔𠃉𠃌\z
--    𠕁𠥓𠫔𡆪𢎘𢎨𣄼𣎆𤕪𤴓𦈢𦘒𧘇𧰧𩵋𪚦𪚴𪛉𫜵𫩏\z
--    ⽱⾻⿔𬹝𬺰𮍌ㄅㄊㄋㄑㄗㄡㄣㄥ𰀪𱤻𱕻𱍐㇀㇂\z
--    ㇅㇈㇋㇎㇏㇗㇞㇢⺀⺁⺃⺄⺆⺇⺈⺊⺌⺍⺗⺜\z
--    ⺝⺥⺧⺪⺬⺮⺶⺷⺸⺻⺼⺽⻊⻍⻗⻞'


local function init(env)
  local config = env.engine.schema.config
  local code_rvdb = config:get_string('hao/code')
  env.code_rvdb = ReverseDb('build/' .. code_rvdb .. '.reverse.bin')
  env.his_inp = config:get_string('history/input')
  env.delimiter = config:get_string('speller/delimiter')
  env.max_index = config:get_int('hao/postpone_fullcode/max_index')
      or 4
end


local function get_short(codestr)
  local s = ' ' .. codestr
  for code in s:gmatch('%l+') do
    if s:find(' ' .. code .. '%l+') then
      return code
    end
  end
end


local function has_short_and_is_full(cand, env)
  -- completion 和 sentence 类型不属于精确匹配，但要通过 cand:get_genuine() 判
  -- 断，因为 simplifier 会覆盖类型为 simplified。先行判断 type 并非必要，只是
  -- 为了轻微的性能优势。
  local cand_gen = cand:get_genuine()
  if cand_gen.type == 'completion' or cand_gen.type == 'sentence' then
    return false, true
  end
  local input = env.engine.context.input
  local cand_input = input:sub(cand.start + 1, cand._end)
  -- 去掉可能含有的 delimiter。
  cand_input = cand_input:gsub('[' .. env.delimiter .. ']', '')
  -- 字根可能设置了特殊扩展码，不视作全码，不予后置。
  if cand_input:len() > 2 and radstr:find(cand_gen.text, 1, true) then
    return
  end
  -- history_translator 不后置。
  if cand_input == env.his_inp then return end
  local codestr = env.code_rvdb:lookup(cand_gen.text)
  local is_comp = not
    string.find(' ' .. codestr .. ' ', ' ' .. cand_input .. ' ', 1, true)
  local short = not is_comp and get_short(codestr)
  -- 注意排除有简码但是输入的是不规则编码的情况
  return short and cand_input:find('^' .. short .. '%l+'), is_comp
end


local function filter(input, env)
  local context = env.engine.context
  if not context:get_option("hao_postpone_fullcode") then
    for cand in input:iter() do yield(cand) end
  else
    -- 具体实现不是后置目标候选，而是前置非目标候选
    local dropped_cands = {}
    local done_drop
    local pos = 1
    -- Todo: 计算 pos 时考虑可能存在的重复候选被 uniquifier 合并的情况。
    for cand in input:iter() do
      if done_drop then
        yield(cand)
      else
        -- 后置不越过 env.max_index 和以下几类候选：
        -- 1) 顶功方案使用 script_translator 导致的匹配部分输入的候选，例如输入
        -- otu 且光标在 u 后时会出现编码为 ot 的候选。不过通过填满码表的三码和
        -- 四码的位置，能消除这类候选。2) 顶功方案的造词翻译器允许出现的
        -- completion 类型候选。3) 顶功方案的补空候选——全角空格（ U+3000）。
        local is_bad_script_cand = cand._end < context.caret_pos
        local drop, is_comp = has_short_and_is_full(cand, env)
        if pos >= env.max_index
            or is_bad_script_cand or is_comp or cand.text == '　' then
          for i, cand in ipairs(dropped_cands) do yield(cand) end
          done_drop = true
          yield(cand)
        -- 精确匹配的词组不予后置
        elseif not drop or utf8.len(cand.text) > 1 then
          yield(cand)
          pos = pos + 1
        else table.insert(dropped_cands, cand)
        end
      end
    end
    for i, cand in ipairs(dropped_cands) do yield(cand) end
  end
end


return { init = init, func = filter }