-- ============================================================================
-- main.lua - 摆摊大亨游戏入口（重构版：摆摊成长经营）
-- ============================================================================

local UI = require("urhox-libs/UI")

-- 核心模块
local GameConfig = require("config.GameConfig")
local GameState = require("core.GameState")
local TimeSystem = require("core.TimeSystem")
local FinanceSystem = require("core.FinanceSystem")
local PlayerSystem = require("core.PlayerSystem")
local EventSystem = require("core.EventSystem")
local FameSystem = require("core.FameSystem")
local StallSystem = require("core.StallSystem")
local AudioManager = require("core.AudioManager")
local ProgressionSystem = require("core.ProgressionSystem")
local SaveSystem = require("core.SaveSystem")

-- UI 模块
local UIManager = require("ui.UIManager")
local SceneRenderer = require("scenes.SceneRenderer")
local GrillMiniGame = require("ui.GrillMiniGame")

-- 注册所有场景
local ShopScene = require("scenes.ShopScene")
local RestScene = require("scenes.RestScene")
local StallScene = require("scenes.StallScene")
local DapaidangScene = require("scenes.DapaidangScene")
local HotelScene = require("scenes.HotelScene")
local PharmacyScene = require("scenes.PharmacyScene")
local SupermarketScene = require("scenes.SupermarketScene")

SceneRenderer.register("shop", ShopScene)
SceneRenderer.register("rest", RestScene)
SceneRenderer.register("stall", StallScene)
SceneRenderer.register("dapaidang", DapaidangScene)
SceneRenderer.register("hotel", HotelScene)
SceneRenderer.register("pharmacy", PharmacyScene)
SceneRenderer.register("supermarket", SupermarketScene)

-- ============================================================================
-- 全局状态
-- ============================================================================
local gs = GameState
local config = GameConfig

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = config.Game.TITLE
    math.randomseed(os.time())

    -- 1. 初始化 UI 系统
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DESIGN_RESOLUTION(450, 800),
    })

    -- 2. 初始化游戏状态（优先加载存档）
    local loaded = SaveSystem.load(config)
    if loaded then
        gs.addMessage("存档已加载！继续你的创业之旅", "success")
        gs.addMessage(string.format("当前第%d年 %d月", gs.year, gs.monthInYear), "info")
    else
        gs.init(config)
        gs.addMessage("欢迎来到摆摊大亨！从小摊做起，成就商业帝国！", "info")
        gs.addMessage("从摆摊开始，一步步做大做强吧！", "info")
    end

    -- 3. 构建 UI
    UIManager.build(gs, config, SceneRenderer, {
        onAction = HandleAction,
    })

    -- 4. 初始化音频
    AudioManager.init()

    -- 5. 播放主题 BGM
    AudioManager.playBGM("audio/music_1776264521002.ogg", 0.4)

    -- 6. 订阅事件
    SubscribeToEvent("Update", "HandleUpdate")

    print("=== 摆摊大亨 游戏启动 ===")
end

function Stop()
    AudioManager.shutdown()
    UI.Shutdown()
end

-- ============================================================================
-- 核心游戏循环
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    gs.animTime = (gs.animTime or 0) + dt

    if gs.isStalling then
        local changed = StallSystem.updateRealtime(gs, config, dt)
        if changed then
            UIManager.refresh(gs, config, { onAction = HandleAction })
        end
    end

    -- 更新制作进度条动画
    UpdatePrepProgress()
end

-- ============================================================================
-- 破产检查与警告
-- ============================================================================

--- 破产检查与警告?????????
--- @return boolean true=游戏结束?false=继续
function CheckAndWarnFinancial()
    local status = gs.checkFinancialHealth(config)
    if status == "ok" then
        gs.lastFinancialWarningLevel = 0
        return false
    end

    if status == "gameover" then
        gs.phase = "lost"
        gs.addMessage("资不抵债，彻底破产了...", "danger")
        gs.addLog("资产为负，宣告破产", "danger")
        ShowBankruptcyScreen()
        return true
    end

    -- 警告/严重警告（只在等级升高时弹一次）
    local level = (status == "severe") and 2 or 1
    if level > gs.lastFinancialWarningLevel then
        gs.lastFinancialWarningLevel = level
        ShowFinancialWarningPopup(status)
    end
    return false
end

--- 破产游戏结束画面
function ShowBankruptcyScreen()
    local root = UIManager.getRoot()
    if not root then return end

    local old = root:FindById("bankruptcyOverlay")
    if old then old:Remove() end

    local overlay = UI.Panel {
        id = "bankruptcyOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 200 },
        children = {
            UI.Panel {
                width = "85%", maxWidth = 360,
                padding = 24, gap = 12,
                backgroundColor = { 60, 20, 20, 250 },
                borderRadius = 16, borderWidth = 2,
                borderColor = { 255, 60, 60, 220 },
                alignItems = "center",
                children = {
                    UI.Label { text = "💀", fontSize = 48 },
                    UI.Label {
                        text = "破产了！",
                        fontSize = 22,
                        fontColor = { 255, 80, 80, 255 },
                    },
                    UI.Label {
                        text = string.format(
                            "你的现金已降至 $%s\n资不抵债，无法继续经营...\n\n不要灰心，重新来过吧！",
                            gs.formatMoney(gs.cash)),
                        fontSize = 12,
                        fontColor = { 200, 180, 180, 255 },
                        textAlign = "center",
                    },
                    UI.Button {
                        text = "重新开始",
                        variant = "danger",
                        width = "80%", height = 44,
                        marginTop = 8, fontSize = 14,
                        onClick = function(self)
                            RestartGame()
                        end,
                    },
                },
            },
        },
    }
    root:AddChild(overlay)
end

