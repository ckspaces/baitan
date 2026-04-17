-- ============================================================================
-- PlayerSystem.lua - 体力/心情/技能/经验（重构版：移除openShop/runShop）
-- ============================================================================

local FinanceSystem = require("core.FinanceSystem")

local PlayerSystem = {}

--- 休息
function PlayerSystem.rest(gs, config)
    local C = config.Rest
    gs.energy = math.min(config.Player.MAX_ENERGY, gs.energy + C.ENERGY_GAIN)
    gs.mood = math.min(config.Player.MAX_MOOD, gs.mood + C.MOOD_GAIN)
    gs.currentActivity = "resting"
    gs.addMessage(string.format("休息了一下，体力+%d 心情+%d", C.ENERGY_GAIN, C.MOOD_GAIN), "info")
    return true
end

--- 娱乐
function PlayerSystem.relax(gs, config)
    local C = config.Relax
    if gs.cash < C.CASH_COST then
        gs.addMessage("钱不够去玩！", "warning")
        return false
    end
    gs.cash = gs.cash - C.CASH_COST
    gs.energy = math.max(0, gs.energy - C.ENERGY_COST)
    gs.mood = math.min(config.Player.MAX_MOOD, gs.mood + C.MOOD_GAIN)
    gs.currentActivity = "eating"
    gs.addMessage(string.format("放松一下，心情+%d 花费$%d", C.MOOD_GAIN, C.CASH_COST), "info")
    return true
end

--- 吃大餐
function PlayerSystem.feast(gs, config)
    if gs.cash < 800 then
        gs.addMessage("钱不够吃大餐！", "warning")
        return false
    end
    gs.cash = gs.cash - 800
    gs.mood = math.min(config.Player.MAX_MOOD, gs.mood + 30)
    gs.energy = math.min(config.Player.MAX_ENERGY, gs.energy + 10)
    gs.currentActivity = "eating"
    gs.addMessage("吃了顿大餐，心情+30 体力+10", "success")
    return true
end

--- 还款
function PlayerSystem.repay(gs, amount, config)
    local paid = FinanceSystem.manualRepay(gs, amount)
    return paid > 0
end

--- 借款
function PlayerSystem.borrow(gs, amount, config)
    FinanceSystem.borrowShark(gs, amount)
    return true
end

--- 去医院
function PlayerSystem.goHospital(gs, config)
    local H = config.Health
    if gs.cash < H.HOSPITAL_COST then
        gs.addMessage(string.format("去医院需要 $%d，钱不够！", H.HOSPITAL_COST), "warning")
        return false
    end
    gs.cash = gs.cash - H.HOSPITAL_COST
    gs.health = math.min(config.Player.MAX_HEALTH, gs.health + H.HOSPITAL_HEAL)
    if gs.isSick then
        gs.isSick = false
        gs.sickDays = 0
        gs.addMessage(string.format("去医院看病花了$%d，病治好了！健康+%d", H.HOSPITAL_COST, H.HOSPITAL_HEAL), "success")
        gs.addLog("去医院看病，恢复健康", "info")
    else
        gs.addMessage(string.format("去医院体检花了$%d，健康+%d", H.HOSPITAL_COST, H.HOSPITAL_HEAL), "info")
    end
    gs.currentActivity = "resting"
    return true
end

--- 去药店
function PlayerSystem.goPharmacy(gs, config)
    local H = config.Health
    if gs.cash < H.PHARMACY_COST then
        gs.addMessage(string.format("买药需要 $%d，钱不够！", H.PHARMACY_COST), "warning")
        return false
    end
    gs.cash = gs.cash - H.PHARMACY_COST
    gs.health = math.min(config.Player.MAX_HEALTH, gs.health + H.PHARMACY_HEAL)
    if gs.isSick then
        -- 药店只能缓解，不一定治好
        if gs.health >= (H.SICK_THRESHOLD or 30) + 20 then
            gs.isSick = false
            gs.sickDays = 0
            gs.addMessage(string.format("买药花了$%d，吃完药感觉好多了，病好了！健康+%d", H.PHARMACY_COST, H.PHARMACY_HEAL), "success")
            gs.addLog("买药吃药，病情痊愈", "info")
        else
            gs.addMessage(string.format("买药花了$%d，症状缓解了一些，但还没完全好…健康+%d", H.PHARMACY_COST, H.PHARMACY_HEAL), "warning")
        end
    else
        gs.addMessage(string.format("买了保健品$%d，健康+%d", H.PHARMACY_COST, H.PHARMACY_HEAL), "info")
    end
    gs.currentActivity = "resting"
    gs.currentScene = "pharmacy"
    return true
