-- ============================================================================
-- TimeSystem.lua - 时间推进与月末结算（含健康/体力联动/微信事件） 
-- ============================================================================

local FinanceSystem = require("core.FinanceSystem")
local StallSystem = require("core.StallSystem")
local ProgressionSystem = require("core.ProgressionSystem")
local HelperSystem = require("core.HelperSystem")

local TimeSystem = {}

--- 推进一天
function TimeSystem.advanceDay(gs, config)
    local P = config.Player
    local H = config.Health

    -- 1. 心情自然衰减
    gs.mood = math.max(0, gs.mood - P.MOOD_DECAY)

    -- 2. 心情好时自动恢复体力
    if gs.mood >= P.GOOD_MOOD_THRESHOLD then
        gs.energy = math.min(P.MAX_ENERGY, gs.energy + P.GOOD_MOOD_ENERGY_REGEN)
    end

    -- 3. 健康系统
    if H then
        TimeSystem.updateHealth(gs, config)
    end

    -- 4. 更新季节与天气
    TimeSystem.rollWeather(gs, config)

    -- 5. 微信事件触发
    TimeSystem.rollWechatEvent(gs, config)

    -- 6. 生病天数累加
    if gs.isSick then
        gs.sickDays = (gs.sickDays or 0) + 1
    end

    -- 7. 重置超市每日购买次数
    gs.supermarketPurchasesToday = 0

    -- 8. 地点冷却递减
    if gs.locationCooldowns then
        for locId, cd in pairs(gs.locationCooldowns) do
            if cd > 1 then
                gs.locationCooldowns[locId] = cd - 1
            else
                gs.locationCooldowns[locId] = nil
                -- 找地点名称
                local locName = locId
                for _, loc in ipairs(config.Locations or {}) do
                    if loc.id == locId then
                        locName = loc.emoji .. loc.name
                        break
                    end
                end
                gs.addMessage(string.format("📍 %s 的城管风头过了，可以回去摆摊了", locName), "info")
            end
        end
    end

    -- 9. 竞争对手倒计时
    if gs.activeCompetitor and gs.activeCompetitor.daysLeft > 0 then
        gs.activeCompetitor.daysLeft = gs.activeCompetitor.daysLeft - 1
        if gs.activeCompetitor.daysLeft <= 0 then
            local name = (gs.activeCompetitor.emoji or "") .. (gs.activeCompetitor.name or "同行")
            gs.activeCompetitor = nil
            gs.addMessage(string.format("📢 %s 离开了，客流恢复正常！", name), "info")
        end
    end

    -- 10. 伙计工资结算（每天扣除）
    HelperSystem.deductSalary(gs, config)
    -- 收摊后伙计自动停止值守
    if not gs.isStalling and gs.helperActive then
        gs.helperActive = false
    end

    -- 11. 推进日期
    gs.currentDay = gs.currentDay + 1

    if gs.currentDay > config.Game.DAYS_PER_MONTH then
        gs.currentDay = 1
        TimeSystem.endOfMonth(gs, config)
    end
end

--- 健康更新（每天调用）
function TimeSystem.updateHealth(gs, config)
    local H = config.Health
    local P = config.Player

    -- 自然衰减
    local decay = H.DAILY_DECAY

    -- 低体力额外衰减
    if gs.energy < (H.OVERWORK_THRESHOLD or 20) then
        decay = decay + H.LOW_ENERGY_DECAY
    end

    -- 恶劣天气额外衰减
    if gs.currentWeather == "rainy" or gs.currentWeather == "snowy" then
        decay = decay + H.BAD_WEATHER_DECAY
    end

    -- 心情好时健康自然恢复
    if gs.mood >= (P.GOOD_MOOD_THRESHOLD or 60) then
        decay = decay - (H.GOOD_MOOD_REGEN or 2)
    end

    gs.health = math.max(0, math.min(P.MAX_HEALTH, gs.health - decay))

    -- 生病判定
    if not gs.isSick and gs.health < (H.SICK_THRESHOLD or 30) then
        if math.random() < (H.SICK_CHANCE or 0.35) then
            gs.isSick = true
            gs.sickDays = 0
            gs.addMessage("身体扛不住了，生病了！赶紧去医院或药店吧", "danger")
            gs.addLog("身体不适，生病了", "danger")
        end
    end
end