--- 财务警告弹窗
function ShowFinancialWarningPopup(level)
    local root = UIManager.getRoot()
    if not root then return end

    local old = root:FindById("financialWarningOverlay")
    if old then old:Remove() end

    local isSevere = (level == "severe")
    local title = isSevere and "严重警告！" or "财务警告"
    local emoji = isSevere and "🚨" or "⚠️"
    local msg = isSevere
        and string.format("你的现金已降至 $%s\n再这样下去就要破产了！\n赶紧想办法赚钱，减少开支！", gs.formatMoney(gs.cash))
        or string.format("你的现金已降至 $%s\n注意控制开支，别入不敷出！", gs.formatMoney(gs.cash))
    local borderColor = isSevere and { 255, 50, 50, 220 } or { 255, 180, 50, 220 }
    local bgColor = isSevere and { 60, 25, 25, 250 } or { 60, 50, 25, 250 }
    local titleColor = isSevere and { 255, 80, 80, 255 } or { 255, 200, 60, 255 }

    local overlay = UI.Panel {
        id = "financialWarningOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 160 },
        children = {
            UI.Panel {
                width = "82%", maxWidth = 340,
                padding = 20, gap = 10,
                backgroundColor = bgColor,
                borderRadius = 12, borderWidth = 2,
                borderColor = borderColor,
                alignItems = "center",
                children = {
                    UI.Label { text = emoji, fontSize = 36 },
                    UI.Label {
                        text = title,
                        fontSize = 18,
                        fontColor = titleColor,
                    },
                    UI.Label {
                        text = msg,
                        fontSize = 11,
                        fontColor = { 220, 210, 200, 255 },
                        textAlign = "center",
                    },
                    UI.Button {
                        text = "我知道了",
                        variant = isSevere and "danger" or "warning",
                        width = "70%", height = 36,
                        marginTop = 6, fontSize = 12,
                        onClick = function(self)
                            local o = root:FindById("financialWarningOverlay")
                            if o then o:Remove() end
                        end,
                    },
                },
            },
        },
    }
    root:AddChild(overlay)
end

-- ============================================================================
-- 产品制作进度条动画
-- ============================================================================

--- 制作进度条弹窗状态
local prepProgress = {
    active = false,
    startTime = 0,
    duration = 2.5,       -- 2.5秒完成
    onComplete = nil,
    stages = {
        { at = 0.00, text = "🔪 准备食材...",  color = { 255, 200, 80, 255 } },
        { at = 0.25, text = "🍳 开始制作...",  color = { 255, 160, 60, 255 } },
        { at = 0.55, text = "🔥 烹饪中...",    color = { 255, 120, 40, 255 } },
        { at = 0.80, text = "✅ 即将完成！",   color = { 100, 220, 100, 255 } },
    },
}

function ShowPrepProgressPopup(onComplete)
    local root = UIManager.getRoot()
    if not root then
        if onComplete then onComplete() end
        return
    end

    -- 移除旧弹窗
    local old = root:FindById("prepProgressOverlay")
    if old then old:Remove() end

    -- 获取当前选择的商品信息
    local items = ProgressionSystem.getCurrentItems(gs, config)
    local selectedIdx = gs.selectedStallItem or 1
    local item = items[selectedIdx] or items[1]

    -- 初始化进度状态
    prepProgress.active = true
    prepProgress.startTime = gs.animTime or 0
    prepProgress.onComplete = onComplete

    -- 构建弹窗（进度条使用 Label 模拟，通过 Update 事件更新）
    local overlay = UI.Panel {
        id = "prepProgressOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 180 },
        children = {
            UI.Panel {
                width = "80%", maxWidth = 340,
                padding = 20, gap = 10,
                backgroundColor = { 35, 40, 60, 252 },
                borderRadius = 14, borderWidth = 2,
                borderColor = { 255, 180, 50, 200 },
                alignItems = "center",
                children = {
                    -- 商品名称
                    UI.Label {
                        text = string.format("%s 正在制作 %s", item.emoji, item.name),
                        fontSize = 14, fontColor = { 255, 240, 200, 255 },
                    },
                    -- 产量信息
                    UI.Label {
                        text = string.format("进货 $%d → 制作 %d 份", item.batchCost, item.yield),
                        fontSize = 10, fontColor = { 180, 180, 200, 200 },
                    },
                    -- 进度条背景
                    UI.Panel {
                        width = "100%", height = 20, marginTop = 4,
                        backgroundColor = { 20, 25, 40, 255 },
                        borderRadius = 10, overflow = "hidden",
                        children = {
                            -- 进度条填充（初始为0%）
                            UI.Panel {
                                id = "prepProgressFill",
                                width = "0%", height = "100%",
                                backgroundColor = { 255, 180, 50, 255 },
                                borderRadius = 10,
                            },
                        },
                    },
                    -- 阶段文字
                    UI.Label {
                        id = "prepStageLabel",
                        text = prepProgress.stages[1].text,
                        fontSize = 11, fontColor = prepProgress.stages[1].color,
                    },
                    -- 百分比
                    UI.Label {
                        id = "prepPctLabel",
                        text = "0%",
                        fontSize = 10, fontColor = { 160, 160, 180, 255 },
                    },
                },
            },
        },
    }

    root:AddChild(overlay)
end

--- 更新进度条（在 HandleUpdate 中调用）
function UpdatePrepProgress()
    if not prepProgress.active then return end

    local elapsed = (gs.animTime or 0) - prepProgress.startTime
    local pct = math.min(1.0, elapsed / prepProgress.duration)

    -- 更新进度条 UI
    local root = UIManager.getRoot()
    if not root then return end

    local fill = root:FindById("prepProgressFill")
    local stageLabel = root:FindById("prepStageLabel")
    local pctLabel = root:FindById("prepPctLabel")

    if fill then
        fill:SetStyle({ width = string.format("%.0f%%", pct * 100) })
    end
    if pctLabel then
        pctLabel:SetText(string.format("%.0f%%", pct * 100))
    end

    -- 更新阶段文字
    if stageLabel then
        local currentStage = prepProgress.stages[1]
        for _, stage in ipairs(prepProgress.stages) do
            if pct >= stage.at then
                currentStage = stage
            end
        end
        stageLabel:SetText(currentStage.text)
        -- 进度条颜色跟随阶段变化
        if fill then
            fill:SetStyle({ backgroundColor = currentStage.color })
        end
    end

    -- 完成
    if pct >= 1.0 then
        prepProgress.active = false

        -- 移除弹窗
        local overlay = root:FindById("prepProgressOverlay")
        if overlay then overlay:Remove() end

        -- 执行回调
        if prepProgress.onComplete then
            prepProgress.onComplete()
            prepProgress.onComplete = nil
        end
    end
end

