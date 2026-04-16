-- ============================================================================
-- GrillMiniGame.lua - 烤串小游戏（叫卖时触发）
-- ============================================================================
-- 玩法：3根烤串在烤架上，火候条自动走动
-- 玩家点击"翻面"在最佳时机停住火候
-- 评分影响叫卖收入倍率
-- ============================================================================

local UI = require("urhox-libs/UI")
local Widget = UI.Widget

local GrillMiniGame = {}

-- ============================================================================
-- 自定义 Widget：烤架渲染
-- ============================================================================

---@class GrillWidget : Widget
local GrillWidget = Widget:Extend("GrillWidget")

function GrillWidget:Init(props)
    props = props or {}
    props.width = props.width or "100%"
    props.height = props.height or 180
    Widget.Init(self, props)
    self.onResult_ = props.onResult    -- 回调：完成时返回结果
    self.elapsed_ = 0
    self.phase_ = "cooking"            -- cooking / result
    self.resultTimer_ = 0

    -- 3根烤串的火候（0~1，0.4~0.7 是最佳区间）
    self.skewers_ = {
        { heat = 0, speed = 0.25 + math.random() * 0.10, flipped = false, score = 0 },
        { heat = 0, speed = 0.22 + math.random() * 0.12, flipped = false, score = 0 },
        { heat = 0, speed = 0.28 + math.random() * 0.08, flipped = false, score = 0 },
    }
    self.currentSkewer_ = 1   -- 当前需要翻面的烤串索引
    self.totalScore_ = 0
    self.resultText_ = ""
    self.resultEmoji_ = ""
end

function GrillWidget:IsStateful()
    return true
end

function GrillWidget:Update(dt)
    if self.phase_ == "cooking" then
        self.elapsed_ = self.elapsed_ + dt

        -- 更新当前烤串的火候
        local idx = self.currentSkewer_
        if idx <= #self.skewers_ then
            local s = self.skewers_[idx]
            if not s.flipped then
                s.heat = math.min(1, s.heat + s.speed * dt)
                -- 火候超过0.95自动翻面（烤焦了）
                if s.heat >= 0.95 then
                    self:flipCurrent()
                end
            end
        end
    elseif self.phase_ == "result" then
        self.resultTimer_ = self.resultTimer_ + dt
        if self.resultTimer_ > 2.0 then
            -- 返回结果
            if self.onResult_ then
                self.onResult_(self.totalScore_, self.resultText_)
            end
        end
    end
end

--- 翻面（锁定当前烤串火候）
function GrillWidget:flipCurrent()
    local idx = self.currentSkewer_
    if idx > #self.skewers_ then return end
    local s = self.skewers_[idx]
    if s.flipped then return end

    s.flipped = true

    -- 评分
    local heat = s.heat
    if heat >= 0.40 and heat <= 0.70 then
        s.score = 3  -- 完美
    elseif heat >= 0.25 and heat <= 0.85 then
        s.score = 2  -- 不错
    elseif heat < 0.25 then
        s.score = 1  -- 太生
    else
        s.score = 1  -- 烤焦
    end

    -- 移到下一根
    self.currentSkewer_ = idx + 1

    -- 检查是否所有烤串都翻完
    if self.currentSkewer_ > #self.skewers_ then
        self:finishCooking()
    end
end

--- 完成烤制
function GrillWidget:finishCooking()
    self.phase_ = "result"
    self.resultTimer_ = 0

    -- 计算总分
    local total = 0
    for _, s in ipairs(self.skewers_) do
        total = total + s.score
    end
    self.totalScore_ = total  -- 3~9分

    if total >= 8 then
        self.resultText_ = "完美烤制！"
        self.resultEmoji_ = "🔥"
    elseif total >= 6 then
        self.resultText_ = "烤得不错！"
        self.resultEmoji_ = "👍"
    elseif total >= 4 then
        self.resultText_ = "勉强能吃..."
        self.resultEmoji_ = "😅"
    else
        self.resultText_ = "烤糊了..."
        self.resultEmoji_ = "💨"
    end
end

