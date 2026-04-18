-- ============================================================================
-- HelperSystem.lua - 伙计系统（招募、值守、工资、效率）
-- ============================================================================

local HelperSystem = {}

--- 获取伙计配置中的等级显示名
local function getLevelLabel(config, level)
    local H = config.Helper or {}
    local names = H.LEVEL_NAMES or { "普通伙计", "熟练伙计", "老手伙计" }
    local emojis = H.LEVEL_EMOJI or { "🧑", "👨‍🍳", "⭐" }
    local lv = math.max(1, math.min(3, level or 1))
    return (emojis[lv] or "🧑") .. " " .. (names[lv] or "伙计")
end

--- 雇用一个候选人
--- @param gs table GameState
--- @param config table GameConfig
--- @param candidateIndex number 候选人在 CANDIDATES 中的下标
--- @return boolean 是否雇用成功
function HelperSystem.hireHelper(gs, config, candidateIndex)
    local H = config.Helper
    if not H then return false end

    local candidates = gs.helperCandidates or H.CANDIDATES
    local c = candidates[candidateIndex]
    if not c then return false end

    -- 已有伙计先解雇
    if gs.helper then
        HelperSystem.dismissHelper(gs, config)
    end

    gs.helper = {
        name       = c.name,
        level      = c.level,
        salary     = c.salary,
        efficiency = c.efficiency,
        avatar     = c.avatar,
        desc       = c.desc,
        trait      = c.trait,
        mood       = c.mood or 80,
        loyalty    = c.loyalty or 60,
        daysWorked = 0,
    }
    gs.helperActive = false
    gs.helperCandidates = nil
    gs.helperRecruitCooldown = H.RECRUIT_COOLDOWN_DAYS or 7

    local label = getLevelLabel(config, c.level)
    gs.addMessage(string.format(
        "🤝 成功雇用 %s！等级：%s，效率：%.0f%%，日薪 $%d",
        c.name, label, c.efficiency * 100, c.salary), "success")
    return true
end

--- 解雇当前伙计
--- @param gs table GameState
--- @param config table GameConfig
function HelperSystem.dismissHelper(gs, config)
    if not gs.helper then return end
    local name = gs.helper.name
    gs.helper = nil
    gs.helperActive = false
    gs.addMessage(string.format("👋 %s 离开了，摊位需要你亲自盯着了", name), "info")
end

--- 让伙计开始/停止值守（出摊中调用）
--- @param gs table GameState
--- @param active boolean
function HelperSystem.setHelperActive(gs, active)
    if not gs.helper then return end
    gs.helperActive = active
    if active then
        gs.addMessage(string.format("🧑 %s 开始帮你看摊，你可以去做其他事了！", gs.helper.name), "info")
    else
        gs.addMessage(string.format("🧑 %s 暂停值守", gs.helper.name), "info")
    end
end

--- 返回伙计效率修正系数（作用于 calcIncomeModifiers）
--- @param gs table GameState
--- @param config table GameConfig
--- @return number 效率系数（无伙计或伙计未激活时=1.0）
function HelperSystem.applyHelperModifier(gs, config)
    if gs.helperActive and gs.helper then
        return gs.helper.efficiency
    end
    return 1.0
end

--- 每天结算时扣除伙计工资（在 TimeSystem.advanceDay 末尾调用）
--- @param gs table GameState
--- @param config table GameConfig
function HelperSystem.deductSalary(gs, config)
    -- 招募冷却倒计时
    if (gs.helperRecruitCooldown or 0) > 0 then
        gs.helperRecruitCooldown = gs.helperRecruitCooldown - 1
    end

    if not gs.helper then return end

    local salary = gs.helper.salary or 0
    if salary <= 0 then return end

    gs.helper.daysWorked = (gs.helper.daysWorked or 0) + 1

    -- 扣工资（允许现金变负，但给出提示）
    gs.cash = gs.cash - salary
    local H = config.Helper or {}
    local msg = string.format(H.SALARY_DEDUCT_MSG or "支付 %s 工资 $%d", gs.helper.name, salary)
    gs.addMessage(msg, "warning")

    -- 伙计没工资会不满
    if gs.cash < 0 then
        gs.addMessage(string.format("💸 现金不足！%s 对你皱起了眉头…", gs.helper.name), "danger")
    end
end

--- 随机生成候选人列表（从候选人池中随机选2~3人）
--- @param gs table GameState
--- @param config table GameConfig
--- @return table 候选人列表
function HelperSystem.generateCandidates(gs, config)
    local H = config.Helper or {}
    local pool = H.CANDIDATES or {}
    if #pool == 0 then return {} end

    -- 随机排序，取2~3人
    local shuffled = {}
    for _, c in ipairs(pool) do
        shuffled[#shuffled + 1] = c
    end
    -- Fisher-Yates shuffle
    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end
    local count = math.random(2, math.min(3, #shuffled))
    local result = {}
    for i = 1, count do
        result[i] = shuffled[i]
    end
    return result
end

--- 返回伙计状态文字（用于 UI 显示）
--- @param gs table GameState
--- @param config table GameConfig
--- @return string
function HelperSystem.getHelperStatusText(gs, config)
    if not gs.helper then
        return "暂无伙计"
    end
    local h = gs.helper
    local label = getLevelLabel(config, h.level)
    local status = gs.helperActive and "值守中" or "待命"
    return string.format("%s %s · 效率%.0f%% · 日薪$%d · %s",
        label, h.name, h.efficiency * 100, h.salary, status)
end

return HelperSystem
