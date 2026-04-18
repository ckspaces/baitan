-- ============================================================================
-- SkillTrainingPanel.lua - 技能训练 UI 面板
-- 展示所有技能课程，支持学习、CD进度条、广告加速、领取奖励
-- ============================================================================

local UI = require("urhox-libs/UI")
local SkillTrainingSystem = require("core.SkillTrainingSystem")

local SkillTrainingPanel = {}

-- 技能顺序（与 GameConfig.Skills.TYPES 一致）
local SKILL_ORDER = { "management", "marketing", "tech", "charm", "negotiation" }

-- ============================================================================
-- 当前训练进度卡（顶部横幅）
-- ============================================================================
local function buildTrainingProgressCard(gs, config, colors, callbacks)
    local t = gs.training
    if not t then return nil end

    local meta     = SkillTrainingSystem.SKILL_META[t.skillType]
    local progress = SkillTrainingSystem.getProgress(gs)
    local isDone   = t.remainSecs <= 0
    local adUsed   = t.adSpeedUps or 0
    local adLeft   = 3 - adUsed

    local statusText = isDone
        and "✅ 学习完成！点击领取经验"
        or string.format("⏳ %s  （还可看广告加速 %d 次）",
            SkillTrainingSystem.formatRemaining(t.remainSecs), adLeft)

    local cardColor = isDone
        and { 20, 60, 30, 230 }
        or  { 20, 30, 60, 230 }
    local borderColor = isDone and colors.SUCCESS or colors.ACCENT

    local actionRow = {}

    -- 广告加速按钮（未完成且还有次数）
    if not isDone and adLeft > 0 then
        actionRow[#actionRow + 1] = UI.Button {
            text = string.format("📺 看广告加速（%d次）", adLeft),
            fontSize = 10, height = 30, flex = 1,
            variant = "ghost",
            borderColor = colors.WARNING,
            fontColor = colors.WARNING,
            onClick = function(self)
                if callbacks and callbacks.onAction then
                    callbacks.onAction("training_speedup_ad", {})
                end
            end,
        }
    end

    -- 领取按钮（已完成）
    if isDone then
        actionRow[#actionRow + 1] = UI.Button {
            id = "trainingClaimBtn",
            text = "🎁 领取经验奖励",
            fontSize = 11, height = 32, flex = 1,
            variant = "primary",
            onClick = function(self)
                if callbacks and callbacks.onAction then
                    callbacks.onAction("training_claim", {})
                end
            end,
        }
    end

    local children = {
        -- 标题行
        UI.Panel {
            width = "100%", flexDirection = "row", alignItems = "center", gap = 6,
            children = {
                UI.Label { text = t.emoji, fontSize = 16 },
                UI.Panel { flex = 1, flexDirection = "column", gap = 2,
                    children = {
                        UI.Label {
                            text = string.format("%s（%s）",
                                t.courseName, meta and meta.name or ""),
                            fontSize = 11, fontColor = colors.TEXT_WHITE,
                        },
                        UI.Label {
                            id = "trainingStatusText",
                            text = statusText,
                            fontSize = 9,
                            fontColor = isDone and colors.SUCCESS or colors.TEXT_GRAY,
                        },
                    },
                },
                UI.Label {
                    text = string.format("+%d XP", t.xpReward),
                    fontSize = 11, fontColor = colors.GOLD,
                },
            },
        },
        -- 进度条
        UI.ProgressBar {
            id = "trainingProgressBar",
            value = progress,
            width = "100%", height = 6,
            borderRadius = 3,
            fillColor = isDone and colors.SUCCESS or colors.ACCENT,
            marginTop = 4, marginBottom = 4,
        },
    }

    -- 操作行
    if #actionRow > 0 then
        children[#children + 1] = UI.Panel {
            width = "100%", flexDirection = "row", gap = 6,
            children = actionRow,
        }
    end

    return UI.Panel {
        id = "trainingProgressCard",
        width = "100%",
        padding = 10,
        backgroundColor = cardColor,
        borderRadius = 8,
        borderWidth = 1,
        borderColor = borderColor,
        flexDirection = "column",
        gap = 6,
        marginBottom = 8,
        children = children,
    }
end

