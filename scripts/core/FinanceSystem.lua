-- ============================================================================
-- FinanceSystem.lua - 债务/利息/借贷/还款逻辑
-- ============================================================================

local FinanceSystem = {}

--- 还款（优先还高息的民间借贷）
function FinanceSystem.repayDebt(gs, amount)
    if amount <= 0 then return 0 end

    local actualRepay = math.min(amount, gs.cash)
    if actualRepay <= 0 then return 0 end

    local remaining = actualRepay

    -- 先还民间借贷（利息高）
    if gs.sharkDebt > 0 and remaining > 0 then
        local pay = math.min(remaining, gs.sharkDebt)
        gs.sharkDebt = gs.sharkDebt - pay
        remaining = remaining - pay
    end

    -- 再还银行贷款
    if gs.bankDebt > 0 and remaining > 0 then
        local pay = math.min(remaining, gs.bankDebt)
        gs.bankDebt = gs.bankDebt - pay
        remaining = remaining - pay
    end

    local paid = actualRepay - remaining
    gs.cash = gs.cash - paid
    gs.totalRepaid = gs.totalRepaid + paid
    gs.totalDebt = gs.bankDebt + gs.sharkDebt

    return paid
end

--- 手动额外还款
function FinanceSystem.manualRepay(gs, amount)
    if gs.cash < amount then
        gs.addMessage("现金不足！", "danger")
        return 0
    end
    local paid = FinanceSystem.repayDebt(gs, amount)
    if paid > 0 then
        gs.addMessage(string.format("主动还款: %s", gs.formatMoney(paid)), "success")
    end
    return paid
end

--- 借新债（民间借贷，高利息但快速获取现金）
function FinanceSystem.borrowShark(gs, amount)
    gs.sharkDebt = gs.sharkDebt + amount
    gs.totalDebt = gs.bankDebt + gs.sharkDebt
    gs.cash = gs.cash + amount
    gs.addMessage(string.format("民间借贷: +%s (月息3%%)", gs.formatMoney(amount)), "warning")
end

--- 获取本月利息预估
function FinanceSystem.getInterestPreview(gs, config)
    local bankInterest = math.floor(gs.bankDebt * config.Finance.BANK_RATE)
    local sharkInterest = math.floor(gs.sharkDebt * config.Finance.LOAN_SHARK_RATE)
    return bankInterest, sharkInterest, bankInterest + sharkInterest
end

--- 获取还款进度百分比
function FinanceSystem.getRepayProgress(gs, config)
    local initial = config.Finance.INITIAL_BANK_DEBT + config.Finance.INITIAL_SHARK_DEBT
    return gs.totalRepaid / initial
end

return FinanceSystem
