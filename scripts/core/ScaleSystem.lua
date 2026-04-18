-- ============================================================================
-- ScaleSystem.lua - 规模成长系统
-- ============================================================================
-- 经营越久、技能越高，三个维度持续改善：
--   1. 批量上限 (管理技能 + 经营天数)  → 每次可做更多份，摊薄固定成本
--   2. 采购折扣 (谈判技能 + 经营天数)  → 供应商关系加深，原料成本降低
--   3. 尾货回收 (管理技能 + 技术技能)  → 剩余食材部分可回收，减少浪费损失
-- ============================================================================

local ScaleSystem = {}

-- ============================================================================
-- 内部：经营天数对应的里程碑档位
-- ============================================================================
local function getDayTier(stallDayCount)
    local d = stallDayCount or 0
    if     d >= 70 then return 5
    elseif d >= 40 then return 4
    elseif d >= 20 then return 3
    elseif d >= 7  then return 2
    else                return 1
    end
end

-- ============================================================================
-- 1. 批量上限（有效产量）
-- ============================================================================
-- 管理技能代表需求预判和组织效率（知道今天能卖多少就备多少）
-- 经营天数代表客群积累（固定回头客让备货更有底气）
--
-- Lv1→×1.00  Lv5→×1.44  Lv10→×2.00（管理满级产量翻番）
-- 配合天数加成最高再×1.30 → 理论上限 2.60×base
-- ============================================================================
function ScaleSystem.getEffectiveYield(gs, config, item)
    local base    = item.yield
    local mgmtLv  = gs.skills.management.level

    -- 管理技能加成：每升一级 +11%产能
    local skillMult = 1 + (mgmtLv - 1) * 0.11   -- Lv1:1.00 Lv5:1.44 Lv10:2.00

    -- 经营天数里程碑
    local dayMults  = { 1.00, 1.05, 1.12, 1.20, 1.30 }
    local dayMult   = dayMults[getDayTier(gs.stallDayCount)]

    return math.max(base, math.floor(base * skillMult * dayMult))
end

-- ============================================================================
-- 2. 采购折扣（有效进货成本）
-- ============================================================================
-- 谈判技能：砍价能力，每级 -3%（Lv1:0% Lv5:-12% Lv10:-27%）
-- 经营天数：量大从优，供应商主动给出长期价
-- 总折扣上限 40%（再低就是贱卖了，供应商也要活）
-- ============================================================================
function ScaleSystem.getEffectiveCost(gs, config, item)
    local base   = item.batchCost
    if base <= 0 then return 0 end

    local negoLv     = gs.skills.negotiation.level
    local negoDisc   = (negoLv - 1) * 0.03   -- 每级-3%

    -- 经营天数量折
    local dayDiscounts = { 0.00, 0.02, 0.06, 0.10, 0.14 }
    local volDisc      = dayDiscounts[getDayTier(gs.stallDayCount)]

    local totalDisc = math.min(negoDisc + volDisc, 0.40)
    return math.max(1, math.floor(base * (1 - totalDisc)))
end

-- ============================================================================
-- 3. 尾货回收率（收摊时退回部分未售成本）
-- ============================================================================
-- 管理技能：需求预判准 → 采购量更精准 → 尾货本来就少；
--            剩余食材也更容易处置（转卖给同行等）
-- 技术技能：保鲜处理和食材二次利用能力
--
-- 每级管理 +3%，每级技术 +2%，上限 40%
-- Lv10管理+Lv10技术 = 0.27+0.18 = 0.45 → 取 min(0.45, 0.40) = 40%
-- ============================================================================
function ScaleSystem.getSalvageRate(gs, config)
    local mgmtLv = gs.skills.management.level
    local techLv = gs.skills.tech.level

    local rate = (mgmtLv - 1) * 0.03 + (techLv - 1) * 0.02
    return math.min(rate, 0.40)
end

-- ============================================================================
-- 综合信息（用于 UI 展示和 openStall 预览）
-- ============================================================================
---@return table {baseYield, effYield, yieldBonus, baseCost, effCost, discPct, salvagePct, nextMilestone}
function ScaleSystem.getInfo(gs, config, item)
    local effYield  = ScaleSystem.getEffectiveYield(gs, config, item)
    local effCost   = ScaleSystem.getEffectiveCost(gs, config, item)
    local salvage   = ScaleSystem.getSalvageRate(gs, config)
    local baseCost  = item.batchCost

    -- 下一个经营天数里程碑
    local days = gs.stallDayCount or 0
    local nextDay = days < 7 and 7 or days < 20 and 20 or days < 40 and 40 or days < 70 and 70 or nil

    -- 单份成本（用于尾货金额估算）
    local unitCost = effYield > 0 and (effCost / effYield) or 0

    return {
        baseYield   = item.yield,
        effYield    = effYield,
        yieldBonus  = effYield - item.yield,

        baseCost    = baseCost,
        effCost     = effCost,
        discPct     = baseCost > 0 and math.floor((1 - effCost / baseCost) * 100) or 0,

        unitCost    = unitCost,
        salvageRate = salvage,
        salvagePct  = math.floor(salvage * 100),

        nextMilestone = nextDay,
        stallDayCount = days,
    }
end

-- ============================================================================
-- 计算本次收摊的尾货回收金额
-- ============================================================================
---@param leftover number 剩余未售份数
---@param effCost number 本次实际进货成本
---@param effYield number 本次实际产量
---@param salvageRate number 回收率 0~0.40
---@return number salvageAmount 应退款金额
function ScaleSystem.calcSalvageAmount(leftover, effCost, effYield, salvageRate)
    if leftover <= 0 or salvageRate <= 0 or effYield <= 0 then return 0 end
    local unitCost = effCost / effYield
    return math.floor(leftover * unitCost * salvageRate)
end

return ScaleSystem