-- ============================================================================
-- 行动处理（回合制核心）
-- ============================================================================

function HandleAction(actionType, data)
    -- 游戏结束不能操作
    if gs.phase ~= "playing" then
        ShowEndScreen()
        return
    end

    local success = false
    data = data or {}

    -- === 摆摊状态机（不消耗回合的操作，优先处理） ===
    if actionType == "select_stall_item" then
        StallSystem.selectItem(gs, data.index, config)
        UIManager.refresh(gs, config, { onAction = HandleAction })
        return
    elseif actionType == "distribute_flyers" then
        local ok = StallSystem.distributeFlyers(gs, config)
        if ok then
            AudioManager.playSFX("audio/sfx/sfx_flyer_distribute.ogg", 0.6)
        end
        UIManager.refresh(gs, config, { onAction = HandleAction })
        return
    elseif actionType == "open_stall" then
        -- 显示制作进度条动画，完成后再执行开摊
        ShowPrepProgressPopup(function()
            local ok = StallSystem.openStall(gs, config)
            if ok then
                AudioManager.playSFX("audio/sfx/sfx_cash_register.ogg", 0.5)
                UpdateBGM()
                -- 开摊扣了进货成本，检查破产
                if CheckAndWarnFinancial() then
                    UIManager.refresh(gs, config, { onAction = HandleAction })
                    return
                end
            end
            UIManager.refresh(gs, config, { onAction = HandleAction })
        end)
        return
    elseif actionType == "close_stall" then
        StallSystem.closeStall(gs, config)
        -- 收摊结束这一天，推进时间
        EventSystem.rollEvent(gs, config)
        StallSystem.tickPromotion(gs, config)
        TimeSystem.advanceDay(gs, config)
        SaveSystem.save()
        UpdateBGM()
        if gs.phase ~= "playing" then
            ShowEndScreen()
        end
        UIManager.refresh(gs, config, { onAction = HandleAction })
        -- 检查微信事件弹窗
        if gs.pendingWechatEvent and gs.phase == "playing" then
            ShowWechatEventPopup(gs.pendingWechatEvent)
        end
        return
    elseif actionType == "toggle_livestream" then
        StallSystem.toggleLiveStream(gs, config)
        UIManager.refresh(gs, config, { onAction = HandleAction })
        return
    elseif actionType == "upgrade_tier" then
        success = ProgressionSystem.upgrade(gs, config)
        if success then
            AudioManager.playSFX("audio/sfx/sfx_cash_register.ogg", 0.8)
            UpdateBGM()
        end
        UIManager.refresh(gs, config, { onAction = HandleAction })
        return
    elseif actionType == "edit_banner" then
        ShowBannerEditPopup()
        return
    elseif actionType == "select_location" then
        StallSystem.selectLocation(gs, data.index, config)
        SaveSystem.save()
        UIManager.refresh(gs, config, { onAction = HandleAction })
        return
    elseif actionType == "activate_promotion" then
        local ok = StallSystem.activatePromotion(gs, data.promoId, config)
        if ok then
            AudioManager.playSFX("audio/sfx/sfx_cash_register.ogg", 0.5)
            SaveSystem.save()
        end
        UIManager.refresh(gs, config, { onAction = HandleAction })
        return
    end

    -- === 摆摊中拦截：除了叫卖，其他消耗回合的行动都不允许 ===
    if gs.isStalling and actionType ~= "hawk_sell" then
        gs.addMessage("正在营业中！先收摊才能做其他事", "warning")
        UIManager.refresh(gs, config, { onAction = HandleAction })
        return
    end

    -- === 消耗回合的行动分发 ===
    if actionType == "hawk_sell" then
        -- 弹出烤串小游戏，完成后执行叫卖
        local root = UIManager.getRoot()
        if root then
            GrillMiniGame.show(root, function(multiplier, resultText)
                -- 获取当前商品名（用于对话系统）
                local items = ProgressionSystem.getCurrentItems(gs, config)
                local curItem = items[gs.stallItemIndex] or items[1]
                local itemName = curItem and curItem.name or "小吃"

                -- 小游戏完成回调：执行实际叫卖
                local ok = StallSystem.hawkSell(gs, config, multiplier)
                if ok then
                    AudioManager.playSFX("audio/sfx/sfx_cash_register.ogg", 0.7)
                end
                -- 触发事件（摆摊期间不推进天数，收摊/休息才推进）
                EventSystem.rollEvent(gs, config)
                StallSystem.tickPromotion(gs, config)
                SaveSystem.save()
                UpdateBGM()
                if gs.phase ~= "playing" then
                    ShowEndScreen()
                end
                UIManager.refresh(gs, config, { onAction = HandleAction })

                -- 检查城管对话弹窗（优先于顾客对话）
                if gs.pendingChengguan and gs.phase == "playing" then
                    ShowChengguanDialogue()
                -- 检查顾客对话弹窗（叫卖成功且仍在营业中时）
                elseif ok and gs.phase == "playing" and gs.isStalling then
                    local dialogue = StallSystem.rollCustomerDialogue(gs, config, itemName)
                    if dialogue then
                        ShowCustomerDialogue(dialogue)
                    end
                end

                -- 检查微信事件弹窗
                if gs.pendingWechatEvent and gs.phase == "playing" then
                    ShowWechatEventPopup(gs.pendingWechatEvent)
                end
            end)
        end
        return  -- 异步处理，提前返回
    elseif actionType == "rest" then
        success = PlayerSystem.rest(gs, config)
        if success then gs.currentScene = "rest" end
    elseif actionType == "relax" then
        success = PlayerSystem.relax(gs, config)
    elseif actionType == "feast" then
        success = PlayerSystem.feast(gs, config)
    elseif actionType == "go_hospital" then
        success = PlayerSystem.goHospital(gs, config)
    elseif actionType == "go_pharmacy" then
        success = PlayerSystem.goPharmacy(gs, config)
    elseif actionType == "go_supermarket" then
        -- 超市特殊流程：进入场景后弹出购物弹窗，不直接推进时间
        local ok = PlayerSystem.goSupermarket(gs, config)
        if ok then
            UIManager.refresh(gs, config, { onAction = HandleAction })
            ShowSupermarketPopup()
        end
        return
    elseif actionType == "buy_supermarket_item" then
        -- 在超市购买商品（不推进时间，购买完关闭弹窗时才推进）
        local bought = PlayerSystem.buyFromSupermarket(gs, config, data.itemId)
        if bought then
            AudioManager.playSFX("audio/sfx/sfx_cash_register.ogg", 0.5)
            -- 即时破产检查
            if gs.phase == "playing" and CheckAndWarnFinancial() then
                UIManager.refresh(gs, config, { onAction = HandleAction })
                return
            end
        end
        -- 刷新弹窗（重新打开以更新购买次数和状态）
        UIManager.refresh(gs, config, { onAction = HandleAction })
        ShowSupermarketPopup()
        return
    elseif actionType == "leave_supermarket" then
        -- 离开超市：推进时间
        EventSystem.rollEvent(gs, config)
        StallSystem.tickPromotion(gs, config)
        TimeSystem.advanceDay(gs, config)
        SaveSystem.save()
        UpdateBGM()
        if gs.phase ~= "playing" then
            ShowEndScreen()
        end
        if gs.phase == "playing" and CheckAndWarnFinancial() then
            UIManager.refresh(gs, config, { onAction = HandleAction })
            return
        end
        UIManager.refresh(gs, config, { onAction = HandleAction })
        if gs.pendingWechatEvent and gs.phase == "playing" then
            ShowWechatEventPopup(gs.pendingWechatEvent)
        end
        return
    elseif actionType == "repay" then
        success = PlayerSystem.repay(gs, data.amount, config)
    elseif actionType == "borrow" then
        success = PlayerSystem.borrow(gs, data.amount, config)
    end

    if success then
        -- 触发随机事件
        EventSystem.rollEvent(gs, config)

        -- 促销天数扣减
        StallSystem.tickPromotion(gs, config)

        -- 推进时间
        TimeSystem.advanceDay(gs, config)

        -- 自动存档
        SaveSystem.save()

        -- BGM 切换
        UpdateBGM()

        -- 检查游戏结束
        if gs.phase ~= "playing" then
            ShowEndScreen()
        end

        -- 即时破产检查（每次扣款后）
        if gs.phase == "playing" then
            if CheckAndWarnFinancial() then
                UIManager.refresh(gs, config, { onAction = HandleAction })
                return
            end
        end
    end

    -- 刷新 UI
    UIManager.refresh(gs, config, { onAction = HandleAction })

    -- 检查微信事件弹窗（在 UI 刷新后弹出）
    if gs.pendingWechatEvent and gs.phase == "playing" then
        ShowWechatEventPopup(gs.pendingWechatEvent)
    end
