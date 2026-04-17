-- ============================================================================
-- FishingMiniGame.lua - 钓鱼小游戏（3轮：等咬钩 → 收线）
-- ============================================================================
-- 玩法：抛竿后等待鱼儿咬钩，看到浮标剧烈抖动时点击"收线！"
-- 计时窗口内点击成功钓到鱼，超时则跑鱼
-- ============================================================================

local UI = require("urhox-libs/UI")
local Widget = UI.Widget

local FishingMiniGame = {}

-- ============================================================================
-- 阶段常量
-- ============================================================================
local PHASE_CASTING  = "casting"   -- 抛竿动画（1.4s）
local PHASE_WAITING  = "waiting"   -- 等待咬钩
local PHASE_BITING   = "biting"    -- 鱼儿咬钩（剧烈抖动，1.6s 内收线）
local PHASE_REELING  = "reeling"   -- 收线动画（1.8s）
local PHASE_RESULT   = "result"    -- 单轮结果（1.4s）
local PHASE_SUMMARY  = "summary"   -- 最终总结（2.2s 后自动关闭）

local CAST_DURATION    = 1.4
local REEL_DURATION    = 1.8
local RESULT_DURATION  = 1.4
local BITING_WINDOW    = 1.6      -- 收线窗口（超时则跑鱼）
local SUMMARY_DURATION = 2.2
local TOTAL_ROUNDS     = 3

-- ============================================================================
-- 自定义 Widget
-- ============================================================================

---@class FishingWidget : Widget
local FishingWidget = Widget:Extend("FishingWidget")

function FishingWidget:Init(props)
    props = props or {}
    props.width  = props.width  or "100%"
    props.height = props.height or 220
    Widget.Init(self, props)

    self.onComplete_ = props.onComplete  -- function(fishCaught, summaryText)
    self.fishConfig_ = props.fishConfig  -- Fishing config table
    self.elapsed_    = 0
    self.phase_      = PHASE_CASTING

    self.currentRound_ = 1
    self.fishCaught_   = 0
    self.roundResults_ = {}   -- "caught" | "missed" per round

    self.waitDuration_ = self:_randomWait()
    self.resultMsg_    = ""
    self.summaryMsg_   = ""
    self.reelSuccess_  = false

    -- 按钮引用（show() 注入）
    self.reelBtn_ = nil
end

function FishingWidget:IsStateful()
    return true
end

function FishingWidget:_randomWait()
    return 1.8 + math.random() * 3.5
end

function FishingWidget:Update(dt)
    self.elapsed_ = self.elapsed_ + dt

    if self.phase_ == PHASE_CASTING then
        if self.elapsed_ >= CAST_DURATION then
            self.elapsed_ = 0
            self.phase_ = PHASE_WAITING
        end

    elseif self.phase_ == PHASE_WAITING then
        if self.elapsed_ >= self.waitDuration_ then
            self.elapsed_ = 0
            self.phase_ = PHASE_BITING
            -- 激活收线按钮
            if self.reelBtn_ then
                self.reelBtn_:SetStyle({ variant = "primary" })
            end
        end

    elseif self.phase_ == PHASE_BITING then
        if self.elapsed_ >= BITING_WINDOW then
            -- 超时：鱼跑掉
            self.elapsed_ = 0
            self.reelSuccess_ = false
            self.resultMsg_ = "鱼儿跑了！"
            self:_endRound(false)
        end

    elseif self.phase_ == PHASE_REELING then
        if self.elapsed_ >= REEL_DURATION then
            self.elapsed_ = 0
            self.phase_ = PHASE_RESULT
        end

    elseif self.phase_ == PHASE_RESULT then
        if self.elapsed_ >= RESULT_DURATION then
            self.elapsed_ = 0
            self.currentRound_ = self.currentRound_ + 1
            if self.currentRound_ > TOTAL_ROUNDS then
                self:_buildSummary()
                self.phase_ = PHASE_SUMMARY
            else
                self.waitDuration_ = self:_randomWait()
                self.phase_ = PHASE_CASTING
                -- 重置按钮样式
                if self.reelBtn_ then
                    self.reelBtn_:SetStyle({ variant = "ghost" })
                    self.reelBtn_:SetText(string.format("🎣 收线！（第%d轮）", self.currentRound_))
                end
            end
        end

    elseif self.phase_ == PHASE_SUMMARY then
        if self.elapsed_ >= SUMMARY_DURATION then
            self.elapsed_ = 0
            if self.onComplete_ then
                self.onComplete_(self.fishCaught_, self.summaryMsg_)
            end
        end
    end