--- 微信事件随机触发
function TimeSystem.rollWechatEvent(gs, config)
    local W = config.WechatEvents
    if not W then return end
    -- 已有待处理事件就不再触发
    if gs.pendingWechatEvent then return end

    if math.random() > (W.DAILY_TRIGGER_CHANCE or 0.12) then return end

    local events = W.EVENTS
    if not events or #events == 0 then return end

    -- 随机选一个事件
    local evt = events[math.random(1, #events)]

    -- 随机金额
    local amount = math.random(evt.amountRange[1], evt.amountRange[2])

    -- 存入待处理事件（main.lua 会弹窗）
    gs.pendingWechatEvent = {
        event = evt,
        amount = amount,
    }
end

--- 月末结算
function TimeSystem.endOfMonth(gs, config)
    local totalIncome = 0
    local totalExpense = 0

    -- 1. 利息累加
    local bankInterest = math.floor(gs.bankDebt * config.Finance.BANK_RATE)
    local sharkInterest = math.floor(gs.sharkDebt * config.Finance.LOAN_SHARK_RATE)
    gs.bankDebt = gs.bankDebt + bankInterest
    gs.sharkDebt = gs.sharkDebt + sharkInterest
    totalExpense = totalExpense + bankInterest + sharkInterest

    if bankInterest + sharkInterest > 0 then
        gs.addMessage(string.format("利息支出: %s (银行%s + 民间%s)",
            gs.formatMoney(bankInterest + sharkInterest),
            gs.formatMoney(bankInterest),
            gs.formatMoney(sharkInterest)), "warning")
    end

    -- 2. 固定生活支出
    local livingCost = config.Game.MONTHLY_LIVING_COST
    gs.cash = gs.cash - livingCost
    totalExpense = totalExpense + livingCost

    -- 3. 主业固定开支（tier 2+ 有月租/人工）
    local overhead = ProgressionSystem.getMonthlyOverhead(gs, config)
    if overhead > 0 then
        gs.cash = gs.cash - overhead
        totalExpense = totalExpense + overhead
        local tierDef = ProgressionSystem.getCurrentTier(gs, config)
        gs.addMessage(string.format("%s月度开支: -%s",
            tierDef.name, gs.formatMoney(overhead)), "info")
    end

    -- 4. 主业被动收入（tier 2+）
    local bizPassive = ProgressionSystem.getMonthlyPassiveIncome(gs, config)
    if bizPassive > 0 then
        gs.cash = gs.cash + bizPassive
        totalIncome = totalIncome + bizPassive
        local tierDef = ProgressionSystem.getCurrentTier(gs, config)
        gs.addMessage(string.format("%s被动收入: +%s",
            tierDef.name, gs.formatMoney(bizPassive)), "success")
    end

    -- 5. 粉丝广告收入
    if gs.followers > 0 then
        local adIncome = math.floor(gs.followers * 0.01)
        gs.cash = gs.cash + adIncome
        totalIncome = totalIncome + adIncome
        if adIncome > 0 then
            gs.addMessage(string.format("广告收入: +%s (%d粉丝)",
                gs.formatMoney(adIncome), gs.followers), "success")
        end
    end



    -- 9. 传单衰减
    StallSystem.monthlyDecay(gs, config)

    -- 10. 自动还款
    local repay = math.min(config.Finance.MIN_REPAY, gs.cash)
    if repay > 0 then
        FinanceSystem.repayDebt(gs, repay)
        totalExpense = totalExpense + repay
        gs.addMessage(string.format("自动还款: %s", gs.formatMoney(repay)), "info")
    end

    -- 11. 更新汇总
    gs.totalDebt = gs.bankDebt + gs.sharkDebt
    gs.monthIncome = totalIncome
    gs.monthExpense = totalExpense

    -- 12. 记录历史
    table.insert(gs.monthHistory, {
        month = gs.currentMonth,
        cash = gs.cash,
        debt = gs.totalDebt,
        income = totalIncome,
        expense = totalExpense,
    })

    -- 13. 推进月份
    gs.currentMonth = gs.currentMonth + 1
    gs.monthInYear = ((gs.currentMonth - 1) % 12) + 1
    gs.year = math.floor((gs.currentMonth - 1) / 12) + 1

    -- 14. 胜负判定
    local winFame = config.Game.WIN_FAME or 5000
    if (gs.fame or 0) >= winFame then
        gs.phase = "won"
        gs.addMessage("🎉 恭喜！你成为了美食网红！粉丝们都在追你！", "success")
    elseif gs.currentMonth > config.Game.TOTAL_MONTHS then
        gs.phase = "lost"
        gs.addMessage("时间到了，没能成为网红...继续努力吧！", "danger")
    elseif gs.cash < -50000 then
        gs.phase = "lost"
        gs.addMessage("资不抵债，破产了...", "danger")
    end

    gs.addMessage(string.format("=== 第%d年 %d月 结算完成 ===",
        gs.year, gs.monthInYear), "info")
end

--- 滚动天气
function TimeSystem.rollWeather(gs, config)
    local W = config.Weather
    if not W then return end

    -- 季节（按 monthInYear 1~12）
    local miy = gs.monthInYear or 1
    gs.currentSeason = W.SEASON_MAP[miy] or "spring"

    -- 按季节概率随机天气
    local probs = W.WEATHER_PROBS[gs.currentSeason]
    if not probs then gs.currentWeather = "sunny"; return end

    local roll = math.random()
    local acc = 0
    for wtype, prob in pairs(probs) do
        acc = acc + prob
        if roll <= acc then
            gs.currentWeather = wtype
            return
        end
    end
    gs.currentWeather = "sunny"
end

return TimeSystem
