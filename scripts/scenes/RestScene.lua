-- ============================================================================
-- RestScene.lua - 休息/吃饭/学习场景
-- ============================================================================

local RestScene = {}

function RestScene.draw(nvg, x, y, w, h, gs, animTime)
    -- 夜晚室内背景
    local bg = nvgLinearGradient(nvg, x, y, x, y + h,
        nvgRGBA(25, 25, 45, 255), nvgRGBA(15, 15, 30, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, bg)
    nvgFill(nvg)

    -- 窗户（外面是夜空）
    local winX = x + w * 0.6
    local winY = y + h * 0.1
    local winW = w * 0.3
    local winH = h * 0.25
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, winX, winY, winW, winH, 3)
    nvgFillColor(nvg, nvgRGBA(20, 30, 60, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(100, 100, 120, 255))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)
    -- 窗框十字
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, winX + winW / 2, winY)
    nvgLineTo(nvg, winX + winW / 2, winY + winH)
    nvgMoveTo(nvg, winX, winY + winH / 2)
    nvgLineTo(nvg, winX + winW, winY + winH / 2)
    nvgStrokeColor(nvg, nvgRGBA(100, 100, 120, 255))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 星星
    nvgFillColor(nvg, nvgRGBA(255, 255, 200, 180))
    for i = 1, 5 do
        local sx = winX + math.sin(i * 1.5) * winW * 0.35 + winW * 0.5
        local sy = winY + math.cos(i * 2.1) * winH * 0.3 + winH * 0.35
        local twinkle = 1 + 0.3 * math.sin(animTime * 3 + i)
        nvgBeginPath(nvg)
        nvgCircle(nvg, sx, sy, 1.5 * twinkle)
        nvgFill(nvg)
    end
    -- 月亮
    nvgBeginPath(nvg)
    nvgCircle(nvg, winX + winW * 0.75, winY + winH * 0.25, 8)
    nvgFillColor(nvg, nvgRGBA(255, 245, 200, 200))
    nvgFill(nvg)

    -- 床
    local bedX = x + w * 0.1
    local bedY = y + h * 0.55
    local bedW = w * 0.55
    local bedH = h * 0.2
    -- 床垫
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bedX, bedY, bedW, bedH, 4)
    nvgFillColor(nvg, nvgRGBA(70, 80, 120, 255))
    nvgFill(nvg)
    -- 枕头
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bedX + 5, bedY + 5, bedW * 0.2, bedH * 0.6, 5)
    nvgFillColor(nvg, nvgRGBA(220, 220, 230, 255))
    nvgFill(nvg)
    -- 被子
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bedX + bedW * 0.25, bedY + 3, bedW * 0.7, bedH - 6, 3)
    nvgFillColor(nvg, nvgRGBA(100, 120, 180, 200))
    nvgFill(nvg)

    -- 床头柜
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, bedX + bedW + 5, bedY + bedH * 0.3, 18, bedH * 0.7, 2)
    nvgFillColor(nvg, nvgRGBA(120, 90, 60, 255))
    nvgFill(nvg)
    -- 台灯
    local lampGlow = 0.5 + 0.2 * math.sin(animTime)
    nvgBeginPath(nvg)
    nvgCircle(nvg, bedX + bedW + 14, bedY + bedH * 0.2, 8)
    nvgFillColor(nvg, nvgRGBA(255, 230, 150, math.floor(80 * lampGlow)))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, bedX + bedW + 14, bedY + bedH * 0.2, 3)
    nvgFillColor(nvg, nvgRGBA(255, 240, 180, 200))
    nvgFill(nvg)

    -- 地板
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.82, w, h * 0.18)
    nvgFillColor(nvg, nvgRGBA(80, 65, 45, 255))
    nvgFill(nvg)

    -- Zzz 睡眠特效
    if gs.currentActivity == "resting" then
        RestScene.drawZzz(nvg, x + w * 0.45, y + h * 0.45, animTime)
    end
end

--- Zzz 动画
function RestScene.drawZzz(nvg, cx, cy, animTime)
    nvgFontFace(nvg, "sans")
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for i = 0, 2 do
        local t = (animTime + i * 0.8) % 2.5
        local alpha = math.floor(200 * (1 - t / 2.5))
        local offY = -t * 20
        local offX = t * 8
        nvgFontSize(nvg, 10 + i * 3)
        nvgFillColor(nvg, nvgRGBA(200, 200, 255, alpha))
        nvgText(nvg, cx + offX + i * 10, cy + offY - i * 5, "Z", nil)
    end
end

return RestScene