end

--- 玩家点击"收线"
function FishingWidget:tryReel()
    if self.phase_ == PHASE_BITING then
        self.elapsed_ = 0
        self.reelSuccess_ = true
        self.resultMsg_ = "钓到了！🐟"
        self:_endRound(true)
    elseif self.phase_ == PHASE_WAITING then
        -- 过早收线：惊鱼
        self.elapsed_ = 0
        self.reelSuccess_ = false
        self.resultMsg_ = "太心急了，鱼被吓跑了！"
        self:_endRound(false)
    end
end

function FishingWidget:isWaitingForReel()
    return self.phase_ == PHASE_BITING
end

function FishingWidget:_endRound(success)
    self.roundResults_[self.currentRound_] = success and "caught" or "missed"
    if success then
        self.fishCaught_ = self.fishCaught_ + 1
        self.phase_ = PHASE_REELING
    else
        self.phase_ = PHASE_RESULT
    end
    -- 收线按钮变暗
    if self.reelBtn_ then
        self.reelBtn_:SetStyle({ variant = "ghost" })
    end
end

function FishingWidget:_buildSummary()
    local n = self.fishCaught_
    if n >= 3 then
        self.summaryMsg_ = "大丰收，钓了满桶！"
    elseif n == 2 then
        self.summaryMsg_ = "钓了两条，不错的收获"
    elseif n == 1 then
        self.summaryMsg_ = "只钓到一条，下次继续努力"
    else
        self.summaryMsg_ = "一条没钓到，今天鱼儿不给面子"
    end
end

-- ============================================================================
-- NanoVG 渲染
-- ============================================================================

