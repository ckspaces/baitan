-- ============================================================================
-- BottomActions.lua - 底部操作面板（分页Tab）- 重构版
-- ============================================================================

local UI = require("urhox-libs/UI")
local ProgressionSystem = require("core.ProgressionSystem")

local BottomActions = {}

local TAB_DEFS = {
    { id = "main",     label = "主业" },
    { id = "life",     label = "生活" },
    { id = "finance",  label = "财务" },
}

--- 创建底部面板
function BottomActions.create(gs, config, colors, callbacks)
    return UI.Panel {
        id = "bottomPanel",
        width = "100%",
        flex = 1,
        flexBasis = 0,
        minHeight = 280,
        flexDirection = "column",
        backgroundColor = colors.BG_PANEL,
        borderTopWidth = 1,
        borderTopColor = colors.BORDER,
        children = {
            BottomActions.createMessageBar(gs, colors),
            BottomActions.createTabBar(colors, callbacks),
            UI.ScrollView {
                id = "actionContent",
                flex = 1,
                width = "100%",
                flexBasis = 0,
                padding = 6,
                scrollY = true,
                children = {
                    BottomActions.buildMainTab(gs, config, colors, callbacks),
                },
            },
        },
    }
end

--- 消息日志条
function BottomActions.createMessageBar(gs, colors)
    local msg = gs.messages[1]
    local msgText = msg and msg.text or "从摆摊开始，一步步东山再起吧！"
    local msgColor = colors.TEXT_DIM
    if msg then
        if msg.type == "success" then msgColor = colors.SUCCESS
        elseif msg.type == "warning" then msgColor = colors.WARNING
        elseif msg.type == "danger" then msgColor = colors.DANGER
        end
    end
    return UI.Panel {
        id = "messageBar",
        width = "100%",
        height = 22,
        paddingLeft = 8,
        paddingRight = 8,
        justifyContent = "center",
        backgroundColor = { 10, 12, 22, 200 },
        children = {
            UI.Label {
                id = "messageLabel",
                text = msgText,
                fontSize = 10,
                fontColor = msgColor,
            },
        },
    }
end

--- Tab 栏
function BottomActions.createTabBar(colors, callbacks)
    local tabs = {}
    for i, tab in ipairs(TAB_DEFS) do
        local isFirst = (i == 1)
        tabs[i] = UI.Button {
            id = "tab_" .. tab.id,
            text = tab.label,
            fontSize = 11,
            height = 28,
            flex = 1,
            borderRadius = 0,
            variant = isFirst and "primary" or "ghost",
            onClick = function(self)
                if callbacks.onTabChange then
                    callbacks.onTabChange(tab.id)
                end
            end,
        }
    end
    return UI.Panel {
        id = "tabBar",
        width = "100%",
        height = 28,
        flexDirection = "row",
        children = tabs,
    }
end

-- ============================================================================
-- 主业 Tab（状态机：出摊前 / 摆摊中 两种视图）
-- ============================================================================
function BottomActions.buildMainTab(gs, config, colors, callbacks)
    if gs.isStalling then
        return BottomActions.buildStallingView(gs, config, colors, callbacks)
    else
        return BottomActions.buildPreStallView(gs, config, colors, callbacks)
    end
end

