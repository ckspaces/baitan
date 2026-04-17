-- ============================================================================
-- CharacterRenderer.lua - 卡通人物绘制（多种状态）
-- ============================================================================

local CharacterRenderer = {}

--- 主绘制入口
function CharacterRenderer.draw(nvg, sx, sy, sw, sh, gs, animTime)
    -- 角色位置：场景中下方（比例与行人协调）
    local cx = sx + sw * 0.5
    local cy = sy + sh * 0.68
    local scale = math.min(math.min(sw, sh) / 400, 0.45)

    -- 根据活动调整位置
    if gs.currentActivity == "resting" then
        cy = sy + sh * 0.75  -- 休息时更低
    end

    -- 身体微微呼吸动画
    local breathe = math.sin(animTime * 2) * 1.5 * scale

    -- 绘制阴影
    CharacterRenderer.drawShadow(nvg, cx, cy + 30 * scale, scale)

    -- 绘制腿
    CharacterRenderer.drawLegs(nvg, cx, cy, scale, gs, animTime)

    -- 绘制身体
    CharacterRenderer.drawBody(nvg, cx, cy + breathe, scale, gs)

    -- 绘制手臂
    CharacterRenderer.drawArms(nvg, cx, cy + breathe, scale, gs, animTime)

    -- 绘制头
    CharacterRenderer.drawHead(nvg, cx, cy - 55 * scale + breathe, scale, gs, animTime)

    -- 绘制道具
    CharacterRenderer.drawProps(nvg, cx, cy + breathe, scale, gs, animTime)
end

--- 绘制阴影
function CharacterRenderer.drawShadow(nvg, cx, cy, scale)
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx, cy, 20 * scale, 5 * scale)
    nvgFillColor(nvg, nvgRGBA(0, 0, 0, 40))
    nvgFill(nvg)
end

--- 绘制头部
function CharacterRenderer.drawHead(nvg, cx, cy, scale, gs, animTime)
    local headR = 18 * scale
    local weather = gs.currentWeather or 'sunny'
    local isSnowy = weather == 'snowy'

    -- 头（圆形）
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx, cy, headR)
    nvgFillColor(nvg, nvgRGBA(255, 220, 185, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(200, 170, 140, 255))
    nvgStrokeWidth(nvg, 1.5 * scale)
    nvgStroke(nvg)

    -- 头发
    nvgBeginPath(nvg)
    nvgArc(nvg, cx, cy, headR, math.rad(-160), math.rad(-20), 1)
    nvgLineTo(nvg, cx + headR * 0.7, cy - headR * 0.5)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(40, 30, 25, 255))
    nvgFill(nvg)

    if isSnowy then
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, cy - headR * 0.85, headR * 1.05, headR * 0.32)
        nvgFillColor(nvg, nvgRGBA(70, 90, 120, 240))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - headR * 0.78, cy - headR * 1.65, headR * 1.56, headR * 0.9, headR * 0.32)
        nvgFillColor(nvg, nvgRGBA(92, 120, 160, 245))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx, cy - headR * 1.75, headR * 0.18)
        nvgFillColor(nvg, nvgRGBA(235, 240, 250, 220))
        nvgFill(nvg)
    end

    -- 表情
    if gs.mood > 60 then
        CharacterRenderer.drawHappyFace(nvg, cx, cy, scale)
    elseif gs.mood > 30 then
        CharacterRenderer.drawNeutralFace(nvg, cx, cy, scale)
    else
        CharacterRenderer.drawSadFace(nvg, cx, cy, scale)
    end
end

--- 开心表情
function CharacterRenderer.drawHappyFace(nvg, cx, cy, scale)
    -- 眼睛（弯弯的）
    nvgStrokeColor(nvg, nvgRGBA(40, 30, 25, 255))
    nvgStrokeWidth(nvg, 1.5 * scale)
    for _, dx in ipairs({ -6, 6 }) do
        nvgBeginPath(nvg)
        nvgArc(nvg, cx + dx * scale, cy - 2 * scale, 3 * scale, math.rad(200), math.rad(340), 1)
        nvgStroke(nvg)
    end
    -- 嘴巴（微笑）
    nvgBeginPath(nvg)
    nvgArc(nvg, cx, cy + 6 * scale, 6 * scale, math.rad(20), math.rad(160), 1)
    nvgStroke(nvg)
    -- 腮红
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx - 10 * scale, cy + 3 * scale, 4 * scale, 2.5 * scale)
    nvgFillColor(nvg, nvgRGBA(255, 150, 130, 60))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgEllipse(nvg, cx + 10 * scale, cy + 3 * scale, 4 * scale, 2.5 * scale)
    nvgFill(nvg)
