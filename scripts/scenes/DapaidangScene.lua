-- ============================================================================
-- DapaidangScene.lua - 大排档场景（露天棚、塑料桌椅、烟火升级版）
-- ============================================================================

local DapaidangScene = {}

-- 食客数据
local diners_ = {}
local DINER_COUNT = 6

local function initDiners(w, h)
    diners_ = {}
    for i = 1, DINER_COUNT do
        diners_[i] = {
            tableX = w * (0.12 + (i - 1) * 0.14),
            seated = math.random() > 0.3,
            bodyColor = {
                math.random(100, 230),
                math.random(80, 200),
                math.random(80, 220),
            },
            eating = math.random() > 0.4,
            emoji = ({ "😋", "🍺", "🤤", "😆", "👍" })[math.random(1, 5)],
        }
    end
end

--- 主绘制入口
function DapaidangScene.draw(nvg, x, y, w, h, gs, animTime)
    if #diners_ == 0 then initDiners(w, h) end

    local dayPhase = (gs.currentDay - 1) / 4

    -- 天空（傍晚暖色调为主）
    DapaidangScene.drawSky(nvg, x, y, w, h, dayPhase, animTime)

    -- 背景楼房
    DapaidangScene.drawBackground(nvg, x, y, w, h, dayPhase)

    -- 地面
    DapaidangScene.drawGround(nvg, x, y, w, h, dayPhase)

    -- 大棚
    DapaidangScene.drawCanopy(nvg, x, y, w, h, animTime)

    -- 桌椅和食客
    DapaidangScene.drawTablesAndDiners(nvg, x, y, w, h, gs, animTime)

    -- 炉灶区（左侧）
    DapaidangScene.drawKitchen(nvg, x, y, w, h, gs, animTime)

    -- 灯笼装饰
    DapaidangScene.drawLanterns(nvg, x, y, w, h, animTime)

    -- 烟气
    if gs.currentActivity == "stalling" then
        DapaidangScene.drawSmoke(nvg, x, y, w, h, animTime)
    end
end

--- 天空
function DapaidangScene.drawSky(nvg, x, y, w, h, dayPhase, animTime)
    local skyTop, skyBot
    if dayPhase < 0.5 then
        skyTop = nvgRGBA(100, 150, 210, 255)
        skyBot = nvgRGBA(200, 190, 170, 255)
    else
        skyTop = nvgRGBA(30, 35, 70, 255)
        skyBot = nvgRGBA(60, 40, 50, 255)
    end
    local sky = nvgLinearGradient(nvg, x, y, x, y + h * 0.4, skyTop, skyBot)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h * 0.4)
    nvgFillPaint(nvg, sky)
    nvgFill(nvg)
end

--- 背景
function DapaidangScene.drawBackground(nvg, x, y, w, h, dayPhase)
    local isNight = dayPhase >= 0.5
    local baseY = y + h * 0.4
    local bldgs = {
        { rx = 0.0,  rw = 0.12, rh = 0.18 },
        { rx = 0.14, rw = 0.08, rh = 0.14 },
        { rx = 0.80, rw = 0.10, rh = 0.20 },
        { rx = 0.92, rw = 0.08, rh = 0.12 },
    }
    for _, b in ipairs(bldgs) do
        nvgBeginPath(nvg)
        nvgRect(nvg, x + w * b.rx, baseY - h * b.rh, w * b.rw, h * b.rh)
        nvgFillColor(nvg, isNight and nvgRGBA(25, 25, 40, 255) or nvgRGBA(70, 72, 85, 255))
        nvgFill(nvg)
    end
end

--- 地面
function DapaidangScene.drawGround(nvg, x, y, w, h, dayPhase)
    local isNight = dayPhase >= 0.5
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.55, w, h * 0.45)
    nvgFillColor(nvg, isNight and nvgRGBA(35, 35, 42, 255) or nvgRGBA(90, 85, 75, 255))
    nvgFill(nvg)

    -- 水泥地
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.60, w, h * 0.40)
    nvgFillColor(nvg, isNight and nvgRGBA(42, 42, 48, 255) or nvgRGBA(105, 100, 92, 255))
    nvgFill(nvg)
end

--- 大棚遮阳篷
function DapaidangScene.drawCanopy(nvg, x, y, w, h, animTime)
    local canopyY = y + h * 0.38
    local canopyH = h * 0.08
    -- 蓝色彩条棚
    local stripeW = w / 10
    for i = 0, 9 do
        nvgBeginPath(nvg)
        nvgRect(nvg, x + i * stripeW, canopyY, stripeW, canopyH)
        if i % 2 == 0 then
            nvgFillColor(nvg, nvgRGBA(50, 100, 180, 220))
        else
            nvgFillColor(nvg, nvgRGBA(240, 240, 235, 220))
        end
        nvgFill(nvg)
    end
    -- 棚底边弧形
    nvgBeginPath(nvg)
    for i = 0, 9 do
        local cx = x + i * stripeW + stripeW * 0.5
        nvgArc(nvg, cx, canopyY + canopyH, stripeW * 0.5, 0, math.rad(180), 1)
    end
    nvgFillColor(nvg, nvgRGBA(50, 100, 180, 60))
    nvgFill(nvg)

    -- 棚柱
    nvgFillColor(nvg, nvgRGBA(120, 120, 130, 255))
    local posts = { 0.02, 0.50, 0.96 }
    for _, px in ipairs(posts) do
        nvgBeginPath(nvg)
        nvgRect(nvg, x + w * px, canopyY + canopyH, 3, h * 0.25)
        nvgFill(nvg)
    end