function GrillWidget:Render(nvg)
    local l = self:GetAbsoluteLayout()
    if l.w <= 0 or l.h <= 0 then return end

    nvgSave(nvg)
    nvgIntersectScissor(nvg, l.x, l.y, l.w, l.h)

    -- 烤架背景
    local grillBg = nvgLinearGradient(nvg, l.x, l.y, l.x, l.y + l.h,
        nvgRGBA(40, 20, 10, 255), nvgRGBA(60, 30, 15, 255))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, l.x, l.y, l.w, l.h, 8)
    nvgFillPaint(nvg, grillBg)
    nvgFill(nvg)

    -- 烤架网格线
    nvgStrokeColor(nvg, nvgRGBA(100, 80, 50, 150))
    nvgStrokeWidth(nvg, 1)
    local gridY = l.y + l.h * 0.5
    for i = 0, 6 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, l.x + 10, gridY - 15 + i * 5)
        nvgLineTo(nvg, l.x + l.w - 10, gridY - 15 + i * 5)
        nvgStroke(nvg)
    end

    -- 火焰效果（底部）
    local fireY = l.y + l.h * 0.72
    for i = 1, 12 do
        local fx = l.x + l.w * (0.08 + (i - 1) * 0.08)
        local flicker = math.sin(self.elapsed_ * 8 + i * 1.3) * 0.3 + 0.7
        local fh = 10 + flicker * 8

        -- 外焰（橙色）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, fx, fireY, 6, fh)
        nvgFillColor(nvg, nvgRGBA(255, 120, 20, math.floor(flicker * 120)))
        nvgFill(nvg)

        -- 内焰（黄色）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, fx, fireY + 2, 3, fh * 0.6)
        nvgFillColor(nvg, nvgRGBA(255, 220, 50, math.floor(flicker * 150)))
        nvgFill(nvg)
    end

    -- 绘制3根烤串
    local skewerW = (l.w - 40) / 3
    for i, s in ipairs(self.skewers_) do
        local sx = l.x + 20 + (i - 1) * skewerW + skewerW * 0.5
        local sy = gridY

        -- 烤串竹签
        nvgStrokeColor(nvg, nvgRGBA(200, 180, 120, 255))
        nvgStrokeWidth(nvg, 3)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, sx, sy - 20)
        nvgLineTo(nvg, sx, sy + 25)
        nvgStroke(nvg)

        -- 烤串肉块（根据火候变色）
        for j = 1, 3 do
            local my = sy - 12 + (j - 1) * 10
            local r, g, b
            if not s.flipped then
                -- 根据当前火候实时变色
                local h = s.heat
                r = math.floor(200 + h * 55)
                g = math.floor(160 - h * 120)
                b = math.floor(120 - h * 100)
            else
                -- 已翻面，根据分数显示
                if s.score == 3 then
                    r, g, b = 200, 140, 60   -- 金黄完美
                elseif s.score == 2 then
                    r, g, b = 180, 120, 50   -- 不错
                else
                    r, g, b = 80, 60, 40     -- 太生或焦
                end
            end
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, sx - 6, my, 12, 8, 3)
            nvgFillColor(nvg, nvgRGBA(r, g, b, 255))
            nvgFill(nvg)
        end

        -- 当前烤串指示箭头
        local isCurrent = (i == self.currentSkewer_)
        if isCurrent and self.phase_ == "cooking" then
            local arrowBob = math.sin(self.elapsed_ * 4) * 3
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 14)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(nvg, nvgRGBA(255, 255, 100, 255))
            nvgText(nvg, sx, sy - 30 + arrowBob, "▼", nil)
        end

        -- 翻面后评分标记
        if s.flipped then
            local scoreEmoji = s.score == 3 and "⭐" or (s.score == 2 and "👌" or "💨")
            nvgFontFace(nvg, "sans")
            nvgFontSize(nvg, 14)
            nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgText(nvg, sx, sy - 30, scoreEmoji, nil)
        end

        -- 烟雾效果（正在烤的）
        if isCurrent and not s.flipped and self.phase_ == "cooking" then
            for k = 1, 3 do
                local smokePhase = (self.elapsed_ * 1.5 + k * 0.5) % 1.5
                local smokeY = sy - 25 - smokePhase * 15
                local smokeAlpha = math.max(0, 1.0 - smokePhase / 1.5) * 80
                nvgBeginPath(nvg)
                nvgCircle(nvg, sx + math.sin(k * 2.1) * 5, smokeY, 2 + smokePhase * 3)
                nvgFillColor(nvg, nvgRGBA(200, 200, 200, math.floor(smokeAlpha)))
                nvgFill(nvg)
            end
        end
    end

    -- 当前火候条（底部）
    if self.phase_ == "cooking" and self.currentSkewer_ <= #self.skewers_ then
        local s = self.skewers_[self.currentSkewer_]
        local barX = l.x + 20
        local barY = l.y + l.h - 28
        local barW = l.w - 40
        local barH = 12

        -- 条背景
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, barW, barH, 4)
        nvgFillColor(nvg, nvgRGBA(30, 30, 30, 200))
        nvgFill(nvg)

        -- 区间颜色标注
        -- 太生区（0~0.25）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, barW * 0.25, barH, 4)
        nvgFillColor(nvg, nvgRGBA(150, 150, 255, 80))
        nvgFill(nvg)

        -- 还行区（0.25~0.40）
        nvgBeginPath(nvg)
        nvgRect(nvg, barX + barW * 0.25, barY, barW * 0.15, barH)
        nvgFillColor(nvg, nvgRGBA(200, 200, 100, 80))
        nvgFill(nvg)

        -- 完美区（0.40~0.70）- 绿色
        nvgBeginPath(nvg)
        nvgRect(nvg, barX + barW * 0.40, barY, barW * 0.30, barH)
        nvgFillColor(nvg, nvgRGBA(80, 220, 80, 100))
        nvgFill(nvg)

        -- 还行区（0.70~0.85）
        nvgBeginPath(nvg)
        nvgRect(nvg, barX + barW * 0.70, barY, barW * 0.15, barH)
        nvgFillColor(nvg, nvgRGBA(200, 200, 100, 80))
        nvgFill(nvg)

        -- 烤焦区（0.85~1.0）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX + barW * 0.85, barY, barW * 0.15, barH, 4)
        nvgFillColor(nvg, nvgRGBA(255, 80, 80, 80))
        nvgFill(nvg)

        -- 指针
        local pointerX = barX + barW * s.heat
        nvgBeginPath(nvg)
        nvgRect(nvg, pointerX - 1.5, barY - 2, 3, barH + 4)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 230))
        nvgFill(nvg)

        -- 区间标签
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 7)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(180, 180, 200, 180))
        nvgText(nvg, barX + barW * 0.125, barY + barH + 2, "太生", nil)
        nvgFillColor(nvg, nvgRGBA(80, 255, 80, 200))
        nvgText(nvg, barX + barW * 0.55, barY + barH + 2, "完美", nil)
        nvgFillColor(nvg, nvgRGBA(255, 100, 100, 200))
        nvgText(nvg, barX + barW * 0.925, barY + barH + 2, "烤焦", nil)
    end

    -- 结果展示
    if self.phase_ == "result" then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 22)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 230, 100, 255))

        local resultY = l.y + l.h * 0.3
        nvgText(nvg, l.x + l.w / 2, resultY, self.resultEmoji_ .. " " .. self.resultText_, nil)

        -- 倍率提示
        local mult = self:getMultiplier()
        nvgFontSize(nvg, 14)
        local multColor = mult >= 1.5 and nvgRGBA(100, 255, 100, 255)
            or (mult >= 1.0 and nvgRGBA(200, 200, 150, 255)
            or nvgRGBA(255, 100, 100, 255))
        nvgFillColor(nvg, multColor)
        nvgText(nvg, l.x + l.w / 2, resultY + 28,
            string.format("收入倍率: x%.1f", mult), nil)
    end

    nvgRestore(nvg)
