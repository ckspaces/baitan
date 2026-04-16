-- ============================================================================
-- OfficeScene.lua - 工作室/起步场景（默认场景）
-- ============================================================================

local OfficeScene = {}

function OfficeScene.draw(nvg, x, y, w, h, gs, animTime)
    -- 天空渐变（根据时间段变化）
    local dayPhase = (gs.currentDay - 1) / 4  -- 0~0.75
    local skyTop, skyBot
    if dayPhase < 0.25 then
        -- 早晨
        skyTop = nvgRGBA(135, 190, 235, 255)
        skyBot = nvgRGBA(200, 220, 245, 255)
    elseif dayPhase < 0.5 then
        -- 下午
        skyTop = nvgRGBA(100, 160, 220, 255)
        skyBot = nvgRGBA(180, 200, 230, 255)
    else
        -- 傍晚
        skyTop = nvgRGBA(60, 80, 140, 255)
        skyBot = nvgRGBA(140, 100, 120, 255)
    end

    -- 天空
    local sky = nvgLinearGradient(nvg, x, y, x, y + h * 0.5, skyTop, skyBot)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h * 0.5)
    nvgFillPaint(nvg, sky)
    nvgFill(nvg)

    -- 云朵
    OfficeScene.drawClouds(nvg, x, y, w, h, animTime)

    -- 地面
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.5, w, h * 0.5)
    nvgFillColor(nvg, nvgRGBA(60, 65, 80, 255))
    nvgFill(nvg)

    -- 街道
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.72, w, h * 0.06)
    nvgFillColor(nvg, nvgRGBA(75, 75, 85, 255))
    nvgFill(nvg)
    -- 道路虚线
    nvgStrokeColor(nvg, nvgRGBA(200, 200, 180, 80))
    nvgStrokeWidth(nvg, 1)
    local dashOffset = (animTime * 20) % 20
    for dx = -dashOffset, w, 20 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x + dx, y + h * 0.75)
        nvgLineTo(nvg, x + dx + 8, y + h * 0.75)
        nvgStroke(nvg)
    end

    -- 远处楼群
    OfficeScene.drawBuildings(nvg, x, y, w, h)

    -- 小房间/出租屋
    OfficeScene.drawRoom(nvg, x, y, w, h, gs, animTime)
end

--- 绘制云朵
function OfficeScene.drawClouds(nvg, x, y, w, h, animTime)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 50))
    local cloudY = y + h * 0.12
    for i = 1, 3 do
        local cx = x + ((i * 130 + animTime * 8) % (w + 60)) - 30
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, cloudY + i * 20, 30 + i * 5, 10)
        nvgEllipse(nvg, cx + 20, cloudY + i * 20 - 5, 20, 8)
        nvgEllipse(nvg, cx - 15, cloudY + i * 20 + 3, 18, 7)
        nvgFill(nvg)
    end
end

--- 绘制远处楼群
function OfficeScene.drawBuildings(nvg, x, y, w, h)
    local baseY = y + h * 0.5
    local buildings = {
        { x = 0.05, w = 0.08, h = 0.18, c = { 50, 55, 75 } },
        { x = 0.14, w = 0.06, h = 0.25, c = { 55, 60, 80 } },
        { x = 0.22, w = 0.1,  h = 0.15, c = { 45, 50, 70 } },
        { x = 0.35, w = 0.07, h = 0.22, c = { 60, 65, 85 } },
        { x = 0.55, w = 0.09, h = 0.2,  c = { 50, 55, 75 } },
        { x = 0.66, w = 0.06, h = 0.28, c = { 55, 58, 78 } },
        { x = 0.75, w = 0.1,  h = 0.16, c = { 48, 52, 72 } },
        { x = 0.88, w = 0.08, h = 0.23, c = { 52, 56, 76 } },
    }
    for _, b in ipairs(buildings) do
        local bx = x + w * b.x
        local bw = w * b.w
        local bh = h * b.h
        local by = baseY - bh
        nvgBeginPath(nvg)
        nvgRect(nvg, bx, by, bw, bh)
        nvgFillColor(nvg, nvgRGBA(b.c[1], b.c[2], b.c[3], 255))
        nvgFill(nvg)
        -- 窗户
        nvgFillColor(nvg, nvgRGBA(255, 230, 150, 60))
        local winW = bw * 0.2
        local winH = bh * 0.06
        for wy = by + bh * 0.1, by + bh * 0.85, bh * 0.12 do
            for wx = bx + bw * 0.15, bx + bw * 0.75, bw * 0.3 do
                nvgBeginPath(nvg)
                nvgRect(nvg, wx, wy, winW, winH)
                nvgFill(nvg)
            end
        end
    end
end

--- 绘制出租屋小房间
function OfficeScene.drawRoom(nvg, x, y, w, h, gs, animTime)
    local roomX = x + w * 0.2
    local roomY = y + h * 0.42
    local roomW = w * 0.6
    local roomH = h * 0.28

    -- 房间墙壁
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, roomX, roomY, roomW, roomH, 3)
    nvgFillColor(nvg, nvgRGBA(85, 80, 100, 220))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(100, 95, 115, 255))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 窗户
    local winX = roomX + roomW * 0.65
    local winY = roomY + 8
    local winW = roomW * 0.25
    local winH = roomH * 0.35
    nvgBeginPath(nvg)
    nvgRect(nvg, winX, winY, winW, winH)
    nvgFillColor(nvg, nvgRGBA(150, 190, 230, 180))
    nvgFill(nvg)
    -- 窗框
    nvgStrokeColor(nvg, nvgRGBA(120, 115, 130, 255))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, winX + winW / 2, winY)
    nvgLineTo(nvg, winX + winW / 2, winY + winH)
    nvgStroke(nvg)

    -- 地板
    nvgBeginPath(nvg)
    nvgRect(nvg, roomX, roomY + roomH - 4, roomW, 4)
    nvgFillColor(nvg, nvgRGBA(120, 100, 70, 255))
    nvgFill(nvg)

    -- 门
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, roomX + 5, roomY + roomH * 0.4, roomW * 0.15, roomH * 0.58, 2)
    nvgFillColor(nvg, nvgRGBA(140, 100, 60, 255))
    nvgFill(nvg)
    -- 门把手
    nvgBeginPath(nvg)
    nvgCircle(nvg, roomX + 5 + roomW * 0.12, roomY + roomH * 0.7, 2)
    nvgFillColor(nvg, nvgRGBA(200, 180, 100, 255))
    nvgFill(nvg)

    -- 招牌文字
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 9)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
    nvgFillColor(nvg, nvgRGBA(200, 200, 220, 180))
    nvgText(nvg, roomX + roomW / 2, roomY - 3, "我的出租屋", nil)
end

return OfficeScene
