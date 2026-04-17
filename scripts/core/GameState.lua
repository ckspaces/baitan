-- ============================================================================
-- GameState.lua - 游戏中心状态（重构版）
-- ============================================================================

local GameState = {}

function GameState.init(config)
    local C = config.Game
    local F = config.Finance
    local P = config.Player

    -- 时间
    GameState.currentMonth = 1
    GameState.currentDay = 1
    GameState.year = 1
    GameState.monthInYear = 1
    GameState.timeOfDayMinutes = 9 * 60
    GameState.actionsToday = 0          -- 今日已消耗行动槽（0-2，满3时推进一天）

    -- 财务
    GameState.cash = C.INITIAL_CASH
    GameState.bankDebt = F.INITIAL_BANK_DEBT
    GameState.sharkDebt = F.INITIAL_SHARK_DEBT
    GameState.totalDebt = F.INITIAL_BANK_DEBT + F.INITIAL_SHARK_DEBT
    GameState.totalRepaid = 0
    GameState.monthIncome = 0
    GameState.monthExpense = 0
    GameState.cashLedger = {}

    -- 角色属性
    GameState.energy = P.MAX_ENERGY
    GameState.mood = 70
    GameState.health = P.MAX_HEALTH

    -- 技能
    GameState.skills = {}
    for _, stype in ipairs(config.Skills.TYPES) do
        GameState.skills[stype] = { level = 1, xp = 0 }
    end

    -- 声望与粉丝
    GameState.followers = 0
    GameState.reputation = 0

    -- === 名气/网红系统 ===
    GameState.fame = 0                      -- 名气值（0~10000）
    GameState.fameLevel = 1                 -- 名气等级（对应 GameConfig.Fame.LEVELS 索引）
    GameState.viralEventsTriggered = {}     -- 已触发过的网红事件ID列表（防重复连续触发）
    GameState.lastViralEvent = nil          -- 上次触发的网红事件（用于UI显示）

    -- === 主业系统（替代旧 businesses） ===
    GameState.mainBizTier = 1               -- 当前主业等级 1~4
    GameState.selectedStallItem = 1         -- 当前选品索引
    GameState.itemProgress = {}             -- 单品制作/售卖经验 { [itemId] = xp }
    GameState.flyersActive = 0              -- 传单层数
    GameState.stallDayCount = 0             -- 累计经营天数
    GameState.stallProficiency = 0          -- 摆摊熟练度（累计经验）
    GameState.stallProfLevel = 1            -- 摆摊熟练度等级
    GameState.stallTrust = 0                -- 信任度/口碑（0~100，跨出摊保留）
    GameState.stallPassiveSold = 0          -- 本回合被动卖出量（用于UI显示）
    GameState.stallPassiveEarned = 0        -- 本回合被动收入（用于UI显示）
    GameState.stallSessionRevenue = 0
    GameState.stallSessionCosts = 0
    GameState.stallSessionNet = 0
    GameState.stallSessionStartCash = GameState.cash
    GameState.stallSessionStartMinute = 0
    GameState.stallSessionEndMinute = 0
    GameState.stallActionMode = 'balanced'
    GameState.stallActionModeUntil = 0
    GameState.stallTickAccumulator = 0
    GameState.stallDemandRemainder = 0
    GameState.stallLastSettlement = nil
    GameState.equipmentWear = 0

    -- === 地点系统 ===
    GameState.currentLocation = 1           -- 当前摆摊地点索引（对应 GameConfig.Locations）
    GameState.locationTrust = {}            -- 每个地点独立的信任度 { [locationId] = number }
    for _, loc in ipairs(config.Locations) do
        GameState.locationTrust[loc.id] = 0
    end

    -- === 促销活动 ===
    GameState.activePromotion = nil         -- 当前进行中的促销 { id, remaining }
    GameState.promotionCooldown = 0         -- 促销冷却（天数，防止连续使用）

    -- === 摆摊状态机 ===
    GameState.isStalling = false            -- 是否正在摆摊中
    GameState.stallInventory = 0            -- 当前库存份数
    GameState.stallInventoryMax = 0         -- 本次营业累计制作份数
    GameState.stallItemIndex = 1            -- 当前进货的商品索引（Lua 1-based）
    GameState.stallTotalSold = 0            -- 本次出摊累计已卖
    GameState.stallTotalEarned = 0          -- 本次出摊累计收入
    GameState.isLiveStreaming = false        -- 是否在边摊边播
    GameState.stallTimeSlot = 0             -- 本次出摊已使用的时段数
    GameState.liveViewerCount = 0           -- 当前直播间观众数
    GameState.liveTipsEarned = 0            -- 本次直播打赏收入
    GameState.liveOrdersSold = 0            -- 本次直播带来的额外销量
    GameState.liveComments = {}             -- 最近直播弹幕
    GameState.stallNaturalSold = 0          -- 本回合自然来客卖出量
    GameState.stallNaturalEarned = 0        -- 本回合自然来客收入

    -- === 地点冷却（城管驱赶后冷却） ===
    GameState.locationCooldowns = {}        -- { [locationId] = 剩余冷却天数 }

    -- === 城管遭遇标记 ===
    GameState.pendingChengguan = false       -- 是否需要弹城管对话

    -- === 超市购物 ===
    GameState.supermarketPurchasesToday = 0  -- 今日已购买件数

    -- === 破产警告 ===
    GameState.lastFinancialWarningLevel = 0  -- 上次警告等级（0=无, 1=警告, 2=严重）

    -- 当前场景（默认为摆摊，不再是 office）
    GameState.currentScene = "stall"
    GameState.currentActivity = "idle"

    -- 游戏阶段
    GameState.phase = "playing"

    -- 月度历史记录
    GameState.monthHistory = {}

    -- 消息日志
    GameState.messages = {}

    -- 天气与季节
    GameState.currentSeason = "spring"
    GameState.currentWeather = "sunny"

    -- 健康系统
    GameState.isSick = false          -- 是否生病
    GameState.sickDays = 0            -- 已生病天数

    -- === 钓鱼库存 ===
    GameState.fishStock = 0             -- 鱼库存（钓鱼获得，用于摆摊烤鱼）

    -- 待处理的微信事件（弹窗用）
    GameState.pendingWechatEvent = nil

    -- 横幅广告语（玩家可自定义）
    GameState.bannerText = "好吃不贵，走过路过别错过！"

    -- 活动日志（永久记录关键事件）
    GameState.activityLog = {}

    -- 动画时间
    GameState.animTime = 0
