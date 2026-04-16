-- ============================================================================
-- OverseasScene.lua - 海外贸易场景
-- ============================================================================

local OverseasScene = {}

function OverseasScene.draw(nvg, x, y, w, h, gs, animTime)
    -- 海洋天空渐变
    local sky = nvgLinearGradient(nvg, x, y, x, y + h * 0.4,
        nvgRGBA(20, 80, 160, 255), nvgRGBA(60, 140, 200, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h * 0.4)
    nvgFillPaint(nvg, sky)
    nvgFill(nvg)

    -- 太阳
    local sunX = x + w * 0.8
    local sunY = y + h * 0.12
    local sunGlow = nvgRadialGradient(nvg, sunX, sunY, 8, 40,
        nvgRGBA(255, 230, 100, 200), nvgRGBA(255, 200, 50, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sunX, sunY, 40)
    nvgFillPaint(nvg, sunGlow)
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, sunX, sunY, 12)
    nvgFillColor(nvg, nvgRGBA(255, 240, 150, 255))
    nvgFill(nvg)

    -- 海洋
    local ocean = nvgLinearGradient(nvg, x, y + h * 0.4, x, y + h,
        nvgRGBA(20, 80, 150, 255), nvgRGBA(10, 40, 80, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.4, w, h * 0.6)
    nvgFillPaint(nvg, ocean)
    nvgFill(nvg)

    -- 海浪
    OverseasScene.drawWaves(nvg, x, y, w, h, animTime)

    -- 货船
    OverseasScene.drawShip(nvg, x, y, w, h, gs, animTime)

    -- 远处陆地轮廓
    OverseasScene.drawDistantLand(nvg, x, y, w, h, animTime)

    -- 飞行的海鸥
    OverseasScene.drawSeagulls(nvg, x, y, w, h, animTime)

    -- 目的地文字
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 255, 200, 180))
    nvgText(nvg, x + w / 2, y + 8, "海外贸易航线", nil)
end

--- 海浪
function OverseasScene.drawWaves(nvg, x, y, w, h, animTime)
    nvgStrokeWidth(nvg, 1.5)
    for i = 0, 4 do
        local waveY = y + h * (0.42 + i * 0.08)
        local alpha = math.max(30, 100 - i * 15)
        nvgStrokeColor(nvg, nvgRGBA(100, 180, 255, alpha))
        nvgBeginPath(nvg)
        local offset = animTime * 30 + i * 40
        for dx = 0, w, 4 do
            local wy = waveY + math.sin((dx + offset) * 0.04) * (3 + i)
            if dx == 0 then
                nvgMoveTo(nvg, x + dx, wy)
            else
                nvgLineTo(nvg, x + dx, wy)
            end
        end
        nvgStroke(nvg)
    end
end

--- 货船
function OverseasScene.drawShip(nvg, x, y, w, h, gs, animTime)
    local shipX = x + w * 0.35
    local shipY = y + h * 0.52 + math.sin(animTime * 1.5) * 3

    -- 船体
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, shipX - 35, shipY)
    nvgLineTo(nvg, shipX + 35, shipY)
    nvgLineTo(nvg, shipX + 25, shipY + 15)
    nvgLineTo(nvg, shipX - 25, shipY + 15)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(120, 80, 50, 255))
    nvgFill(nvg)

    -- 船舱
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, shipX - 15, shipY - 18, 30, 18, 2)
    nvgFillColor(nvg, nvgRGBA(180, 160, 130, 255))
    nvgFill(nvg)

    -- 烟囱
    nvgBeginPath(nvg)
    nvgRect(nvg, shipX + 5, shipY - 30, 6, 12)
    nvgFillColor(nvg, nvgRGBA(80, 80, 90, 255))
    nvgFill(nvg)

    -- 烟雾
    nvgFillColor(nvg, nvgRGBA(180, 180, 190, 60))
    for i = 0, 2 do
        local smokeX = shipX + 8 + i * 6 + math.sin(animTime * 2 + i) * 3
        local smokeY = shipY - 32 - i * 8
        local smokeR = 4 + i * 2
        nvgBeginPath(nvg)
        nvgCircle(nvg, smokeX, smokeY, smokeR)
        nvgFill(nvg)
    end

    -- 货物箱子
    local boxColors = {
        { 200, 100, 80 },
        { 80, 160, 100 },
        { 100, 120, 200 },
    }
    for i = 1, 3 do
        local bc = boxColors[i]
        nvgBeginPath(nvg)
        nvgRect(nvg, shipX - 22 + (i - 1) * 14, shipY - 8, 10, 8)
        nvgFillColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], 255))
        nvgFill(nvg)
    end
end

--- 远处陆地
function OverseasScene.drawDistantLand(nvg, x, y, w, h, animTime)
    nvgFillColor(nvg, nvgRGBA(40, 80, 60, 120))
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, x + w * 0.6, y + h * 0.38)
    nvgLineTo(nvg, x + w * 0.7, y + h * 0.32)
    nvgLineTo(nvg, x + w * 0.8, y + h * 0.35)
    nvgLineTo(nvg, x + w * 0.95, y + h * 0.37)
    nvgLineTo(nvg, x + w, y + h * 0.4)
    nvgLineTo(nvg, x + w * 0.6, y + h * 0.4)
    nvgClosePath(nvg)
    nvgFill(nvg)

    -- 棕榈树轮廓
    local palmX = x + w * 0.75
    local palmY = y + h * 0.33
    nvgStrokeColor(nvg, nvgRGBA(30, 60, 40, 100))
    nvgStrokeWidth(nvg, 1.5)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, palmX, palmY + 5)
    nvgLineTo(nvg, palmX, palmY - 5)
    nvgStroke(nvg)
    -- 叶子
    nvgFillColor(nvg, nvgRGBA(30, 70, 40, 100))
    for a = -2, 2 do
        nvgBeginPath(nvg)
        local angle = a * 0.5
        nvgEllipse(nvg, palmX + math.sin(angle) * 6, palmY - 6 + math.cos(angle) * 2, 5, 2)
        nvgFill(nvg)
    end
end

--- 海鸥
function OverseasScene.drawSeagulls(nvg, x, y, w, h, animTime)
    nvgStrokeColor(nvg, nvgRGBA(255, 255, 255, 120))
    nvgStrokeWidth(nvg, 1.2)
    for i = 1, 4 do
        local bx = x + ((i * 100 + animTime * 25) % (w + 40)) - 20
        local by = y + h * (0.08 + i * 0.06) + math.sin(animTime * 3 + i * 2) * 5
        local wingSpan = 6 + math.sin(animTime * 5 + i) * 2
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, bx - wingSpan, by + 2)
        nvgQuadTo(nvg, bx - wingSpan * 0.5, by - 2, bx, by)
        nvgQuadTo(nvg, bx + wingSpan * 0.5, by - 2, bx + wingSpan, by + 2)
        nvgStroke(nvg)
    end
end

return OverseasScene
