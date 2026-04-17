-- ============================================================================
-- FishingScene.lua - 钓鱼场景背景（湖边清晨）
-- ============================================================================

local FishingScene = {}

--- 主绘制函数
function FishingScene.draw(nvg, x, y, w, h, gs, animTime)
    -- 天空渐变（清晨蓝紫 → 淡蓝）
    local sky = nvgLinearGradient(nvg, x, y, x, y + h * 0.65,
        nvgRGBA(80, 100, 160, 255), nvgRGBA(160, 200, 230, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, sky)
    nvgFill(nvg)

    -- 太阳光晕
    local sunX = x + w * 0.72
    local sunY = y + h * 0.18
    local pulse = 1.0 + 0.05 * math.sin(animTime * 0.8)
    -- 外发光
    local sunGlow = nvgRadialGradient(nvg, sunX, sunY, 18 * pulse, 60 * pulse,
        nvgRGBA(255, 220, 100, 80), nvgRGBA(255, 220, 100, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, sunX, sunY, 60 * pulse)
    nvgFillPaint(nvg, sunGlow)
    nvgFill(nvg)
    -- 太阳本体
    nvgBeginPath(nvg)
    nvgCircle(nvg, sunX, sunY, 18 * pulse)
    nvgFillColor(nvg, nvgRGBA(255, 240, 160, 255))
    nvgFill(nvg)

    -- 云朵
    FishingScene.drawCloud(nvg, x + w * 0.15, y + h * 0.08, 28, animTime * 3.5)
    FishingScene.drawCloud(nvg, x + w * 0.50, y + h * 0.05, 22, animTime * 2.8)
    FishingScene.drawCloud(nvg, x + w * 0.82, y + h * 0.12, 18, animTime * 4.0)

    -- 远山（深蓝紫，模糊感）
    local mtn1 = {
        { x + w * 0.0,  y + h * 0.50 },
        { x + w * 0.18, y + h * 0.28 },
        { x + w * 0.35, y + h * 0.42 },
        { x + w * 0.50, y + h * 0.24 },
        { x + w * 0.65, y + h * 0.38 },
        { x + w * 0.80, y + h * 0.22 },
        { x + w * 1.0,  y + h * 0.48 },
        { x + w * 1.0,  y + h * 0.65 },
        { x + w * 0.0,  y + h * 0.65 },
    }
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, mtn1[1][1], mtn1[1][2])
    for i = 2, #mtn1 do nvgLineTo(nvg, mtn1[i][1], mtn1[i][2]) end
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(90, 110, 150, 180))
    nvgFill(nvg)

    -- 近山（深绿）
    local mtn2 = {
        { x + w * 0.0,  y + h * 0.60 },
        { x + w * 0.12, y + h * 0.40 },
        { x + w * 0.25, y + h * 0.52 },
        { x + w * 0.38, y + h * 0.35 },
        { x + w * 0.55, y + h * 0.50 },
        { x + w * 0.72, y + h * 0.36 },
        { x + w * 0.88, y + h * 0.55 },
        { x + w * 1.0,  y + h * 0.45 },
        { x + w * 1.0,  y + h * 0.68 },
        { x + w * 0.0,  y + h * 0.68 },
    }
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, mtn2[1][1], mtn2[1][2])
    for i = 2, #mtn2 do nvgLineTo(nvg, mtn2[i][1], mtn2[i][2]) end
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(60, 100, 70, 220))
    nvgFill(nvg)

    -- 湖面
    local lakeY   = y + h * 0.62
    local lakeH   = h * 0.38
    local lakeBg  = nvgLinearGradient(nvg, x, lakeY, x, lakeY + lakeH,
        nvgRGBA(80, 140, 190, 255), nvgRGBA(30, 80, 130, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, lakeY, w, lakeH)
    nvgFillPaint(nvg, lakeBg)
    nvgFill(nvg)

    -- 水面波纹（sin 动画）
    nvgStrokeColor(nvg, nvgRGBA(200, 230, 255, 50))
    nvgStrokeWidth(nvg, 1)
    for row = 0, 4 do
        local wy = lakeY + 12 + row * 14
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, wy)
        local step = 8
        local cols = math.ceil(w / step)
        for col = 0, cols do
            local wx = x + col * step
            local waveOff = math.sin(animTime * 2.5 + col * 0.5 + row * 0.8) * 2
            nvgLineTo(nvg, wx, wy + waveOff)
        end
        nvgStroke(nvg)
    end

    -- 太阳倒影
    local reflectGrad = nvgLinearGradient(nvg, sunX, lakeY, sunX, lakeY + 60,
        nvgRGBA(255, 220, 100, 60), nvgRGBA(255, 220, 100, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, sunX - 18, lakeY, 36, 60)
    nvgFillPaint(nvg, reflectGrad)
    nvgFill(nvg)

    -- 岸边草地
    nvgBeginPath(nvg)
    nvgRect(nvg, x, lakeY - 10, w, 18)
    nvgFillColor(nvg, nvgRGBA(70, 130, 60, 255))
    nvgFill(nvg)

    -- 芦苇（左侧）
    FishingScene.drawReeds(nvg, x + w * 0.08, lakeY + 5, 5, animTime, 1)
    -- 芦苇（右侧）
    FishingScene.drawReeds(nvg, x + w * 0.75, lakeY + 5, 4, animTime, -1)
end

--- 绘制芦苇丛
---@param baseX number 起始X
---@param baseY number 起始Y
---@param count number 根数
---@param animTime number 动画时间
---@param swayDir number 摇摆方向（1/-1）
function FishingScene.drawReeds(nvg, baseX, baseY, count, animTime, swayDir)
    for i = 1, count do
        local rx = baseX + (i - 1) * 12 + math.sin(i * 0.7) * 4
        local sway = swayDir * math.sin(animTime * 1.5 + i * 0.6) * 3
        local rh = 30 + math.sin(i * 1.3) * 8

        -- 茎
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, rx, baseY)
        nvgLineTo(nvg, rx + sway, baseY - rh)
        nvgStrokeColor(nvg, nvgRGBA(100, 140, 70, 220))
        nvgStrokeWidth(nvg, 2)
        nvgStroke(nvg)

        -- 穗（椭圆）
        nvgBeginPath(nvg)
        nvgEllipse(nvg, rx + sway, baseY - rh - 5, 3, 7)
        nvgFillColor(nvg, nvgRGBA(140, 100, 50, 220))
        nvgFill(nvg)
    end
end

--- 绘制云朵
---@param cx number 中心X
---@param cy number 中心Y
---@param size number 大小
---@param drift number 偏移量（用于轻微漂移动画）
function FishingScene.drawCloud(nvg, cx, cy, size, drift)
    local driftX = math.sin(drift * 0.1) * 5
    local cx2 = cx + driftX
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 170))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx2, cy, size)
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx2 + size * 0.8, cy + size * 0.2, size * 0.75)
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx2 - size * 0.7, cy + size * 0.2, size * 0.65)
    nvgFill(nvg)
    -- 底部填平
    nvgBeginPath(nvg)
    nvgRect(nvg, cx2 - size * 1.5, cy, size * 3, size)
    nvgFill(nvg)
end

return FishingScene