end

--- 获取收入倍率
function GrillWidget:getMultiplier()
    if self.totalScore_ >= 8 then return 1.8
    elseif self.totalScore_ >= 6 then return 1.3
    elseif self.totalScore_ >= 4 then return 1.0
    else return 0.7
    end
end

-- ============================================================================
-- 公开接口：创建小游戏弹窗
-- ============================================================================

--- 弹出烤串小游戏
---@param parentRoot Widget UI 根节点
---@param onComplete function(multiplier, resultText) 完成回调
function GrillMiniGame.show(parentRoot, onComplete)
    if not parentRoot then return end

    -- 移除旧的
    local old = parentRoot:FindById("grillOverlay")
    if old then old:Remove() end

    -- 前向声明，闭包中引用
    local grillWidget
    grillWidget = GrillWidget {
        onResult = function(score, text)
            local mult = grillWidget and grillWidget:getMultiplier() or 1.0
            -- 移除弹窗
            local ov = parentRoot:FindById("grillOverlay")
            if ov then ov:Remove() end
            -- 回调
            if onComplete then
                onComplete(mult, text)
            end
        end,
    }

    local flipBtn = UI.Button {
        id = "grillFlipBtn",
        text = "🔥 翻面！",
        width = "80%",
        height = 40,
        fontSize = 14,
        variant = "warning",
        onClick = function(self)
            if grillWidget and grillWidget.phase_ == "cooking" then
                grillWidget:flipCurrent()
                if grillWidget.currentSkewer_ > #grillWidget.skewers_ then
                    self:SetStyle({ variant = "ghost" })
                    self:SetText("烤制完成！")
                else
                    self:SetText(string.format("🔥 翻第%d串！", grillWidget.currentSkewer_))
                end
            end
        end,
    }

    local overlay = UI.Panel {
        id = "grillOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems = "center",
        backgroundColor = { 0, 0, 0, 160 },
        children = {
            UI.Panel {
                width = "90%",
                maxWidth = 400,
                padding = 12,
                gap = 8,
                backgroundColor = { 40, 25, 15, 240 },
                borderRadius = 12,
                borderWidth = 2,
                borderColor = { 200, 120, 50, 200 },
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "🔥 烤串时间！",
                        fontSize = 16,
                        fontColor = { 255, 200, 80, 255 },
                    },
                    UI.Label {
                        text = "在绿色区域点击翻面获得最佳火候",
                        fontSize = 10,
                        fontColor = { 200, 180, 150, 200 },
                    },
                    grillWidget,
                    flipBtn,
                },
            },
        },
    }

    parentRoot:AddChild(overlay)
end

return GrillMiniGame