end

--- 平静表情
function CharacterRenderer.drawNeutralFace(nvg, cx, cy, scale)
    -- 眼睛（小圆点）
    nvgFillColor(nvg, nvgRGBA(40, 30, 25, 255))
    for _, dx in ipairs({ -6, 6 }) do
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx + dx * scale, cy - 2 * scale, 2 * scale)
        nvgFill(nvg)
    end
    -- 嘴巴（一字）
    nvgStrokeColor(nvg, nvgRGBA(40, 30, 25, 255))
    nvgStrokeWidth(nvg, 1.5 * scale)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - 4 * scale, cy + 7 * scale)
    nvgLineTo(nvg, cx + 4 * scale, cy + 7 * scale)
    nvgStroke(nvg)
end

--- 沮丧表情
function CharacterRenderer.drawSadFace(nvg, cx, cy, scale)
    -- 眼睛（向下看）
    nvgFillColor(nvg, nvgRGBA(40, 30, 25, 255))
    for _, dx in ipairs({ -6, 6 }) do
        nvgBeginPath(nvg)
        nvgCircle(nvg, cx + dx * scale, cy, 2 * scale)
        nvgFill(nvg)
    end
    -- 嘴巴（倒弧）
    nvgStrokeColor(nvg, nvgRGBA(40, 30, 25, 255))
    nvgStrokeWidth(nvg, 1.5 * scale)
    nvgBeginPath(nvg)
    nvgArc(nvg, cx, cy + 12 * scale, 5 * scale, math.rad(200), math.rad(340), 1)
    nvgStroke(nvg)
    -- 眉毛下垂
    for _, dx in ipairs({ -1, 1 }) do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx + (dx * 3) * scale, cy - 7 * scale)
        nvgLineTo(nvg, cx + (dx * 9) * scale, cy - 5 * scale)
        nvgStroke(nvg)
    end
end

--- 绘制身体
function CharacterRenderer.drawBody(nvg, cx, cy, scale, gs)
    local colors = {
        office    = { 70, 100, 160 },
        shop      = { 200, 80, 60 },
        livestream = { 180, 60, 180 },
        rest      = { 100, 140, 100 },
        overseas  = { 160, 140, 80 },
        stall     = { 220, 120, 40 },
    }
    local c = colors[gs.currentScene] or colors.office
    local weather = gs.currentWeather or 'sunny'
    local isSnowy = weather == 'snowy'

    if isSnowy then
        c = {
            math.max(40, c[1] - 55),
            math.max(50, c[2] - 35),
            math.max(60, c[3] - 10),
        }
    end

    -- 上衣
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx - 14 * scale, cy - 35 * scale, 28 * scale, 38 * scale, 4 * scale)
    nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(c[1] - 20, c[2] - 20, c[3] - 20, 255))
    nvgStrokeWidth(nvg, 1 * scale)
    nvgStroke(nvg)

    -- 领口
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx - 5 * scale, cy - 35 * scale)
    nvgLineTo(nvg, cx, cy - 28 * scale)
    nvgLineTo(nvg, cx + 5 * scale, cy - 35 * scale)
    nvgFillColor(nvg, nvgRGBA(240, 235, 220, 255))
    nvgFill(nvg)

    if isSnowy then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - 17 * scale, cy - 37 * scale, 34 * scale, 42 * scale, 6 * scale)
        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 210))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(math.max(0, c[1] - 25), math.max(0, c[2] - 25), math.max(0, c[3] - 25), 220))
        nvgStrokeWidth(nvg, 1.2 * scale)
        nvgStroke(nvg)

        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - 9 * scale, cy - 33 * scale, 18 * scale, 7 * scale, 3 * scale)
        nvgFillColor(nvg, nvgRGBA(225, 80, 70, 235))
        nvgFill(nvg)
    end
end