end

--- 添加消息日志
function GameState.addMessage(msg, msgType)
    table.insert(GameState.messages, 1, {
        text = msg,
        type = msgType or "info",
        time = GameState.currentMonth + (GameState.currentDay - 1) * 0.25,
    })
    while #GameState.messages > 15 do
        table.remove(GameState.messages)
    end
end

--- 添加活动日志（永久记录）
function GameState.addLog(text, logType)
    table.insert(GameState.activityLog, 1, {
        text = text,
        type = logType or "info",
        date = GameState.getDateText(),
        timeText = GameState.getTimeText(),
        month = GameState.currentMonth,
        day = GameState.currentDay,
    })
    -- 最多保留50条
    while #GameState.activityLog > 50 do
        table.remove(GameState.activityLog)
    end
end

function GameState.getTimeText()
    local total = math.max(0, GameState.timeOfDayMinutes or 0)
    local hour = math.floor(total / 60) % 24
    local minute = total % 60
    return string.format('%02d:%02d', hour, minute)
end

--- 获取格式化日期文本
function GameState.getDateText()
    return string.format("第%d年 %d月 %d日",
        GameState.year, GameState.monthInYear, GameState.currentDay)
end

--- 格式化金额
function GameState.formatMoney(amount)
    if math.abs(amount) >= 100000000 then
        return string.format("%.2f亿", amount / 100000000)
    elseif math.abs(amount) >= 10000 then
        return string.format("%.1f万", amount / 10000)
    else
        return string.format("%d", math.floor(amount))
    end
end

--- 获取技能等级
function GameState.getSkillLevel(skillType)
    local s = GameState.skills[skillType]
    return s and s.level or 0
end

--- 检查技能需求是否满足
function GameState.meetsSkillReq(req)
    if not req then return true end
    for skill, level in pairs(req) do
        if GameState.getSkillLevel(skill) < level then
            return false
        end
    end
    return true
end

--- 获取当前地点配置（需要传入 GameConfig）
function GameState.getCurrentLocation(config)
    return config.Locations[GameState.currentLocation]
end

--- 切换地点时同步信任度
function GameState.syncTrustToLocation(config)
    local loc = GameState.getCurrentLocation(config)
    if loc then
        GameState.stallTrust = GameState.locationTrust[loc.id] or 0
    end
end

--- 保存当前地点的信任度
function GameState.saveTrustFromLocation(config)
    local loc = GameState.getCurrentLocation(config)
    if loc then
        GameState.locationTrust[loc.id] = GameState.stallTrust
    end
end

--- 检查财务健康状态
--- @return string "ok" | "warning" | "severe" | "gameover"
function GameState.checkFinancialHealth(config)
    local B = config.Bankruptcy
    if not B then return "ok" end
    if GameState.cash <= B.GAMEOVER_THRESHOLD then
        return "gameover"
    elseif GameState.cash <= B.SEVERE_THRESHOLD then
        return "severe"
    elseif GameState.cash <= B.WARNING_THRESHOLD then
        return "warning"
    end
    return "ok"
end