end

--- 桌椅和食客
function DapaidangScene.drawTablesAndDiners(nvg, x, y, w, h, gs, animTime)
    for i, d in ipairs(diners_) do
        local tx = x + d.tableX
        local ty = y + h * 0.62

        -- 圆桌
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, tx - 12, ty, 24, 12, 3)
        nvgFillColor(nvg, nvgRGBA(200, 200, 210, 220))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(150, 150, 160, 200))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)

        -- 桌上食物
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 10)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        local foods = { "🍲", "🍖", "🍺", "🦞", "🥘" }
        nvgText(nvg, tx, ty + 5, foods[(i % #foods) + 1], nil)

        -- 食客
        if d.seated then
            local px = tx - 1
            local py = ty - 2
            local bodyH = 13

            -- 身体
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, px - 3, py - bodyH, 6, bodyH, 2)
            nvgFillColor(nvg, nvgRGBA(d.bodyColor[1], d.bodyColor[2], d.bodyColor[3], 220))
            nvgFill(nvg)

            -- 头
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py - bodyH - 4, 4)
            nvgFillColor(nvg, nvgRGBA(255, 220, 185, 220))
            nvgFill(nvg)

            -- 吃饭表情
            if d.eating then
                local bounce = math.sin(animTime * 3 + i * 1.2) * 2
                nvgFontSize(nvg, 10)
                nvgText(nvg, px, py - bodyH - 12 + bounce, d.emoji, nil)
            end
        end
    end
end

--- 炉灶区
function DapaidangScene.drawKitchen(nvg, x, y, w, h, gs, animTime)
    local kx = x + w * 0.78
    local ky = y + h * 0.52

    -- 灶台
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, kx, ky, w * 0.18, h * 0.12, 3)
    nvgFillColor(nvg, nvgRGBA(80, 80, 90, 240))
    nvgFill(nvg)

    -- 火焰
    for i = 1, 3 do
        local fx = kx + w * 0.04 + (i - 1) * w * 0.05
        local fy = ky - 2
        local flicker = math.sin(animTime * 8 + i * 2) * 2
        nvgBeginPath(nvg)
        nvgEllipse(nvg, fx, fy + flicker, 4, 6)
        nvgFillColor(nvg, nvgRGBA(255, 160 + math.floor(flicker * 20), 40, 200))
        nvgFill(nvg)
    end

    -- 锅
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 16)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgText(nvg, kx + w * 0.09, ky + h * 0.06, "🍳", nil)
end

--- 灯笼
function DapaidangScene.drawLanterns(nvg, x, y, w, h, animTime)
    local lanterns = { 0.15, 0.35, 0.55, 0.75 }
    for i, lx in ipairs(lanterns) do
        local px = x + w * lx
        local py = y + h * 0.40
        local swing = math.sin(animTime * 1.5 + i * 1.1) * 2

        -- 灯笼线
        nvgStrokeColor(nvg, nvgRGBA(100, 100, 100, 150))
        nvgStrokeWidth(nvg, 1)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, px, py)
        nvgLineTo(nvg, px + swing, py + 12)
        nvgStroke(nvg)

        -- 灯笼体
        nvgBeginPath(nvg)
        nvgEllipse(nvg, px + swing, py + 18, 6, 8)
        nvgFillColor(nvg, nvgRGBA(220, 50, 30, 230))
        nvgFill(nvg)

        -- 发光
        local glow = nvgRadialGradient(nvg, px + swing, py + 18, 3, 20,
            nvgRGBA(255, 200, 100, 40), nvgRGBA(255, 200, 100, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, px + swing, py + 18, 20)
        nvgFillPaint(nvg, glow)
        nvgFill(nvg)
    end
end

--- 烟气效果
function DapaidangScene.drawSmoke(nvg, x, y, w, h, animTime)
    local smokeX = x + w * 0.82
    local baseY = y + h * 0.50
    for i = 1, 6 do
        local phase = (animTime * 0.6 + i * 0.5) % 2.5
        local sy = baseY - phase * h * 0.15
        local alpha = math.max(0, 1.0 - phase / 2.5) * 80
        local radius = 4 + phase * 5
        local drift = math.sin(animTime + i) * 5
        nvgBeginPath(nvg)
        nvgCircle(nvg, smokeX + drift, sy, radius)
        nvgFillColor(nvg, nvgRGBA(200, 200, 210, math.floor(alpha)))
        nvgFill(nvg)
    end
end

return DapaidangScene