function FishingWidget:Render(nvg)
    local l = self:GetAbsoluteLayout()
    if l.w <= 0 or l.h <= 0 then return end

    nvgSave(nvg)
    nvgIntersectScissor(nvg, l.x, l.y, l.w, l.h)

    local x, y, w, h = l.x, l.y, l.w, l.h

    -- 背景：湖景（天空 + 水面）
    local skyGrad = nvgLinearGradient(nvg, x, y, x, y + h * 0.45,
        nvgRGBA(100, 150, 200, 255), nvgRGBA(170, 210, 235, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h * 0.45)
    nvgFillPaint(nvg, skyGrad)
    nvgFill(nvg)

    local waterGrad = nvgLinearGradient(nvg, x, y + h * 0.45, x, y + h,
        nvgRGBA(60, 120, 175, 255), nvgRGBA(30, 70, 130, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.45, w, h * 0.55)
    nvgFillPaint(nvg, waterGrad)
    nvgFill(nvg)

    -- 远岸轮廓
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.38, w, h * 0.10)
    nvgFillColor(nvg, nvgRGBA(60, 100, 65, 180))
    nvgFill(nvg)

    -- 水面波纹
    local waterY = y + h * 0.48
    nvgStrokeWidth(nvg, 1)
    for row = 0, 3 do
        local wy = waterY + row * 15
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, wy)
        local step = 12
        local cols = math.ceil(w / step) + 1
        for col = 0, cols do
            local wx = x + col * step
            local wo = math.sin(self.elapsed_ * 2.5 + col * 0.6 + row * 1.0) * 2
            nvgLineTo(nvg, wx, wy + wo)
        end
        nvgStrokeColor(nvg, nvgRGBA(200, 230, 255, 35))
        nvgStroke(nvg)
    end

    -- 岸边（玩家站立位置）
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.72, w * 0.30, h * 0.28)
    nvgFillColor(nvg, nvgRGBA(80, 130, 65, 255))
    nvgFill(nvg)

    -- 角色剪影（钓鱼人）
    local charX = x + w * 0.18
    local charY = y + h * 0.72
    -- 身体
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, charX - 8, charY - 30, 16, 22, 4)
    nvgFillColor(nvg, nvgRGBA(50, 60, 80, 230))
    nvgFill(nvg)
    -- 头（带帽子）
    nvgBeginPath(nvg)
    nvgCircle(nvg, charX, charY - 35, 8)
    nvgFillColor(nvg, nvgRGBA(60, 70, 90, 230))
    nvgFill(nvg)
    -- 帽檐
    nvgBeginPath(nvg)
    nvgRect(nvg, charX - 11, charY - 40, 22, 4)
    nvgFillColor(nvg, nvgRGBA(100, 80, 50, 230))
    nvgFill(nvg)

    -- 鱼竿（角度随阶段变化）
    local rodEndX, rodEndY = self:_getRodTip(charX, charY, w, h)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, charX + 5, charY - 28)
    nvgLineTo(nvg, rodEndX, rodEndY)
    nvgStrokeColor(nvg, nvgRGBA(180, 140, 80, 255))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 鱼线和浮标
    self:_drawLineAndFloat(nvg, rodEndX, rodEndY, waterY, w, h)

    -- 收线进度条（reeling 阶段）
    if self.phase_ == PHASE_REELING then
        local prog = math.min(1, self.elapsed_ / REEL_DURATION)
        local barX = x + w * 0.1
        local barY = y + h - 30
        local barW = w * 0.8
        local barH = 10
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, barW, barH, 4)
        nvgFillColor(nvg, nvgRGBA(30, 30, 30, 160))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, barX, barY, barW * prog, barH, 4)
        nvgFillColor(nvg, nvgRGBA(80, 220, 120, 220))
        nvgFill(nvg)
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 9)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
        nvgFillColor(nvg, nvgRGBA(220, 255, 220, 200))
        nvgText(nvg, x + w / 2, barY + barH + 3, "收线中...", nil)
    end

    -- 阶段文字提示
    self:_drawPhaseHint(nvg, x, y, w, h, waterY)

    -- 轮次指示点
    self:_drawRoundDots(nvg, x, y, w, h)

    nvgRestore(nvg)
end

--- 计算竿尖位置
function FishingWidget:_getRodTip(charX, charY, w, h)
    local l = self:GetAbsoluteLayout()
    local angle
    if self.phase_ == PHASE_CASTING then
        -- 抛竿：从竖直扫到前倾
        local t = math.min(1, self.elapsed_ / CAST_DURATION)
        angle = -80 + t * 50   -- -80° → -30°
    elseif self.phase_ == PHASE_REELING then
        -- 收线：竿子抬高
        local t = math.min(1, self.elapsed_ / REEL_DURATION)
        angle = -30 + t * (-40)  -- -30° → -70°
    else
        angle = -35
    end
    local rad = math.rad(angle)
    local rodLen = h * 0.5
    return charX + 5 + math.cos(rad) * rodLen,
           charY - 28 + math.sin(rad) * rodLen
end