--- 出摊前视图：选品、进货出摊、升级、打工
function BottomActions.buildPreStallView(gs, config, colors, callbacks)
    local items = ProgressionSystem.getCurrentItems(gs, config)
    local selectedIdx = gs.selectedStallItem or 1
    if selectedIdx > #items then selectedIdx = 1 end
    local selectedItem = items[selectedIdx]
    local tierDef = ProgressionSystem.getCurrentTier(gs, config)

    local children = {}

    -- 当前等级标题
    children[#children + 1] = UI.Panel {
        width = "100%", flexDirection = "row", justifyContent = "center",
        alignItems = "center", gap = 4, marginBottom = 2,
        children = {
            UI.Label {
                text = string.format("%s %s", tierDef.emoji, tierDef.name),
                fontSize = 12, fontColor = colors.GOLD,
            },
        },
    }

    -- 选品区
    children[#children + 1] = UI.Panel {
        width = "100%", padding = 6, backgroundColor = { 25, 30, 45, 200 }, borderRadius = 6,
        flexDirection = "column", gap = 4,
        children = {
            UI.Label { text = "-- 选择商品 --", fontSize = 11, fontColor = colors.ACCENT, textAlign = "center" },
            BottomActions.buildItemSelector(gs, config, colors, callbacks),
            UI.Label {
                text = string.format("当前: %s%s  进货$%d → 产出%d份  售价$%d/份",
                    selectedItem.emoji, selectedItem.name,
                    selectedItem.batchCost, selectedItem.yield, selectedItem.unitPrice),
                fontSize = 9, fontColor = colors.TEXT_DIM, textAlign = "center",
            },
        },
    }

    -- === 地点选择区 ===
    local loc = gs.getCurrentLocation(config)
    children[#children + 1] = UI.Panel {
        width = "100%", padding = 6, backgroundColor = { 22, 32, 48, 200 }, borderRadius = 6,
        flexDirection = "column", gap = 4,
        children = {
            UI.Label { text = "-- 摆摊地点 --", fontSize = 11, fontColor = colors.ACCENT, textAlign = "center" },
            BottomActions.buildLocationSelector(gs, config, colors, callbacks),
            loc and UI.Label {
                text = string.format("当前: %s%s  %s%s",
                    loc.emoji, loc.name, loc.desc,
                    loc.rentCost > 0 and string.format("  摊位费$%d", loc.rentCost) or " (免租)"),
                fontSize = 9, fontColor = colors.TEXT_DIM, textAlign = "center",
            } or nil,
        },
    }

    -- === 促销活动区 ===
    children[#children + 1] = BottomActions.buildPromotionPanel(gs, config, colors, callbacks)

    -- === 横幅广告语 ===
    local bannerDisplay = (gs.bannerText and gs.bannerText ~= "") and gs.bannerText or "(未设置)"
    children[#children + 1] = UI.Panel {
        width = "100%", padding = 6, backgroundColor = { 50, 20, 15, 180 }, borderRadius = 6,
        borderWidth = 1, borderColor = { 200, 60, 40, 150 },
        flexDirection = "row", alignItems = "center", gap = 6,
        children = {
            UI.Label { text = "🏮", fontSize = 16 },
            UI.Panel {
                flex = 1, flexDirection = "column", gap = 2,
                children = {
                    UI.Label { text = "横幅广告语", fontSize = 10, fontColor = { 255, 200, 100, 255 } },
                    UI.Label {
                        text = bannerDisplay, fontSize = 9, fontColor = colors.TEXT_DIM,
                        flexShrink = 1,
                    },
                },
            },
            UI.Button {
                text = "编辑", fontSize = 9, height = 26, width = 48, variant = "ghost",
                onClick = function(self)
                    if callbacks.onAction then callbacks.onAction("edit_banner", {}) end
                end,
            },
        },
    }

    -- 发传单 + 进货出摊按钮
    local flyerBonus = math.floor((gs.flyersActive or 0) * config.Flyer.BONUS_PER_STACK * 100)
    local stallLabel = tierDef.tier >= 2 and "进货开业！" or "进货出摊！"
    children[#children + 1] = UI.Panel {
        width = "100%", flexDirection = "row", gap = 4, marginTop = 4,
        children = {
            UI.Button {
                text = string.format("发传单(%d/%d)", gs.flyersActive or 0, config.Flyer.MAX_STACKS),
                flex = 1, fontSize = 10, height = 32, variant = "warning",
                disabled = (gs.flyersActive or 0) >= config.Flyer.MAX_STACKS
                    or gs.cash < config.Flyer.COST
                    or gs.energy < config.Flyer.ENERGY_COST,
                onClick = function(self)
                    if callbacks.onAction then callbacks.onAction("distribute_flyers", {}) end
                end,
            },
            UI.Button {
                text = stallLabel,
                flex = 1, fontSize = 12, height = 32, variant = "primary",
                disabled = gs.cash < selectedItem.batchCost,
                onClick = function(self)
                    if callbacks.onAction then callbacks.onAction("open_stall", {}) end
                end,
            },
        },
    }

    -- 传单加成提示
    if flyerBonus > 0 then
        children[#children + 1] = UI.Label {
            text = string.format("传单加成: +%d%% 收入", flyerBonus),
            fontSize = 9, fontColor = colors.SUCCESS, textAlign = "center",
        }
    end

    -- 升级提示（如果有下一级）
    local nextTier = ProgressionSystem.getNextTier(gs, config)
    if nextTier then
        local canUpgrade, reason = ProgressionSystem.canUpgrade(gs, config)
        children[#children + 1] = UI.Panel {
            width = "100%", marginTop = 6, padding = 6,
            backgroundColor = { 30, 28, 15, 200 }, borderRadius = 6,
            borderWidth = 1, borderColor = canUpgrade and colors.GOLD or colors.BORDER,
            flexDirection = "column", gap = 3, alignItems = "center",
            children = {
                UI.Label {
                    text = string.format("升级为 %s%s", nextTier.emoji, nextTier.name),
                    fontSize = 11, fontColor = colors.GOLD,
                },
                UI.Label {
                    text = canUpgrade and string.format("费用: $%s", gs.formatMoney(nextTier.upgradeCost))
                        or reason,
                    fontSize = 9, fontColor = canUpgrade and colors.SUCCESS or colors.TEXT_DIM,
                },
                UI.Button {
                    text = canUpgrade and "立即升级" or "条件不足",
                    fontSize = 10, height = 28, width = 120,
                    variant = canUpgrade and "primary" or "ghost",
                    disabled = not canUpgrade,
                    onClick = function(self)
                        if callbacks.onAction then callbacks.onAction("upgrade_tier", {}) end
                    end,
                },
            },
        }
    end

    return UI.Panel {
        id = "mainTab",
        width = "100%", flexDirection = "column", gap = 4,
        children = children,
    }
end

--- 摆摊中视图：库存、信任度、叫卖/等待、直播、收摊
function BottomActions.buildStallingView(gs, config, colors, callbacks)
    local items = ProgressionSystem.getCurrentItems(gs, config)
    local item = items[gs.stallItemIndex] or items[1]
    local tierDef = ProgressionSystem.getCurrentTier(gs, config)
    local StallSystem = require("core.StallSystem")

    local children = {}
    local currentTime = gs.getTimeText and gs.getTimeText() or '--:--'
    local sessionRevenue = gs.stallSessionRevenue or 0
    local sessionCosts = gs.stallSessionCosts or 0
    local sessionNet = (gs.stallSessionRevenue or 0) - (gs.stallSessionCosts or 0)
    local closeHour = ((config.StallRealtime or {}).CLOSE_HOUR or 21)
    local modeLabel = ({ balanced = '平衡经营', observe = '观望蓄客', hawk = '冲刺叫卖' })[gs.stallActionMode or 'balanced'] or '平衡经营'

    -- 标题 + 营业中标记
    children[#children + 1] = UI.Panel {
        width = "100%", padding = 6, backgroundColor = { 18, 24, 38, 220 }, borderRadius = 6,
        flexDirection = "column", gap = 3,
        children = {
            UI.Panel {
                width = "100%", flexDirection = "row", justifyContent = "space-between",
                children = {
                    UI.Label { text = string.format("营业时间 %s / %02d:00", currentTime, closeHour), fontSize = 10, fontColor = colors.ACCENT },
                    UI.Label { text = modeLabel, fontSize = 9, fontColor = colors.TEXT_WHITE },
                },
            },
            UI.Panel {
                width = "100%", flexDirection = "row", justifyContent = "space-between",
                children = {
                    UI.Label { text = string.format("本摊收入 $%s", gs.formatMoney(sessionRevenue)), fontSize = 9, fontColor = colors.CASH_GREEN },
                    UI.Label { text = string.format("本摊成本 $%s", gs.formatMoney(sessionCosts)), fontSize = 9, fontColor = colors.WARNING },
                    UI.Label { text = string.format("净收益 $%s", gs.formatMoney(sessionNet)), fontSize = 9, fontColor = sessionNet >= 0 and colors.SUCCESS or colors.DANGER },
                },
            },
        },
    }

    children[#children + 1] = UI.Panel {
        width = "100%", flexDirection = "row", justifyContent = "center",
        alignItems = "center", gap = 6, marginBottom = 2,
        children = {
            UI.Label {
                text = string.format("%s %s · 营业中", tierDef.emoji, tierDef.name),
                fontSize = 13, fontColor = colors.GOLD,
            },
        },
    }

    -- 库存进度
    local invPct = gs.stallInventoryMax > 0 and gs.stallInventory / gs.stallInventoryMax or 0
    local invColor = invPct > 0.3 and colors.SUCCESS or colors.WARNING
    children[#children + 1] = UI.Panel {
        width = "100%", padding = 8, backgroundColor = { 25, 30, 45, 220 }, borderRadius = 8,
        flexDirection = "column", gap = 4, alignItems = "center",
        children = {
            UI.Label {
                text = string.format("📦 %s%s  库存: %d / %d 份",
                    item.emoji, item.name, gs.stallInventory, gs.stallInventoryMax),
                fontSize = 12, fontColor = colors.TEXT_WHITE,
            },
            UI.ProgressBar {
                value = invPct,
                width = "100%", height = 8, borderRadius = 4, fillColor = invColor,
            },
            UI.Panel {
                width = "100%", flexDirection = "row", justifyContent = "space-between",
                children = {
                    UI.Label {
                        text = string.format("已卖: %d份", gs.stallTotalSold),
                        fontSize = 9, fontColor = colors.TEXT_DIM,
                    },
                    UI.Label {
                        text = string.format("售价: $%d/份", item.unitPrice),
                        fontSize = 9, fontColor = colors.TEXT_DIM,
                    },
                    UI.Label {
                        text = string.format("累计: $%s", gs.formatMoney(gs.stallTotalEarned)),
                        fontSize = 9, fontColor = colors.CASH_GREEN,
                    },
                },
            },
        },
    }

    -- === 信任度/口碑面板 ===
    local trust = gs.stallTrust or 0
    local T = config.Trust
    local trustPct = math.min(1.0, trust / T.MAX_TRUST)
    local trustInfo = StallSystem.getTrustInfo(gs, config)
    local traffic = StallSystem.getTrafficSnapshot(gs, config)
    local trustColor = trust >= 70 and colors.GOLD
        or (trust >= 30 and { 120, 200, 255, 255 } or colors.TEXT_DIM)

    -- 口碑反馈文案
    local passiveDesc
    if trust < 15 then
        passiveDesc = "刚起步，主要靠自己把第一波客人喊过来"
    elseif trust < 30 then
        passiveDesc = "有人记住你了，偶尔会自己回来找你买"
    elseif trust < 50 then
        passiveDesc = "回头客正在形成，自然客流慢慢变稳"
    elseif trust < 70 then
        passiveDesc = "口碑开始接管客流，不叫卖也能卖出一部分"
    elseif trust < 90 then
        passiveDesc = "周边已经传开了，摊位开始自带热度"
    else
        passiveDesc = "金字招牌，光摆在这里就会有人来买"
    end

    children[#children + 1] = UI.Panel {
        width = "100%", padding = 6, backgroundColor = { 20, 35, 50, 200 }, borderRadius = 6,
        flexDirection = "column", gap = 3,
        children = {
            UI.Panel {
                width = "100%", flexDirection = "row", justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = string.format("%s 口碑: %s (%d)", trustInfo.emoji, trustInfo.name, trust),
                        fontSize = 10, fontColor = trustColor,
                    },
                    UI.Label {
                        text = passiveDesc,
                        fontSize = 8, fontColor = colors.TEXT_DIM,
                    },
                },
            },
            UI.ProgressBar {
                value = trustPct,
                width = "100%", height = 5, borderRadius = 3,
                fillColor = trustColor,
            },
        },
    }

    -- === 名气/网红面板 ===
    if config.Fame then
        local fameInfo = StallSystem.getFameInfo(gs, config)
        local fame = gs.fame or 0
        local famePct = math.min(1.0, fame / config.Fame.MAX_FAME)
        local fameColor = fame >= 1000 and { 255, 100, 200, 255 }
            or (fame >= 200 and { 200, 120, 255, 255 } or colors.TEXT_DIM)

        local fameKids = {}
        fameKids[#fameKids + 1] = UI.Panel {
            width = "100%", flexDirection = "row", justifyContent = "space-between",
            alignItems = "center",
            children = {
                UI.Label {
                    text = string.format("%s 名气: %s (%d)", fameInfo.emoji, fameInfo.name, fame),
                    fontSize = 10, fontColor = fameColor,
                },
                UI.Label {
                    text = fameInfo.bonus > 0 and string.format("客流+%d%%", math.floor(fameInfo.bonus * 100)) or "",
                    fontSize = 8, fontColor = colors.SUCCESS,
                },
            },
        }
        fameKids[#fameKids + 1] = UI.ProgressBar {
            value = famePct,
            width = "100%", height = 4, borderRadius = 2,
            fillColor = fameColor,
        }
        -- 最近网红事件
        if gs.lastViralEvent then
            fameKids[#fameKids + 1] = UI.Label {
                text = string.format("🔥 %s", gs.lastViralEvent.name or "突然爆火"),
                fontSize = 8, fontColor = { 255, 180, 50, 255 }, textAlign = "center",
            }
        end

        children[#children + 1] = UI.Panel {
            width = "100%", padding = 5, backgroundColor = { 35, 20, 45, 180 }, borderRadius = 5,
            flexDirection = "column", gap = 2,
            children = fameKids,
        }
    end

    -- === 当前促销活动状态 ===
    local activePromo = nil
    if gs.activePromotion then
        local StallSysRef = require("core.StallSystem")
        activePromo = StallSysRef.getActivePromotionConfig(gs, config)
    end
    if activePromo and gs.activePromotion then
        children[#children + 1] = UI.Panel {
            width = "100%", padding = 5, backgroundColor = { 50, 35, 10, 200 }, borderRadius = 5,
            borderWidth = 1, borderColor = { 255, 180, 50, 120 },
            flexDirection = "row", justifyContent = "space-between", alignItems = "center",
            children = {
                UI.Label {
                    text = string.format("%s %s", activePromo.emoji, activePromo.name),
                    fontSize = 10, fontColor = colors.GOLD,
                },
                UI.Label {
                    text = string.format("剩余%d天 | %s", gs.activePromotion.remaining, activePromo.desc),
                    fontSize = 8, fontColor = colors.TEXT_DIM,
                },
            },
        }
    end

    -- === 当前地点信息 ===
    local curLoc = gs.getCurrentLocation(config)
    if curLoc then
        local t = gs.timeOfDayMinutes or 0
        local timeHint
        if t < 900 then timeHint = "上午旺时 🔥"
        elseif t < 1080 then timeHint = "下午客流稳定"
        elseif t < 1170 then timeHint = "傍晚客流回落 📉"
        else timeHint = "夜晚人少了 🌙"
        end

        children[#children + 1] = UI.Panel {
            width = "100%", padding = 6, backgroundColor = { 25, 28, 45, 180 }, borderRadius = 5,
            flexDirection = "row", justifyContent = "space-between", alignItems = "center",
            children = {
                UI.Label {
                    text = string.format("📍 %s%s%s", curLoc.emoji, curLoc.name,
                        curLoc.rentCost > 0 and string.format("  摊位费$%d", curLoc.rentCost) or ""),
                    fontSize = 9, fontColor = colors.ACCENT,
                },
                UI.Label {
                    text = timeHint,
                    fontSize = 8, fontColor = colors.TEXT_DIM,
                },
            },
        }
    end

    -- 本轮经营结果
    local pSold = gs.stallPassiveSold or 0
    local pEarned = gs.stallPassiveEarned or 0
    local nSold = gs.stallNaturalSold or 0
    local nEarned = gs.stallNaturalEarned or 0
    children[#children + 1] = UI.Panel {
        width = "100%", padding = 6, backgroundColor = { 26, 40, 34, 180 }, borderRadius = 6,
        flexDirection = "column", gap = 3,
        children = {
            UI.Label {
                text = "-- 本轮经营结果 --",
                fontSize = 10, fontColor = { 140, 230, 160, 255 }, textAlign = "center",
            },
            UI.Panel {
                width = "100%", flexDirection = "row", justifyContent = "space-between",
                children = {
                    UI.Label { text = string.format("回头客 %d份", pSold), fontSize = 9, fontColor = colors.TEXT_WHITE },
                    UI.Label { text = string.format("+$%s", gs.formatMoney(pEarned)), fontSize = 9, fontColor = colors.CASH_GREEN },
                },
            },
            UI.Panel {
                width = "100%", flexDirection = "row", justifyContent = "space-between",
                children = {
                    UI.Label { text = string.format("自然来客 %d份", nSold), fontSize = 9, fontColor = colors.TEXT_WHITE },
                    UI.Label { text = string.format("+$%s", gs.formatMoney(nEarned)), fontSize = 9, fontColor = colors.CASH_GREEN },
                },
            },
        },
    }

    -- 熟练度信息
    local profLevel = gs.stallProfLevel or 1
    local profXP = gs.stallProficiency or 0
    local P = config.Proficiency
    local nextLvXP = P.LEVELS[profLevel + 1] or P.LEVELS[P.MAX_LEVEL]
    local currLvXP = P.LEVELS[profLevel] or 0
    local profPct = (profLevel >= P.MAX_LEVEL) and 1.0
        or math.min(1, (profXP - currLvXP) / math.max(1, nextLvXP - currLvXP))
    local profName = P.LEVEL_NAMES[profLevel] or "新手"
    local profBonus = math.floor((profLevel - 1) * P.SALES_BONUS_PER_LEVEL * 100)

    children[#children + 1] = UI.Panel {
        width = "100%", padding = 6, backgroundColor = { 35, 28, 15, 180 }, borderRadius = 6,
        flexDirection = "column", gap = 3, alignItems = "center",
        children = {
            UI.Panel {
                width = "100%", flexDirection = "row", justifyContent = "space-between",
                children = {
                    UI.Label {
                        text = string.format("🔥 熟练度: %s Lv.%d", profName, profLevel),
                        fontSize = 10, fontColor = colors.GOLD,
                    },
                    UI.Label {
                        text = profBonus > 0 and string.format("销量+%d%%", profBonus) or "持续经营会越来越顺手",
                        fontSize = 9, fontColor = profBonus > 0 and colors.SUCCESS or colors.TEXT_DIM,
                    },
                },
            },
            UI.ProgressBar {
                value = profPct,
                width = "100%", height = 4, borderRadius = 2,
                fillColor = { 255, 180, 50, 255 },
            },
        },
    }

    -- 直播状态
    local liveBonusPct = math.floor(StallSystem.calcLivestreamBonus(gs, config) * 100)
    local liveComments = gs.liveComments or {}
    local liveChildren = {
        UI.Panel {
            width = "100%", flexDirection = "row", justifyContent = "space-between",
            alignItems = "center",
            children = {
                UI.Label {
                    text = gs.isLiveStreaming and "📱 直播经营中" or "📱 直播未开启",
                    fontSize = 10, fontColor = gs.isLiveStreaming and { 255, 120, 120, 255 } or colors.TEXT_DIM,
                },
                UI.Label {
                    text = gs.isLiveStreaming and string.format("收入+%d%%", liveBonusPct) or "开启后可涨粉、接单、收打赏",
                    fontSize = 8, fontColor = gs.isLiveStreaming and colors.SUCCESS or colors.TEXT_DIM,
                },
            },
        },
        UI.Panel {
            width = "100%", flexDirection = "row", justifyContent = "space-between",
            children = {
                UI.Label { text = string.format("观众 %d", gs.liveViewerCount or 0), fontSize = 9, fontColor = colors.TEXT_WHITE },
                UI.Label { text = string.format("打赏 $%s", gs.formatMoney(gs.liveTipsEarned or 0)), fontSize = 9, fontColor = colors.GOLD },
                UI.Label { text = string.format("带货 %d份", gs.liveOrdersSold or 0), fontSize = 9, fontColor = colors.CASH_GREEN },
            },
        },
    }
    if #liveComments > 0 then
        for i = 1, math.min(3, #liveComments) do
            liveChildren[#liveChildren + 1] = UI.Label {
                text = string.format("• %s", liveComments[i]),
                fontSize = 8, fontColor = { 255, 220, 220, 255 }, textAlign = "left",
            }
        end
    else
        liveChildren[#liveChildren + 1] = UI.Label {
            text = gs.isLiveStreaming and "弹幕正在涌入，继续经营会刷新互动" or "直播不是单纯加成，它会把经营过程变成可见的人气反馈",
            fontSize = 8, fontColor = colors.TEXT_DIM, textAlign = "left",
        }
    end

    children[#children + 1] = UI.Panel {
        width = "100%", padding = 6, backgroundColor = { 28, 34, 48, 200 }, borderRadius = 6,
        borderWidth = 1, borderColor = { 90, 110, 150, 100 },
        flexDirection = "column", gap = 3,
        children = {
            UI.Panel {
                width = "100%", flexDirection = "row", justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Label {
                        text = string.format("📈 经营势能: %s", traffic.level),
                        fontSize = 10, fontColor = colors.ACCENT,
                    },
                    UI.Label {
                        text = string.format("热度 %d/100", traffic.score),
                        fontSize = 8, fontColor = colors.TEXT_WHITE,
                    },
                },
            },
            UI.ProgressBar {
                value = math.min(1.0, (traffic.score or 0) / 100),
                width = "100%", height = 4, borderRadius = 2,
                fillColor = traffic.score >= 60 and colors.SUCCESS or (traffic.score >= 30 and colors.WARNING or colors.TEXT_DIM),
            },
            UI.Label {
                text = traffic.summary,
                fontSize = 8, fontColor = colors.TEXT_DIM, textAlign = "left",
            },
        },
    }
    children[#children + 1] = UI.Panel {
        width = "100%", padding = 6,
        backgroundColor = gs.isLiveStreaming and { 70, 28, 34, 190 } or { 32, 24, 40, 180 },
        borderRadius = 6,
        borderWidth = 1,
        borderColor = gs.isLiveStreaming and { 220, 90, 100, 120 } or { 80, 80, 110, 100 },
        flexDirection = "column", gap = 3,
        children = liveChildren,
    }

    -- 操作按钮
    local actualHawkCost = item.energyCost
    if gs.isSick and config.Health then
        actualHawkCost = math.floor(item.energyCost * (config.Health.SICK_ENERGY_PENALTY or 1.5))
    end
    local canHawk = gs.stallInventory > 0 and gs.energy >= actualHawkCost
    children[#children + 1] = UI.Panel {
        width = "100%", flexDirection = "column", gap = 4, marginTop = 4,
        children = {
            UI.Button {
                text = canHawk and string.format("📣 叫卖揽客（体力-%d·主动爆发拉客）", actualHawkCost)
                    or (gs.stallInventory <= 0 and "库存卖完了" or "体力不足，先靠自然经营续住客流"),
                width = "100%", fontSize = 12, height = 40, variant = canHawk and "primary" or "ghost",
                disabled = not canHawk,
                onClick = function(self)
                    if callbacks.onAction then callbacks.onAction("hawk_sell", {}) end
                end,
            },
            UI.Panel {
                width = "100%", flexDirection = "row", gap = 4,
                children = {
                    UI.Button {
                        text = gs.isLiveStreaming and "📱 关直播" or "📱 开直播",
                        flex = 1, fontSize = 10, height = 32,
                        variant = gs.isLiveStreaming and "danger" or "warning",
                        onClick = function(self)
                            if callbacks.onAction then callbacks.onAction("toggle_livestream", {}) end
                        end,
                    },
                    UI.Button {
                        text = "🏠 收摊",
                        flex = 1, fontSize = 10, height = 32, variant = "ghost",
                        onClick = function(self)
                            if callbacks.onAction then callbacks.onAction("close_stall", {}) end
                        end,
                    },
                },
            },
        },
    }

    -- 提示
    local tipText = not canHawk
        and "💡 体力不足时自然来客和回头客会持续照顾生意，越晚人越少，趁早叫卖效果更好。"
        or "💡 先用叫卖拉第一波，再靠口碑、名气、地点和直播把摊位经营成自带客流的生意。"
    local tipColor = not canHawk and { 120, 200, 255, 255 } or colors.WARNING
    children[#children + 1] = UI.Label {
        text = tipText,
        fontSize = 9, fontColor = tipColor, textAlign = "center", marginTop = 4,
    }

    return UI.Panel {
        id = "mainTab",
        width = "100%", flexDirection = "column", gap = 4,
        children = children,
    }
