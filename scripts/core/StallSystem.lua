-- ============================================================================
-- StallSystem.lua - 经营系统（信任度 + 被动销售 + 完整交易流程）
-- 状态机：进货→出摊→（叫卖/等待观望）→收摊
-- ============================================================================

local PlayerSystem = require("core.PlayerSystem")
local ProgressionSystem = require("core.ProgressionSystem")

local StallSystem = {}

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
        local maxSlots = loc.maxSlots or 5
        local usedSlots = gs.stallTimeSlot or 0
        if usedSlots >= maxSlots then
            -- 超时后客流降到30%
            baseSales = math.floor(baseSales * 0.30)
        end
    end

    return math.max(0, baseSales)
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
    gs.isLiveStreaming = false
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
        gs.addMessage("库存卖光了！该收摊啦", "warning")
        return false
    end

    local items = ProgressionSystem.getCurrentItems(gs, config)
    local item = items[gs.stallItemIndex] or items[1]
    if not item then
        gs.addMessage("商品数据异常", "danger")
        return false
    end

    -- 生病时体力消耗增加
    local energyCostMult = 1.0
    if gs.isSick and config.Health then
        energyCostMult = config.Health.SICK_ENERGY_PENALTY or 1.5
    end
    local actualEnergyCost = math.floor(item.energyCost * energyCostMult)

    if gs.energy < actualEnergyCost then
        gs.addMessage("体力不足，卖不动了！可以选择【等待观望】或收摊休息", "warning")
        return false
    end

    -- 扣体力、心情
    gs.energy = math.max(0, gs.energy - actualEnergyCost)
    gs.mood = math.max(0, gs.mood - item.moodCost)

    -- 收入修正因子
    local modifier = StallSystem.calcIncomeModifiers(gs, config)
    local grillMult = grillMultiplier or 1.0

    -- === 1. 被动销售（信任度客流） ===
    local passiveUnits, passiveIncome = StallSystem.doPassiveSales(gs, config, item, modifier * grillMult)
    gs.stallPassiveSold = passiveUnits
    gs.stallPassiveEarned = passiveIncome

    -- === 2. 主动叫卖销售（渐进式：1-3位顾客，每人买1-3份） ===
    local maxCanSell = gs.stallInventory  -- 被动已扣，这里是剩余库存
    local H = config.Hawking
    local numCustomers = math.random(H.CUSTOMERS_PER_HAWK[1], H.CUSTOMERS_PER_HAWK[2])

    -- 熟练度额外顾客（每3级+1位顾客上限）
    local profLevel = gs.stallProfLevel or 1
    local profExtraCustomers = math.floor((profLevel - 1) / 3)
    numCustomers = numCustomers + profExtraCustomers

    -- 时段超时：客流大幅下降
    local locForSlot = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    if locForSlot then
        local maxSlots = locForSlot.maxSlots or 5
        local usedSlots = gs.stallTimeSlot or 0
        if usedSlots >= maxSlots then
            numCustomers = math.max(1, math.floor(numCustomers * 0.30))
        end
    end

    -- 逐位顾客计算购买量
    local unitsSold = 0
    local customerDetails = {}
    for c = 1, numCustomers do
        if unitsSold >= maxCanSell then break end
        local buyUnits = math.random(H.UNITS_PER_CUSTOMER[1], H.UNITS_PER_CUSTOMER[2])
        buyUnits = math.min(buyUnits, maxCanSell - unitsSold)
        if buyUnits > 0 then
            unitsSold = unitsSold + buyUnits
            -- 随机选一句顾客台词
            local line = H.CUSTOMER_LINES[math.random(1, #H.CUSTOMER_LINES)]
            customerDetails[#customerDetails + 1] = string.format(line, buyUnits)
        end
    end

    local gross = unitsSold * item.unitPrice
    local income = math.floor(gross * modifier * grillMult)

    -- === 3. 摆摊事件 ===
    local evt = StallSystem.rollStallEvent(gs, config)
    StallSystem.lastStallEvent = evt

    if evt then
        if evt.effect == "chengguan_encounter" then
            -- 城管来了！设置标记，由 main.lua 弹对话框处理
            gs.pendingChengguan = true
            gs.addMessage(string.format("[经营] %s - %s", evt.name, evt.desc), "danger")
            -- 先结算本轮叫卖收入再弹对话
        elseif evt.effect == "half_income" then
            income = math.floor(income * 0.5)
            gs.addMessage(string.format("[经营] %s - %s", evt.name, evt.desc), "warning")
        elseif evt.effect == "reduce_30" then
            income = math.floor(income * 0.7)
            gs.addMessage(string.format("[经营] %s - %s", evt.name, evt.desc), "warning")
        elseif evt.effect == "repair_cost" then
            local repairCost = math.random(1000, 5000) * (gs.mainBizTier or 1)
            gs.cash = gs.cash - repairCost
            gs.addMessage(string.format("[经营] %s 维修费$%d", evt.name, repairCost), "warning")
        elseif evt.effect == "double_income" then
            income = income * 2
            gs.addMessage(string.format("[经营] %s - %s", evt.name, evt.desc), "success")
        elseif evt.effect == "reputation_up" then
            gs.reputation = (gs.reputation or 0) + math.random(5, 15)
            StallSystem.addTrust(gs, config, math.random(3, 6))
            gs.addMessage(string.format("[经营] %s 声望+，口碑提升！", evt.name), "success")
        elseif evt.effect == "fans_up" then
            local fans = math.random(50, 300)
            gs.followers = gs.followers + fans
            gs.addMessage(string.format("[经营] %s 涨粉+%d", evt.name, fans), "success")
        end
    end

    -- === 4. 更新库存和收入（主动部分） ===
    gs.stallInventory = gs.stallInventory - unitsSold
    gs.stallTotalSold = gs.stallTotalSold + unitsSold
    gs.stallTotalEarned = gs.stallTotalEarned + income
    gs.cash = gs.cash + income

    -- 直播额外涨粉
    if gs.isLiveStreaming then
        local fans = math.random(5, 30)
        gs.followers = gs.followers + fans
    end

    -- === 5. 信任度增长（叫卖涨得多） ===
    local T = config.Trust
    local trustGain = math.random(T.HAWK_TRUST_GAIN[1], T.HAWK_TRUST_GAIN[2])
    -- 地点信任增长倍率
    local locForTrust = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    if locForTrust then
        trustGain = math.floor(trustGain * (locForTrust.trustGainMod or 1.0))
    end
    -- 促销活动额外信任加成
    local promoForTrust = StallSystem.getActivePromotionConfig(gs, config)
    if promoForTrust then
        trustGain = trustGain + (promoForTrust.trustGainBonus or 0)
    end
    StallSystem.addTrust(gs, config, trustGain)

    -- 显示顾客台词（最多显示3条，避免刷屏）
    local actualCustomerCount = #customerDetails
    for i = 1, math.min(3, actualCustomerCount) do
        gs.addMessage(string.format("🧑 顾客%d: %s", i, customerDetails[i]), "info")
    end
    if actualCustomerCount > 3 then
        gs.addMessage(string.format("...还有%d位顾客也买了", actualCustomerCount - 3), "info")
    end

    -- 显示综合结果
    local tierDef = ProgressionSystem.getCurrentTier(gs, config)
    local tierName = tierDef and tierDef.name or "经营"
    local liveTag = gs.isLiveStreaming and " 📱直播中" or ""
    local totalUnits = unitsSold + passiveUnits
    local totalIncome = income + passiveIncome
    local passiveTag = passiveUnits > 0
        and string.format("（叫卖%d+回头客%d）", unitsSold, passiveUnits) or ""

    gs.addMessage(string.format("来了%d位顾客，卖出%d份%s%s%s，赚$%s | 余%d份",
        actualCustomerCount, totalUnits, item.name, passiveTag, liveTag,
        gs.formatMoney(totalIncome), gs.stallInventory), "success")

    -- === 6. 时段推进 ===
    gs.stallTimeSlot = (gs.stallTimeSlot or 0) + 1

    -- === 7. 库存卖完自动收摊 ===
    if gs.stallInventory <= 0 then
        gs.addMessage("库存全部卖完了！本次营业结束", "info")
        StallSystem.doCloseStall(gs, config)
    end

    -- === 8. 熟练度经验增长 ===
    local profFans = StallSystem.processProficiency(gs, config)

    -- === 8. 名气增长 ===
    if config.Fame then
        local fameGain = math.random(config.Fame.HAWK_FAME_GAIN[1], config.Fame.HAWK_FAME_GAIN[2])
        if gs.isLiveStreaming then
            fameGain = math.floor(fameGain * config.Fame.LIVESTREAM_FAME_MULT)
        end
        StallSystem.addFame(gs, config, fameGain)
        -- 促销名气加成
        if gs.activePromotion then
            local activePromo = StallSystem.getActivePromotionConfig(gs, config)
            if activePromo and activePromo.fameGainBonus then
                StallSystem.addFame(gs, config, activePromo.fameGainBonus)
            end
        end
    end

    -- === 9. 网红事件触发 ===
    StallSystem.rollViralEvent(gs, config)

    -- 记录活动日志
    gs.addLog(string.format("叫卖招来%d位顾客，卖%d份%s（回头客%d），赚$%s，口碑+%d",
        actualCustomerCount, totalUnits, item.name, passiveUnits,
        gs.formatMoney(totalIncome), trustGain), "sell")

    PlayerSystem.addSkillXP(gs, "negotiation", math.random(8, 20), config)
    PlayerSystem.addSkillXP(gs, "marketing", math.random(3, 10), config)

    return true
end

-- ============================================================================
-- 等待观望（低体力时也能赚钱，消耗回合）
-- ============================================================================
function StallSystem.waitObserve(gs, config)
    if not gs.isStalling then
        gs.addMessage("还没出摊呢！", "warning")
        return false
    end
    if gs.stallInventory <= 0 then
        gs.addMessage("库存卖光了！该收摊啦", "warning")
        return false
    end

    local items = ProgressionSystem.getCurrentItems(gs, config)
    local item = items[gs.stallItemIndex] or items[1]
    if not item then
        gs.addMessage("商品数据异常", "danger")
        return false
    end

    local T = config.Trust

    -- 消耗少量体力和心情
    local energyCost = T.WAIT_ENERGY_COST
    local moodCost = T.WAIT_MOOD_COST
    if gs.energy < energyCost then
        -- 即使体力极低也允许等待，但不扣到负数
        energyCost = gs.energy
    end
    gs.energy = math.max(0, gs.energy - energyCost)
    gs.mood = math.max(0, gs.mood - moodCost)

    -- 收入修正
    local modifier = StallSystem.calcIncomeModifiers(gs, config)

    -- === 被动销售 ===
    local passiveUnits, passiveIncome = StallSystem.doPassiveSales(gs, config, item, modifier)
    gs.stallPassiveSold = passiveUnits
    gs.stallPassiveEarned = passiveIncome

    -- === 信任度微涨（等待也能跟路人打招呼） ===
    local trustGain = math.random(T.WAIT_TRUST_GAIN[1], T.WAIT_TRUST_GAIN[2])
    -- 地点信任增长倍率
    local locForTrust = gs.getCurrentLocation and gs.getCurrentLocation(config) or nil
    if locForTrust then
        trustGain = math.floor(trustGain * (locForTrust.trustGainMod or 1.0))
    end
    -- 促销活动额外信任加成（等待时减半）
    local promoForTrust = StallSystem.getActivePromotionConfig(gs, config)
    if promoForTrust then
        trustGain = trustGain + math.floor((promoForTrust.trustGainBonus or 0) * 0.5)
    end
    StallSystem.addTrust(gs, config, trustGain)

    -- === 摆摊事件 ===
    local evt = StallSystem.rollStallEvent(gs, config)
    StallSystem.lastStallEvent = evt

    if evt then
        if evt.effect == "chengguan_encounter" then
            -- 城管来了！设置标记，由 main.lua 弹对话框处理
            gs.pendingChengguan = true
            gs.addMessage(string.format("[经营] %s - %s", evt.name, evt.desc), "danger")
        elseif evt.effect == "half_income" then
            -- 被动收入已结算，这里不重复处理
            gs.addMessage(string.format("[经营] %s - %s", evt.name, evt.desc), "warning")
        elseif evt.effect == "double_income" then
            -- 额外奖励
            local bonus = passiveIncome
            gs.cash = gs.cash + bonus
            gs.stallTotalEarned = gs.stallTotalEarned + bonus
            passiveIncome = passiveIncome + bonus
            gs.addMessage(string.format("[经营] %s - %s 额外+$%s", evt.name, evt.desc, gs.formatMoney(bonus)), "success")
        elseif evt.effect == "reputation_up" then
            gs.reputation = (gs.reputation or 0) + math.random(5, 15)
            StallSystem.addTrust(gs, config, math.random(3, 6))
            gs.addMessage(string.format("[经营] %s 声望+，口碑提升！", evt.name), "success")
        elseif evt.effect == "fans_up" then
            local fans = math.random(50, 300)
            gs.followers = gs.followers + fans
            gs.addMessage(string.format("[经营] %s 涨粉+%d", evt.name, fans), "success")
        elseif evt.effect == "repair_cost" then
            local repairCost = math.random(1000, 5000) * (gs.mainBizTier or 1)
            gs.cash = gs.cash - repairCost
            gs.addMessage(string.format("[经营] %s 维修费$%d", evt.name, repairCost), "warning")
        elseif evt.effect == "reduce_30" then
            gs.addMessage(string.format("[经营] %s - %s", evt.name, evt.desc), "warning")
        end
    end

    -- 时段推进
    gs.stallTimeSlot = (gs.stallTimeSlot or 0) + 1

    -- 显示结果
    local trustInfo = StallSystem.getTrustInfo(gs, config)
    if passiveUnits > 0 then
        gs.addMessage(string.format("等待观望中…回头客买了%d份%s，赚$%s | 库存余%d份",
            passiveUnits, item.name, gs.formatMoney(passiveIncome), gs.stallInventory), "info")
    else
        gs.addMessage(string.format("等了半天，没什么人…%s口碑还需要积累",
            trustInfo.emoji), "info")
    end

    -- 直播额外涨粉
    if gs.isLiveStreaming then
        local fans = math.random(3, 15)
        gs.followers = gs.followers + fans
    end

    -- 库存卖完自动收摊
    if gs.stallInventory <= 0 then
        gs.addMessage("库存全部卖完了！本次营业结束", "info")
        StallSystem.doCloseStall(gs, config)
    end

    -- 少量熟练度（等待也在学习经营）
    local P = config.Proficiency
    local profXP = math.random(3, 8)
    gs.stallProficiency = (gs.stallProficiency or 0) + profXP

    -- 名气微涨
    if config.Fame then
        local fameGain = math.random(config.Fame.WAIT_FAME_GAIN[1], config.Fame.WAIT_FAME_GAIN[2])
        if gs.isLiveStreaming then
            fameGain = math.floor(fameGain * config.Fame.LIVESTREAM_FAME_MULT)
        end
        if fameGain > 0 then
            StallSystem.addFame(gs, config, fameGain)
        end
    end

    -- 网红事件（等待时也有小概率触发）
    StallSystem.rollViralEvent(gs, config)

    -- 记录日志
    gs.addLog(string.format("等待观望，回头客买%d份%s，赚$%s，口碑+%d",
        passiveUnits, item.name, gs.formatMoney(passiveIncome), trustGain), "sell")

    PlayerSystem.addSkillXP(gs, "negotiation", math.random(2, 6), config)

    return true
end

-- ============================================================================
-- 收摊
-- ============================================================================

--- 收摊（不消耗回合）
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
    gs.isLiveStreaming = false
    gs.currentActivity = "idle"
end

--- 开/关直播（不消耗回合）
function StallSystem.toggleLiveStream(gs, config)
    if not gs.isStalling then
        gs.addMessage("需要先出摊才能直播！", "warning")
        return false
    end
    gs.isLiveStreaming = not gs.isLiveStreaming
    if gs.isLiveStreaming then
        gs.addMessage("📱 开始直播！卖货收入+30%，还能涨粉", "success")
    else
        gs.addMessage("关闭直播", "info")
    end
    return true
end

--- 摆摊事件滚骰（40%触发率）
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
        local charm = (gs.skills and gs.skills.charm) or 0
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
