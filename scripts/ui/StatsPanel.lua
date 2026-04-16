-- ============================================================================
-- StatsPanel.lua - 详细统计面板（嵌入经营 Tab）
-- ============================================================================

local UI = require("urhox-libs/UI")

local StatsPanel = {}

--- 创建统计信息面板
function StatsPanel.create(gs, config, colors)
    local skillRows = {}
    for i, stype in ipairs(config.Skills.TYPES) do
        local skill = gs.skills[stype]
        local sname = config.Skills.NAMES[stype]
        local maxXP = config.Skills.XP_PER_LEVEL[skill.level] or 99999
        skillRows[i] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            justifyContent = "space-between",
            alignItems = "center",
            children = {
                UI.Label {
                    text = string.format("%s Lv.%d", sname, skill.level),
                    fontSize = 9,
                    fontColor = colors.TEXT_GRAY,
                    width = 60,
                },
                UI.ProgressBar {
                    value = skill.xp / maxXP,
                    flex = 1,
                    height = 4,
                    marginLeft = 4,
                    marginRight = 4,
                    borderRadius = 2,
                    fillColor = colors.ACCENT,
                },
                UI.Label {
                    text = string.format("%d/%d", skill.xp, maxXP),
                    fontSize = 8,
                    fontColor = colors.TEXT_DIM,
                    width = 45,
                    textAlign = "right",
                },
            },
        }
    end

    return UI.Panel {
        width = "100%",
        flexDirection = "column",
        gap = 6,
        children = {
            -- 技能总览
            UI.Panel {
                width = "100%",
                padding = 8,
                backgroundColor = { 25, 30, 45, 200 },
                borderRadius = 6,
                flexDirection = "column",
                gap = 4,
                children = {
                    UI.Label {
                        text = "-- 技能总览 --",
                        fontSize = 11,
                        fontColor = colors.ACCENT,
                        textAlign = "center",
                    },
                    table.unpack(skillRows),
                },
            },
            -- 经营数据
            UI.Panel {
                width = "100%",
                padding = 8,
                backgroundColor = { 25, 30, 45, 200 },
                borderRadius = 6,
                flexDirection = "column",
                gap = 3,
                children = {
                    UI.Label {
                        text = "-- 数据概况 --",
                        fontSize = 11,
                        fontColor = colors.ACCENT,
                        textAlign = "center",
                    },
                    StatsPanel.infoRow("粉丝数", tostring(gs.followers), colors.MOOD_YELLOW, colors),
                    StatsPanel.infoRow("声望", tostring(gs.reputation or 0), colors.ACCENT, colors),
                    StatsPanel.infoRow("店铺数", tostring(#gs.businesses), colors.SUCCESS, colors),
                    StatsPanel.infoRow("月被动收入", gs.formatMoney(gs.monthIncome), colors.CASH_GREEN, colors),
                    StatsPanel.infoRow("月支出", gs.formatMoney(gs.monthExpense), colors.DEBT_RED, colors),
                    StatsPanel.infoRow("已还总额", gs.formatMoney(gs.totalRepaid), colors.SUCCESS, colors),
                    StatsPanel.infoRow("进度",
                        string.format("%d/%d月", gs.currentMonth, 60),
                        colors.TEXT_WHITE, colors),
                },
            },
        },
    }
end

function StatsPanel.infoRow(label, value, valueColor, colors)
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        justifyContent = "space-between",
        children = {
            UI.Label { text = label, fontSize = 10, fontColor = colors.TEXT_GRAY },
            UI.Label { text = value, fontSize = 10, fontColor = valueColor },
        },
    }
end

return StatsPanel