--- 获取可序列化的存档数据
function GameState.toSaveData()
    local data = {}
    -- 时间
    data.currentMonth = GameState.currentMonth
    data.currentDay = GameState.currentDay
    data.year = GameState.year
    data.monthInYear = GameState.monthInYear
    data.timeOfDayMinutes = GameState.timeOfDayMinutes
    -- 财务
    data.cash = GameState.cash
    data.bankDebt = GameState.bankDebt
    data.sharkDebt = GameState.sharkDebt
    data.totalDebt = GameState.totalDebt
    data.totalRepaid = GameState.totalRepaid
    data.monthIncome = GameState.monthIncome
    data.monthExpense = GameState.monthExpense
    data.cashLedger = GameState.cashLedger
    -- 角色
    data.energy = GameState.energy
    data.mood = GameState.mood
    data.health = GameState.health
    data.skills = GameState.skills
    data.followers = GameState.followers
    data.reputation = GameState.reputation
    -- 名气
    data.fame = GameState.fame
    data.fameLevel = GameState.fameLevel
    data.viralEventsTriggered = GameState.viralEventsTriggered
    -- 主业
    data.mainBizTier = GameState.mainBizTier
    data.selectedStallItem = GameState.selectedStallItem
    data.itemProgress = GameState.itemProgress
    data.flyersActive = GameState.flyersActive
    data.stallDayCount = GameState.stallDayCount
    data.stallProficiency = GameState.stallProficiency
    data.stallProfLevel = GameState.stallProfLevel
    data.stallTrust = GameState.stallTrust
    data.equipmentWear = GameState.equipmentWear
    -- 地点 & 促销
    data.currentLocation = GameState.currentLocation
    data.locationTrust = GameState.locationTrust
    data.locationCooldowns = GameState.locationCooldowns
    data.activePromotion = GameState.activePromotion
    data.promotionCooldown = GameState.promotionCooldown
    data.supermarketPurchasesToday = GameState.supermarketPurchasesToday
    data.lastFinancialWarningLevel = GameState.lastFinancialWarningLevel
    -- 钓鱼
    data.fishStock = GameState.fishStock
    -- 状态
    data.currentScene = GameState.currentScene
    data.phase = GameState.phase
    data.monthHistory = GameState.monthHistory
    data.currentSeason = GameState.currentSeason
    data.currentWeather = GameState.currentWeather
    data.isSick = GameState.isSick
    data.sickDays = GameState.sickDays
    data.activityLog = GameState.activityLog
    return data
end

--- 从存档数据恢复状态
function GameState.fromSaveData(data)
    if not data then return false end
    -- 逐字段恢复，缺失字段保持 init 默认值
    for k, v in pairs(data) do
        if k == "skills" then
            -- skills 是表，需深拷贝
            GameState.skills = {}
            for sk, sv in pairs(v) do
                GameState.skills[sk] = { level = sv.level, xp = sv.xp }
            end
        elseif k == "locationTrust" then
            GameState.locationTrust = {}
            for lid, tv in pairs(v) do
                GameState.locationTrust[lid] = tv
            end
        elseif k == "activePromotion" then
            if v then
                GameState.activePromotion = { id = v.id, remaining = v.remaining }
            else
                GameState.activePromotion = nil
            end
        elseif k == "locationCooldowns" then
            GameState.locationCooldowns = {}
            for lid, cd in pairs(v) do
                GameState.locationCooldowns[lid] = cd
            end
        elseif k == "monthHistory" or k == "activityLog" or k == "viralEventsTriggered" or k == "cashLedger" then
            GameState[k] = v  -- 表直接赋值（cjson 反序列化后已是新表）
        else
            GameState[k] = v
        end
    end
    -- 重置运行时临时状态（不需要存档的）
    GameState.isStalling = false
    GameState.stallInventory = 0
    GameState.stallInventoryMax = 0
    GameState.stallItemIndex = 1
    GameState.stallTotalSold = 0
    GameState.stallTotalEarned = 0
    GameState.isLiveStreaming = false
    GameState.stallTimeSlot = 0
    GameState.liveViewerCount = 0
    GameState.liveTipsEarned = 0
    GameState.liveOrdersSold = 0
    GameState.liveComments = {}
    GameState.stallNaturalSold = 0
    GameState.stallNaturalEarned = 0
    GameState.stallPassiveSold = 0
    GameState.stallPassiveEarned = 0
    GameState.stallSessionRevenue = 0
    GameState.stallSessionCosts = 0
    GameState.stallSessionNet = 0
    GameState.stallSessionStartCash = GameState.cash
    GameState.stallSessionStartMinute = GameState.timeOfDayMinutes or 0
    GameState.stallSessionEndMinute = GameState.timeOfDayMinutes or 0
    GameState.stallActionMode = 'balanced'
    GameState.stallActionModeUntil = 0
    GameState.stallTickAccumulator = 0
    GameState.stallDemandRemainder = 0
    GameState.stallLastSettlement = nil
    GameState.pendingChengguan = false
    GameState.messages = {}
    GameState.pendingWechatEvent = nil
    GameState.lastViralEvent = nil
    GameState.animTime = 0
    GameState.currentActivity = "idle"
    -- 兼容旧存档（无钓鱼字段时默认为0）
    if GameState.fishStock == nil then GameState.fishStock = 0 end
    -- 兼容旧存档（行动槽）
    if GameState.actionsToday == nil then GameState.actionsToday = 0 end
    return true
end

return GameState