--- 绘制鱼线和浮标
function FishingWidget:_drawLineAndFloat(nvg, rodX, rodY, waterY, w, h)
    local l    = self:GetAbsoluteLayout()
    local lx   = l.x
    -- 浮标水面位置（fixed）
    local floatX = lx + w * 0.58
    local floatY

    if self.phase_ == PHASE_CASTING then
        -- 抛出中：浮标从竿尖位置飞出落水
        local t = math.min(1, self.elapsed_ / CAST_DURATION)
        floatX = rodX + (lx + w * 0.58 - rodX) * t
        floatY = rodY + (waterY + 5 - rodY) * t - math.sin(t * math.pi) * h * 0.15
    elseif self.phase_ == PHASE_WAITING then
        -- 等待：轻微上下晃动
        floatY = waterY + 5 + math.sin(self.elapsed_ * 2.0) * 2
    elseif self.phase_ == PHASE_BITING then
        -- 咬钩：剧烈抖动
        local shake = math.sin(self.elapsed_ * 25) * 6
        floatY = waterY + 5 + shake
    elseif self.phase_ == PHASE_REELING then
        -- 收线：浮标朝竿尖移动
        local t = math.min(1, self.elapsed_ / REEL_DURATION)
        floatX = lx + w * 0.58 + (rodX - (lx + w * 0.58)) * t
        floatY = waterY + 5 + (rodY - waterY - 5) * t
    else
        floatY = waterY + 5
    end

    -- 鱼线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, rodX, rodY)
    nvgLineTo(nvg, floatX, floatY)
    nvgStrokeColor(nvg, nvgRGBA(200, 200, 200, 160))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 浮标（不在收线/抛竿过程中才画完整浮标）
    if self.phase_ ~= PHASE_CASTING or self.elapsed_ > CAST_DURATION * 0.7 then
        -- 浮标上半（红）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, floatX, floatY - 4, 3, 5)
        nvgFillColor(nvg, nvgRGBA(220, 60, 60, 230))
        nvgFill(nvg)
        -- 浮标下半（白）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, floatX, floatY + 3, 3, 4)
        nvgFillColor(nvg, nvgRGBA(240, 240, 240, 230))
        nvgFill(nvg)
    end

    -- 收线时显示鱼
    if self.phase_ == PHASE_REELING then
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 14)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
        nvgText(nvg, floatX, floatY - 15, "🐟", nil)
    end
end

--- 阶段文字提示
function FishingWidget:_drawPhaseHint(nvg, x, y, w, h, waterY)
    nvgFontFace(nvg, "sans")
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)

    if self.phase_ == PHASE_CASTING then
        nvgFontSize(nvg, 12)
        nvgFillColor(nvg, nvgRGBA(220, 240, 255, 200))
        nvgText(nvg, x + w / 2, y + h * 0.88, "抛竿中...", nil)

    elseif self.phase_ == PHASE_WAITING then
        nvgFontSize(nvg, 11)
        nvgFillColor(nvg, nvgRGBA(200, 220, 255, 180))
        nvgText(nvg, x + w / 2, y + h * 0.88, "等待鱼儿上钩...", nil)

    elseif self.phase_ == PHASE_BITING then
        -- 闪烁提示
        local blink = math.sin(self.elapsed_ * 12) > 0 and 255 or 180
        nvgFontSize(nvg, 14)
        nvgFillColor(nvg, nvgRGBA(255, 220, 50, blink))
        nvgText(nvg, x + w / 2, y + h * 0.88, "鱼咬钩了！赶快收线！", nil)
        -- 剩余时间
        local remain = BITING_WINDOW - self.elapsed_
        nvgFontSize(nvg, 10)
        nvgFillColor(nvg, nvgRGBA(255, 160, 100, 200))
        nvgText(nvg, x + w / 2, y + h * 0.93,
            string.format("%.1f 秒", remain), nil)

    elseif self.phase_ == PHASE_RESULT then
        local col = self.reelSuccess_ and nvgRGBA(100, 255, 120, 255)
                                     or  nvgRGBA(255, 120, 80, 255)
        nvgFontSize(nvg, 14)
        nvgFillColor(nvg, col)
        nvgText(nvg, x + w / 2, y + h * 0.60, self.resultMsg_, nil)
        nvgFontSize(nvg, 10)
        nvgFillColor(nvg, nvgRGBA(200, 200, 220, 180))
        nvgText(nvg, x + w / 2, y + h * 0.68,
            string.format("第%d/%d轮", self.currentRound_, TOTAL_ROUNDS), nil)

    elseif self.phase_ == PHASE_SUMMARY then
        -- 最终总结
        local col = self.fishCaught_ > 0 and nvgRGBA(100, 255, 150, 255)
                                         or  nvgRGBA(220, 180, 100, 255)
        nvgFontSize(nvg, 15)
        nvgFillColor(nvg, col)
        nvgText(nvg, x + w / 2, y + h * 0.48, self.summaryMsg_, nil)
        nvgFontSize(nvg, 20)
        nvgFillColor(nvg, nvgRGBA(255, 230, 100, 255))
        nvgText(nvg, x + w / 2, y + h * 0.32,
            string.format("🐟 × %d", self.fishCaught_), nil)
    end