-- ============================================================================
-- 单个技能区块（含课程列表）
-- ============================================================================
local function buildSkillSection(gs, config, colors, callbacks, skillType)
    local meta    = SkillTrainingSystem.SKILL_META[skillType]
    local skill   = gs.skills[skillType]
    if not skill or not meta then return nil end

    local maxXP   = config.Skills.XP_PER_LEVEL[skill.level] or 99999
    local isMax   = skill.level >= config.Skills.MAX_LEVEL
    local xpRatio = isMax and 1 or (skill.xp / maxXP)

    -- 当前等级效果
    local effectText = isMax
        and "已达满级"
        or (meta.levelEffects and meta.levelEffects[skill.level + 1])
        or "继续学习解锁更多效果"

    -- 课程行
    local courseRows = {}
    local courses = SkillTrainingSystem.COURSES[skillType]
    local isTraining = SkillTrainingSystem.isTraining(gs)

    for i, course in ipairs(courses) do
        local btnDisabled = isTraining or isMax
        local btnText = "学习"
        local btnVariant = "primary"

        if isTraining then
            -- 如果正在训练的就是这门课
            local t = gs.training
            if t and t.courseId == course.id then
                btnText = "学习中"
                btnVariant = "ghost"
            else
                btnText = "学习"
                btnVariant = "ghost"
            end
        elseif isMax then
            btnText = "满级"
            btnVariant = "ghost"
        end

        local costLabel = course.costCash > 0
            and string.format("$%d", course.costCash)
            or  "免费"
        local costColor = (course.costCash > 0 and gs.cash < course.costCash)
            and colors.DANGER
            or  colors.TEXT_DIM

        local capturedSkillType = skillType
        local capturedIdx       = i

        courseRows[i] = UI.Panel {
            width = "100%",
            flexDirection = "row",
            alignItems = "center",
            gap = 6,
            paddingVertical = 5,
            borderBottomWidth = (i < #courses) and 1 or 0,
            borderBottomColor = { 50, 55, 80, 150 },
            children = {
                -- 图标 + 名称
                UI.Label { text = course.emoji, fontSize = 14, width = 20, textAlign = "center" },
                UI.Panel { flex = 1, flexDirection = "column", gap = 1,
                    children = {
                        UI.Label {
                            text = course.name,
                            fontSize = 10,
                            fontColor = btnDisabled and colors.TEXT_DIM or colors.TEXT_WHITE,
                        },
                        UI.Label {
                            text = course.desc,
                            fontSize = 8,
                            fontColor = colors.TEXT_DIM,
                        },
                    },
                },
                -- 时长 + 经验
                UI.Panel { width = 52, flexDirection = "column", alignItems = "flex-end", gap = 1,
                    children = {
                        UI.Label {
                            text = SkillTrainingSystem.formatRemaining(course.durationSecs),
                            fontSize = 9, fontColor = colors.TEXT_GRAY,
                        },
                        UI.Label {
                            text = string.format("+%dXP", course.xpReward),
                            fontSize = 9, fontColor = colors.GOLD,
                        },
                    },
                },
                -- 费用 + 按钮
                UI.Panel { flexDirection = "column", alignItems = "flex-end", gap = 3, width = 46,
                    children = {
                        UI.Label { text = costLabel, fontSize = 9, fontColor = costColor },
                        UI.Button {
                            text = btnText,
                            fontSize = 9, height = 22, width = 46,
                            variant = btnVariant,
                            disabled = btnDisabled,
                            onClick = function(self)
                                if not btnDisabled and callbacks and callbacks.onAction then
                                    callbacks.onAction("training_start", {
                                        skillType = capturedSkillType,
                                        courseIdx = capturedIdx,
                                    })
                                end
                            end,
                        },
                    },
                },
            },
        }
    end

    -- 技能头部
    local headerChildren = {
        UI.Label { text = meta.emoji, fontSize = 15, width = 22, textAlign = "center" },
        UI.Panel { flex = 1, flexDirection = "column", gap = 2,
            children = {
                UI.Panel { flexDirection = "row", alignItems = "center", gap = 6,
                    children = {
                        UI.Label {
                            text = string.format("%s  Lv.%d", meta.name, skill.level),
                            fontSize = 11, fontColor = meta.color or colors.TEXT_WHITE,
                        },
                        UI.Label {
                            text = isMax and "满级" or string.format("%d/%d XP", skill.xp, maxXP),
                            fontSize = 9, fontColor = colors.TEXT_DIM,
                        },
                    },
                },
                UI.ProgressBar {
                    value = xpRatio,
                    width = "100%", height = 4, borderRadius = 2,
                    fillColor = meta.color or colors.ACCENT,
                },
            },
        },
    }

    -- 下一级效果提示
    local sectionChildren = {
        UI.Panel {
            width = "100%", flexDirection = "row", alignItems = "center", gap = 6,
            paddingBottom = 6,
            borderBottomWidth = 1, borderBottomColor = { 50, 55, 80, 150 },
            children = headerChildren,
        },
        UI.Label {
            text = isMax and "🏆 已达满级" or string.format("▶ 下一级：%s", effectText),
            fontSize = 9,
            fontColor = isMax and colors.GOLD or colors.TEXT_DIM,
            marginTop = 4, marginBottom = 2,
        },
    }

    for _, row in ipairs(courseRows) do
        sectionChildren[#sectionChildren + 1] = row
    end

    return UI.Panel {
        width = "100%",
        padding = 10,
        backgroundColor = { 25, 30, 50, 210 },
        borderRadius = 8,
        borderWidth = 1,
        borderColor = { 55, 60, 90, 200 },
        flexDirection = "column",
        gap = 0,
        children = sectionChildren,
    }
end

-- ============================================================================
-- 主入口：构建整个成长面板
-- ============================================================================
function SkillTrainingPanel.build(gs, config, colors, callbacks)
    local children = {}

    -- 标题
    children[#children + 1] = UI.Panel {
        width = "100%", flexDirection = "row", alignItems = "center",
        justifyContent = "space-between", marginBottom = 4,
        children = {
            UI.Label {
                text = "🎓 技能训练",
                fontSize = 13, fontColor = colors.GOLD,
            },
            UI.Label {
                text = "学习课程 → CD完成 → 领取经验",
                fontSize = 9, fontColor = colors.TEXT_DIM,
            },
        },
    }

    -- 当前训练进度卡（如有）
    local progressCard = buildTrainingProgressCard(gs, config, colors, callbacks)
    if progressCard then
        children[#children + 1] = progressCard
    end

    -- 无训练时的提示
    if not gs.training then
        children[#children + 1] = UI.Panel {
            width = "100%", padding = 8,
            backgroundColor = { 30, 35, 55, 180 },
            borderRadius = 6, marginBottom = 4,
            children = {
                UI.Label {
                    text = "💡 选择一门课程开始学习，等待CD结束后领取经验。看广告可加速 3 次！",
                    fontSize = 9, fontColor = colors.TEXT_DIM,
                    flexShrink = 1,
                },
            },
        }
    end

    -- 各技能板块
    for _, skillType in ipairs(SKILL_ORDER) do
        local section = buildSkillSection(gs, config, colors, callbacks, skillType)
        if section then
            children[#children + 1] = section
        end
    end

    return UI.Panel {
        id = "skillTrainingPanel",
        width = "100%",
        flexDirection = "column",
        gap = 8,
        children = children,
    }
end

-- ============================================================================
-- 轻量刷新：只更新进度条和状态文字（在 HandleUpdate 中调用，避免全量重建）
-- ============================================================================
function SkillTrainingPanel.tickUpdate(uiRoot, gs)
    local t = gs.training
    if not t then return end

    local bar = uiRoot:FindById("trainingProgressBar")
    if bar then
        bar:SetValue(SkillTrainingSystem.getProgress(gs))
        if t.remainSecs <= 0 then
            bar:SetStyle({ fillColor = { 80, 200, 120, 255 } })
        end
    end

    local statusLabel = uiRoot:FindById("trainingStatusText")
    if statusLabel then
        if t.remainSecs <= 0 then
            statusLabel:SetText("✅ 学习完成！点击领取经验")
            statusLabel:SetStyle({ fontColor = { 80, 200, 120, 255 } })
        else
            local adLeft = 3 - (t.adSpeedUps or 0)
            statusLabel:SetText(string.format("⏳ %s  （还可看广告加速 %d 次）",
                SkillTrainingSystem.formatRemaining(t.remainSecs), adLeft))
        end
    end
end

return SkillTrainingPanel
