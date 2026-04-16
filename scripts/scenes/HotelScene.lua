-- ============================================================================
-- HotelScene.lua - 大酒店场景（豪华大堂、旋转门、水晶吊灯）
-- ============================================================================

local HotelScene = {}

--- 主绘制入口
function HotelScene.draw(nvg, x, y, w, h, gs, animTime)
    -- 室内大堂背景
    HotelScene.drawLobby(nvg, x, y, w, h, animTime)

    -- 大理石地板
    HotelScene.drawFloor(nvg, x, y, w, h, animTime)

    -- 前台
    HotelScene.drawReception(nvg, x, y, w, h, gs, animTime)

    -- 水晶吊灯
    HotelScene.drawChandelier(nvg, x, y, w, h, animTime)

    -- 装饰柱
    HotelScene.drawPillars(nvg, x, y, w, h)

    -- 盆栽装饰
    HotelScene.drawPlants(nvg, x, y, w, h)

    -- 客人
    HotelScene.drawGuests(nvg, x, y, w, h, gs, animTime)
end

--- 大堂墙面
function HotelScene.drawLobby(nvg, x, y, w, h, animTime)
    -- 墙面（暖色调奢华感）
    local wall = nvgLinearGradient(nvg, x, y, x, y + h * 0.6,
        nvgRGBA(60, 45, 30, 255), nvgRGBA(45, 35, 25, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h * 0.6)
    nvgFillPaint(nvg, wall)
    nvgFill(nvg)

    -- 壁纸花纹（隐约金色）
    nvgGlobalAlpha(nvg, 0.08)
    nvgFillColor(nvg, nvgRGBA(255, 210, 120, 255))
    for row = 0, 5 do
        for col = 0, 12 do
            local px = x + col * 35 + (row % 2) * 17
            local py = y + row * 30 + 10
            nvgBeginPath(nvg)
            nvgCircle(nvg, px, py, 4)
            nvgFill(nvg)
        end
    end
    nvgGlobalAlpha(nvg, 1)

    -- 天花线脚
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.02, w, 3)
    nvgFillColor(nvg, nvgRGBA(200, 170, 100, 180))
    nvgFill(nvg)

    -- 腰线
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.35, w, 2)
    nvgFillColor(nvg, nvgRGBA(180, 150, 80, 120))
    nvgFill(nvg)
end

--- 大理石地板
function HotelScene.drawFloor(nvg, x, y, w, h, animTime)
    -- 大理石基色
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.6, w, h * 0.4)
    nvgFillColor(nvg, nvgRGBA(200, 195, 185, 255))
    nvgFill(nvg)

    -- 棋盘格纹
    local tileSize = w / 10
    for row = 0, 4 do
        for col = 0, 10 do
            if (row + col) % 2 == 0 then
                nvgBeginPath(nvg)
                nvgRect(nvg, x + col * tileSize, y + h * 0.6 + row * tileSize * 0.6,
                    tileSize, tileSize * 0.6)
                nvgFillColor(nvg, nvgRGBA(170, 165, 155, 255))
                nvgFill(nvg)
            end
        end
    end

    -- 地板反光
    local reflection = nvgLinearGradient(nvg, x, y + h * 0.6, x, y + h,
        nvgRGBA(255, 255, 255, 30), nvgRGBA(255, 255, 255, 0))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.6, w, h * 0.4)
    nvgFillPaint(nvg, reflection)
    nvgFill(nvg)
end

--- 前台
function HotelScene.drawReception(nvg, x, y, w, h, gs, animTime)
    local rx = x + w * 0.30
    local ry = y + h * 0.50
    local rw = w * 0.40
    local rh = h * 0.12

    -- 前台桌面（深色木质）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, rx, ry, rw, rh, 4)
    nvgFillColor(nvg, nvgRGBA(70, 40, 25, 240))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(140, 100, 50, 200))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)

    -- 金色边线
    nvgBeginPath(nvg)
    nvgRect(nvg, rx + 2, ry + 2, rw - 4, 2)
    nvgFillColor(nvg, nvgRGBA(210, 180, 100, 200))
    nvgFill(nvg)

    -- 酒店名字
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 11)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 220, 130, 230))
    nvgText(nvg, rx + rw * 0.5, ry + rh * 0.5, "🏨 Grand Hotel", nil)

    -- 前台服务员
    local sx = rx + rw * 0.5
    local sy = ry - 2
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, sx - 4, sy - 16, 8, 16, 2)
    nvgFillColor(nvg, nvgRGBA(30, 30, 60, 230))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, sx, sy - 20, 4)
    nvgFillColor(nvg, nvgRGBA(255, 220, 185, 230))
    nvgFill(nvg)
end