--- 绘制腿
function CharacterRenderer.drawLegs(nvg, cx, cy, scale, gs, animTime)
    local isResting = gs.currentActivity == "resting"

    if isResting then
        -- 休息时腿伸直
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - 12 * scale, cy + 3 * scale, 10 * scale, 28 * scale, 3 * scale)
        nvgFillColor(nvg, nvgRGBA(50, 55, 85, 255))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx + 2 * scale, cy + 3 * scale, 10 * scale, 28 * scale, 3 * scale)
        nvgFill(nvg)
    else
        -- 站立
        nvgFillColor(nvg, nvgRGBA(50, 55, 85, 255))
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - 10 * scale, cy + 3 * scale, 8 * scale, 25 * scale, 2 * scale)
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx + 2 * scale, cy + 3 * scale, 8 * scale, 25 * scale, 2 * scale)
        nvgFill(nvg)
    end

    -- 鞋子
    nvgFillColor(nvg, nvgRGBA(60, 40, 30, 255))
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx - 12 * scale, cy + 27 * scale, 12 * scale, 5 * scale, 2 * scale)
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, cx + 0 * scale, cy + 27 * scale, 12 * scale, 5 * scale, 2 * scale)
    nvgFill(nvg)
end

--- 绘制手臂
function CharacterRenderer.drawArms(nvg, cx, cy, scale, gs, animTime)
    local activity = gs.currentActivity
    local weather = gs.currentWeather or 'sunny'
    local armWeatherFactor = (weather == 'snowy' or weather == 'rainy' or weather == 'stormy') and 0.7 or 1.0

    if weather == 'rainy' or weather == 'stormy' then
        local umbX = cx + 6 * scale
        local umbTopY = cy - 82 * scale
        local umbR = 24 * scale
        local canopyBottomY = umbTopY + umbR * 0.68

        nvgStrokeColor(nvg, nvgRGBA(90, 70, 45, 220))
        nvgStrokeWidth(nvg, 2.0 * scale)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, umbX, cy - 14 * scale)
        nvgLineTo(nvg, umbX, umbTopY)
        nvgStroke(nvg)

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, umbX - umbR, canopyBottomY)
        nvgQuadTo(nvg, umbX - umbR * 0.72, umbTopY - umbR * 0.25, umbX, umbTopY - umbR * 0.95)
        nvgQuadTo(nvg, umbX + umbR * 0.72, umbTopY - umbR * 0.25, umbX + umbR, canopyBottomY)
        nvgQuadTo(nvg, umbX + umbR * 0.45, umbTopY + umbR * 0.32, umbX, canopyBottomY - umbR * 0.12)
        nvgQuadTo(nvg, umbX - umbR * 0.45, umbTopY + umbR * 0.32, umbX - umbR, canopyBottomY)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(70, 110, 185, 220))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(40, 70, 120, 230))
        nvgStrokeWidth(nvg, 1.2 * scale)
        nvgStroke(nvg)
    end
    nvgStrokeColor(nvg, nvgRGBA(255, 220, 185, 255))
    nvgStrokeWidth(nvg, 5 * scale)
    nvgLineCap(nvg, NVG_ROUND)

    if activity == "stalling" then
        -- 摆摊：双手前伸招揽，上下翻动
        local flip = math.sin(animTime * 3) * 8
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - 14 * scale, cy - 25 * scale)
        nvgLineTo(nvg, cx - 28 * scale, cy - 15 * scale + flip * scale * 0.1)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx + 14 * scale, cy - 25 * scale)
        nvgLineTo(nvg, cx + 28 * scale, cy - 15 * scale - flip * scale * 0.1)
        nvgStroke(nvg)
    elseif activity == "working" or activity == "studying" then
        -- 手臂向前伸（打字/写字）
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - 14 * scale, cy - 25 * scale)
        nvgLineTo(nvg, cx - 22 * scale, cy - 10 * scale)
        nvgLineTo(nvg, cx - 15 * scale, cy - 5 * scale)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx + 14 * scale, cy - 25 * scale)
        nvgLineTo(nvg, cx + 22 * scale, cy - 10 * scale)
        nvgLineTo(nvg, cx + 15 * scale, cy - 5 * scale)
        nvgStroke(nvg)
    elseif activity == "streaming" then
        -- 直播：一只手挥舞
        local wave = math.sin(animTime * 4) * 15
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - 14 * scale, cy - 25 * scale)
        nvgLineTo(nvg, cx - 25 * scale, cy - 15 * scale)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx + 14 * scale, cy - 25 * scale)
        nvgLineTo(nvg, cx + 28 * scale, cy - 35 * scale + wave * scale * 0.1)
        nvgStroke(nvg)
    else
        -- 默认自然下垂，轻微摆动
        local swing = math.sin(animTime * 1.5) * 3 * scale * armWeatherFactor
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - 14 * scale, cy - 25 * scale)
        nvgLineTo(nvg, cx - 18 * scale + swing, cy - 5 * scale)
        nvgStroke(nvg)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx + 14 * scale, cy - 25 * scale)
        nvgLineTo(nvg, cx + 18 * scale - swing, cy - 5 * scale)
        nvgStroke(nvg)
    end