end

--- 去超市（设置场景，不推进时间，由购买商品后统一推进）
function PlayerSystem.goSupermarket(gs, config)
    gs.currentActivity = "shopping"
    gs.currentScene = "supermarket"
    return true
end

--- 去钓鱼（消耗体力，进入钓鱼场景，通过 FishingMiniGame 获得鱼）
function PlayerSystem.goFishing(gs, config)
    local F = config.Fishing
    if gs.energy < F.ENERGY_COST then
        gs.addMessage(string.format("体力不足！钓鱼需要体力 %d，先去休息一下吧", F.ENERGY_COST), "warning")
        return false
    end
    gs.energy = gs.energy - F.ENERGY_COST
    gs.currentScene = "fishing"
    gs.currentActivity = "fishing"
    gs.addMessage(string.format("拿上鱼竿去湖边，消耗体力%d", F.ENERGY_COST), "info")
    return true
end

--- 在超市购买商品
function PlayerSystem.buyFromSupermarket(gs, config, itemId)
    local S = config.Supermarket
    local P = config.Player

    -- 检查购买次数
    if gs.supermarketPurchasesToday >= S.MAX_PURCHASES_PER_DAY then
        gs.addMessage("今天已经买够了，明天再来吧", "warning")
        return false
    end

    -- 查找商品
    local item = nil
    for _, it in ipairs(S.ITEMS) do
        if it.id == itemId then
            item = it
            break
        end
    end
    if not item then
        gs.addMessage("找不到这个商品", "warning")
        return false
    end

    -- 检查金额
    if gs.cash < item.price then
        gs.addMessage(string.format("买不起 %s%s，需要$%d", item.emoji, item.name, item.price), "warning")
        return false
    end

    -- 扣款 + 应用效果
    gs.cash = gs.cash - item.price
    local eff = item.effects
    local parts = {}

    if eff.energy and eff.energy ~= 0 then
        gs.energy = math.max(0, math.min(P.MAX_ENERGY, gs.energy + eff.energy))
        local sign = eff.energy > 0 and "+" or ""
        parts[#parts + 1] = string.format("体力%s%d", sign, eff.energy)
    end
    if eff.mood and eff.mood ~= 0 then
        gs.mood = math.max(0, math.min(P.MAX_MOOD, gs.mood + eff.mood))
        local sign = eff.mood > 0 and "+" or ""
        parts[#parts + 1] = string.format("心情%s%d", sign, eff.mood)
    end
    if eff.health and eff.health ~= 0 then
        gs.health = math.max(0, math.min(P.MAX_HEALTH, gs.health + eff.health))
        local sign = eff.health > 0 and "+" or ""
        parts[#parts + 1] = string.format("健康%s%d", sign, eff.health)
    end

    gs.supermarketPurchasesToday = gs.supermarketPurchasesToday + 1
    local effectStr = table.concat(parts, " ")
    gs.addMessage(string.format("购买了 %s%s -$%d | %s", item.emoji, item.name, item.price, effectStr), "success")
    return true
end

--- 添加技能经验（返回是否升级）
function PlayerSystem.addSkillXP(gs, skillType, xp, config)
    local skill = gs.skills[skillType]
    if not skill then return false end
    if skill.level >= config.Skills.MAX_LEVEL then return false end

    skill.xp = skill.xp + xp
    local threshold = config.Skills.XP_PER_LEVEL[skill.level] or 99999

    if skill.xp >= threshold then
        skill.xp = skill.xp - threshold
        skill.level = math.min(skill.level + 1, config.Skills.MAX_LEVEL)
        return true
    end
    return false
end

return PlayerSystem
