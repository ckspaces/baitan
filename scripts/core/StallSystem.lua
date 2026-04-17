-- ============================================================================
-- StallSystem.lua - 经营系统（信任度 + 被动销售 + 完整交易流程）
-- 状态机：进货→出摊→（叫卖/等待观望）→收摊
-- ============================================================================

local PlayerSystem = require("core.PlayerSystem")
local ProgressionSystem = require("core.ProgressionSystem")

local StallSystem = {}

local function addItemProgress(gs, itemId, amount)
    if not itemId or amount <= 0 then return 0 end
    gs.itemProgress = gs.itemProgress or {}
    gs.itemProgress[itemId] = (gs.itemProgress[itemId] or 0) + amount
    return gs.itemProgress[itemId]
end

local function pushLiveComment(gs, text)
    if not text or text == "" then return end
    gs.liveComments = gs.liveComments or {}
    table.insert(gs.liveComments, 1, text)
    while #gs.liveComments > 4 do
        table.remove(gs.liveComments)
    end
end

--- 上次事件结果
StallSystem.lastStallEvent = nil

-- ============================================================================
-- 信任度辅助函数
-- ============================================================================

--- 获取信任度等级信息
function StallSystem.getTrustInfo(gs, config)
    local T = config.Trust
    local trust = gs.stallTrust or 0
    local info = T.TRUST_NAMES[1]
    for _, entry in ipairs(T.TRUST_NAMES) do
        if trust >= entry.threshold then
            info = entry
        end
    end
    return info
end

local function getSlotWindowInfo(gs, loc)
    local usedSlots = gs.stallTimeSlot or 0
    local maxSlots = loc and (loc.maxSlots or 5) or 5
    local actionSlot = usedSlots + 1
    return {
        usedSlots = usedSlots,
        maxSlots = maxSlots,
        actionSlot = actionSlot,
        isTailSlot = actionSlot == maxSlots,
        isOverSlot = actionSlot > maxSlots,
    }
end

--- 计算被动销售量（根据信任度线性插值 + 地点客流 + 促销加成）
function StallSystem.calcPassiveSales(gs, config)
    local T = config.Trust
    local trust = gs.stallTrust or 0
    local ratio = math.min(1.0, trust / T.MAX_TRUST)

    -- 线性插值：低信任几乎没人，高信任客流充足
    local minLo, minHi = T.PASSIVE_BASE_SELL[1], T.PASSIVE_BASE_SELL[2]
    local maxLo, maxHi = T.PASSIVE_MAX_SELL[1], T.PASSIVE_MAX_SELL[2]

    local lo = math.floor(minLo + (maxLo - minLo) * ratio)
    local hi = math.floor(minHi + (maxHi - minHi) * ratio)

    if lo > hi then lo = hi end
    local baseSales = math.random(lo, hi)

    -- 地点客流修正
    local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    if loc then
        baseSales = math.floor(baseSales * loc.customerMod)
        -- 高峰期加成
        local dayOfWeek = ((gs.currentDay - 1) % 7) + 1
        if loc.peakDays then
            for _, pd in ipairs(loc.peakDays) do
                if pd == dayOfWeek then
                    baseSales = math.floor(baseSales * (1 + (loc.peakBonus or 0)))
                    break
                end
            end
        end
        -- 天气对该地点的额外惩罚
        if gs.currentWeather == "rainy" or gs.currentWeather == "stormy" then
            baseSales = math.floor(baseSales / (loc.weatherPenalty or 1.0))
        end
    end

    -- 促销活动客流加成
    local promo = StallSystem.getActivePromotionConfig(gs, config)
    if promo then
        baseSales = math.floor(baseSales * (promo.salesMod or 1.0))
    end

    -- 名气带来的额外慕名客流
    local fameCustomers = StallSystem.calcFameCustomers(gs, config)
    baseSales = baseSales + fameCustomers

    -- 时段超时衰减（超过 maxSlots 后客流大幅下降）
    if loc then
        local slotInfo = getSlotWindowInfo(gs, loc)
        if slotInfo.isOverSlot then
            baseSales = math.floor(baseSales * 0.30)
        elseif slotInfo.isTailSlot then
            baseSales = math.floor(baseSales * 0.70)
        end
    end

    return math.max(0, baseSales)
end

function StallSystem.calcNaturalSales(gs, config)
    local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    local trust = gs.stallTrust or 0
    local fameCustomers = StallSystem.calcFameCustomers(gs, config)
    local base = 1 + math.floor(trust / 35)
    if loc then
        base = math.max(1, math.floor(base * (loc.customerMod or 1.0)))

        local dayOfWeek = ((gs.currentDay - 1) % 7) + 1
        if loc.peakDays then
            for _, pd in ipairs(loc.peakDays) do
                if pd == dayOfWeek then
                    base = math.floor(base * (1 + (loc.peakBonus or 0) * 0.5))
                    break
                end
            end
        end
    end
    base = base + math.max(1, math.floor(fameCustomers * 0.35))

    if loc then
        local slotInfo = getSlotWindowInfo(gs, loc)
        if slotInfo.isOverSlot then
            base = math.max(0, math.floor(base * 0.35))
        elseif slotInfo.isTailSlot then
            base = math.max(0, math.floor(base * 0.70))
        end
    end

    if gs.currentWeather == "rainy" or gs.currentWeather == "stormy" then
        base = math.max(0, math.floor(base * 0.70))
    elseif gs.currentWeather == "snowy" then
        base = math.max(0, math.floor(base * 0.60))
    end

    local promo = StallSystem.getActivePromotionConfig(gs, config)
    if promo then
        base = math.floor(base * (1 + math.max(0, (promo.salesMod or 1.0) - 1) * 0.5))
    end

    return math.max(0, base)
end

