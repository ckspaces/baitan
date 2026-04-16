-- ============================================================================
-- EventSystem.lua - 随机事件引擎（重构版：适配主业等级系统）
-- ============================================================================

local EventSystem = {}

-- 事件定义
local EVENT_POOL = {
    -- 负面事件
    {
        name = "房东涨租",
        desc = "房东突然说要涨30%的租金...",
        type = "negative",
        prob = 0.12,
        minMonth = 3,
        minTier = 2,  -- 只有开店后才有租金
        apply = function(gs) gs.mood = math.max(0, gs.mood - 15) end,
    },
    {
        name = "身体不适",
        desc = "连续加班导致身体抱恙，需要休养...",
        type = "negative",
        prob = 0.10,
        minMonth = 1,
        apply = function(gs)
            gs.energy = math.max(0, gs.energy - 30)
            gs.mood = math.max(0, gs.mood - 10)
            gs.cash = math.max(0, gs.cash - 3000)
        end,
    },
    {
        name = "催债电话",
        desc = "民间借贷的人又打电话来催了...",
        type = "negative",
        prob = 0.15,
        minMonth = 1,
        apply = function(gs)
            gs.mood = math.max(0, gs.mood - 20)
        end,
    },
    {
        name = "设备损坏",
        desc = "店里的设备坏了，需要维修费用",
        type = "negative",
        prob = 0.08,
        minMonth = 4,
        minTier = 2,
        apply = function(gs)
            local cost = math.random(5000, 20000) * (gs.mainBizTier or 1)
            gs.cash = gs.cash - cost
            gs.addMessage(string.format("维修花费 $%s", gs.formatMoney(cost)), "warning")
        end,
    },

    -- 正面事件
    {
        name = "贵人相助",
        desc = "一位老朋友主动借了一笔钱给你，不收利息！",
        type = "positive",
        prob = 0.04,
        minMonth = 6,
        apply = function(gs)
            local gift = math.random(50000, 200000)
            gs.cash = gs.cash + gift
            gs.mood = math.min(100, gs.mood + 20)
            gs.addMessage(string.format("朋友资助 +$%s", gs.formatMoney(gift)), "success")
        end,
    },
    {
        name = "视频爆火",
        desc = "你随手拍的一个视频突然火了！涨了一大波粉",
        type = "positive",
        prob = 0.06,
        minMonth = 3,
        apply = function(gs)
            local fans = math.random(500, 5000)
            gs.followers = gs.followers + fans
            gs.mood = math.min(100, gs.mood + 15)
            gs.addMessage(string.format("涨粉 +%d", fans), "success")
        end,
    },
    {
        name = "大单上门",
        desc = "一位客户下了一笔大订单！",
        type = "positive",
        prob = 0.07,
        minMonth = 4,
        minTier = 2,
        apply = function(gs)
            local income = math.random(20000, 100000) * (gs.mainBizTier or 1)
            gs.cash = gs.cash + income
            gs.mood = math.min(100, gs.mood + 10)
            gs.addMessage(string.format("大单收入 +$%s", gs.formatMoney(income)), "success")
        end,
    },
    {
        name = "捡到优惠",
        desc = "路边捡到一张优惠券，省了一笔！",
        type = "positive",
        prob = 0.10,
        minMonth = 1,
        apply = function(gs)
            gs.mood = math.min(100, gs.mood + 8)
            gs.cash = gs.cash + math.random(500, 3000)
        end,
    },
    {
        name = "灵感迸发",
        desc = "突然想到了一个好主意，经验大涨！",
        type = "positive",
        prob = 0.06,
        minMonth = 2,
        apply = function(gs)
            gs.mood = math.min(100, gs.mood + 10)
            local types = { "management", "marketing", "tech", "charm", "negotiation" }
            local stype = types[math.random(1, #types)]
            local skill = gs.skills[stype]
            if skill then
                skill.xp = skill.xp + math.random(30, 80)
            end
        end,
    },

    {
        name = "口碑传开",
        desc = "好口碑传开了，声望和客流都涨了！",
        type = "positive",
        prob = 0.06,
        minMonth = 2,
        apply = function(gs)
            gs.reputation = (gs.reputation or 0) + math.random(5, 12)
            gs.followers = gs.followers + math.random(20, 80)
            gs.mood = math.min(100, gs.mood + 8)
        end,
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
        if gs.currentMonth >= evt.minMonth then
            local tierOk = not evt.minTier or currentTier >= evt.minTier
            if tierOk then
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
            gs.addMessage("[事件] " .. evt.name .. ": " .. evt.desc, typeLabel)
            EventSystem.lastEvent = evt
            return evt
        end
    end

    return nil
end

return EventSystem
