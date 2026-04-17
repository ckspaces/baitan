-- ============================================================================
-- EventSystem.lua - 随机事件引擎（重构版：适配摆摊网红玩法）
-- ============================================================================

local EventSystem = {}

-- 事件定义
-- 字段说明:
--   name        显示名称
--   desc        描述文案
--   type        "negative" / "positive"
--   prob        触发权重概率
--   minMonth    最早在第几月触发
--   minTier     主业最低等级要求（默认1）
--   condition   额外条件函数 function(gs) return bool end （可选）
--   apply       效果函数 function(gs) end

local EVENT_POOL = {
    -- ========================================================================
    -- 负面事件
    -- ========================================================================
    {
        name = "催债电话",
        desc = "民间借贷的人又打电话来催了，压力好大...",
        type = "negative", prob = 0.12, minMonth = 1,
        apply = function(gs)
            gs.mood = math.max(0, gs.mood - 20)
        end,
    },
    {
        name = "身体不适",
        desc = "连续高强度摆摊，身体开始抗议了，不得不花钱看医生...",
        type = "negative", prob = 0.09, minMonth = 1,
        apply = function(gs)
            gs.energy = math.max(0, gs.energy - 30)
            gs.mood = math.max(0, gs.mood - 10)
            gs.cash = math.max(0, gs.cash - 2000)
            gs.addMessage("生病就医花了 -$2000", "warning")
        end,
    },
    {
        name = "原材料涨价",
        desc = "批发市场食材集体涨价，成本压力陡增...",
        type = "negative", prob = 0.12, minMonth = 1,
        apply = function(gs)
            local loss = math.random(500, 2000)
            gs.cash = math.max(0, gs.cash - loss)
            gs.mood = math.max(0, gs.mood - 8)
            gs.addMessage(string.format("食材成本上涨 -$%d", loss), "warning")
        end,
    },
    {
        name = "收到差评",
        desc = "有人在网上给你刷了一星差评，说卫生不合格，名气受损...",
        type = "negative", prob = 0.10, minMonth = 2,
        apply = function(gs)
            local fameLoss = math.random(15, 60)
            gs.fame = math.max(0, gs.fame - fameLoss)
            gs.mood = math.max(0, gs.mood - 12)
            gs.addMessage(string.format("差评来袭！名气 -%d", fameLoss), "danger")
        end,
    },
    {
        name = "平台限流",
        desc = "发布内容被平台算法降权，最近曝光量大减，粉丝增长停滞...",
        type = "negative", prob = 0.08, minMonth = 2,
        condition = function(gs) return (gs.followers or 0) >= 50 end,
        apply = function(gs)
            local fameLoss = math.random(20, 80)
            gs.fame = math.max(0, gs.fame - fameLoss)
            gs.mood = math.max(0, gs.mood - 10)
            gs.addMessage(string.format("被限流了，名气 -%d", fameLoss), "warning")
        end,
    },
    {
        name = "账号被封",
        desc = "社媒账号因内容违规被临时封禁，掉了一批粉！",
        type = "negative", prob = 0.05, minMonth = 3,
        condition = function(gs) return (gs.followers or 0) >= 100 end,
        apply = function(gs)
            local loss = math.random(80, 300)
            gs.followers = math.max(0, gs.followers - loss)
            gs.mood = math.max(0, gs.mood - 20)
            gs.addMessage(string.format("账号封禁！掉粉 -%d", loss), "danger")
        end,
    },
    {
        name = "手机碎屏",
        desc = "手机摔碎了屏，没法更新社媒，还得花钱修...",
        type = "negative", prob = 0.07, minMonth = 1,
        apply = function(gs)
            local cost = math.random(400, 900)
            gs.cash = math.max(0, gs.cash - cost)
            local fanLoss = math.random(10, 50)
            gs.followers = math.max(0, gs.followers - fanLoss)
            gs.mood = math.max(0, gs.mood - 12)
            gs.addMessage(string.format("修屏花了$%d，还掉了%d粉", cost, fanLoss), "warning")
        end,
    },
    {
        name = "食材变质",
        desc = "一批食材保存不当全变质了，直接扔掉，血亏...",
        type = "negative", prob = 0.09, minMonth = 1,
        apply = function(gs)
            local loss = math.random(300, 1500)
            gs.cash = math.max(0, gs.cash - loss)
            gs.mood = math.max(0, gs.mood - 8)
            gs.addMessage(string.format("食材报废损失 -$%d", loss), "warning")
        end,
    },
    {
        name = "同行抹黑",
        desc = "竞争对手散布谣言说你食材不干净，口碑受损...",
        type = "negative", prob = 0.07, minMonth = 2,
        apply = function(gs)
            local fameLoss = math.random(20, 50)
            gs.fame = math.max(0, gs.fame - fameLoss)
            gs.reputation = math.max(0, (gs.reputation or 0) - 3)
            gs.mood = math.max(0, gs.mood - 15)
            gs.addMessage("被同行抹黑，名气和口碑双降", "danger")
        end,
    },
    {
        name = "遭遇小偷",
        desc = "摆摊忙碌时，摊位旁的小包被人顺走了...",
        type = "negative", prob = 0.07, minMonth = 1,
        apply = function(gs)
            local loss = math.random(200, 1200)
            gs.cash = math.max(0, gs.cash - loss)
            gs.mood = math.max(0, gs.mood - 20)
            gs.addMessage(string.format("被偷！损失 -$%d，心情崩了", loss), "danger")
        end,
    },
    {
        name = "扭伤脚踝",
        desc = "摆摊来回跑不小心扭伤了脚，行动不便，体力大减...",
        type = "negative", prob = 0.07, minMonth = 1,
        apply = function(gs)
            gs.energy = math.max(0, gs.energy - 40)
            gs.mood = math.max(0, gs.mood - 15)
            gs.cash = math.max(0, gs.cash - 500)
            gs.addMessage("受伤！体力-40，药费 -$500", "warning")
        end,
    },
    {
        name = "设备损坏",
        desc = "煤气炉坏了，维修费一笔不少...",
        type = "negative", prob = 0.07, minMonth = 3,
        apply = function(gs)
            local cost = math.random(800, 3000)
            gs.cash = math.max(0, gs.cash - cost)
            gs.mood = math.max(0, gs.mood - 10)
            gs.addMessage(string.format("设备维修 -$%d", cost), "warning")
        end,
    },
    {
        name = "粉丝负面风波",
        desc = "某个粉丝把你之前说的一句话断章取义，引发争议，名气大跌...",
        type = "negative", prob = 0.05, minMonth = 4,
        condition = function(gs) return (gs.fame or 0) >= 300 end,
        apply = function(gs)
            local fameLoss = math.random(100, 300)
            local fanLoss = math.random(200, 800)
            gs.fame = math.max(0, gs.fame - fameLoss)
            gs.followers = math.max(0, gs.followers - fanLoss)
            gs.mood = math.max(0, gs.mood - 25)
            gs.addMessage(string.format("网络风波！名气-%d，掉粉%d", fameLoss, fanLoss), "danger")
        end,
    },
    {
        name = "租摊位被涨价",
        desc = "摊位负责人突然说要涨价，每月额外支出增加...",
        type = "negative", prob = 0.07, minMonth = 4,
        apply = function(gs)
            local cost = math.random(500, 2000)
            gs.cash = math.max(0, gs.cash - cost)
            gs.mood = math.max(0, gs.mood - 12)
            gs.addMessage(string.format("摊位费上涨 -$%d", cost), "warning")
        end,
    },

    -- ========================================================================
    -- 正面事件
    -- ========================================================================
    {
        name = "视频爆火",
        desc = "你随手拍的一个摆摊视频突然在网上火了！粉丝暴涨！",
        type = "positive", prob = 0.06, minMonth = 2,
        apply = function(gs)
            local fans = math.random(300, 2000)
            local fameGain = math.random(30, 120)
            gs.followers = gs.followers + fans
            gs.fame = gs.fame + fameGain
            gs.mood = math.min(100, gs.mood + 15)
            gs.addMessage(string.format("视频爆火！涨粉%d，名气+%d", fans, fameGain), "success")
        end,
    },
    {
        name = "口碑爆发",
        desc = "老顾客把亲朋好友都带来了，今天客流量暴增！",
        type = "positive", prob = 0.07, minMonth = 2,
        apply = function(gs)
            local income = math.random(500, 3000)
            gs.cash = gs.cash + income
            gs.reputation = (gs.reputation or 0) + math.random(3, 8)
            gs.mood = math.min(100, gs.mood + 12)
            gs.addMessage(string.format("口碑爆发！额外收入 +$%d", income), "success")
        end,
    },
    {
        name = "批发大甩卖",
        desc = "批发市场搞活动，食材成本大降，省了不少！",
        type = "positive", prob = 0.08, minMonth = 1,
        apply = function(gs)
            local saving = math.random(300, 1500)
            gs.cash = gs.cash + saving
            gs.mood = math.min(100, gs.mood + 8)
            gs.addMessage(string.format("食材打折省了 +$%d！", saving), "success")
        end,
    },
    {
        name = "励志照片出圈",
        desc = "路人把你专注摆摊的照片发上网，引发共鸣，涨粉了！",
        type = "positive", prob = 0.06, minMonth = 2,
        apply = function(gs)
            local fameGain = math.random(30, 120)
            local fanGain = math.random(80, 400)
            gs.fame = gs.fame + fameGain
            gs.followers = gs.followers + fanGain
            gs.mood = math.min(100, gs.mood + 15)
            gs.addMessage(string.format("励志照片出圈！名气+%d，涨粉%d", fameGain, fanGain), "success")
        end,
    },
    {
        name = "灵感迸发",
        desc = "刷到一个美食纪录片，突然对摆摊有了新思路，技能飞速成长！",
        type = "positive", prob = 0.07, minMonth = 1,
        apply = function(gs)
            gs.mood = math.min(100, gs.mood + 10)
            local types = { "management", "marketing", "charm", "negotiation" }
            local stype = types[math.random(1, #types)]
            local skill = gs.skills[stype]
            if skill then
                local xpGain = math.random(50, 130)
                skill.xp = skill.xp + xpGain
                local names = { management = "经营", marketing = "营销", charm = "魅力", negotiation = "谈判" }
                gs.addMessage(string.format("灵感！%s经验 +%d", names[stype] or stype, xpGain), "success")
            end
        end,
    },
    {
        name = "美食节曝光",
        desc = "当地美食节对你进行了专题报道，知名度大增！",
        type = "positive", prob = 0.04, minMonth = 3,
        condition = function(gs) return (gs.fame or 0) >= 80 end,
        apply = function(gs)
            local fameGain = math.random(80, 200)
            local fanGain = math.random(150, 600)
            gs.fame = gs.fame + fameGain
            gs.followers = gs.followers + fanGain
            gs.mood = math.min(100, gs.mood + 20)
            gs.addMessage(string.format("美食节专题！名气+%d，涨粉%d", fameGain, fanGain), "success")
        end,
    },
    {
        name = "小网红来合拍",
        desc = "一位粉丝量不少的小网红主动联系你，想合拍一期内容！",
        type = "positive", prob = 0.04, minMonth = 4,
        condition = function(gs) return (gs.fame or 0) >= 150 end,
        apply = function(gs)
            local fameGain = math.random(100, 350)
            local fanGain = math.random(300, 1200)
            gs.fame = gs.fame + fameGain
            gs.followers = gs.followers + fanGain
            gs.mood = math.min(100, gs.mood + 18)
            gs.addMessage(string.format("合拍成功！名气+%d，涨粉%d", fameGain, fanGain), "success")
        end,
    },
    {
        name = "粉丝打赏",
        desc = "直播时粉丝热情打赏，感谢你的美食内容！",
        type = "positive", prob = 0.06, minMonth = 2,
        condition = function(gs) return (gs.followers or 0) >= 200 end,
        apply = function(gs)
            local income = math.random(400, 2500)
            gs.cash = gs.cash + income
            gs.mood = math.min(100, gs.mood + 15)
            gs.addMessage(string.format("粉丝打赏 +$%d，感动！", income), "success")
        end,
    },
    {
        name = "品牌广告合作",
        desc = "一家食品品牌看到你的账号，主动来谈广告合作！",
        type = "positive", prob = 0.03, minMonth = 5,
        condition = function(gs) return (gs.followers or 0) >= 800 end,
        apply = function(gs)
            local income = math.random(3000, 10000)
            gs.cash = gs.cash + income
            gs.mood = math.min(100, gs.mood + 20)
            gs.addMessage(string.format("广告合作！收入 +$%s", gs.formatMoney(income)), "success")
        end,
    },
    {
        name = "创业补贴到账",
        desc = "小微企业创业补贴审批通过，政府扶持资金到账！",
        type = "positive", prob = 0.03, minMonth = 4,
        condition = function(gs) return gs.currentMonth <= 20 end,
        apply = function(gs)
            local subsidy = math.random(3000, 10000)
            gs.cash = gs.cash + subsidy
            gs.mood = math.min(100, gs.mood + 15)
            gs.addMessage(string.format("创业补贴到账 +$%s", gs.formatMoney(subsidy)), "success")
        end,
    },
    {
        name = "邻居雪中送炭",
        desc = "隔壁摊的老阿姨看你今天生意不好，主动分了一些食材！",
        type = "positive", prob = 0.06, minMonth = 1,
        condition = function(gs) return gs.cash < 2000 end,
        apply = function(gs)
            local help = math.random(300, 1000)
            gs.cash = gs.cash + help
            gs.mood = math.min(100, gs.mood + 20)
            gs.addMessage(string.format("邻居帮忙！食材相当于 +$%d，太感动了", help), "success")
        end,
    },
    {
        name = "陌生人好意",
        desc = "一位好心顾客看出你在难关，悄悄多付了很多钱……",
        type = "positive", prob = 0.06, minMonth = 1,
        condition = function(gs) return gs.cash < 500 end,
        apply = function(gs)
            local gift = math.random(300, 1000)
            gs.cash = gs.cash + gift
            gs.mood = math.min(100, gs.mood + 25)
            gs.addMessage(string.format("好心人馈赠 +$%d，眼眶都红了……", gift), "success")
        end,
    },
    {
        name = "厂家赠品",
        desc = "供货商感谢你长期合作，送来一批样品试吃，省了进货钱！",
        type = "positive", prob = 0.05, minMonth = 3,
        apply = function(gs)
            local value = math.random(500, 1800)
            gs.cash = gs.cash + value
            gs.mood = math.min(100, gs.mood + 10)
            gs.addMessage(string.format("收到赠品，价值约 +$%d", value), "success")
        end,
    },
    {
        name = "诚信回报",
        desc = "上次帮顾客垫付的那位，特意回来还钱，还多付了谢意！",
        type = "positive", prob = 0.06, minMonth = 2,
        apply = function(gs)
            local reward = math.random(400, 1500)
            gs.cash = gs.cash + reward
            gs.mood = math.min(100, gs.mood + 18)
            gs.reputation = (gs.reputation or 0) + 2
            gs.addMessage(string.format("诚信回报 +$%d，心里暖暖的", reward), "success")
        end,
    },
    {
        name = "老同学资助",
        desc = "多年不见的同学听说你在创业，专程过来捧场还塞了钱！",
        type = "positive", prob = 0.03, minMonth = 5,
        condition = function(gs) return gs.cash < 5000 end,
        apply = function(gs)
            local help = math.random(5000, 18000)
            gs.cash = gs.cash + help
            gs.mood = math.min(100, gs.mood + 25)
            gs.addMessage(string.format("同学资助！+$%s，感动到想哭", gs.formatMoney(help)), "success")
        end,
    },
    {
        name = "贵人相助",
        desc = "偶遇一位有经验的老前辈，送了你一些创业心得，技能和现金双涨！",
        type = "positive", prob = 0.03, minMonth = 5,
        apply = function(gs)
            local gift = math.random(20000, 80000)
            gs.cash = gs.cash + gift
            gs.mood = math.min(100, gs.mood + 20)
            gs.addMessage(string.format("贵人相助 +$%s！", gs.formatMoney(gift)), "success")
        end,
    },
}

-- ============================================================================
-- 场景专属事件池（按活动类型触发，40% 概率）
-- 场景: rest / relax / feast / hospital / pharmacy / supermarket / fishing / stall / livestream
-- ============================================================================

local CONTEXT_EVENTS = {
    -- ---- 休息 ----
    rest = {
        { name = "睡了个好觉", desc = "一觉到天亮，精力完全恢复！", type = "positive", prob = 0.4,
          apply = function(gs)
            gs.energy = math.min(100, gs.energy + 35)
            gs.health = math.min(100, (gs.health or 100) + 5)
            gs.addMessage("睡眠质量极好！体力+35，健康+5", "success")
          end },
        { name = "失眠噩梦", desc = "睡前刷手机，辗转反侧，天亮了还是没睡好...", type = "negative", prob = 0.2,
          apply = function(gs)
            gs.energy = math.max(0, gs.energy - 15)
            gs.mood = math.max(0, gs.mood - 12)
            gs.addMessage("失眠！体力-15，心情-12", "warning")
          end },
        { name = "做了个好梦", desc = "梦见自己当了大老板，醒来心情特别好！", type = "positive", prob = 0.3,
          apply = function(gs)
            gs.mood = math.min(100, gs.mood + 20)
            gs.addMessage("做了个好梦！心情+20", "success")
          end },
        { name = "灵感闪现", desc = "休息时突然想到了提高营业额的新办法！", type = "positive", prob = 0.1,
          apply = function(gs)
            local types = { "management", "marketing", "charm", "negotiation" }
            local stype = types[math.random(1, #types)]
            if gs.skills[stype] then
                gs.skills[stype].xp = gs.skills[stype].xp + 60
                gs.addMessage("灵感来了！相关技能经验+60", "success")
            end
          end },
    },

    -- ---- 放松 ----
    relax = {
        { name = "刷到干货视频", desc = "刷到一个厉害的营销课，偷偷学了干货！", type = "positive", prob = 0.35,
          apply = function(gs)
            local types = { "management", "marketing" }
            local stype = types[math.random(1, #types)]
            if gs.skills[stype] then
                gs.skills[stype].xp = gs.skills[stype].xp + 80
                gs.mood = math.min(100, gs.mood + 10)
                gs.addMessage("学到干货！相关技能经验+80，心情+10", "success")
            end
          end },
        { name = "不小心充值", desc = "刷着刷着手滑充了个大会员...", type = "negative", prob = 0.2,
          apply = function(gs)
            local cost = math.random(50, 200)
            gs.cash = math.max(0, gs.cash - cost)
            gs.mood = math.max(0, gs.mood - 5)
            gs.addMessage(string.format("手滑充值 -$%d，后悔死了", cost), "warning")
          end },
        { name = "遇到老朋友", desc = "逛着逛着遇到了多年不见的老朋友，聊得很开心！", type = "positive", prob = 0.25,
          apply = function(gs)
            gs.mood = math.min(100, gs.mood + 22)
            gs.addMessage("遇见老友，心情大好！心情+22", "success")
          end },
        { name = "看了励志片", desc = "看了部励志电影，重新燃起了斗志！", type = "positive", prob = 0.2,
          apply = function(gs)
            gs.mood = math.min(100, gs.mood + 15)
            gs.energy = math.min(100, gs.energy + 10)
            gs.addMessage("励志满满！心情+15，体力+10", "success")
          end },
    },

    -- ---- 下馆子/大餐 ----
    feast = {
        { name = "偷师厨艺", desc = "在餐厅观察大厨手法，学到了不少烹饪技巧！", type = "positive", prob = 0.35,
          apply = function(gs)
            if gs.skills["cooking"] then
                gs.skills["cooking"].xp = gs.skills["cooking"].xp + 100
            end
            gs.mood = math.min(100, gs.mood + 10)
            gs.addMessage("学到厨艺！烹饪技能经验+100", "success")
          end },
        { name = "录了美食vlog", desc = "边吃边录，发了条美食探店视频，粉丝涨了！", type = "positive", prob = 0.3,
          apply = function(gs)
            local fanGain = math.random(30, 200)
            local fameGain = math.random(15, 80)
            gs.followers = gs.followers + fanGain
            gs.fame = gs.fame + fameGain
            gs.mood = math.min(100, gs.mood + 12)
            gs.addMessage(string.format("美食vlog！涨粉%d，名气+%d", fanGain, fameGain), "success")
          end },
        { name = "吃坏肚子了", desc = "不知道吃了什么不新鲜的，晚上拉肚子...", type = "negative", prob = 0.15,
          apply = function(gs)
            gs.health = math.max(0, (gs.health or 100) - 15)
            gs.energy = math.max(0, gs.energy - 20)
            gs.mood = math.max(0, gs.mood - 10)
            gs.addMessage("食物不洁！健康-15，体力-20，心情-10", "danger")
          end },
        { name = "遇到美食达人", desc = "餐厅遇到一位美食博主，互相加了微信！", type = "positive", prob = 0.2,
          apply = function(gs)
            local fameGain = math.random(20, 80)
            gs.fame = gs.fame + fameGain
            gs.mood = math.min(100, gs.mood + 15)
            gs.addMessage(string.format("结交美食达人！名气+%d", fameGain), "success")
          end },
    },

    -- ---- 去医院 ----
    hospital = {
        { name = "等待时间超长", desc = "医院人超多，等了两个多小时，体力大减...", type = "negative", prob = 0.3,
          apply = function(gs)
            gs.energy = math.max(0, gs.energy - 25)
            gs.mood = math.max(0, gs.mood - 8)
            gs.addMessage("排队耗尽体力！体力-25，心情-8", "warning")
          end },
        { name = "医生好建议", desc = "医生不仅治了病还给了很多养生建议，很有用！", type = "positive", prob = 0.35,
          apply = function(gs)
            gs.health = math.min(100, (gs.health or 100) + 15)
            gs.mood = math.min(100, gs.mood + 10)
            gs.addMessage("医生妙手回春！健康+15，心情+10", "success")
          end },
        { name = "检查出小毛病", desc = "顺带检查了一下，发现个小问题，多花了一笔...", type = "negative", prob = 0.2,
          apply = function(gs)
            local cost = math.random(500, 2000)
            gs.cash = math.max(0, gs.cash - cost)
            gs.mood = math.max(0, gs.mood - 5)
            gs.addMessage(string.format("额外检查费 -$%d", cost), "warning")
          end },
        { name = "遇病友聊开了", desc = "和旁边的病友聊了很久，互相鼓励，心情反而好了！", type = "positive", prob = 0.15,
          apply = function(gs)
            gs.mood = math.min(100, gs.mood + 18)
            gs.addMessage("与病友互励，心情+18", "success")
          end },
    },

    -- ---- 去药店 ----
    pharmacy = {
        { name = "发现特效药", desc = "找到了对症的特效药，效果比普通药好多了！", type = "positive", prob = 0.35,
          apply = function(gs)
            gs.health = math.min(100, (gs.health or 100) + 10)
            gs.addMessage("特效药！健康额外+10", "success")
          end },
        { name = "药品打折", desc = "今天药店搞活动，买一送一，省了不少！", type = "positive", prob = 0.25,
          apply = function(gs)
            local saving = math.random(50, 300)
            gs.cash = gs.cash + saving
            gs.mood = math.min(100, gs.mood + 8)
            gs.addMessage(string.format("药品打折省了 +$%d", saving), "success")
          end },
        { name = "店员推销保健品", desc = "店员一直推销各种保健品，没买，但搞得很烦...", type = "negative", prob = 0.2,
          apply = function(gs)
            gs.mood = math.max(0, gs.mood - 8)
            gs.addMessage("被保健品推销烦到了，心情-8", "warning")
          end },
        { name = "营业员给小贴士", desc = "好心的营业员教了你几个省钱买药的技巧！", type = "positive", prob = 0.2,
          apply = function(gs)
            gs.mood = math.min(100, gs.mood + 10)
            gs.addMessage("学到了省钱技巧，心情+10", "success")
          end },
    },

    -- ---- 超市 ----
    supermarket = {
        { name = "发现特价商品", desc = "超市今日特价，随手买了一堆好东西！", type = "positive", prob = 0.3,
          apply = function(gs)
            local saving = math.random(100, 500)
            gs.cash = gs.cash + saving
            gs.mood = math.min(100, gs.mood + 12)
            gs.addMessage(string.format("捡漏特价！省了 +$%d", saving), "success")
          end },
        { name = "遇见老顾客", desc = "超市偶遇你的老顾客，当场推荐了好几个朋友关注你！", type = "positive", prob = 0.2,
          apply = function(gs)
            local fanGain = math.random(10, 60)
            gs.followers = gs.followers + fanGain
            gs.mood = math.min(100, gs.mood + 15)
            gs.addMessage(string.format("老顾客帮推广！涨粉%d", fanGain), "success")
          end },
        { name = "结账长队", desc = "收银台排了超长的队，等得不耐烦了...", type = "negative", prob = 0.25,
          apply = function(gs)
            gs.energy = math.max(0, gs.energy - 10)
            gs.mood = math.max(0, gs.mood - 8)
            gs.addMessage("排队结账，体力-10，心情-8", "warning")
          end },
        { name = "买到食材新品", desc = "发现了一款新的食材，灵感大发！", type = "positive", prob = 0.25,
          apply = function(gs)
            gs.mood = math.min(100, gs.mood + 12)
            local fameGain = math.random(10, 40)
            gs.fame = gs.fame + fameGain
            gs.addMessage(string.format("发现新食材！名气+%d", fameGain), "success")
          end },
    },

    -- ---- 钓鱼 ----
    fishing = {
        { name = "钓到大鱼", desc = "运气爆棚！钓上来一条超大的鱼！", type = "positive", prob = 0.25,
          apply = function(gs)
            local bonus = math.random(3, 8)
            gs.fishStock = (gs.fishStock or 0) + bonus
            gs.mood = math.min(100, gs.mood + 20)
            gs.addMessage(string.format("大鱼！额外获得%d条鱼！", bonus), "success")
          end },
        { name = "钓竿断了", desc = "用力过猛，钓竿突然断了，还损失了鱼饵...", type = "negative", prob = 0.2,
          apply = function(gs)
            local cost = math.random(100, 400)
            gs.cash = math.max(0, gs.cash - cost)
            gs.mood = math.max(0, gs.mood - 15)
            gs.addMessage(string.format("钓竿断了！修理费 -$%d，心情-15", cost), "warning")
          end },
        { name = "直播钓鱼爆火", desc = "顺手开了直播，没想到钓鱼视频突然火了！", type = "positive", prob = 0.2,
          apply = function(gs)
            local fanGain = math.random(100, 600)
            local fameGain = math.random(30, 150)
            gs.followers = gs.followers + fanGain
            gs.fame = gs.fame + fameGain
            gs.mood = math.min(100, gs.mood + 18)
            gs.addMessage(string.format("钓鱼直播爆火！涨粉%d，名气+%d", fanGain, fameGain), "success")
          end },
        { name = "钓友分享技巧", desc = "旁边的钓鱼高手传授了几招绝活！", type = "positive", prob = 0.2,
          apply = function(gs)
            gs.mood = math.min(100, gs.mood + 15)
            gs.addMessage("学到钓鱼绝活，心情愉悦！心情+15", "success")
          end },
        { name = "风景怡人", desc = "湖边风景太美了，心情整个舒畅开来！", type = "positive", prob = 0.15,
          apply = function(gs)
            gs.mood = math.min(100, gs.mood + 18)
            gs.energy = math.min(100, gs.energy + 10)
            gs.addMessage("大自然治愈！心情+18，体力+10", "success")
          end },
    },

    -- ---- 摆摊中 ----
    stall = {
        { name = "顾客排长龙", desc = "今天不知为何特别多人，生意超好！", type = "positive", prob = 0.25,
          apply = function(gs)
            local income = math.random(300, 1500)
            gs.cash = gs.cash + income
            gs.stallTrust = math.min(100, gs.stallTrust + 3)
            gs.addMessage(string.format("排队抢购！额外收入 +$%d", income), "success")
          end },
        { name = "设备突然故障", desc = "炉子出了问题，急忙找人维修，耽误了生意...", type = "negative", prob = 0.2,
          apply = function(gs)
            local cost = math.random(200, 800)
            gs.cash = math.max(0, gs.cash - cost)
            gs.mood = math.max(0, gs.mood - 10)
            gs.addMessage(string.format("设备故障！维修费 -$%d", cost), "warning")
          end },
        { name = "收到好评卡", desc = "顾客主动在手机上给了五星好评，口碑大涨！", type = "positive", prob = 0.25,
          apply = function(gs)
            local fameGain = math.random(15, 50)
            gs.fame = gs.fame + fameGain
            gs.stallTrust = math.min(100, gs.stallTrust + 5)
            gs.mood = math.min(100, gs.mood + 12)
            gs.addMessage(string.format("五星好评！名气+%d，口碑+5", fameGain), "success")
          end },
        { name = "老顾客带全家", desc = "一位老顾客带来了他全家来光顾！", type = "positive", prob = 0.3,
          apply = function(gs)
            local income = math.random(200, 800)
            gs.cash = gs.cash + income
            gs.stallTrust = math.min(100, gs.stallTrust + 4)
            gs.addMessage(string.format("老顾客带全家！额外收入 +$%d，口碑+4", income), "success")
          end },
    },

    -- ---- 直播中 ----
    livestream = {
        { name = "直播突然爆火", desc = "不知道哪来的流量，直播间突然涌入大量新观众！", type = "positive", prob = 0.2,
          apply = function(gs)
            local fanGain = math.random(200, 1500)
            local fameGain = math.random(50, 200)
            gs.followers = gs.followers + fanGain
            gs.fame = gs.fame + fameGain
            gs.mood = math.min(100, gs.mood + 20)
            gs.addMessage(string.format("直播爆火！涨粉%d，名气+%d", fanGain, fameGain), "success")
          end },
        { name = "黑粉来刷屏", desc = "直播间突然来了一波黑粉，刷侮辱性弹幕...", type = "negative", prob = 0.2,
          apply = function(gs)
            local fameLoss = math.random(20, 80)
            gs.fame = math.max(0, gs.fame - fameLoss)
            gs.mood = math.max(0, gs.mood - 15)
            gs.addMessage(string.format("黑粉入侵！名气-%d，心情-15", fameLoss), "danger")
          end },
        { name = "大V空降", desc = "一位百万大V意外进了你的直播间并@粉丝来看！", type = "positive", prob = 0.1,
          apply = function(gs)
            local fanGain = math.random(1000, 5000)
            local fameGain = math.random(100, 400)
            gs.followers = gs.followers + fanGain
            gs.fame = gs.fame + fameGain
            gs.mood = math.min(100, gs.mood + 25)
            gs.addMessage(string.format("大V空降！涨粉%d，名气+%d！", fanGain, fameGain), "success")
          end },
        { name = "技术突然故障", desc = "直播时网络或设备出了问题，直播中断，损失大批观众！", type = "negative", prob = 0.15,
          apply = function(gs)
            local fanLoss = math.random(50, 300)
            gs.followers = math.max(0, gs.followers - fanLoss)
            gs.mood = math.max(0, gs.mood - 12)
            gs.addMessage(string.format("直播故障！掉粉%d，心情-12", fanLoss), "warning")
          end },
        { name = "粉丝送大礼", desc = "一位铁粉在直播间连续打赏，说是给你鼓励！", type = "positive", prob = 0.2,
          apply = function(gs)
            local gift = math.random(300, 2000)
            gs.cash = gs.cash + gift
            gs.mood = math.min(100, gs.mood + 18)
            gs.addMessage(string.format("粉丝打赏 +$%d！感动！", gift), "success")
          end },
        { name = "连麦互动超火", desc = "和观众连麦互动效果超好，直播间气氛很活跃！", type = "positive", prob = 0.15,
          apply = function(gs)
            local fameGain = math.random(30, 100)
            gs.fame = gs.fame + fameGain
            gs.mood = math.min(100, gs.mood + 12)
            gs.addMessage(string.format("连麦互动！名气+%d", fameGain), "success")
          end },
    },
}

--- 本回合事件结果
EventSystem.lastEvent = nil

--- 随机触发事件（每回合30%概率）
function EventSystem.rollEvent(gs, config)
    EventSystem.lastEvent = nil

    if math.random() > 0.30 then
        return nil
    end

    local currentTier = gs.mainBizTier or 1

    -- 收集可触发的事件
    local candidates = {}
    for _, evt in ipairs(EVENT_POOL) do
        if gs.currentMonth >= (evt.minMonth or 1) then
            local tierOk = not evt.minTier or currentTier >= evt.minTier
            local condOk = not evt.condition or evt.condition(gs)
            if tierOk and condOk then
                table.insert(candidates, evt)
            end
        end
    end

    if #candidates == 0 then return nil end

    local totalProb = 0
    for _, evt in ipairs(candidates) do
        totalProb = totalProb + evt.prob
    end

    local roll = math.random() * totalProb
    local acc = 0
    for _, evt in ipairs(candidates) do
        acc = acc + evt.prob
        if roll <= acc then
            evt.apply(gs)
            local typeLabel = evt.type == "positive" and "success" or "warning"
            gs.addMessage("[事件] " .. evt.name .. "：" .. evt.desc, typeLabel)
            EventSystem.lastEvent = evt
            return evt
        end
    end

    return nil
end

--- 场景随机事件（40%概率，从指定场景的事件池中选取）
--- @param gs table         游戏状态
--- @param config table     游戏配置
--- @param context string   场景标识：rest/relax/feast/hospital/pharmacy/supermarket/fishing/stall/livestream
function EventSystem.rollContextEvent(gs, config, context)
    local pool = CONTEXT_EVENTS[context]
    if not pool or #pool == 0 then return nil end

    if math.random() > 0.40 then return nil end

    -- 加权随机
    local totalProb = 0
    for _, evt in ipairs(pool) do
        totalProb = totalProb + evt.prob
    end

    local roll = math.random() * totalProb
    local acc = 0
    for _, evt in ipairs(pool) do
        acc = acc + evt.prob
        if roll <= acc then
            evt.apply(gs)
            local typeLabel = evt.type == "positive" and "success" or "warning"
            gs.addMessage("[" .. context .. "] " .. evt.name .. "：" .. evt.desc, typeLabel)
            return evt
        end
    end

    return nil
end

return EventSystem
