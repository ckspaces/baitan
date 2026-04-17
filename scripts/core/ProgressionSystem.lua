-- ============================================================================
-- ProgressionSystem.lua - 主业升级系统（摆摊→大排档→餐饮→大酒店）
-- ============================================================================

local ProgressionSystem = {}

--- 获取当前等级定义
function ProgressionSystem.getCurrentTier(gs, config)
    local tier = gs.mainBizTier or 1
    return config.MainBusinessTiers[tier]
end

--- 获取下一等级定义（如果有）
function ProgressionSystem.getNextTier(gs, config)
    local tier = gs.mainBizTier or 1
    if tier >= #config.MainBusinessTiers then return nil end
    return config.MainBusinessTiers[tier + 1]
end

--- 获取当前等级对应的菜品列表（Tier 1 支持地点专属商品）
function ProgressionSystem.getCurrentItems(gs, config)
    local tier = gs.mainBizTier or 1
    if tier == 2 then return config.DapaidangItems
    elseif tier == 3 then return config.RestaurantItems
    elseif tier == 4 then return config.HotelItems
    end
    -- Tier 1: 通用商品 + 当前地点专属商品
    local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    if loc and config.LocationItems and config.LocationItems[loc.id] then
        local combined = {}
        -- 先放通用商品
        for _, item in ipairs(config.StallItems) do
            combined[#combined + 1] = item
        end
        -- 再追加地点专属商品
        for _, item in ipairs(config.LocationItems[loc.id]) do
            combined[#combined + 1] = item
        end
        return combined
    end
    return config.StallItems
end

function ProgressionSystem.getItemProgress(gs, itemId)
    local progress = gs.itemProgress or {}
    return progress[itemId] or 0
end

function ProgressionSystem.getItemUnlockRequirement(index, config)
    if index <= 1 then return 0 end
    local R = config.RecipeProgression or {}
    local baseXP = R.UNLOCK_XP_BASE or 16
    local stepXP = R.UNLOCK_XP_STEP or 10
    return baseXP + (index - 2) * stepXP
end

function ProgressionSystem.getItemUnlockStatus(gs, config, index, items)
    items = items or ProgressionSystem.getCurrentItems(gs, config)
    local item = items[index]
    if not item then
        return { unlocked = false, reason = missing }
    end

    local skillOk = gs.meetsSkillReq(item.skillReq)
    local monthReq = item.unlockMonth or 1
    local monthOk = (gs.currentMonth or 1) >= monthReq

    if index == 1 then
        return {
            unlocked = skillOk and monthOk,
            skillOk = skillOk,
            monthOk = monthOk,
            monthReq = monthReq,
            requiredXP = 0,
            currentXP = 0,
            previousItem = nil,
        }
    end

    local previousItem = items[index - 1]
    local requiredXP = ProgressionSystem.getItemUnlockRequirement(index, config)
    local currentXP = previousItem and ProgressionSystem.getItemProgress(gs, previousItem.id) or 0

    return {
        unlocked = skillOk and monthOk and currentXP >= requiredXP,
        skillOk = skillOk,
        monthOk = monthOk,
        monthReq = monthReq,
        requiredXP = requiredXP,
        currentXP = currentXP,
        previousItem = previousItem,
    }
end

function ProgressionSystem.isItemUnlocked(gs, config, index, items)
    return ProgressionSystem.getItemUnlockStatus(gs, config, index, items).unlocked
end

--- 获取当前地点的专属促销活动列表（返回空表或促销列表）
function ProgressionSystem.getLocationPromotions(gs, config)
    local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    if not loc or not config.LocationPromotions then return {} end
    return config.LocationPromotions[loc.id] or {}
end

--- 获取当前等级对应的场景ID
function ProgressionSystem.getCurrentScene(gs, config)
    local tierDef = ProgressionSystem.getCurrentTier(gs, config)
    return tierDef and tierDef.scene or "stall"
end

--- 检查是否满足升级条件
function ProgressionSystem.canUpgrade(gs, config)
    local nextTier = ProgressionSystem.getNextTier(gs, config)
    if not nextTier then return false, "已是最高等级" end

    local req = nextTier.unlockReq
    if not req then return true, "" end

    -- 检查月份
    if req.month and gs.currentMonth < req.month then
        return false, string.format("需要第%d个月（当前第%d月）", req.month, gs.currentMonth)
    end

    -- 检查技能
    if req.skills then
        for skill, level in pairs(req.skills) do
            if gs.getSkillLevel(skill) < level then
                local sname = config.Skills.NAMES[skill] or skill
                return false, string.format("%s需要Lv.%d", sname, level)
            end
        end
    end

    -- 检查摆摊天数
    if req.stallDays and (gs.stallDayCount or 0) < req.stallDays then
        return false, string.format("需要摆摊%d天（已%d天）", req.stallDays, gs.stallDayCount or 0)
    end

    -- 检查声望
    if req.reputation and (gs.reputation or 0) < req.reputation then
        return false, string.format("需要声望%d（当前%d）", req.reputation, gs.reputation or 0)
    end

    -- 检查资金
    if gs.cash < nextTier.upgradeCost then
        return false, string.format("需要$%s", gs.formatMoney(nextTier.upgradeCost))
    end

    return true, ""
end

--- 执行升级
function ProgressionSystem.upgrade(gs, config)
    local can, reason = ProgressionSystem.canUpgrade(gs, config)
    if not can then
        gs.addMessage("无法升级: " .. reason, "warning")
        return false
    end

    local nextTier = ProgressionSystem.getNextTier(gs, config)
    if not nextTier then return false end

    -- 扣费
    gs.cash = gs.cash - nextTier.upgradeCost
    gs.mainBizTier = nextTier.tier

    -- 切换场景
    gs.currentScene = nextTier.scene

    -- 重置选品索引
    gs.selectedStallItem = 1

    gs.addMessage(string.format("恭喜升级为 %s%s！", nextTier.emoji, nextTier.name), "success")
    return true
end

--- 获取主业月度被动收入（tier 2+）
function ProgressionSystem.getMonthlyPassiveIncome(gs, config)
    local tierDef = ProgressionSystem.getCurrentTier(gs, config)
    if not tierDef or not tierDef.passiveIncome then return 0 end
    return math.random(tierDef.passiveIncome[1], tierDef.passiveIncome[2])
end

--- 获取主业月度固定开支
function ProgressionSystem.getMonthlyOverhead(gs, config)
    local tierDef = ProgressionSystem.getCurrentTier(gs, config)
    return tierDef and tierDef.monthlyOverhead or 0
end

return ProgressionSystem