function StallSystem.getTrafficSnapshot(gs, config)
    local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    local reasons = {}
    local warnings = {}
    local score = 10

    if loc then
        local customerMod = loc.customerMod or 1.0
        if customerMod >= 1.35 then
            reasons[#reasons + 1] = "地点大人流"
            score = score + 18
        elseif customerMod >= 1.10 then
            reasons[#reasons + 1] = "地点稳定客流"
            score = score + 12
        else
            reasons[#reasons + 1] = "基础路过客流"
            score = score + 6
        end

        local dayOfWeek = ((gs.currentDay - 1) % 7) + 1
        if loc.peakDays then
            for _, pd in ipairs(loc.peakDays) do
                if pd == dayOfWeek then
                    reasons[#reasons + 1] = "赶上地点高峰"
                    score = score + math.floor((loc.peakBonus or 0) * 40) + 6
                    break
                end
            end
        end

        local slotInfo = getSlotWindowInfo(gs, loc)
        if slotInfo.isOverSlot then
            warnings[#warnings + 1] = "已过营业高峰"
            score = score - 20
        elseif slotInfo.isTailSlot then
            warnings[#warnings + 1] = "高峰尾段"
            score = score - 8
        end
    else
        reasons[#reasons + 1] = "基础路过客流"
    end

    local trust = gs.stallTrust or 0
    if trust >= 70 then
        reasons[#reasons + 1] = "口碑回流"
        score = score + 24
    elseif trust >= 40 then
        reasons[#reasons + 1] = "回头客稳定"
        score = score + 16
    elseif trust >= 15 then
        reasons[#reasons + 1] = "口碑在发酵"
        score = score + 8
    end

    local fameCustomers = StallSystem.calcFameCustomers(gs, config)
    if fameCustomers >= 6 then
        reasons[#reasons + 1] = "名气引流"
        score = score + 18
    elseif fameCustomers >= 2 then
        reasons[#reasons + 1] = "有人慕名来逛"
        score = score + 10
    end

    local promo = StallSystem.getActivePromotionConfig(gs, config)
    if promo then
        reasons[#reasons + 1] = promo.name .. "活动"
        score = score + math.max(6, math.floor(math.max(0, (promo.salesMod or 1.0) - 1.0) * 30))
    end

    local flyers = gs.flyersActive or 0
    if flyers > 0 then
        reasons[#reasons + 1] = "传单扩散"
        score = score + flyers * 3
    end

    if gs.isLiveStreaming then
        reasons[#reasons + 1] = "直播引流"
        score = score + 12 + math.min(12, math.floor((gs.liveViewerCount or 0) / 20))
    end

    if gs.currentWeather == "rainy" or gs.currentWeather == "stormy" then
        warnings[#warnings + 1] = "雨天客流受阻"
        score = score - 12
    elseif gs.currentWeather == "snowy" then
        warnings[#warnings + 1] = "下雪天出门意愿低"
        score = score - 16
    elseif gs.currentWeather == "sunny" then
        reasons[#reasons + 1] = "晴天更愿意逛"
        score = score + 6
    end

    score = math.max(0, math.min(100, score))

    local level = "冷清"
    if score >= 80 then
        level = "爆摊"
    elseif score >= 60 then
        level = "热摊"
    elseif score >= 40 then
        level = "稳客"
    elseif score >= 20 then
        level = "起势"
    end

    local summary = #reasons > 0 and table.concat(reasons, "、") or "基础路过客"
    if #warnings > 0 then
        summary = summary .. "；当前阻力：" .. table.concat(warnings, "、")
    end

    return {
        score = score,
        level = level,
        reasons = reasons,
        warnings = warnings,
        summary = summary,
    }
end

function StallSystem.applyLiveStreamTurn(gs, config, item, actionTag)
    if not gs.isLiveStreaming or not config.LiveStream then
        return { viewers = 0, comments = {}, tips = 0, tipIncome = 0, extraUnits = 0, extraIncome = 0, followers = 0 }
    end

    local L = config.LiveStream
    local viewers = math.random(L.BASE_VIEWERS[1], L.BASE_VIEWERS[2])
    viewers = viewers + math.floor((gs.followers or 0) / (L.FOLLOWERS_PER_VIEWER or 40))
    viewers = viewers + math.floor((gs.fame or 0) / (L.FAME_PER_VIEWER or 80))
    viewers = viewers + math.floor((gs.stallTrust or 0) / (L.TRUST_PER_VIEWER or 20))
    if actionTag == "hawk" then
        viewers = viewers + (L.HAWK_VIEWER_BONUS or 0)
    end
    viewers = math.max(0, math.min(L.MAX_VIEWERS or 5000, viewers))
    gs.liveViewerCount = viewers

    local comments = {}
    local commentCount = math.min(L.MAX_COMMENTS_PER_TURN or 2, math.floor(viewers / (L.COMMENT_VIEWERS_STEP or 25)) + 1)
    if viewers <= 0 then commentCount = 0 end

    for _ = 1, commentCount do
        local line = L.COMMENT_LINES[math.random(1, #L.COMMENT_LINES)]
        local viewerName = L.VIEWER_NAMES[math.random(1, #L.VIEWER_NAMES)]
        local fullText = string.format("%s：%s", viewerName, string.format(line, item.name))
        comments[#comments + 1] = fullText
        pushLiveComment(gs, fullText)
    end

    local tipChance = math.min(
        L.TIP_CHANCE_CAP or 0.60,
        (L.TIP_CHANCE_BASE or 0.18) + math.floor(viewers / 50) * (L.TIP_CHANCE_PER_50_VIEWERS or 0.05)
    )
    local tipIncome = 0
    local tips = 0
    if viewers > 0 and math.random() < tipChance then
        tipIncome = math.random(L.TIP_RANGE[1], L.TIP_RANGE[2])
        tips = 1
        gs.liveTipsEarned = (gs.liveTipsEarned or 0) + tipIncome
        gs.cash = gs.cash + tipIncome
        gs.stallTotalEarned = gs.stallTotalEarned + tipIncome
    end

    local followersGain = math.random(L.FOLLOWERS_GAIN_BASE[1], L.FOLLOWERS_GAIN_BASE[2])
        + math.floor(viewers / 20) * (L.FOLLOWERS_GAIN_PER_20_VIEWERS or 1)
    gs.followers = (gs.followers or 0) + followersGain

    local extraUnits = 0
    local extraIncome = 0
    local orderChance = math.min(
        L.ORDER_CHANCE_CAP or 0.65,
        (L.ORDER_CHANCE_BASE or 0.20) + (actionTag == "hawk" and (L.ORDER_CHANCE_HAWK_BONUS or 0) or 0)
    )
    if gs.stallInventory > 0 and viewers > 0 and math.random() < orderChance then
        extraUnits = math.min(gs.stallInventory, math.random(L.ORDER_UNITS[1], L.ORDER_UNITS[2]))
        if extraUnits > 0 then
            local modifier = StallSystem.calcIncomeModifiers(gs, config)
            extraIncome = math.floor(extraUnits * item.unitPrice * modifier)
            gs.stallInventory = gs.stallInventory - extraUnits
            gs.stallTotalSold = gs.stallTotalSold + extraUnits
            gs.stallTotalEarned = gs.stallTotalEarned + extraIncome
            gs.cash = gs.cash + extraIncome
            gs.liveOrdersSold = (gs.liveOrdersSold or 0) + extraUnits
        end
    end

    return {
        viewers = viewers,
        comments = comments,
        tips = tips,
        tipIncome = tipIncome,
        extraUnits = extraUnits,
        extraIncome = extraIncome,
        followers = followersGain,
    }
end

--- 增加信任度（同步保存到当前地点的独立信任度）
function StallSystem.addTrust(gs, config, amount)
    local T = config.Trust
    gs.stallTrust = math.min(T.MAX_TRUST, (gs.stallTrust or 0) + amount)
    -- 同步到 locationTrust
    if gs.saveTrustFromLocation then
        gs.saveTrustFromLocation(config)
    end
end

--- 月末信任度衰减
function StallSystem.monthlyTrustDecay(gs, config)
    local T = config.Trust
    if (gs.stallTrust or 0) > 0 then
        gs.stallTrust = math.max(0, gs.stallTrust - T.MONTHLY_DECAY)
    end
end

--- 应用收入修正因子（心情、传单、直播、天气、生病、地点、促销）
function StallSystem.calcIncomeModifiers(gs, config)
    local moodFactor = gs.mood > config.Player.LOW_MOOD and 1.0 or 0.5
    local flyerBonus = gs.flyersActive * config.Flyer.BONUS_PER_STACK
    local liveBonus = StallSystem.calcLivestreamBonus(gs, config)
    local weatherMod = 1.0
    if config.Weather and config.Weather.INCOME_MODIFIER and gs.currentWeather then
        weatherMod = config.Weather.INCOME_MODIFIER[gs.currentWeather] or 1.0
    end
    local sickMod = 1.0
    if gs.isSick and config.Health then
        sickMod = config.Health.SICK_INCOME_PENALTY or 0.5
    end

    -- 地点价格修正
    local locationPriceMod = 1.0
    local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    if loc then
        locationPriceMod = loc.priceMod or 1.0
    end

    -- 促销价格修正
    local promoPriceMod = 1.0
    local promo = StallSystem.getActivePromotionConfig(gs, config)
    if promo then
        promoPriceMod = promo.priceMod or 1.0
    end

    return moodFactor * (1 + flyerBonus) * (1 + liveBonus)
        * weatherMod * sickMod * locationPriceMod * promoPriceMod
end

--- 获取当前激活的促销活动配置（返回 config 表或 nil，支持通用+地点促销）
function StallSystem.getActivePromotionConfig(gs, config)
    if not gs.activePromotion then return nil end
    -- 先查通用促销
    for _, p in ipairs(config.Promotions) do
        if p.id == gs.activePromotion.id then
            return p
        end
    end
    -- 再查地点专属促销
    if config.LocationPromotions then
        for _, promos in pairs(config.LocationPromotions) do
            for _, p in ipairs(promos) do
                if p.id == gs.activePromotion.id then
                    return p
                end
            end
        end
    end
    return nil
end

--- 执行被动销售（供 hawkSell 和 waitObserve 内部调用）
--- 返回 passiveUnits, passiveIncome
function StallSystem.doPassiveSales(gs, config, item, modifier)
    if gs.stallInventory <= 0 then return 0, 0 end

    local passiveUnits = StallSystem.calcPassiveSales(gs, config)
    passiveUnits = math.min(passiveUnits, gs.stallInventory)

    if passiveUnits <= 0 then return 0, 0 end

    local passiveGross = passiveUnits * item.unitPrice
    local passiveIncome = math.floor(passiveGross * modifier)

    -- 更新库存和收入
    gs.stallInventory = gs.stallInventory - passiveUnits
    gs.stallTotalSold = gs.stallTotalSold + passiveUnits
    gs.stallTotalEarned = gs.stallTotalEarned + passiveIncome
    gs.cash = gs.cash + passiveIncome

    return passiveUnits, passiveIncome
end

--- 处理熟练度经验与升级
function StallSystem.processProficiency(gs, config)
    local P = config.Proficiency
    local profXP = math.random(P.XP_PER_HAWK[1], P.XP_PER_HAWK[2])
    gs.stallProficiency = (gs.stallProficiency or 0) + profXP

    local oldLevel = gs.stallProfLevel or 1
    local newLevel = 1
    for lv = P.MAX_LEVEL, 1, -1 do
        if gs.stallProficiency >= (P.LEVELS[lv] or 0) then
            newLevel = lv
            break
        end
    end
    gs.stallProfLevel = newLevel

    if newLevel > oldLevel then
        local levelName = P.LEVEL_NAMES[newLevel] or ("Lv." .. newLevel)
        gs.addMessage(string.format("🎉 摆摊熟练度升级！→ %s（Lv.%d）", levelName, newLevel), "success")
        gs.addLog(string.format("摆摊熟练度升至 %s（Lv.%d）", levelName, newLevel), "levelup")
    end

    -- 涨粉
    local baseFans = math.random(P.FANS_PER_HAWK[1], P.FANS_PER_HAWK[2])
    local profFans = baseFans + (newLevel - 1) * P.FANS_BONUS_PER_LEVEL
    gs.followers = gs.followers + profFans

    return profFans
end

-- ============================================================================
-- 原有功能
-- ============================================================================

--- 选择商品（不消耗回合）
function StallSystem.selectItem(gs, index, config)
    if gs.isStalling then
        gs.addMessage("正在摆摊中，收摊后才能换商品！", "warning")
        return false
    end
    local items = ProgressionSystem.getCurrentItems(gs, config)
    if index < 1 or index > #items then
        gs.addMessage("无效的商品选择", "warning")
        return false
    end
    local item = items[index]
    local unlock = ProgressionSystem.getItemUnlockStatus(gs, config, index, items)
    if not unlock.unlocked then
        if not unlock.monthOk then
            gs.addMessage(string.format("%s 需要第%d月才能解锁", item.name, unlock.monthReq or 1), "warning")
            return false
        end
        if unlock.previousItem and (unlock.currentXP or 0) < (unlock.requiredXP or 0) then
            gs.addMessage(string.format("%s 需要先把 %s 熟练到 %d/%d", item.name,
                unlock.previousItem.name, unlock.currentXP or 0, unlock.requiredXP or 0), "warning")
            return false
        end
    end
    if not gs.meetsSkillReq(item.skillReq) then
        gs.addMessage(string.format("%s 技能不满足要求", item.name), "warning")
        return false
    end
    gs.selectedStallItem = index
    gs.addMessage(string.format("选择商品: %s %s", item.emoji, item.name), "info")
    return true
end

--- 发传单（不消耗回合）
function StallSystem.distributeFlyers(gs, config)
    local C = config.Flyer
    if gs.flyersActive >= C.MAX_STACKS then
        gs.addMessage("传单效果已满！最多叠" .. C.MAX_STACKS .. "层", "warning")
        return false
    end
    if gs.cash < C.COST then
        gs.addMessage(string.format("印传单需要 $%d", C.COST), "warning")
        return false
    end
    if gs.energy < C.ENERGY_COST then
        gs.addMessage("体力不足，发不动传单！", "warning")
        return false
    end

    gs.cash = gs.cash - C.COST
    gs.energy = math.max(0, gs.energy - C.ENERGY_COST)
    gs.flyersActive = gs.flyersActive + 1

    local bonusPct = math.floor(gs.flyersActive * C.BONUS_PER_STACK * 100)
    gs.addMessage(string.format("发传单成功！当前加成 +%d%%（%d/%d层）",
        bonusPct, gs.flyersActive, C.MAX_STACKS), "success")
    return true
end

--- 进货+出摊（消耗金钱，进入摆摊状态，不消耗回合）
function StallSystem.openStall(gs, config)
    if gs.isStalling then
        gs.addMessage("已经在摆摊了！", "warning")
        return false
    end

    local items = ProgressionSystem.getCurrentItems(gs, config)
    local item = items[gs.selectedStallItem]
    if not item then
        gs.addMessage("请先选择商品！", "warning")
        return false
    end
    if gs.cash < item.batchCost then
        gs.addMessage(string.format("进货成本不足！需要 $%d", item.batchCost), "warning")
        return false
    end

    -- 扣进货成本
    gs.cash = gs.cash - item.batchCost

    -- 扣地点租金
    local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    local rentCost = 0
    if loc and (loc.rentCost or 0) > 0 then
        rentCost = loc.rentCost
        gs.cash = gs.cash - rentCost
    end

    -- 进入摆摊状态
    gs.isStalling = true
    gs.stallItemIndex = gs.selectedStallItem
    gs.stallInventory = item.yield
    gs.stallInventoryMax = item.yield
    gs.stallTotalSold = 0
    gs.stallTotalEarned = 0
    gs.stallPassiveSold = 0
    gs.stallPassiveEarned = 0
    gs.stallNaturalSold = 0
    gs.stallNaturalEarned = 0
    gs.isLiveStreaming = false
    gs.liveViewerCount = 0
    gs.liveTipsEarned = 0
    gs.liveOrdersSold = 0
    gs.liveComments = {}
    gs.stallTimeSlot = 0            -- 重置时段计数
    gs.pendingChengguan = false     -- 重置城管标记

    -- 切换场景
    gs.currentScene = ProgressionSystem.getCurrentScene(gs, config)
    gs.currentActivity = "stalling"

    local tierDef = ProgressionSystem.getCurrentTier(gs, config)
    local tierName = tierDef and tierDef.name or "摆摊"
    local trustInfo = StallSystem.getTrustInfo(gs, config)
    local locName = loc and (loc.emoji .. loc.name) or ""
    local rentTag = rentCost > 0 and string.format("，摊位费$%d", rentCost) or ""
    gs.addMessage(string.format("%s在%s进货 %s%s × %d份，花费$%d%s，开始营业！",
        tierName, locName, item.emoji, item.name, item.yield, item.batchCost, rentTag), "info")
    gs.addMessage(string.format("当前口碑: %s%s（信任度%d）",
        trustInfo.emoji, trustInfo.name, gs.stallTrust or 0), "info")

    local craftXP = math.max(0, ((config.RecipeProgression or {}).XP_PER_CRAFT or 0) * (item.yield or 0))
    if craftXP > 0 then
        addItemProgress(gs, item.id, craftXP)
    end

    -- 显示促销信息
    local promo = StallSystem.getActivePromotionConfig(gs, config)
    if promo and gs.activePromotion then
        gs.addMessage(string.format("促销活动：%s%s 剩余%d天",
            promo.emoji, promo.name, gs.activePromotion.remaining), "info")
    end
    return true
end

-- ============================================================================
-- 叫卖（主动推销 + 被动客流，消耗回合）
-- ============================================================================
---@param grillMultiplier number|nil 烤串小游戏倍率（默认1.0）
function StallSystem.hawkSell(gs, config, grillMultiplier)
    if not gs.isStalling then
        gs.addMessage("还没出摊呢！", "warning")
        return false
    end
    if gs.stallInventory <= 0 then
        gs.addMessage("库存卖光了，该收摊啦！", "warning")
        return false
    end

    local items = ProgressionSystem.getCurrentItems(gs, config)
    local item = items[gs.stallItemIndex] or items[1]
    if not item then
        gs.addMessage("商品数据异常", "danger")
        return false
    end

    local energyCostMult = 1.0
    if gs.isSick and config.Health then
        energyCostMult = config.Health.SICK_ENERGY_PENALTY or 1.5
    end
    local actualEnergyCost = math.floor(item.energyCost * energyCostMult)
    if gs.energy < actualEnergyCost then
        gs.addMessage("体力不足，先等客流自己过来，或者直接收摊休息。", "warning")
        return false
    end

    gs.energy = math.max(0, gs.energy - actualEnergyCost)
    gs.mood = math.max(0, gs.mood - item.moodCost)

    local modifier = StallSystem.calcIncomeModifiers(gs, config)
    local grillMult = grillMultiplier or 1.0
    local recipeCfg = config.RecipeProgression or {}

    local passiveUnits, passiveIncome = StallSystem.doPassiveSales(gs, config, item, modifier * grillMult)
    gs.stallPassiveSold = passiveUnits
    gs.stallPassiveEarned = passiveIncome
    gs.stallNaturalSold = 0
    gs.stallNaturalEarned = 0

    local passiveXP = math.max(0, (recipeCfg.XP_PER_SALE or 0) * passiveUnits)
    if passiveXP > 0 then
        addItemProgress(gs, item.id, passiveXP)
    end

    local maxCanSell = gs.stallInventory
    local H = config.Hawking
    local numCustomers = math.random(H.CUSTOMERS_PER_HAWK[1], H.CUSTOMERS_PER_HAWK[2])
    local profLevel = gs.stallProfLevel or 1
    local profExtraCustomers = math.floor((profLevel - 1) / 3)
    numCustomers = numCustomers + profExtraCustomers

    local locForSlot = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    if locForSlot then
        local slotInfo = getSlotWindowInfo(gs, locForSlot)
        if slotInfo.isOverSlot then
            numCustomers = math.max(1, math.floor(numCustomers * 0.30))
        elseif slotInfo.isTailSlot then
            numCustomers = math.max(1, math.floor(numCustomers * 0.70))
        end
    end

    local unitsSold = 0
    local customerDetails = {}
    for _ = 1, numCustomers do
        if unitsSold >= maxCanSell then break end
        local buyUnits = math.random(H.UNITS_PER_CUSTOMER[1], H.UNITS_PER_CUSTOMER[2])
        buyUnits = math.min(buyUnits, maxCanSell - unitsSold)
        if buyUnits > 0 then
            unitsSold = unitsSold + buyUnits
            local line = H.CUSTOMER_LINES[math.random(1, #H.CUSTOMER_LINES)]
            customerDetails[#customerDetails + 1] = string.format(line, buyUnits)
        end
    end

    local gross = unitsSold * item.unitPrice
    local income = math.floor(gross * modifier * grillMult)

    local evt = StallSystem.rollStallEvent(gs, config)
    StallSystem.lastStallEvent = evt
    if evt then
        if evt.effect == "chengguan_encounter" then
            gs.pendingChengguan = true
            gs.addMessage(string.format("[经营事件] %s - %s", evt.name, evt.desc), "danger")
        elseif evt.effect == "half_income" then
            income = math.floor(income * 0.5)
            gs.addMessage(string.format("[经营事件] %s - %s", evt.name, evt.desc), "warning")
        elseif evt.effect == "reduce_30" then
            income = math.floor(income * 0.7)
            gs.addMessage(string.format("[经营事件] %s - %s", evt.name, evt.desc), "warning")
        elseif evt.effect == "repair_cost" then
            local repairCost = math.random(1000, 5000) * (gs.mainBizTier or 1)
            gs.cash = gs.cash - repairCost
            gs.addMessage(string.format("[经营事件] %s，维修花了$%d", evt.name, repairCost), "warning")
        elseif evt.effect == "double_income" then
            income = income * 2
            gs.addMessage(string.format("[经营事件] %s - %s", evt.name, evt.desc), "success")
        elseif evt.effect == "reputation_up" then
            gs.reputation = (gs.reputation or 0) + math.random(5, 15)
            StallSystem.addTrust(gs, config, math.random(3, 6))
            gs.addMessage(string.format("[经营事件] %s，口碑和声望都涨了！", evt.name), "success")
        elseif evt.effect == "fans_up" then
            local fans = math.random(50, 300)
            gs.followers = gs.followers + fans
            gs.addMessage(string.format("[经营事件] %s，涨粉+%d", evt.name, fans), "success")
        end
    end

    gs.stallInventory = gs.stallInventory - unitsSold
    gs.stallTotalSold = gs.stallTotalSold + unitsSold
    gs.stallTotalEarned = gs.stallTotalEarned + income
    gs.cash = gs.cash + income

    local activeXP = math.max(0, (recipeCfg.XP_PER_SALE or 0) * unitsSold)
    if activeXP > 0 then
        addItemProgress(gs, item.id, activeXP)
    end

    local trustGain = math.random(config.Trust.HAWK_TRUST_GAIN[1], config.Trust.HAWK_TRUST_GAIN[2])
    local locForTrust = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    if locForTrust then
        trustGain = math.floor(trustGain * (locForTrust.trustGainMod or 1.0))
    end
    local promoForTrust = StallSystem.getActivePromotionConfig(gs, config)
    if promoForTrust then
        trustGain = trustGain + (promoForTrust.trustGainBonus or 0)
    end
    StallSystem.addTrust(gs, config, trustGain)

    local actualCustomerCount = #customerDetails
    for i = 1, math.min(3, actualCustomerCount) do
        gs.addMessage(string.format("顾客%d：%s", i, customerDetails[i]), "info")
    end
    if actualCustomerCount > 3 then
        gs.addMessage(string.format("还有%d位顾客也跟着下单了。", actualCustomerCount - 3), "info")
    end

    local liveResult = StallSystem.applyLiveStreamTurn(gs, config, item, "hawk")
    if gs.isLiveStreaming then
        for i = 1, math.min(2, #liveResult.comments) do
            gs.addMessage(string.format("直播间：%s", liveResult.comments[i]), "info")
        end
    end

    local traffic = StallSystem.getTrafficSnapshot(gs, config)
    local totalUnits = unitsSold + passiveUnits + liveResult.extraUnits
    local totalIncome = income + passiveIncome + liveResult.tipIncome + liveResult.extraIncome
    local detailParts = {}
    if unitsSold > 0 then
        detailParts[#detailParts + 1] = string.format("主动成交%d份", unitsSold)
    end
    if passiveUnits > 0 then
        detailParts[#detailParts + 1] = string.format("回头客%d份", passiveUnits)
    end
    if liveResult.extraUnits > 0 then
        detailParts[#detailParts + 1] = string.format("直播带货%d份", liveResult.extraUnits)
    end
    if liveResult.tipIncome > 0 then
        detailParts[#detailParts + 1] = string.format("打赏$%s", gs.formatMoney(liveResult.tipIncome))
    end
    detailParts[#detailParts + 1] = string.format("涨粉+%d", liveResult.followers or 0)
    gs.addMessage(string.format("一轮叫卖成交%d份%s，收入$%s，剩余%d份。",
        totalUnits,
        #detailParts > 0 and ("（" .. table.concat(detailParts, "，") .. "）") or "",
        gs.formatMoney(totalIncome),
        gs.stallInventory), "success")
    gs.addMessage(string.format("这波客流主要来自：%s。", traffic.summary), "info")

    gs.stallTimeSlot = (gs.stallTimeSlot or 0) + 1
    if gs.stallInventory <= 0 then
        gs.addMessage("这一锅卖完了，今天这摊很漂亮！", "info")
        StallSystem.doCloseStall(gs, config)
    end

    StallSystem.processProficiency(gs, config)
    if config.Fame then
        local fameGain = math.random(config.Fame.HAWK_FAME_GAIN[1], config.Fame.HAWK_FAME_GAIN[2])
        if gs.isLiveStreaming then
            fameGain = math.floor(fameGain * config.Fame.LIVESTREAM_FAME_MULT)
        end
        StallSystem.addFame(gs, config, fameGain)
        if gs.activePromotion then
            local activePromo = StallSystem.getActivePromotionConfig(gs, config)
            if activePromo and activePromo.fameGainBonus then
                StallSystem.addFame(gs, config, activePromo.fameGainBonus)
            end
        end
    end

    StallSystem.rollViralEvent(gs, config)
    gs.addLog(string.format("叫卖成交%d份%s，收入$%s，口碑+%d",
        totalUnits,
        item and ("（" .. item.name .. "）") or "",
        gs.formatMoney(totalIncome),
        trustGain), "sell")

    PlayerSystem.addSkillXP(gs, "negotiation", math.random(8, 20), config)
    PlayerSystem.addSkillXP(gs, "marketing", math.random(3, 10), config)
    return true
end

function StallSystem.waitObserve(gs, config)
    if not gs.isStalling then
        gs.addMessage("还没出摊呢！", "warning")
        return false
    end
    if gs.stallInventory <= 0 then
        gs.addMessage("库存已经卖完了，可以直接收摊。", "warning")
        return false
    end

    local items = ProgressionSystem.getCurrentItems(gs, config)
    local item = items[gs.stallItemIndex] or items[1]
    if not item then
        gs.addMessage("商品数据异常", "danger")
        return false
    end

    local energyCost = config.Trust.WAIT_ENERGY_COST
    local moodCost = config.Trust.WAIT_MOOD_COST
    if gs.energy < energyCost then
        energyCost = gs.energy
    end
    gs.energy = math.max(0, gs.energy - energyCost)
    gs.mood = math.max(0, gs.mood - moodCost)

    local modifier = StallSystem.calcIncomeModifiers(gs, config)
    local passiveUnits, passiveIncome = StallSystem.doPassiveSales(gs, config, item, modifier)
    gs.stallPassiveSold = passiveUnits
    gs.stallPassiveEarned = passiveIncome

    local naturalUnits = math.min(gs.stallInventory, StallSystem.calcNaturalSales(gs, config))
    local naturalIncome = 0
    if naturalUnits > 0 then
        naturalIncome = math.floor(naturalUnits * item.unitPrice * modifier)
        gs.stallInventory = gs.stallInventory - naturalUnits
        gs.stallTotalSold = gs.stallTotalSold + naturalUnits
        gs.stallTotalEarned = gs.stallTotalEarned + naturalIncome
        gs.cash = gs.cash + naturalIncome
    end
    gs.stallNaturalSold = naturalUnits
    gs.stallNaturalEarned = naturalIncome

    local waitXP = math.max(0, ((config.RecipeProgression or {}).XP_PER_SALE or 0) * (passiveUnits + naturalUnits))
    if waitXP > 0 then
        addItemProgress(gs, item.id, waitXP)
    end

    local trustGain = math.random(config.Trust.WAIT_TRUST_GAIN[1], config.Trust.WAIT_TRUST_GAIN[2])
    local locForTrust = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    if locForTrust then
        trustGain = math.floor(trustGain * (locForTrust.trustGainMod or 1.0))
    end
    local promoForTrust = StallSystem.getActivePromotionConfig(gs, config)
    if promoForTrust then
        trustGain = trustGain + math.floor((promoForTrust.trustGainBonus or 0) * 0.5)
    end
    StallSystem.addTrust(gs, config, trustGain)

    local evt = StallSystem.rollStallEvent(gs, config)
    StallSystem.lastStallEvent = evt
    if evt then
        if evt.effect == "chengguan_encounter" then
            gs.pendingChengguan = true
            gs.addMessage(string.format("[经营事件] %s - %s", evt.name, evt.desc), "danger")
        elseif evt.effect == "half_income" then
            gs.addMessage(string.format("[经营事件] %s - %s", evt.name, evt.desc), "warning")
        elseif evt.effect == "double_income" then
            local bonus = passiveIncome + naturalIncome
            gs.cash = gs.cash + bonus
            gs.stallTotalEarned = gs.stallTotalEarned + bonus
            gs.addMessage(string.format("[经营事件] %s，额外多赚$%s", evt.name, gs.formatMoney(bonus)), "success")
        elseif evt.effect == "reputation_up" then
            gs.reputation = (gs.reputation or 0) + math.random(5, 15)
            StallSystem.addTrust(gs, config, math.random(3, 6))
            gs.addMessage(string.format("[经营事件] %s，附近人对你的评价更好了。", evt.name), "success")
        elseif evt.effect == "fans_up" then
            local fans = math.random(50, 300)
            gs.followers = gs.followers + fans
            gs.addMessage(string.format("[经营事件] %s，涨粉+%d", evt.name, fans), "success")
        elseif evt.effect == "repair_cost" then
            local repairCost = math.random(1000, 5000) * (gs.mainBizTier or 1)
            gs.cash = gs.cash - repairCost
            gs.addMessage(string.format("[经营事件] %s，维修花了$%d", evt.name, repairCost), "warning")
        elseif evt.effect == "reduce_30" then
            gs.addMessage(string.format("[经营事件] %s - %s", evt.name, evt.desc), "warning")
        end
    end

    local liveResult = StallSystem.applyLiveStreamTurn(gs, config, item, "wait")
    gs.stallTimeSlot = (gs.stallTimeSlot or 0) + 1

    local traffic = StallSystem.getTrafficSnapshot(gs, config)
    local totalWaitIncome = passiveIncome + naturalIncome + liveResult.tipIncome + liveResult.extraIncome
    local parts = {}
    if passiveUnits > 0 then
        parts[#parts + 1] = string.format("回头客%d份", passiveUnits)
    end
    if naturalUnits > 0 then
        parts[#parts + 1] = string.format("自然来客%d份", naturalUnits)
    end
    if liveResult.extraUnits > 0 then
        parts[#parts + 1] = string.format("直播带货%d份", liveResult.extraUnits)
    end
    if #parts > 0 then
        gs.addMessage(string.format("你先稳住摊位节奏，%s，收入$%s，剩余%d份。",
            table.concat(parts, "，"), gs.formatMoney(totalWaitIncome), gs.stallInventory), "info")
    else
        gs.addMessage("这轮没有立刻成交，但摊位热度和口碑还在继续发酵。", "info")
    end
    gs.addMessage(string.format("现在的客流状态：%s。", traffic.summary), "info")

    if gs.isLiveStreaming then
        local liveParts = { string.format("观众%d", liveResult.viewers) }
        if liveResult.tipIncome > 0 then
            liveParts[#liveParts + 1] = string.format("打赏$%s", gs.formatMoney(liveResult.tipIncome))
        end
        liveParts[#liveParts + 1] = string.format("涨粉+%d", liveResult.followers)
        gs.addMessage(string.format("直播反馈：%s", table.concat(liveParts, "，")), "info")
        for i = 1, math.min(2, #liveResult.comments) do
            gs.addMessage(string.format("直播间：%s", liveResult.comments[i]), "info")
        end
    end

    if gs.stallInventory <= 0 then
        gs.addMessage("自然客流把库存也带空了，今天这摊稳稳收住。", "info")
        StallSystem.doCloseStall(gs, config)
    end

    gs.stallProficiency = (gs.stallProficiency or 0) + math.random(3, 8)
    if config.Fame then
        local fameGain = math.random(config.Fame.WAIT_FAME_GAIN[1], config.Fame.WAIT_FAME_GAIN[2])
        if gs.isLiveStreaming then
            fameGain = math.floor(fameGain * config.Fame.LIVESTREAM_FAME_MULT)
        end
        if fameGain > 0 then
            StallSystem.addFame(gs, config, fameGain)
        end
    end

    StallSystem.rollViralEvent(gs, config)
    gs.addLog(string.format("等待经营：回头客%d份，自然来客%d份，收入$%s，口碑+%d",
        passiveUnits, naturalUnits, gs.formatMoney(totalWaitIncome), trustGain), "sell")

    PlayerSystem.addSkillXP(gs, "negotiation", math.random(2, 6), config)
    return true
end

function StallSystem.closeStall(gs, config)
    if not gs.isStalling then
        gs.addMessage("还没出摊呢！", "warning")
        return false
    end
    StallSystem.doCloseStall(gs, config)
    return true
end

--- 内部收摊逻辑
function StallSystem.doCloseStall(gs, config)
    local leftover = gs.stallInventory
    local items = ProgressionSystem.getCurrentItems(gs, config)
    local item = items[gs.stallItemIndex]
    local itemName = item and (item.emoji .. item.name) or "商品"

    gs.addMessage(string.format("收摊！本次共卖%d份，赚$%s%s",
        gs.stallTotalSold, gs.formatMoney(gs.stallTotalEarned),
        leftover > 0 and string.format("（剩余%d份浪费了）", leftover) or ""), "info")

    -- 收摊时累计经营天数（一天出摊只算一次）
    gs.stallDayCount = gs.stallDayCount + 1

    gs.isStalling = false
    gs.stallInventory = 0
    gs.stallInventoryMax = 0
    gs.stallTotalSold = 0
    gs.stallTotalEarned = 0
    gs.stallPassiveSold = 0
    gs.stallPassiveEarned = 0
    gs.stallNaturalSold = 0
    gs.stallNaturalEarned = 0
    gs.isLiveStreaming = false
    gs.liveViewerCount = 0
    gs.liveTipsEarned = 0
    gs.liveOrdersSold = 0
    gs.liveComments = {}
    gs.currentActivity = "idle"
end

--- 开/关直播（不消耗回合）
function StallSystem.toggleLiveStream(gs, config)
    if not gs.isStalling then
        gs.addMessage("还没开摊，没法直播。", "warning")
        return false
    end
    gs.isLiveStreaming = not gs.isLiveStreaming
    if gs.isLiveStreaming then
        gs.liveViewerCount = math.random(6, 18)
        gs.liveComments = {}
        pushLiveComment(gs, "开播了开播了，看看今天这摊能不能冲起来！")
        gs.addMessage("开播成功！直播间会持续带来观众、弹幕、打赏和额外订单。", "success")
    else
        gs.liveViewerCount = 0
        gs.addMessage("你先把直播关了，专心照看摊位。", "info")
    end
    return true
end

function StallSystem.rollStallEvent(gs, config)
    if math.random() > 0.40 then return nil end

    local events = config.StallEvents
    local tierMod = (gs.mainBizTier or 1) > 1 and 0.5 or 1.0

    -- 地点风险修正（影响城管出现概率）
    local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    local locRiskMod = loc and (loc.riskMod or 1.0) or 1.0

    local totalProb = 0
    for _, e in ipairs(events) do
        local p = e.prob
        if e.id == "chengguan" then p = p * tierMod * locRiskMod end
        totalProb = totalProb + p
    end
    local roll = math.random() * totalProb
    local acc = 0
    for _, e in ipairs(events) do
        local p = e.prob
        if e.id == "chengguan" then p = p * tierMod * locRiskMod end
        acc = acc + p
        if roll <= acc then
            return e
        end
    end
    return nil
end



--- 月末衰减传单层数 + 信任度 + 名气
function StallSystem.monthlyDecay(gs, config)
    if gs.flyersActive > 0 then
        local decay = config.Flyer.MONTHLY_DECAY
        gs.flyersActive = math.max(0, gs.flyersActive - decay)
    end
    -- 信任度月末衰减（所有地点都衰减）
    for locId, trust in pairs(gs.locationTrust or {}) do
        if trust > 0 then
            gs.locationTrust[locId] = math.max(0, trust - (config.Trust.MONTHLY_DECAY or 3))
        end
    end
    -- 同步当前地点
    if gs.syncTrustToLocation then
        gs.syncTrustToLocation(config)
    end
    -- 名气月末衰减
    StallSystem.monthlyFameDecay(gs, config)
end

--- 每天结算促销天数（在每个回合结束时调用）
function StallSystem.tickPromotion(gs, config)
    if not gs.activePromotion then
        if gs.promotionCooldown and gs.promotionCooldown > 0 then
            gs.promotionCooldown = gs.promotionCooldown - 1
        end
        return
    end
    gs.activePromotion.remaining = gs.activePromotion.remaining - 1
    if gs.activePromotion.remaining <= 0 then
        local promo = StallSystem.getActivePromotionConfig(gs, config)
        local name = promo and (promo.emoji .. promo.name) or "促销"
        gs.addMessage(string.format("%s 活动已结束", name), "info")
        gs.activePromotion = nil
        gs.promotionCooldown = 2
        return
    end
    if gs.promotionCooldown and gs.promotionCooldown > 0 then
        gs.promotionCooldown = gs.promotionCooldown - 1
    end
end

-- ============================================================================
-- 新增：地点选择 & 促销活动
-- ============================================================================

--- 选择摆摊地点（不消耗回合）
function StallSystem.selectLocation(gs, index, config)
    if gs.isStalling then
        gs.addMessage("正在摆摊中，收摊后才能换地点！", "warning")
        return false
    end
    local locations = config.Locations
    if index < 1 or index > #locations then
        gs.addMessage("无效的地点选择", "warning")
        return false
    end
    local loc = locations[index]
    -- 检查解锁月份
    if gs.currentMonth < (loc.unlockMonth or 1) then
        gs.addMessage(string.format("%s%s 需要第%d月才能解锁",
            loc.emoji, loc.name, loc.unlockMonth), "warning")
        return false
    end
    -- 检查技能需求
    if not gs.meetsSkillReq(loc.skillReq) then
        gs.addMessage(string.format("%s%s 技能不满足要求",
            loc.emoji, loc.name), "warning")
        return false
    end
    -- 检查地点冷却
    local cd = (gs.locationCooldowns or {})[loc.id]
    if cd and cd > 0 then
        gs.addMessage(string.format("%s%s 被城管盯上了，冷却中（还剩%d天）",
            loc.emoji, loc.name, cd), "warning")
        return false
    end

    -- 保存旧地点信任度
    gs.saveTrustFromLocation(config)
    -- 切换地点
    gs.currentLocation = index
    -- 加载新地点信任度
    gs.syncTrustToLocation(config)

    local trustInfo = StallSystem.getTrustInfo(gs, config)
    gs.addMessage(string.format("选择摆摊地点：%s%s（%s）",
        loc.emoji, loc.name, loc.desc), "info")
    gs.addMessage(string.format("该地点口碑：%s%s（信任度%d）",
        trustInfo.emoji, trustInfo.name, gs.stallTrust or 0), "info")
    if loc.rentCost > 0 then
        gs.addMessage(string.format("每次出摊摊位费：$%d", loc.rentCost), "info")
    end
    return true
end

--- 激活促销活动（不消耗回合）
function StallSystem.activatePromotion(gs, promoId, config)
    if gs.activePromotion then
        local cur = StallSystem.getActivePromotionConfig(gs, config)
        local curName = cur and (cur.emoji .. cur.name) or "促销"
        gs.addMessage(string.format("已有活动进行中：%s，剩余%d天",
            curName, gs.activePromotion.remaining), "warning")
        return false
    end
    if (gs.promotionCooldown or 0) > 0 then
        gs.addMessage(string.format("促销冷却中，还需%d天", gs.promotionCooldown), "warning")
        return false
    end

    -- 找到对应促销配置（通用 + 地点专属）
    local promo = nil
    for _, p in ipairs(config.Promotions) do
        if p.id == promoId then
            promo = p
            break
        end
    end
    if not promo and config.LocationPromotions then
        for _, promos in pairs(config.LocationPromotions) do
            for _, p in ipairs(promos) do
                if p.id == promoId then
                    promo = p
                    break
                end
            end
            if promo then break end
        end
    end
    if not promo then
        gs.addMessage("无效的促销活动", "warning")
        return false
    end

    -- 检查摆摊天数解锁
    local reqDays = promo.unlockStallDays or 0
    if (gs.stallDayCount or 0) < reqDays then
        gs.addMessage(string.format("%s%s 需要摆摊%d天解锁（已%d天）",
            promo.emoji, promo.name, reqDays, gs.stallDayCount or 0), "warning")
        return false
    end
    -- 检查解锁信任度
    local reqTrust = promo.unlockTrust or 0
    if reqTrust > 0 and (gs.stallTrust or 0) < reqTrust then
        gs.addMessage(string.format("%s%s 需要信任度%d解锁（当前%d）",
            promo.emoji, promo.name, reqTrust, gs.stallTrust or 0), "warning")
        return false
    end
    -- 检查技能
    if not gs.meetsSkillReq(promo.skillReq) then
        gs.addMessage(string.format("%s%s 技能不满足要求",
            promo.emoji, promo.name), "warning")
        return false
    end
    -- 检查信任度要求
    if promo.trustRequired and (gs.stallTrust or 0) < promo.trustRequired then
        gs.addMessage(string.format("%s%s 需要信任度达到%d",
            promo.emoji, promo.name, promo.trustRequired), "warning")
        return false
    end
    -- 检查资金
    if gs.cash < promo.cost then
        gs.addMessage(string.format("%s%s 需要$%d",
            promo.emoji, promo.name, promo.cost), "warning")
        return false
    end

    -- 扣费并激活
    gs.cash = gs.cash - promo.cost
    gs.activePromotion = { id = promo.id, remaining = promo.duration }

    gs.addMessage(string.format("启动促销：%s%s！持续%d天，花费$%d",
        promo.emoji, promo.name, promo.duration, promo.cost), "success")
    gs.addMessage(string.format("效果：%s", promo.desc), "info")

    gs.addLog(string.format("启动促销 %s%s，花费$%d",
        promo.emoji, promo.name, promo.cost), "promo")

    return true
end

-- ============================================================================
-- 名气/网红系统
-- ============================================================================

--- 获取名气等级信息
function StallSystem.getFameInfo(gs, config)
    if not config.Fame then return { name = "无", emoji = "😶", bonus = 0, threshold = 0 } end
    local fame = gs.fame or 0
    local info = config.Fame.LEVELS[1]
    for _, entry in ipairs(config.Fame.LEVELS) do
        if fame >= entry.threshold then
            info = entry
        end
    end
    return info
end

--- 增加名气（含等级检查）
function StallSystem.addFame(gs, config, amount)
    if not config.Fame then return end
    gs.fame = math.min(config.Fame.MAX_FAME, (gs.fame or 0) + amount)
    -- 更新等级
    local oldLevel = gs.fameLevel or 1
    local newLevel = 1
    for i, entry in ipairs(config.Fame.LEVELS) do
        if gs.fame >= entry.threshold then
            newLevel = i
        end
    end
    gs.fameLevel = newLevel
    if newLevel > oldLevel then
        local info = config.Fame.LEVELS[newLevel]
        gs.addMessage(string.format("🎉 名气升级！→ %s%s", info.emoji, info.name), "success")
        gs.addLog(string.format("名气升至 %s%s", info.emoji, info.name), "fame")
    end
end

--- 计算名气带来的额外客流
function StallSystem.calcFameCustomers(gs, config)
    if not config.Fame then return 0 end
    local fame = gs.fame or 0
    local ratio = math.min(1.0, fame / config.Fame.MAX_FAME)
    local base = config.Fame.FAME_CUSTOMER_BASE
    local max = config.Fame.FAME_CUSTOMER_MAX
    return math.floor(base + (max - base) * ratio)
end

--- 计算直播收入加成（基础 + 名气额外）
function StallSystem.calcLivestreamBonus(gs, config)
    if not gs.isLiveStreaming then return 0 end
    if not config.Fame then return 0.30 end  -- 无名气配置时保持旧的30%
    local base = config.Fame.LIVESTREAM_BASE_BONUS
    local fameExtra = math.min(
        config.Fame.LIVESTREAM_FAME_CAP,
        (gs.fame or 0) * config.Fame.LIVESTREAM_FAME_EXTRA
    )
    return base + fameExtra
end

--- 尝试触发网红/爆红事件（每次叫卖/等待时调用）
function StallSystem.rollViralEvent(gs, config)
    if not config.ViralEvents then return nil end
    local trust = gs.stallTrust or 0
    local fame = gs.fame or 0
    local triggered = gs.viralEventsTriggered or {}

    for _, evt in ipairs(config.ViralEvents) do
        -- 检查触发条件
        local t = evt.trigger or {}
        if (not t.trustMin or trust >= t.trustMin) and
           (not t.fameMin or fame >= t.fameMin) then
            -- 检查概率
            if math.random() < evt.prob then
                -- 检查是否最近已触发过（同一事件冷却：加入触发列表）
                local recentlyTriggered = false
                for _, tid in ipairs(triggered) do
                    if tid == evt.id then
                        recentlyTriggered = true
                        break
                    end
                end
                if not recentlyTriggered then
                    -- 触发！
                    local fameGain = math.random(evt.fameGain[1], evt.fameGain[2])
                    local followersGain = math.random(evt.followersGain[1], evt.followersGain[2])

                    StallSystem.addFame(gs, config, fameGain)
                    gs.followers = (gs.followers or 0) + followersGain

                    -- 记录已触发（最多记5个，FIFO）
                    table.insert(triggered, evt.id)
                    if #triggered > 5 then
                        table.remove(triggered, 1)
                    end
                    gs.viralEventsTriggered = triggered

                    gs.lastViralEvent = evt
                    gs.addMessage(string.format("%s %s - %s 名气+%d 粉丝+%d",
                        evt.emoji, evt.name, evt.desc, fameGain, followersGain), "success")
                    gs.addLog(string.format("%s%s 名气+%d 粉丝+%d",
                        evt.emoji, evt.name, fameGain, followersGain), "viral")

                    return evt
                end
            end
        end
    end
    return nil
end

--- 月末名气衰减
function StallSystem.monthlyFameDecay(gs, config)
    if not config.Fame then return end
    if (gs.fame or 0) > 0 then
        gs.fame = math.max(0, gs.fame - config.Fame.MONTHLY_DECAY)
    end
    -- 每月重置触发记录（允许下月再次触发同类事件）
    gs.viralEventsTriggered = {}
end

--- 获取所有促销活动（通用 + 地点专属）
function StallSystem.getAllPromotions(gs, config)
    local promos = {}
    for _, p in ipairs(config.Promotions) do
        promos[#promos + 1] = p
    end
    local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    if loc and config.LocationPromotions and config.LocationPromotions[loc.id] then
        for _, p in ipairs(config.LocationPromotions[loc.id]) do
            promos[#promos + 1] = p
        end
    end
    return promos
end

-- ============================================================================
-- 顾客对话系统（叫卖时触发互动对话，提升名气/信任）
-- ============================================================================

--- 尝试触发顾客对话（叫卖后调用，返回对话数据或nil）
---@param gs table GameState
---@param config table GameConfig
---@param itemName string 当前售卖的商品名
---@return table|nil dialogueData { line, itemName }
function StallSystem.rollCustomerDialogue(gs, config, itemName)
    local DialogueConfig = require("config.DialogueConfig")

    -- 概率判断
    if math.random() > DialogueConfig.TRIGGER_CHANCE then
        return nil
    end

    local trust = gs.stallTrust or 0
    local fame = gs.fame or 0

    -- 收集所有满足条件的对话组
    local eligible = {}
    for _, group in ipairs(DialogueConfig.DIALOGUES) do
        local meetsTrust = trust >= (group.minTrust or 0)
        local meetsFame = fame >= (group.minFame or 0)
        if meetsTrust and meetsFame then
            for _, line in ipairs(group.lines) do
                eligible[#eligible + 1] = line
            end
        end
    end

    if #eligible == 0 then return nil end

    -- 随机选一条
    local chosen = eligible[math.random(1, #eligible)]

    -- 将 %s 替换为商品名
    local text = string.format(chosen.text, itemName)

    return {
        text = text,
        avatar = chosen.avatar,
        replies = chosen.replies,
        itemName = itemName,
    }
end

-- ============================================================================
-- 城管对话系统（城管事件触发后，弹对话框让玩家选择应对方式）
-- ============================================================================

--- 应用城管对话选择（由 main.lua 的 HandleChengguanReply 调用）
---@param gs table GameState
---@param config table GameConfig
---@param choice table 玩家选择的应对方式（GameConfig.Chengguan.CHOICES 中的一项）
---@return string resultMsg 反馈文案
function StallSystem.applyChengguanChoice(gs, config, choice)
    local resultMsg = ""

    if choice.id == "sweet_talk" then
        -- 油嘴滑舌：魅力检定
        local charmData = gs.skills and gs.skills.charm
        local charm = (charmData and charmData.level) or 0
        local rate
        if charm >= choice.charmThreshold then
            rate = choice.successRate.high
        else
            rate = choice.successRate.low
        end
        if math.random() < rate then
            -- 成功
            resultMsg = choice.onSuccess.msg
            gs.mood = math.min(config.Player.MAX_MOOD, gs.mood + (choice.onSuccess.moodChange or 0))
        else
            -- 失败：没收部分货物
            local r = choice.onFail
            resultMsg = r.msg
            local loss = math.floor(gs.stallInventory * (r.inventoryLoss or 0))
            gs.stallInventory = gs.stallInventory - loss
            gs.mood = math.max(0, gs.mood + (r.moodChange or 0))
            if (r.cooldownDays or 0) > 0 then
                local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
                if loc then
                    gs.locationCooldowns[loc.id] = r.cooldownDays
                end
            end
        end

    elseif choice.id == "beg" then
        -- 求情
        local rate = choice.successRate
        if math.random() < rate then
            -- 成功
            resultMsg = choice.onSuccess.msg
            gs.mood = math.min(config.Player.MAX_MOOD, gs.mood + (choice.onSuccess.moodChange or 0))
        else
            -- 失败：罚款
            local r = choice.onFail
            resultMsg = r.msg
            local fine = math.random(r.fineRange[1], r.fineRange[2])
            gs.cash = gs.cash - fine
            resultMsg = resultMsg .. string.format(" 罚款$%s", gs.formatMoney(fine))
            gs.mood = math.max(0, gs.mood + (r.moodChange or 0))
            if (r.cooldownDays or 0) > 0 then
                local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
                if loc then
                    gs.locationCooldowns[loc.id] = r.cooldownDays
                end
            end
        end

    elseif choice.id == "run" then
        -- 推车就跑：必定丢货 + 强制收摊 + 地点冷却
        resultMsg = choice.msg
        local loss = math.floor(gs.stallInventory * (choice.inventoryLoss or 0))
        gs.stallInventory = gs.stallInventory - loss
        gs.mood = math.max(0, gs.mood + (choice.moodChange or 0))
        if choice.cooldownDays and choice.cooldownDays > 0 then
            local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
            if loc then
                gs.locationCooldowns[loc.id] = choice.cooldownDays
            end
        end
        if choice.forceClose then
            StallSystem.doCloseStall(gs, config)
        end

    elseif choice.id == "argue" then
        -- 硬刚：最差结果，重罚 + 强制收摊 + 长冷却
        resultMsg = choice.msg
        local fine = math.random(choice.fineRange[1], choice.fineRange[2])
        gs.cash = gs.cash - fine
        resultMsg = resultMsg .. string.format(" 罚款$%s", gs.formatMoney(fine))
        gs.mood = math.max(0, gs.mood + (choice.moodChange or 0))
        if choice.cooldownDays and choice.cooldownDays > 0 then
            local loc = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
            if loc then
                gs.locationCooldowns[loc.id] = choice.cooldownDays
            end
        end
        if choice.forceClose then
            StallSystem.doCloseStall(gs, config)
        end
        -- 硬刚涨谈判经验
        if choice.negotiationXP then
            PlayerSystem.addSkillXP(gs, "negotiation",
                math.random(choice.negotiationXP[1], choice.negotiationXP[2]), config)
        end
    end

    -- 清除标记
    gs.pendingChengguan = false

    return resultMsg
end

--- 应用对话选择结果
---@param gs table GameState
---@param config table GameConfig
---@param reply table 选择的回复选项
function StallSystem.applyDialogueReply(gs, config, reply)
    -- 信任度
    if reply.trustGain and reply.trustGain ~= 0 then
        if reply.trustGain > 0 then
            StallSystem.addTrust(gs, config, reply.trustGain)
        else
            gs.stallTrust = math.max(0, (gs.stallTrust or 0) + reply.trustGain)
        end
    end
    -- 名气
    if reply.fameGain and reply.fameGain ~= 0 and config.Fame then
        if reply.fameGain > 0 then
            StallSystem.addFame(gs, config, reply.fameGain)
        else
            gs.fame = math.max(0, (gs.fame or 0) + reply.fameGain)
        end
    end
    -- 心情
    if reply.moodChange and reply.moodChange ~= 0 then
        gs.mood = math.max(0, math.min(config.Player.MAX_MOOD, gs.mood + reply.moodChange))
    end
end

return StallSystem