end

--- 商品选择器（横排按钮，适配批次模型，渐进解锁 + 锁定态UI）
function BottomActions.buildItemSelector(gs, config, colors, callbacks)
    local items = ProgressionSystem.getCurrentItems(gs, config)
    local btns = {}
    for i, item in ipairs(items) do
        local isSelected = (gs.selectedStallItem == i)
        local unlock = ProgressionSystem.getItemUnlockStatus(gs, config, i, items)

        if unlock.unlocked then
            -- 已解锁：正常显示
            btns[#btns + 1] = UI.Button {
                text = item.emoji .. "\n" .. item.name,
                flex = 1, fontSize = 9, height = 38,
                variant = isSelected and "primary" or "ghost",
                onClick = function(self)
                    if callbacks.onAction then
                        callbacks.onAction("select_stall_item", { index = i })
                    end
                end,
            }
        else
            -- 锁定态：半透明遮罩 + 解锁条件
            local reasons = {}
            if not unlock.monthOk then
                reasons[#reasons + 1] = string.format("第%d月", unlock.monthReq or 1)
            end
            if unlock.previousItem and (unlock.currentXP or 0) < (unlock.requiredXP or 0) then
                reasons[#reasons + 1] = string.format("%s %d/%d", unlock.previousItem.name, unlock.currentXP or 0, unlock.requiredXP or 0)
            end
            if not unlock.skillOk and item.skillReq then
                for skill, lvl in pairs(item.skillReq) do
                    local sname = config.Skills.NAMES[skill] or skill
                    reasons[#reasons + 1] = string.format("%sLv%d", sname, lvl)
                end
            end
            local reasonStr = table.concat(reasons, "\n")

            -- 计算解锁进度（以上一个商品熟练度为主）
            local progress = 0
            local total = 0
            if (unlock.requiredXP or 0) > 0 then
                total = total + 1
                progress = progress + math.min(1, (unlock.currentXP or 0) / unlock.requiredXP)
            end
            if (unlock.monthReq or 1) > 1 then
                total = total + 1
                progress = progress + math.min(1, (gs.currentMonth or 1) / unlock.monthReq)
            end
            local progressPct = total > 0 and math.floor(progress / total * 100) or 0

            btns[#btns + 1] = UI.Panel {
                flex = 1, height = 38,
                backgroundColor = { 20, 22, 35, 180 },
                borderRadius = 4,
                borderWidth = 1, borderColor = { 60, 60, 80, 120 },
                justifyContent = "center",
                alignItems = "center",
                overflow = "hidden",
                children = {
                    -- 锁定图标 + 条件文字
                    UI.Label {
                        text = "🔒",
                        fontSize = 12,
                        fontColor = { 120, 120, 150, 180 },
                    },
                    UI.Label {
                        text = reasonStr,
                        fontSize = 7,
                        fontColor = { 140, 140, 170, 160 },
                        textAlign = "center",
                    },
                    -- 进度条（底部小横条）
                    progressPct > 0 and UI.Panel {
                        position = "absolute",
                        bottom = 0, left = 0,
                        width = string.format("%d%%", progressPct),
                        height = 2,
                        backgroundColor = { 100, 140, 255, 100 },
                    } or nil,
                },
            }
        end
    end
    return UI.Panel {
        width = "100%", flexDirection = "row", gap = 2,
        children = btns,
    }
end

--- 地点选择器（横排按钮，含冷却状态显示）
function BottomActions.buildLocationSelector(gs, config, colors, callbacks)
    local locations = config.Locations
    local btns = {}
    for i, loc in ipairs(locations) do
        local isSelected = (gs.currentLocation == i)
        local unlocked = gs.currentMonth >= (loc.unlockMonth or 1) and gs.meetsSkillReq(loc.skillReq)
        local locTrust = gs.locationTrust[loc.id] or 0
        -- 检查冷却
        local cd = (gs.locationCooldowns or {})[loc.id]
        local onCooldown = cd and cd > 0
        local canSelect = unlocked and not onCooldown

        local label
        if onCooldown then
            label = loc.emoji .. "\n" .. loc.name .. string.format("\n🚫冷却%d天", cd)
        else
            label = loc.emoji .. "\n" .. loc.name
                .. (locTrust > 0 and string.format("\n★%d", locTrust) or "")
        end

        btns[#btns + 1] = UI.Button {
            text = label,
            flex = 1, fontSize = 8, height = 44,
            variant = isSelected and "primary" or (canSelect and "ghost" or "ghost"),
            disabled = not canSelect,
            onClick = function(self)
                if callbacks.onAction then
                    callbacks.onAction("select_location", { index = i })
                end
            end,
        }
    end
    return UI.Panel {
        width = "100%", flexDirection = "row", gap = 2,
        children = btns,
    }
end

--- 促销活动管理面板
function BottomActions.buildPromotionPanel(gs, config, colors, callbacks)
    local promos = config.Promotions
    local StallSysRef = require("core.StallSystem")

    local promoChildren = {}
    promoChildren[#promoChildren + 1] = UI.Label {
        text = "-- 促销活动 --", fontSize = 11, fontColor = { 255, 180, 50, 255 }, textAlign = "center",
    }

    -- 当前促销状态
    if gs.activePromotion then
        local active = StallSysRef.getActivePromotionConfig(gs, config)
        if active then
            promoChildren[#promoChildren + 1] = UI.Panel {
                width = "100%", padding = 4, backgroundColor = { 50, 40, 15, 200 },
                borderRadius = 4, borderWidth = 1, borderColor = colors.GOLD,
                flexDirection = "row", justifyContent = "center", gap = 4,
                children = {
                    UI.Label {
                        text = string.format("进行中: %s%s 剩余%d天",
                            active.emoji, active.name, gs.activePromotion.remaining),
                        fontSize = 10, fontColor = colors.GOLD,
                    },
                },
            }
        end
    elseif (gs.promotionCooldown or 0) > 0 then
        promoChildren[#promoChildren + 1] = UI.Label {
            text = string.format("⏳ 促销冷却中…还需%d天", gs.promotionCooldown),
            fontSize = 9, fontColor = colors.WARNING, textAlign = "center",
        }
    end

    -- 促销列表
    for _, promo in ipairs(promos) do
        local daysOk = (gs.stallDayCount or 0) >= (promo.unlockStallDays or 0)
        local trustUnlockOk = not promo.unlockTrust or (gs.stallTrust or 0) >= (promo.unlockTrust or 0)
        local unlocked = daysOk and trustUnlockOk and gs.meetsSkillReq(promo.skillReq)
        local trustOk = not promo.trustRequired or (gs.stallTrust or 0) >= promo.trustRequired
        local canActivate = unlocked and trustOk
            and not gs.activePromotion
            and (gs.promotionCooldown or 0) <= 0
            and gs.cash >= promo.cost

        local lockReason = ""
        if not daysOk then
            lockReason = string.format("摆摊%d天", promo.unlockStallDays or 0)
        elseif not trustUnlockOk then
            lockReason = string.format("信任%d", promo.unlockTrust)
        elseif not gs.meetsSkillReq(promo.skillReq) then
            lockReason = "技能不足"
        elseif not trustOk then
            lockReason = string.format("信任%d", promo.trustRequired)
        end

        promoChildren[#promoChildren + 1] = UI.Panel {
            width = "100%", flexDirection = "row", alignItems = "center",
            padding = 4, backgroundColor = { 30, 35, 52, 150 }, borderRadius = 4,
            children = {
                UI.Panel {
                    flex = 1, gap = 1,
                    children = {
                        UI.Label {
                            text = string.format("%s %s", promo.emoji, promo.name),
                            fontSize = 10,
                            fontColor = unlocked and colors.TEXT_WHITE or colors.TEXT_DIM,
                        },
                        UI.Label {
                            text = string.format("$%d %d天 | %s", promo.cost, promo.duration, promo.desc),
                            fontSize = 8, fontColor = colors.TEXT_DIM,
                        },
                    },
                },
                UI.Button {
                    text = unlocked and (canActivate and "启动" or (lockReason ~= "" and lockReason or "—"))
                        or lockReason,
                    fontSize = 9, height = 24, width = 48,
                    variant = canActivate and "warning" or "ghost",
                    disabled = not canActivate,
                    onClick = function(self)
                        if callbacks.onAction then
                            callbacks.onAction("activate_promotion", { promoId = promo.id })
                        end
                    end,
                },
            },
        }
    end

    -- === 地点特色促销 ===
    local locPromos = ProgressionSystem.getLocationPromotions(gs, config)
    if #locPromos > 0 then
        local curLoc = gs.getCurrentLocation(config)
        promoChildren[#promoChildren + 1] = UI.Label {
            text = string.format("-- %s特色促销 --", curLoc and curLoc.name or "地点"),
            fontSize = 11, fontColor = { 120, 220, 180, 255 }, textAlign = "center", marginTop = 4,
        }
        for _, lp in ipairs(locPromos) do
            local lpDaysOk = (gs.stallDayCount or 0) >= (lp.unlockStallDays or 0)
            local lpUnlocked = lpDaysOk
            local lpCanActivate = lpUnlocked
                and not gs.activePromotion
                and (gs.promotionCooldown or 0) <= 0
                and gs.cash >= lp.cost

            local lpLockReason = ""
            if not lpDaysOk then
                lpLockReason = string.format("摆摊%d天", lp.unlockStallDays or 0)
            end

            local lpDesc = {}
            if lp.priceMod then lpDesc[#lpDesc + 1] = string.format("售价%+d%%", math.floor(lp.priceMod * 100)) end
            if lp.salesMod then lpDesc[#lpDesc + 1] = string.format("销量%+d%%", math.floor(lp.salesMod * 100)) end
            if lp.trustGainBonus then lpDesc[#lpDesc + 1] = string.format("信任+%d%%", math.floor(lp.trustGainBonus * 100)) end

            promoChildren[#promoChildren + 1] = UI.Panel {
                width = "100%", flexDirection = "row", alignItems = "center",
                padding = 4, backgroundColor = { 20, 40, 35, 150 }, borderRadius = 4,
                borderLeftWidth = 2, borderLeftColor = { 120, 220, 180, 200 },
                children = {
                    UI.Panel {
                        flex = 1, gap = 1,
                        children = {
                            UI.Label {
                                text = string.format("%s %s", lp.emoji, lp.name),
                                fontSize = 10,
                                fontColor = lpUnlocked and colors.TEXT_WHITE or colors.TEXT_DIM,
                            },
                            UI.Label {
                                text = string.format("$%d %d天 | %s", lp.cost, lp.duration, table.concat(lpDesc, " ")),
                                fontSize = 8, fontColor = colors.TEXT_DIM,
                            },
                        },
                    },
                    UI.Button {
                        text = lpUnlocked and (lpCanActivate and "启动" or "—")
                            or lpLockReason,
                        fontSize = 9, height = 24, width = 48,
                        variant = lpCanActivate and "warning" or "ghost",
                        disabled = not lpCanActivate,
                        onClick = function(self)
                            if callbacks.onAction then
                                callbacks.onAction("activate_promotion", { promoId = lp.id })
                            end
                        end,
                    },
                },
            }
        end
    end

    return UI.Panel {
        width = "100%", padding = 6, backgroundColor = { 28, 25, 40, 200 }, borderRadius = 6,
        flexDirection = "column", gap = 3,
        children = promoChildren,
    }
end

--- 信息行（label: value）
function BottomActions.infoRow(label, value, valueColor, colors)
    return UI.Panel {
        width = "100%", flexDirection = "row", justifyContent = "space-between",
        children = {
            UI.Label { text = label, fontSize = 10, fontColor = colors.TEXT_GRAY },
            UI.Label { text = value, fontSize = 10, fontColor = valueColor },
        },
    }
end

-- ============================================================================
-- 生活 Tab
-- ============================================================================
function BottomActions.buildLifeTab(gs, config, colors, callbacks)
    local H = config.Health
    local children = {}

    -- 健康状态面板
    local healthPct = (gs.health or 100) / 100
    local healthColor = (gs.health or 100) > 50 and { 120, 220, 180, 255 }
        or ((gs.health or 100) > 30 and colors.WARNING or colors.DANGER)

    children[#children + 1] = UI.Panel {
        width = "100%", padding = 8, backgroundColor = { 25, 30, 45, 200 },
        borderRadius = 6, flexDirection = "column", gap = 4,
        children = {
            UI.Label { text = "-- 健康状态 --", fontSize = 11, fontColor = { 120, 220, 180, 255 }, textAlign = "center" },
            UI.Panel {
                width = "100%", flexDirection = "row", alignItems = "center", gap = 6,
                children = {
                    UI.Label { text = string.format("❤️ %d/100", gs.health or 100), fontSize = 11, fontColor = healthColor },
                    UI.ProgressBar {
                        value = healthPct, flex = 1, height = 8, borderRadius = 4,
                        fillColor = healthColor,
                    },
                },
            },
            gs.isSick and UI.Panel {
                width = "100%", padding = 4, backgroundColor = { 100, 30, 30, 180 },
                borderRadius = 4, flexDirection = "row", justifyContent = "center",
                alignItems = "center", gap = 4,
                children = {
                    UI.Label {
                        text = string.format("🤒 生病中（第%d天）· 收入减半 · 体力消耗+50%%", gs.sickDays or 0),
                        fontSize = 9, fontColor = { 255, 120, 120, 255 },
                    },
                },
            } or nil,
        },
    }

    -- 医院和药店
    children[#children + 1] = UI.Panel {
        width = "100%", flexDirection = "row", gap = 4,
        children = {
            UI.Panel {
                flex = 1, padding = 6, backgroundColor = { 35, 40, 60, 200 },
                borderRadius = 6, flexDirection = "column", gap = 2,
                borderWidth = gs.isSick and 1 or 0,
                borderColor = { 255, 100, 100, 150 },
                children = {
                    UI.Label { text = "🏥 医院", fontSize = 12, fontColor = colors.TEXT_WHITE },
                    UI.Label { text = string.format("花$%d 健康+%d", H.HOSPITAL_COST, H.HOSPITAL_HEAL),
                        fontSize = 9, fontColor = colors.TEXT_DIM },
                    UI.Label { text = "可治愈疾病", fontSize = 8, fontColor = colors.SUCCESS },
                    UI.Button {
                        text = "就医", fontSize = 10, height = 28, width = "100%", marginTop = 4,
                        variant = gs.cash >= H.HOSPITAL_COST and "primary" or "ghost",
                        disabled = gs.cash < H.HOSPITAL_COST,
                        onClick = function(self)
                            if callbacks.onAction then callbacks.onAction("go_hospital", {}) end
                        end,
                    },
                },
            },
            UI.Panel {
                flex = 1, padding = 6, backgroundColor = { 35, 40, 60, 200 },
                borderRadius = 6, flexDirection = "column", gap = 2,
                children = {
                    UI.Label { text = "💊 药店", fontSize = 12, fontColor = colors.TEXT_WHITE },
                    UI.Label { text = string.format("花$%d 健康+%d", H.PHARMACY_COST, H.PHARMACY_HEAL),
                        fontSize = 9, fontColor = colors.TEXT_DIM },
                    UI.Label { text = "便宜但未必治好", fontSize = 8, fontColor = colors.WARNING },
                    UI.Button {
                        text = "买药", fontSize = 10, height = 28, width = "100%", marginTop = 4,
                        variant = gs.cash >= H.PHARMACY_COST and "success" or "ghost",
                        disabled = gs.cash < H.PHARMACY_COST,
                        onClick = function(self)
                            if callbacks.onAction then callbacks.onAction("go_pharmacy", {}) end
                        end,
                    },
                },
            },
        },
    }

    -- 超市
    local S = config.Supermarket
    local remainBuys = S.MAX_PURCHASES_PER_DAY - (gs.supermarketPurchasesToday or 0)
    children[#children + 1] = UI.Panel {
        width = "100%", padding = 6, backgroundColor = { 30, 45, 65, 200 },
        borderRadius = 6, flexDirection = "column", gap = 2,
        borderWidth = 1, borderColor = { 60, 140, 255, 120 },
        children = {
            UI.Label { text = "🛒 便利超市", fontSize = 12, fontColor = colors.TEXT_WHITE },
            UI.Label {
                text = string.format("买日用品补充状态 (今日剩余%d次)", remainBuys),
                fontSize = 9, fontColor = colors.TEXT_DIM,
            },
            UI.Button {
                text = remainBuys > 0 and "去超市" or "今日已满",
                fontSize = 10, height = 28, width = "100%", marginTop = 4,
                variant = remainBuys > 0 and "primary" or "ghost",
                disabled = remainBuys <= 0,
                onClick = function(self)
                    if callbacks.onAction then callbacks.onAction("go_supermarket", {}) end
                end,
            },
        },
    }

    -- 钓鱼库存提示（有鱼时显示）
    if (gs.fishStock or 0) > 0 then
        children[#children + 1] = UI.Panel {
            width = "100%", padding = 6,
            backgroundColor = { 18, 45, 75, 210 }, borderRadius = 6,
            borderWidth = 1, borderColor = { 60, 170, 220, 160 },
            flexDirection = "row", alignItems = "center", gap = 6,
            children = {
                UI.Label { text = "🐟", fontSize = 18 },
                UI.Panel {
                    flex = 1, flexDirection = "column", gap = 1,
                    children = {
                        UI.Label {
                            text = string.format("鱼库存: %d 条", gs.fishStock),
                            fontSize = 11, fontColor = { 150, 225, 255, 255 },
                        },
                        UI.Label {
                            text = "可选烤鱼摆摊，每条鱼可做3份",
                            fontSize = 9, fontColor = { 120, 180, 210, 200 },
                        },
                    },
                },
            },
        }
    end

    -- 钓鱼按钮
    do
        local F = config.Fishing
        local canFish = gs.energy >= F.ENERGY_COST
        children[#children + 1] = BottomActions.lifeButton(
            "🎣 去钓鱼",
            string.format("体力-%d · 心情+%d · 获得烤鱼食材", F.ENERGY_COST, F.MOOD_GAIN),
            "go_fishing",
            canFish,
            colors,
            callbacks)
    end

    -- 原有生活选项
    children[#children + 1] = BottomActions.lifeButton("休息", "恢复体力+"..config.Rest.ENERGY_GAIN.." 心情+"..config.Rest.MOOD_GAIN,
        "rest", true, colors, callbacks)
    children[#children + 1] = BottomActions.lifeButton("娱乐", "心情+"..config.Relax.MOOD_GAIN.." 花费$"..config.Relax.CASH_COST,
        "relax", gs.cash >= config.Relax.CASH_COST, colors, callbacks)
    children[#children + 1] = BottomActions.lifeButton("吃大餐", "心情+30 体力+10 花费$800",
        "feast", gs.cash >= 800, colors, callbacks)

    return UI.Panel {
        id = "lifeList",
        width = "100%",
        flexDirection = "column",
        gap = 4,
        children = children,
    }
end

function BottomActions.lifeButton(title, desc, actionId, canDo, colors, callbacks)
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        padding = 6,
        backgroundColor = { 35, 40, 60, 200 },
        borderRadius = 6,
        children = {
            UI.Panel {
                flex = 1,
                gap = 2,
                children = {
                    UI.Label { text = title, fontSize = 12, fontColor = colors.TEXT_WHITE },
                    UI.Label { text = desc, fontSize = 9, fontColor = colors.TEXT_DIM },
                },
            },
            UI.Button {
                text = "执行",
                fontSize = 10, height = 28, width = 50,
                variant = canDo and "success" or "ghost",
                disabled = not canDo,
                onClick = function(self)
                    if callbacks.onAction then
                        callbacks.onAction(actionId, {})
                    end
                end,
            },
        },
    }
end

-- ============================================================================
-- 财务 Tab
-- ============================================================================
function BottomActions.buildFinanceTab(gs, config, colors, callbacks)
    local _, _, totalInterest = require("core.FinanceSystem").getInterestPreview(gs, config)
    local F = config.Finance

    local initialTotal = F.INITIAL_BANK_DEBT + F.INITIAL_SHARK_DEBT
    local repayPct = initialTotal > 0 and math.min(1.0, gs.totalRepaid / initialTotal) or 0

    local ledgerChildren = {
        UI.Label { text = "-- 最近资金流水 --", fontSize = 11, fontColor = colors.GOLD, textAlign = "center" },
    }
    local ledger = gs.cashLedger or {}
    if #ledger == 0 then
        ledgerChildren[#ledgerChildren + 1] = UI.Label {
            text = "还没有资金流水记录",
            fontSize = 9, fontColor = colors.TEXT_DIM, textAlign = "center",
        }
    else
        for i = 1, math.min(8, #ledger) do
            local row = ledger[i]
            local amountColor = row.amount >= 0 and colors.CASH_GREEN or colors.DANGER
            local sign = row.amount >= 0 and "+$" or "-$"
            ledgerChildren[#ledgerChildren + 1] = UI.Panel {
                width = "100%", flexDirection = "row", justifyContent = "space-between",
                children = {
                    UI.Label {
                        text = string.format("%s %s", row.timeText or "--:--", row.reason or row.category or "资金变动"),
                        fontSize = 8, fontColor = colors.TEXT_WHITE,
                    },
                    UI.Label {
                        text = string.format("%s%s", sign, gs.formatMoney(math.abs(row.amount or 0))),
                        fontSize = 8, fontColor = amountColor,
                    },
                },
            }
        end
    end

    return UI.Panel {
        id = "financeList",
        width = "100%",
        flexDirection = "column",
        gap = 6,
        children = {
            UI.Panel {
                width = "100%", padding = 8, backgroundColor = { 25, 35, 30, 200 }, borderRadius = 6,
                flexDirection = "column", gap = 4,
                children = {
                    UI.Label { text = "-- 还贷进度 --", fontSize = 11, fontColor = colors.SUCCESS, textAlign = "center" },
                    UI.ProgressBar {
                        value = repayPct,
                        width = "100%", height = 10, borderRadius = 5,
                        fillColor = colors.SUCCESS,
                    },
                    UI.Label {
                        text = string.format("已还 %s / %s（%.0f%%）",
                            gs.formatMoney(gs.totalRepaid), gs.formatMoney(initialTotal), repayPct * 100),
                        fontSize = 9, fontColor = colors.TEXT_DIM, textAlign = "center",
                    },
                },
            },
            UI.Panel {
                width = "100%", padding = 8, backgroundColor = { 25, 30, 45, 200 }, borderRadius = 6,
                flexDirection = "column", gap = 4,
                children = {
                    UI.Label { text = "-- 债务明细 --", fontSize = 11, fontColor = colors.ACCENT, textAlign = "center" },
                    BottomActions.financeRow("银行贷款", "$" .. gs.formatMoney(gs.bankDebt), colors.DEBT_RED, colors),
                    BottomActions.financeRow("民间借贷", "$" .. gs.formatMoney(gs.sharkDebt), colors.DANGER, colors),
                    BottomActions.financeRow("月利息预估", "$" .. gs.formatMoney(totalInterest), colors.WARNING, colors),
                },
            },
            UI.Panel {
                width = "100%", padding = 8, backgroundColor = { 18, 24, 38, 220 }, borderRadius = 6,
                flexDirection = "column", gap = 4,
                children = ledgerChildren,
            },
            UI.Panel {
                width = "100%", flexDirection = "row", gap = 6,
                children = {
                    UI.Button {
                        text = "还款$5000", flex = 1, fontSize = 10, height = 32, variant = "primary",
                        disabled = gs.cash < 5000 or gs.totalDebt <= 0,
                        onClick = function(self)
                            if callbacks.onAction then callbacks.onAction("repay", { amount = 5000 }) end
                        end,
                    },
                    UI.Button {
                        text = "还款$2万", flex = 1, fontSize = 10, height = 32, variant = "primary",
                        disabled = gs.cash < 20000 or gs.totalDebt <= 0,
                        onClick = function(self)
                            if callbacks.onAction then callbacks.onAction("repay", { amount = 20000 }) end
                        end,
                    },
                },
            },
            UI.Button {
                text = string.format("借民间贷款$1万(月息%d%%)", math.floor(F.LOAN_SHARK_RATE * 100)),
                width = "100%", fontSize = 10, height = 32, variant = "warning",
                onClick = function(self)
                    if callbacks.onAction then callbacks.onAction("borrow", { amount = 10000 }) end
                end,
            },
        },
    }
end

function BottomActions.financeRow(label, value, valueColor, colors)
    return UI.Panel {
        width = "100%", flexDirection = "row", justifyContent = "space-between",
        children = {
            UI.Label { text = label, fontSize = 10, fontColor = colors.TEXT_GRAY },
            UI.Label { text = value, fontSize = 10, fontColor = valueColor },
        },
    }
end

return BottomActions