end

--- 轮次指示点（底部）
function FishingWidget:_drawRoundDots(nvg, x, y, w, h)
    local dotR = 5
    local gap  = 18
    local total = TOTAL_ROUNDS
    local startX = x + w / 2 - (total - 1) * gap / 2
    local dotY = y + h - 14

    for i = 1, total do
        local cx = startX + (i - 1) * gap
        local res = self.roundResults_[i]
        local r, g, b, a
        if res == "caught" then
            r, g, b, a = 80, 220, 100, 255
        elseif res == "missed" then
            r, g, b, a = 220, 80, 80, 255
        else
            -- 未来轮次
            r, g, b, a = 120, 140, 180, 100
        end
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, dotY, dotR)
        nvgFillColor(nvg, nvgRGBA(r, g, b, a))
        nvgFill(nvg)
        -- 当前轮外框
        if i == self.currentRound_ and self.phase_ ~= PHASE_SUMMARY then
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx, dotY, dotR + 2)
            nvgStrokeColor(nvg, nvgRGBA(220, 220, 255, 200))
            nvgStrokeWidth(nvg, 1.5)
            nvgStroke(nvg)
        end
    end
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 弹出钓鱼小游戏
---@param parentRoot Widget UI 根节点
---@param fishConfig table config.Fishing 配置
---@param onComplete function(fishCaught, summaryText) 完成回调
function FishingMiniGame.show(parentRoot, fishConfig, onComplete)
    if not parentRoot then return end

    -- 移除旧实例
    local old = parentRoot:FindById("fishingOverlay")
    if old then old:Remove() end

    local fishingWidget  -- 前向声明

    -- 收线按钮
    local reelBtn = UI.Button {
        id      = "fishingReelBtn",
        text    = "🎣 收线！（第1轮）",
        width   = "80%",
        height  = 42,
        fontSize = 14,
        variant = "ghost",
        onClick = function(self)
            if fishingWidget then
                fishingWidget:tryReel()
            end
        end,
    }

    fishingWidget = FishingWidget {
        fishConfig  = fishConfig,
        onComplete  = function(fishCaught, summaryText)
            local ov = parentRoot:FindById("fishingOverlay")
            if ov then ov:Remove() end
            if onComplete then
                onComplete(fishCaught, summaryText)
            end
        end,
    }
    fishingWidget.reelBtn_ = reelBtn

    local overlay = UI.Panel {
        id = "fishingOverlay",
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        justifyContent = "center",
        alignItems     = "center",
        backgroundColor = { 0, 0, 0, 170 },
        children = {
            UI.Panel {
                width   = "92%",
                maxWidth = 420,
                padding  = 10,
                gap      = 8,
                backgroundColor = { 20, 40, 70, 245 },
                borderRadius    = 12,
                borderWidth     = 2,
                borderColor     = { 80, 170, 220, 200 },
                alignItems      = "center",
                children = {
                    UI.Label {
                        text      = "🎣 湖边钓鱼",
                        fontSize  = 15,
                        fontColor = { 180, 230, 255, 255 },
                    },
                    UI.Label {
                        text      = string.format("共%d轮，浮标剧烈抖动时点击收线！", TOTAL_ROUNDS),
                        fontSize  = 9,
                        fontColor = { 160, 190, 220, 200 },
                    },
                    fishingWidget,
                    reelBtn,
                },
            },
        },
    }

    parentRoot:AddChild(overlay)
end

return FishingMiniGame