end

--- 绘制道具
function CharacterRenderer.drawProps(nvg, cx, cy, scale, gs, animTime)
    local activity = gs.currentActivity

    if activity == "working" or activity == "studying" then
        -- 桌子
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - 30 * scale, cy - 8 * scale, 60 * scale, 5 * scale, 2 * scale)
        nvgFillColor(nvg, nvgRGBA(160, 120, 80, 255))
        nvgFill(nvg)
        -- 笔记本电脑
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx - 12 * scale, cy - 18 * scale, 24 * scale, 10 * scale, 1 * scale)
        nvgFillColor(nvg, nvgRGBA(80, 80, 90, 255))
        nvgFill(nvg)
        -- 屏幕
        nvgBeginPath(nvg)
        nvgRect(nvg, cx - 10 * scale, cy - 17 * scale, 20 * scale, 8 * scale)
        nvgFillColor(nvg, nvgRGBA(180, 220, 255, 200))
        nvgFill(nvg)

    elseif activity == "streaming" then
        -- 手机/摄像头
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, cx + 30 * scale, cy - 45 * scale, 12 * scale, 20 * scale, 2 * scale)
        nvgFillColor(nvg, nvgRGBA(40, 40, 50, 255))
        nvgFill(nvg)
        -- 小红点（录制中）
        local blink = math.floor(animTime * 2) % 2
        if blink == 0 then
            nvgBeginPath(nvg)
            nvgCircle(nvg, cx + 36 * scale, cy - 42 * scale, 2 * scale)
            nvgFillColor(nvg, nvgRGBA(255, 50, 50, 255))
            nvgFill(nvg)
        end

    elseif activity == "stalling" then
        -- 围裙
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx - 12 * scale, cy - 20 * scale)
        nvgLineTo(nvg, cx + 12 * scale, cy - 20 * scale)
        nvgLineTo(nvg, cx + 14 * scale, cy + 2 * scale)
        nvgLineTo(nvg, cx - 14 * scale, cy + 2 * scale)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(240, 240, 230, 200))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(200, 195, 180, 255))
        nvgStrokeWidth(nvg, 1 * scale)
        nvgStroke(nvg)

        -- 叫卖对话框（大气泡，循环台词）
        local shouts = { "走过路过别错过!", "新鲜出炉，快来尝!", "好吃不贵，买一送一!", "今日特价，手慢无!", "来来来，尝一尝!" }
        local shoutIdx = math.floor(animTime * 0.5) % #shouts + 1
        local bubbleFloat = math.sin(animTime * 1.5) * 2

        local bx = cx + 25 * scale
        local by = cy - 75 * scale + bubbleFloat * scale

        -- 气泡尖角
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, bx - 8 * scale, by + 12 * scale)
        nvgLineTo(nvg, bx - 15 * scale, by + 20 * scale)
        nvgLineTo(nvg, bx - 2 * scale, by + 12 * scale)
        nvgFillColor(nvg, nvgRGBA(255, 255, 240, 230))
        nvgFill(nvg)

        -- 气泡主体
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, bx - 28 * scale, by - 10 * scale, 56 * scale, 22 * scale, 6 * scale)
        nvgFillColor(nvg, nvgRGBA(255, 255, 240, 230))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(220, 180, 100, 200))
        nvgStrokeWidth(nvg, 1.5 * scale)
        nvgStroke(nvg)

        -- 叫卖文字
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 8 * scale)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(200, 50, 30, 255))
        nvgText(nvg, bx, by, shouts[shoutIdx], nil)

    elseif activity == "eating" then
        -- 碗
        nvgBeginPath(nvg)
        nvgArc(nvg, cx, cy - 3 * scale, 12 * scale, 0, math.rad(180), 1)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(240, 240, 230, 255))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(200, 200, 190, 255))
        nvgStrokeWidth(nvg, 1 * scale)
        nvgStroke(nvg)
    end
end

return CharacterRenderer