--- 水晶吊灯
function HotelScene.drawChandelier(nvg, x, y, w, h, animTime)
    local cx = x + w * 0.50
    local cy = y + h * 0.08

    -- 吊链
    nvgStrokeColor(nvg, nvgRGBA(200, 180, 120, 200))
    nvgStrokeWidth(nvg, 1.5)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx, y)
    nvgLineTo(nvg, cx, cy)
    nvgStroke(nvg)

    -- 主体框架
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, cy + 4, 25, 6)
    nvgFillColor(nvg, nvgRGBA(200, 180, 120, 200))
    nvgFill(nvg)

    -- 水晶灯珠（闪烁）
    for i = 1, 8 do
        local angle = (i - 1) * math.pi * 2 / 8
        local px = cx + math.cos(angle) * 20
        local py = cy + 4 + math.sin(angle) * 5 + 8
        local sparkle = math.sin(animTime * 4 + i * 0.9) * 0.3 + 0.7

        -- 水晶小灯
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 2)
        nvgFillColor(nvg, nvgRGBA(255, 250, 220, math.floor(sparkle * 255)))
        nvgFill(nvg)

        -- 光芒
        local glow = nvgRadialGradient(nvg, px, py, 1, 10,
            nvgRGBA(255, 240, 180, math.floor(sparkle * 40)),
            nvgRGBA(255, 240, 180, 0))
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, py, 10)
        nvgFillPaint(nvg, glow)
        nvgFill(nvg)
    end

    -- 中心大灯光
    local centerGlow = nvgRadialGradient(nvg, cx, cy + 8, 5, 60,
        nvgRGBA(255, 240, 180, 50), nvgRGBA(255, 240, 180, 0))
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy + 8, 60)
    nvgFillPaint(nvg, centerGlow)
    nvgFill(nvg)
end

--- 装饰柱
function HotelScene.drawPillars(nvg, x, y, w, h)
    local pillars = { 0.08, 0.92 }
    for _, px in ipairs(pillars) do
        local pillarX = x + w * px
        local pillarW = 10

        -- 柱身
        nvgBeginPath(nvg)
        nvgRect(nvg, pillarX - pillarW / 2, y + h * 0.05, pillarW, h * 0.55)
        nvgFillColor(nvg, nvgRGBA(180, 170, 150, 240))
        nvgFill(nvg)

        -- 柱头
        nvgBeginPath(nvg)
        nvgRect(nvg, pillarX - pillarW / 2 - 3, y + h * 0.05, pillarW + 6, 5)
        nvgFillColor(nvg, nvgRGBA(200, 180, 120, 220))
        nvgFill(nvg)

        -- 柱基
        nvgBeginPath(nvg)
        nvgRect(nvg, pillarX - pillarW / 2 - 3, y + h * 0.58, pillarW + 6, 5)
        nvgFillColor(nvg, nvgRGBA(200, 180, 120, 220))
        nvgFill(nvg)
    end
end

--- 盆栽装饰
function HotelScene.drawPlants(nvg, x, y, w, h)
    local plants = { 0.18, 0.82 }
    for _, px in ipairs(plants) do
        local plantX = x + w * px
        local plantY = y + h * 0.58

        -- 花盆
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, plantX - 6, plantY)
        nvgLineTo(nvg, plantX + 6, plantY)
        nvgLineTo(nvg, plantX + 5, plantY + 10)
        nvgLineTo(nvg, plantX - 5, plantY + 10)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(150, 100, 60, 230))
        nvgFill(nvg)

        -- 植物
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 16)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgText(nvg, plantX, plantY, "🌿", nil)
    end
end

--- 客人（穿着较为正式）
function HotelScene.drawGuests(nvg, x, y, w, h, gs, animTime)
    local guests = {
        { rx = 0.20, dir = 1 },
        { rx = 0.65, dir = -1 },
        { rx = 0.45, dir = 1 },
    }
    for i, g in ipairs(guests) do
        local gx = x + w * g.rx + math.sin(animTime * 0.5 + i * 2) * 10
        local gy = y + h * 0.68

        -- 身体（深色正装）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, gx - 4, gy - 16, 8, 16, 2)
        nvgFillColor(nvg, nvgRGBA(30, 30, 45, 230))
        nvgFill(nvg)

        -- 头
        nvgBeginPath(nvg)
        nvgCircle(nvg, gx, gy - 20, 4.5)
        nvgFillColor(nvg, nvgRGBA(255, 218, 185, 230))
        nvgFill(nvg)

        -- 腿
        local legSwing = math.sin(animTime * 3 + i * 1.5) * 2
        nvgStrokeColor(nvg, nvgRGBA(30, 30, 45, 200))
        nvgStrokeWidth(nvg, 2)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, gx - 1, gy)
        nvgLineTo(nvg, gx - 1 + legSwing, gy + 8)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, gx + 1, gy)
        nvgLineTo(nvg, gx + 1 - legSwing, gy + 8)
        nvgStroke(nvg)
    end
end

return HotelScene