end

-- ============================================================================
-- BGM 根据场景/等级切换
-- ============================================================================
function UpdateBGM()
    local tier = gs.mainBizTier or 1
    if gs.currentScene == "stall" or gs.currentScene == "dapaidang" then
        AudioManager.playBGM("audio/music_1776264616935.ogg", 0.35)
    else
        AudioManager.playBGM("audio/music_1776264521002.ogg", 0.4)
    end
end

-- ============================================================================
-- 横幅广告语编辑弹窗
-- ============================================================================

function ShowBannerEditPopup()
    local root = UIManager.getRoot()
    if not root then return end

    -- 移除旧弹窗
    local old = root:FindById("bannerEditOverlay")
    if old then old:Remove() end

    -- 预设广告语选项
    local presets = {
        "好吃不贵，走过路过别错过！",
        "新鲜现做，美味飘香！",
        "限时特惠，买到就是赚到！",
        "老顾客都说好，你也来尝尝！",
        "独家秘方，吃了还想吃！",
        "良心品质，童叟无欺！",
    }

    -- 构建预设按钮
    local presetBtns = {}
    for _, preset in ipairs(presets) do
        presetBtns[#presetBtns + 1] = UI.Button {
            text = preset,
            width = "100%",
            height = 30,
            fontSize = 10,
            variant = (gs.bannerText == preset) and "primary" or "ghost",
            onClick = function(self)
                gs.bannerText = preset
                gs.addMessage(string.format("横幅已更换：%s", preset), "success")
                SaveSystem.save()
                -- 关闭弹窗并刷新
                local overlay = root:FindById("bannerEditOverlay")
                if overlay then overlay:Remove() end
                UIManager.refresh(gs, config, { onAction = HandleAction })
            end,
        }
    end

    -- 添加自定义输入
    local inputField = UI.TextField {
        value = gs.bannerText or "",
        placeholder = "输入你的广告语...",
        width = "100%",
        height = 36,
        fontSize = 11,
        maxLength = 20,
    }

    local overlay = UI.Panel {
        id = "bannerEditOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 150 },
        children = {
            UI.Panel {
                width = "88%",
                maxWidth = 380,
                padding = 0,
                backgroundColor = { 45, 30, 25, 250 },
                borderRadius = 12,
                borderWidth = 1,
                borderColor = { 200, 60, 40, 180 },
                flexDirection = "column",
                children = {
                    -- 标题栏
                    UI.Panel {
                        width = "100%", padding = 10,
                        backgroundColor = { 180, 40, 30, 255 },
                        borderTopLeftRadius = 12, borderTopRightRadius = 12,
                        flexDirection = "row", alignItems = "center", gap = 6,
                        children = {
                            UI.Label { text = "🏮 编辑横幅广告语", fontSize = 13, fontColor = { 255, 240, 100, 255 } },
                        },
                    },
                    -- 自定义输入区
                    UI.Panel {
                        width = "100%", padding = 10, flexDirection = "column", gap = 6,
                        children = {
                            UI.Label { text = "自定义广告语（最多20字）：", fontSize = 10, fontColor = { 200, 200, 200, 255 } },
                            inputField,
                            UI.Button {
                                text = "确认使用",
                                width = "100%", height = 32, fontSize = 11, variant = "primary",
                                onClick = function(self)
                                    local newText = inputField:GetValue()
                                    if newText and newText ~= "" then
                                        gs.bannerText = newText
                                        gs.addMessage(string.format("横幅已更换：%s", newText), "success")
                                    end
                                    SaveSystem.save()
                                    local o = root:FindById("bannerEditOverlay")
                                    if o then o:Remove() end
                                    UIManager.refresh(gs, config, { onAction = HandleAction })
                                end,
                            },
                        },
                    },
                    -- 分隔线
                    UI.Panel {
                        width = "100%", height = 1,
                        backgroundColor = { 100, 60, 50, 150 },
                    },
                    -- 预设选择区
                    UI.Panel {
                        width = "100%", padding = 10, flexDirection = "column", gap = 4,
                        children = {
                            UI.Label { text = "或选择预设广告语：", fontSize = 10, fontColor = { 200, 200, 200, 255 } },
                            table.unpack(presetBtns),
                        },
                    },
                    -- 关闭按钮
                    UI.Panel {
                        width = "100%", padding = 8, alignItems = "center",
                        children = {
                            UI.Button {
                                text = "取消", width = "60%", height = 32,
                                fontSize = 11, variant = "ghost",
                                onClick = function(self)
                                    local o = root:FindById("bannerEditOverlay")
                                    if o then o:Remove() end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    root:AddChild(overlay)
end

-- ============================================================================
-- 城管对话弹窗（摆摊事件触发城管后弹出）
-- ============================================================================

function ShowChengguanDialogue()
    local root = UIManager.getRoot()
    if not root then return end

    -- 移除旧弹窗
    local old = root:FindById("chengguanOverlay")
    if old then old:Remove() end

    local CG = config.Chengguan
    -- 随机选一句开场白
    local opening = CG.OPENING_LINES[math.random(1, #CG.OPENING_LINES)]

    -- 构建选项按钮
    local choiceBtns = {}
    for i, choice in ipairs(CG.CHOICES) do
        local variant = "ghost"
        if choice.id == "sweet_talk" then variant = "primary"
        elseif choice.id == "beg" then variant = "warning"
        elseif choice.id == "run" then variant = "warning"
        elseif choice.id == "argue" then variant = "danger"
        end
        choiceBtns[#choiceBtns + 1] = UI.Button {
            text = choice.text,
            width = "100%",
            height = 38,
            fontSize = 11,
            variant = variant,
            onClick = function(self)
                HandleChengguanReply(choice)
            end,
        }
    end

    local overlay = UI.Panel {
        id = "chengguanOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 170 },
        children = {
            UI.Panel {
                width = "90%",
                maxWidth = 400,
                padding = 0,
                backgroundColor = { 40, 45, 55, 252 },
                borderRadius = 12,
                borderWidth = 2,
                borderColor = { 220, 60, 60, 200 },
                flexDirection = "column",
                children = {
                    -- 标题栏（红色警告风格）
                    UI.Panel {
                        width = "100%", padding = 10,
                        backgroundColor = { 180, 40, 40, 255 },
                        borderTopLeftRadius = 12, borderTopRightRadius = 12,
                        flexDirection = "row", alignItems = "center", gap = 6,
                        children = {
                            UI.Label { text = "🚨 城管来了！", fontSize = 14, fontColor = { 255, 255, 255, 255 } },
                        },
                    },
                    -- 城管台词
                    UI.Panel {
                        width = "100%", padding = 12, flexDirection = "column", gap = 8,
                        children = {
                            UI.Panel {
                                flexDirection = "row", alignItems = "flex-start", gap = 8,
                                children = {
                                    UI.Label { text = "👮", fontSize = 36 },
                                    UI.Panel {
                                        flexShrink = 1,
                                        padding = 10,
                                        backgroundColor = { 60, 65, 80, 255 },
                                        borderRadius = 8,
                                        children = {
                                            UI.Label {
                                                text = opening,
                                                fontSize = 12,
                                                fontColor = { 240, 240, 240, 255 },
                                                flexShrink = 1,
                                            },
                                        },
                                    },
                                },
                            },
                            UI.Label {
                                text = "你打算怎么办？",
                                fontSize = 10,
                                fontColor = { 180, 180, 180, 255 },
                            },
                        },
                    },
                    -- 选项按钮区域
                    UI.Panel {
                        width = "100%", padding = 10, paddingTop = 0,
                        flexDirection = "column", gap = 6,
                        children = choiceBtns,
                    },
                },
            },
        },
    }

    root:AddChild(overlay)
end

--- 处理城管对话回复
function HandleChengguanReply(choice)
    -- 调用 StallSystem 处理实际效果
    local resultMsg = StallSystem.applyChengguanChoice(gs, config, choice)

    -- 显示结果消息
    local msgType = "info"
    if choice.id == "argue" then
        msgType = "danger"
    elseif choice.id == "run" then
        msgType = "warning"
    elseif choice.id == "sweet_talk" or choice.id == "beg" then
        -- 根据结果判断（如果有冷却或罚款，说明失败了）
        if resultMsg and (resultMsg:find("罚款") or resultMsg:find("没收")) then
            msgType = "danger"
        else
            msgType = "success"
        end
    end
    gs.addMessage(string.format("👮 城管：%s", resultMsg), msgType)

    -- 移除弹窗
    local root = UIManager.getRoot()
    if root then
        local overlay = root:FindById("chengguanOverlay")
        if overlay then overlay:Remove() end
    end

    -- 自动存档 + 刷新 UI
    SaveSystem.save()
    UIManager.refresh(gs, config, { onAction = HandleAction })
end

-- ============================================================================
-- 顾客对话弹窗（叫卖后随机触发）
-- ============================================================================

function ShowCustomerDialogue(dialogue)
    local root = UIManager.getRoot()
    if not root then return end

    -- 移除旧弹窗
    local old = root:FindById("dialogueOverlay")
    if old then old:Remove() end

    -- 构建回复按钮
    local replyBtns = {}
    for i, reply in ipairs(dialogue.replies) do
        local variant = "ghost"
        if reply.tag == "good" then
            variant = "primary"
        elseif reply.tag == "bad" then
            variant = "danger"
        end
        replyBtns[#replyBtns + 1] = UI.Button {
            text = reply.text,
            width = "100%",
            height = 36,
            fontSize = 11,
            variant = variant,
            onClick = function(self)
                HandleDialogueReply(dialogue, reply)
            end,
        }
    end

    local overlay = UI.Panel {
        id = "dialogueOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 150 },
        children = {
            UI.Panel {
                width = "88%",
                maxWidth = 380,
                padding = 0,
                backgroundColor = { 255, 250, 240, 250 },
                borderRadius = 12,
                flexDirection = "column",
                children = {
                    -- 标题栏
                    UI.Panel {
                        width = "100%", padding = 10,
                        backgroundColor = { 255, 160, 50, 255 },
                        borderTopLeftRadius = 12, borderTopRightRadius = 12,
                        flexDirection = "row", alignItems = "center", gap = 6,
                        children = {
                            UI.Label { text = "💬 顾客搭话", fontSize = 13, fontColor = { 255, 255, 255, 255 } },
                        },
                    },
                    -- 顾客台词
                    UI.Panel {
                        width = "100%", padding = 12, flexDirection = "column", gap = 8,
                        children = {
                            -- 顾客头像和对话
                            UI.Panel {
                                flexDirection = "row", alignItems = "flex-start", gap = 8,
                                children = {
                                    UI.Label { text = dialogue.avatar or "🧑", fontSize = 32 },
                                    UI.Panel {
                                        flexShrink = 1,
                                        padding = 10,
                                        backgroundColor = { 255, 255, 255, 255 },
                                        borderRadius = 8,
                                        children = {
                                            UI.Label {
                                                text = dialogue.text,
                                                fontSize = 12,
                                                fontColor = { 40, 40, 40, 255 },
                                                flexShrink = 1,
                                            },
                                        },
                                    },
                                },
                            },
                            -- 提示
                            UI.Label {
                                text = "选择你的回复：",
                                fontSize = 10,
                                fontColor = { 120, 120, 120, 255 },
                            },
                        },
                    },
                    -- 回复按钮区域
                    UI.Panel {
                        width = "100%", padding = 10, paddingTop = 0,
                        flexDirection = "column", gap = 6,
                        children = replyBtns,
                    },
                },
            },
        },
    }

    root:AddChild(overlay)
end

--- 处理顾客对话回复
function HandleDialogueReply(dialogue, reply)
    -- 应用效果
    StallSystem.applyDialogueReply(gs, config, reply)

    -- 生成反馈消息
    local parts = {}
    if reply.trustGain and reply.trustGain ~= 0 then
        local sign = reply.trustGain > 0 and "+" or ""
        parts[#parts + 1] = string.format("口碑%s%d", sign, reply.trustGain)
    end
    if reply.fameGain and reply.fameGain ~= 0 then
        local sign = reply.fameGain > 0 and "+" or ""
        parts[#parts + 1] = string.format("名气%s%d", sign, reply.fameGain)
    end
    if reply.moodChange and reply.moodChange ~= 0 then
        local sign = reply.moodChange > 0 and "+" or ""
        parts[#parts + 1] = string.format("心情%s%d", sign, reply.moodChange)
    end

    local effectStr = #parts > 0 and (" | " .. table.concat(parts, "  ")) or ""
    local msgType = (reply.tag == "bad") and "warning" or "success"
    gs.addMessage(string.format("%s 顾客：%s%s", dialogue.avatar, reply.text, effectStr), msgType)

    -- 移除弹窗
    local root = UIManager.getRoot()
    if root then
        local overlay = root:FindById("dialogueOverlay")
        if overlay then overlay:Remove() end
    end

    -- 自动存档 + 刷新 UI
    SaveSystem.save()
    UIManager.refresh(gs, config, { onAction = HandleAction })
end

-- ============================================================================
-- 超市购物弹窗
-- ============================================================================

function ShowSupermarketPopup()
    local root = UIManager.getRoot()
    if not root then return end

    -- 移除旧弹窗
    local old = root:FindById("supermarketOverlay")
    if old then old:Remove() end

    local S = config.Supermarket
    local P = config.Player
    local remainBuys = S.MAX_PURCHASES_PER_DAY - (gs.supermarketPurchasesToday or 0)

    -- 每日随机展示商品（确定性轮换）
    local seed = gs.currentMonth * 100 + gs.currentDay
    math.randomseed(seed)

    -- Fisher-Yates 洗牌取前 DAILY_DISPLAY_COUNT 个
    local indices = {}
    for i = 1, #S.ITEMS do indices[i] = i end
    for i = #indices, 2, -1 do
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    local displayCount = math.min(S.DAILY_DISPLAY_COUNT, #S.ITEMS)
    local todayItems = {}
    for i = 1, displayCount do
        todayItems[#todayItems + 1] = S.ITEMS[indices[i]]
    end

    -- 恢复随机种子
    math.randomseed(os.time())

    -- 构建商品列表
    local itemWidgets = {}
    for _, item in ipairs(todayItems) do
        local canBuy = gs.cash >= item.price and remainBuys > 0
        -- 效果描述
        local effParts = {}
        local eff = item.effects
        if eff.energy and eff.energy ~= 0 then
            local sign = eff.energy > 0 and "+" or ""
            effParts[#effParts + 1] = string.format("体力%s%d", sign, eff.energy)
        end
        if eff.mood and eff.mood ~= 0 then
            local sign = eff.mood > 0 and "+" or ""
            effParts[#effParts + 1] = string.format("心情%s%d", sign, eff.mood)
        end
        if eff.health and eff.health ~= 0 then
            local sign = eff.health > 0 and "+" or ""
            effParts[#effParts + 1] = string.format("健康%s%d", sign, eff.health)
        end
        local effStr = table.concat(effParts, " ")

        itemWidgets[#itemWidgets + 1] = UI.Panel {
            width = "100%", flexDirection = "row", alignItems = "center",
            padding = 6, backgroundColor = { 40, 50, 65, 200 }, borderRadius = 6,
            children = {
                UI.Label { text = item.emoji, fontSize = 24, width = 32 },
                UI.Panel {
                    flex = 1, flexDirection = "column", gap = 1, marginLeft = 4,
                    children = {
                        UI.Label {
                            text = string.format("%s  $%d", item.name, item.price),
                            fontSize = 11, fontColor = { 255, 255, 255, 255 },
                        },
                        UI.Label {
                            text = effStr,
                            fontSize = 9, fontColor = { 180, 220, 180, 255 },
                        },
                    },
                },
                UI.Button {
                    text = canBuy and "购买" or (remainBuys <= 0 and "已满" or "没钱"),
                    fontSize = 10, height = 28, width = 52,
                    variant = canBuy and "primary" or "ghost",
                    disabled = not canBuy,
                    onClick = function(self)
                        if HandleAction then
                            HandleAction("buy_supermarket_item", { itemId = item.id })
                        end
                    end,
                },
            },
        }
    end

    local overlay = UI.Panel {
        id = "supermarketOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 160 },
        children = {
            UI.Panel {
                width = "90%",
                maxWidth = 400,
                maxHeight = "85%",
                padding = 0,
                backgroundColor = { 30, 38, 55, 252 },
                borderRadius = 12,
                borderWidth = 2,
                borderColor = { 60, 140, 255, 180 },
                flexDirection = "column",
                children = {
                    -- 标题栏
                    UI.Panel {
                        width = "100%", padding = 10,
                        backgroundColor = { 40, 120, 220, 255 },
                        borderTopLeftRadius = 12, borderTopRightRadius = 12,
                        flexDirection = "row", alignItems = "center",
                        justifyContent = "space-between",
                        children = {
                            UI.Label { text = "🛒 便利超市", fontSize = 14, fontColor = { 255, 255, 255, 255 } },
                            UI.Label {
                                text = string.format("今日可购: %d/%d", remainBuys, S.MAX_PURCHASES_PER_DAY),
                                fontSize = 10,
                                fontColor = remainBuys > 0 and { 200, 255, 200, 255 } or { 255, 150, 150, 255 },
                            },
                        },
                    },
                    -- 提示
                    UI.Panel {
                        width = "100%", paddingLeft = 10, paddingRight = 10, paddingTop = 6, paddingBottom = 4,
                        children = {
                            UI.Label {
                                text = string.format("💰 现金: $%s  |  每天商品随机更换", gs.formatMoney(gs.cash)),
                                fontSize = 9, fontColor = { 160, 180, 200, 255 },
                            },
                        },
                    },
                    -- 商品列表
                    UI.ScrollView {
                        width = "100%", flex = 1,
                        padding = 8, scrollY = true,
                        children = {
                            UI.Panel {
                                width = "100%", flexDirection = "column", gap = 4,
                                children = itemWidgets,
                            },
                        },
                    },
                    -- 离开按钮
                    UI.Panel {
                        width = "100%", padding = 8, alignItems = "center",
                        children = {
                            UI.Button {
                                text = "离开超市",
                                width = "70%", height = 36,
                                fontSize = 12, variant = "ghost",
                                onClick = function(self)
                                    -- 关闭弹窗
                                    local o = root:FindById("supermarketOverlay")
                                    if o then o:Remove() end
                                    -- 离开超市推进时间
                                    HandleAction("leave_supermarket", {})
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    root:AddChild(overlay)
end

-- ============================================================================
-- 微信事件弹窗
-- ============================================================================

function ShowWechatEventPopup(wechatData)
    local root = UIManager.getRoot()
    if not root then return end

    -- 移除旧弹窗
    local old = root:FindById("wechatOverlay")
    if old then old:Remove() end

    local evt = wechatData.event
    local amount = wechatData.amount

    -- 构建选项按钮
    local choiceBtns = {}
    for i, choice in ipairs(evt.choices) do
        local choiceText = choice.text
        -- 给涉及金额的选项显示金额
        if choice.effect == "pay" then
            choiceText = string.format("%s ($%s)", choice.text, gs.formatMoney(amount))
        elseif choice.effect == "half" then
            choiceText = string.format("%s ($%s)", choice.text, gs.formatMoney(math.floor(amount / 2)))
        elseif choice.effect == "scammed" then
            choiceText = string.format("%s ($%s)", choice.text, gs.formatMoney(amount))
        end

        choiceBtns[#choiceBtns + 1] = UI.Button {
            text = choiceText,
            width = "100%",
            height = 36,
            fontSize = 11,
            variant = (choice.effect == "pay" or choice.effect == "accept_gift") and "primary"
                or (choice.effect == "ignore" or choice.effect == "scammed") and "danger"
                or "ghost",
            onClick = function(self)
                HandleWechatChoice(wechatData, choice)
            end,
        }
    end

    -- 弹窗主体：模拟微信聊天界面
    local messageText = evt.message
    if not evt.isGift then
        messageText = messageText .. string.format("\n\n💰 涉及金额: $%s", gs.formatMoney(amount))
    else
        messageText = messageText .. string.format("\n\n🎁 金额: $%s", gs.formatMoney(amount))
    end

    local overlay = UI.Panel {
        id = "wechatOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 160 },
        children = {
            UI.Panel {
                width = "88%",
                maxWidth = 380,
                padding = 0,
                backgroundColor = { 237, 237, 237, 250 },
                borderRadius = 12,
                flexDirection = "column",
                children = {
                    -- 标题栏（模拟微信风格）
                    UI.Panel {
                        width = "100%", padding = 10,
                        backgroundColor = { 30, 180, 60, 255 },
                        borderTopLeftRadius = 12, borderTopRightRadius = 12,
                        flexDirection = "row", alignItems = "center", gap = 6,
                        children = {
                            UI.Label { text = "📱 微信消息", fontSize = 13, fontColor = { 255, 255, 255, 255 } },
                        },
                    },
                    -- 消息内容
                    UI.Panel {
                        width = "100%", padding = 12, flexDirection = "column", gap = 8,
                        children = {
                            -- 发送者
                            UI.Panel {
                                flexDirection = "row", alignItems = "center", gap = 8,
                                children = {
                                    UI.Label { text = evt.avatar or "👤", fontSize = 28 },
                                    UI.Panel {
                                        flexDirection = "column", gap = 2,
                                        children = {
                                            UI.Label { text = evt.sender, fontSize = 13, fontColor = { 50, 50, 50, 255 } },
                                        },
                                    },
                                },
                            },
                            -- 聊天气泡
                            UI.Panel {
                                width = "100%", padding = 10,
                                backgroundColor = { 255, 255, 255, 255 },
                                borderRadius = 8,
                                children = {
                                    UI.Label {
                                        text = messageText,
                                        fontSize = 11,
                                        fontColor = { 40, 40, 40, 255 },
                                        flexShrink = 1,
                                    },
                                },
                            },
                        },
                    },
                    -- 选项按钮区域
                    UI.Panel {
                        width = "100%", padding = 10,
                        flexDirection = "column", gap = 6,
                        children = choiceBtns,
                    },
                },
            },
        },
    }

    root:AddChild(overlay)
end

--- 处理微信事件选择
function HandleWechatChoice(wechatData, choice)
    local evt = wechatData.event
    local amount = wechatData.amount

    -- 处理金额效果
    if choice.effect == "pay" then
        if evt.isGift then
            -- 不应该走这里
        else
            if gs.cash >= amount then
                gs.cash = gs.cash - amount
                gs.addMessage(string.format("转账给%s $%s，欠债还清了", evt.sender, gs.formatMoney(amount)), "info")
                gs.addLog(string.format("还钱给%s $%s", evt.sender, gs.formatMoney(amount)), "event")
            else
                gs.addMessage(string.format("钱不够还%s，只能先欠着了…", evt.sender), "warning")
                choice.moodChange = -10
                choice.repChange = -3
            end
        end
    elseif choice.effect == "half" then
        local halfAmount = math.floor(amount / 2)
        if gs.cash >= halfAmount then
            gs.cash = gs.cash - halfAmount
            gs.addMessage(string.format("先还了%s一半 $%s", evt.sender, gs.formatMoney(halfAmount)), "info")
            gs.addLog(string.format("还%s一半 $%s", evt.sender, gs.formatMoney(halfAmount)), "event")
        else
            gs.addMessage("连一半都拿不出来…", "warning")
            choice.moodChange = -8
        end
    elseif choice.effect == "delay" then
        gs.addMessage(string.format("跟%s说了缓缓再还…", evt.sender), "info")
    elseif choice.effect == "ignore" then
        gs.addMessage(string.format("无视了%s的消息…心里有点过意不去", evt.sender), "warning")
    elseif choice.effect == "accept_gift" then
        gs.cash = gs.cash + amount
        gs.addMessage(string.format("收下了同学们的心意 $%s，感动！", gs.formatMoney(amount)), "success")
        gs.addLog(string.format("收到同学资助 $%s", gs.formatMoney(amount)), "event")
    elseif choice.effect == "refuse_gift" then
        gs.addMessage("虽然困难，但还是婉拒了同学们的好意", "info")
    elseif choice.effect == "block" then
        gs.addMessage("识破诈骗电话，果断拉黑！", "success")
    elseif choice.effect == "scammed" then
        if gs.cash >= amount then
            gs.cash = gs.cash - amount
            gs.addMessage(string.format("被骗了 $%s！太轻信了…", gs.formatMoney(amount)), "danger")
            gs.addLog(string.format("被诈骗损失 $%s", gs.formatMoney(amount)), "danger")
        else
            gs.addMessage("想转但钱都不够…虽然亏了，但因祸得福", "warning")
        end
    end

    -- 应用心情和声望效果
    if choice.moodChange then
        gs.mood = math.max(0, math.min(config.Player.MAX_MOOD, gs.mood + choice.moodChange))
    end
    if choice.repChange then
        gs.reputation = math.max(0, (gs.reputation or 0) + choice.repChange)
    end

    -- 清除待处理事件
    gs.pendingWechatEvent = nil

    -- 移除弹窗
    local root = UIManager.getRoot()
    if root then
        local overlay = root:FindById("wechatOverlay")
        if overlay then overlay:Remove() end
    end

    -- 即时破产检查
    if gs.phase == "playing" then
        if CheckAndWarnFinancial() then
            UIManager.refresh(gs, config, { onAction = HandleAction })
            return
        end
    end

    -- 刷新 UI
    UIManager.refresh(gs, config, { onAction = HandleAction })
end

-- ============================================================================
-- 游戏结束画面
-- ============================================================================

function ShowEndScreen()
    local isWin = gs.phase == "won"
    local title = isWin and "恭喜通关！" or "游戏结束"

    local tierDef = ProgressionSystem.getCurrentTier(gs, config)
    local tierName = tierDef and (tierDef.emoji .. tierDef.name) or "街边摆摊"

    local desc = isWin
        and string.format("你用了%d个月完成了逆袭！\n最终产业: %s\n最终资产: $%s",
            gs.currentMonth - 1, tierName, gs.formatMoney(gs.cash))
        or string.format("很遗憾，你没能在5年内还清贷款\n当前产业: %s\n剩余贷款: $%s\n现金: $%s",
            tierName, gs.formatMoney(gs.totalDebt), gs.formatMoney(gs.cash))

    local overlay = UI.Panel {
        id = "endOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 180 },
        children = {
            UI.Panel {
                width = "85%",
                maxWidth = 360,
                padding = 24,
                gap = 12,
                backgroundColor = isWin and { 30, 50, 40, 245 } or { 50, 30, 30, 245 },
                borderRadius = 16,
                borderWidth = 2,
                borderColor = isWin and { 80, 200, 120, 200 } or { 200, 80, 80, 200 },
                alignItems = "center",
                children = {
                    UI.Label {
                        text = title,
                        fontSize = 22,
                        fontColor = isWin and { 100, 255, 150, 255 } or { 255, 100, 100, 255 },
                    },
                    UI.Label {
                        text = desc,
                        fontSize = 12,
                        fontColor = { 200, 200, 220, 255 },
                        textAlign = "center",
                    },
                    UI.Button {
                        text = "重新开始",
                        variant = "primary",
                        width = "80%",
                        height = 40,
                        marginTop = 8,
                        onClick = function(self)
                            RestartGame()
                        end,
                    },
                },
            },
        },
    }

    local root = UIManager.getRoot()
    if root then
        -- 移除旧的结束画面
        local old = root:FindById("endOverlay")
        if old then old:Remove() end
        root:AddChild(overlay)
    end
end

-- ============================================================================
-- 重新开始
-- ============================================================================

function RestartGame()
    -- 清除存档
    SaveSystem.delete()

    -- 重新初始化状态
    gs.init(config)
    gs.addMessage("新的开始！这次一定要还清贷款！", "info")

    -- 重建 UI
    UIManager.build(gs, config, SceneRenderer, {
        onAction = HandleAction,
    })

    -- 重置音频
    AudioManager.stopBGM()
end
