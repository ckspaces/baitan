-- ============================================================================
-- StallScene.lua - 街头摆摊场景
-- 排队购买 + 递烤串 + 多元化人物 + Y排序 + 真实行走 + 天气系统
-- ============================================================================

local StallScene = {}
local GameConfig = require("config.GameConfig")

--- 当前地点ID缓存（供场景绘制和人物生成使用）
local currentLocationId_ = "school"

-- ============================================================================
-- 人物类型模板
-- ============================================================================
local PERSON_TEMPLATES = {
    { gender = "male",   scale = 1.0,  hasHat = false, hasStroller = false },
    { gender = "male",   scale = 1.0,  hasHat = true,  hasStroller = false },
    { gender = "male",   scale = 1.05, hasHat = false, hasStroller = false },
    { gender = "male",   scale = 0.95, hasHat = true,  hasStroller = false },
    { gender = "male",   scale = 1.0,  hasHat = false, hasStroller = false },
    { gender = "female", scale = 0.92, hasHat = false, hasStroller = false },
    { gender = "female", scale = 0.92, hasHat = true,  hasStroller = false },
    { gender = "female", scale = 0.88, hasHat = false, hasStroller = true  },
    { gender = "female", scale = 0.95, hasHat = false, hasStroller = false },
    { gender = "female", scale = 0.90, hasHat = true,  hasStroller = false },
    { gender = "child",  scale = 0.60, hasHat = false, hasStroller = false },
    { gender = "child",  scale = 0.55, hasHat = true,  hasStroller = false },
    { gender = "child",  scale = 0.65, hasHat = false, hasStroller = false },
}

local SKIN_TONES = {
    { 255, 224, 189 }, { 241, 194, 155 }, { 224, 172, 130 },
    { 198, 145, 100 }, { 255, 213, 170 },
}
local CLOTHES_COLORS = {
    { 70,130,200 }, { 200,75,75 }, { 80,180,100 }, { 200,160,60 },
    { 160,80,180 }, { 60,170,170 }, { 220,130,70 }, { 180,90,120 },
    { 100,100,110 }, { 50,50,60 }, { 220,200,180 }, { 140,70,70 },
}
local HAT_COLORS = {
    { 200,50,50 }, { 50,100,200 }, { 250,200,50 },
    { 50,50,50 }, { 220,220,220 }, { 180,100,60 },
}
local HAIR_COLORS = {
    { 30,25,20 }, { 80,55,30 }, { 50,40,30 }, { 160,120,60 }, { 100,45,30 },
}

local function randomPersonAppearance()
    local tmpl
    if currentLocationId_ == "school" and math.random() < 0.5 then
        -- 学校地点：增加小孩比例（放学人群）
        local children = {}
        for _, t in ipairs(PERSON_TEMPLATES) do
            if t.gender == "child" then children[#children + 1] = t end
        end
        if #children > 0 then
            tmpl = children[math.random(1, #children)]
        end
    end
    if not tmpl then
        tmpl = PERSON_TEMPLATES[math.random(1, #PERSON_TEMPLATES)]
    end
    return {
        gender      = tmpl.gender,
        scale       = tmpl.scale,
        hasHat      = tmpl.hasHat,
        hasStroller = tmpl.hasStroller,
        skin        = SKIN_TONES[math.random(1, #SKIN_TONES)],
        clothes     = CLOTHES_COLORS[math.random(1, #CLOTHES_COLORS)],
        clothes2    = CLOTHES_COLORS[math.random(1, #CLOTHES_COLORS)],
        hair        = HAIR_COLORS[math.random(1, #HAIR_COLORS)],
        hatColor    = tmpl.hasHat and HAT_COLORS[math.random(1, #HAT_COLORS)] or nil,
    }
end

-- ============================================================================
-- 场景数据
-- ============================================================================
local pedestrians_ = {}
local PEDESTRIAN_COUNT = 8
local queue_ = {}
local MAX_QUEUE = 5
local leavingCustomers_ = {}
local handoff_ = { active = false, timer = 0, duration = 0.8, customer = nil }
local floatingCoins_ = {}
local lastSoldCount_ = 0
local prevAnimTime_ = 0
local stallLayout_ = {}

-- 天气粒子
local rainDrops_ = {}
local snowFlakes_ = {}
local windLeaves_ = {}
local weatherInited_ = false
local lastWeather_ = ""
local lastLocationId_ = ""

-- ============================================================================
-- 创建人物（带独立步行相位和步频）
-- ============================================================================
local function makePerson(overrides)
    local appear = overrides.appear or randomPersonAppearance()
    local sc = appear.scale or 1.0
    return {
        x         = overrides.x or 0,
        y         = overrides.y or 0,
        speed     = overrides.speed or (12 + math.random() * 22),
        dir       = overrides.dir or ((math.random() > 0.5) and 1 or -1),
        bodyH     = (overrides.baseBodyH or (13 + math.random() * 5)) * sc,
        headR     = (overrides.baseHeadR or (3.0 + math.random() * 1.0)) * sc,
        appear    = appear,
        -- ★ 每人独立的步行动画参数
        walkPhase = math.random() * math.pi * 2,       -- 随机初始相位
        walkFreq  = 4.5 + math.random() * 3.0,         -- 步频 4.5~7.5 Hz
        -- 排队相关
        phase     = overrides.phase or nil,
        patience  = 0,
        emoji     = nil,
        holdingSkewer = false,
    }
end

local function initPedestrians(w, h, weather)
    pedestrians_ = {}
    -- 恶劣天气减少行人
    local count = PEDESTRIAN_COUNT
    if weather == "rainy" then
        count = math.max(3, math.floor(count * 0.5))
    elseif weather == "stormy" then
        count = math.max(2, math.floor(count * 0.3))
    elseif weather == "snowy" then
        count = math.max(4, math.floor(count * 0.6))
    end
    for i = 1, count do
        local p = makePerson({
            x = math.random() * (w or 400),
            y = 0.74 + math.random() * 0.10,
        })
        -- 下雨时行人带伞
        p.hasUmbrella = (weather == "rainy" or weather == "stormy") and (math.random() > 0.2)
        if p.hasUmbrella then
            -- 雨伞颜色
            local umbrellaColors = {
                {200,50,50}, {50,80,200}, {220,180,40}, {60,160,60},
                {180,60,180}, {50,50,60}, {200,100,50}, {60,140,160},
            }
            p.umbrellaColor = umbrellaColors[math.random(1, #umbrellaColors)]
        end
        pedestrians_[i] = p
    end
end

local function spawnQueueCustomer(w, h)
    if #queue_ >= MAX_QUEUE then return end
    local fromLeft = math.random() > 0.4
    local appear = randomPersonAppearance()
    appear.hasStroller = false  -- 排队不推车
    local c = makePerson({
        x = fromLeft and -20 or (w + 20),
        y = h * 0.70,
        speed = 28 + math.random() * 15,
        dir = fromLeft and 1 or -1,
        phase = "approaching",
        appear = appear,
        baseBodyH = 13 + math.random() * 4,
        baseHeadR = 3.5 + math.random() * 1.0,
    })
    c.phase = "approaching"
    queue_[#queue_ + 1] = c
end

local function getQueueX(queueIdx, w)
    local stallRight = stallLayout_.stallX and (stallLayout_.stallX + stallLayout_.stallW + 10) or (w * 0.72)
    return stallRight + (queueIdx - 1) * 18
end

local function spawnFloatingCoin(x, y, amount)
    floatingCoins_[#floatingCoins_ + 1] = {
        x = x, y = y, life = 0, maxLife = 1.5, amount = amount or math.random(3, 15),
    }
end

local function startHandoff()
    if handoff_.active or #queue_ == 0 then return false end
    local first = queue_[1]
    if first.phase ~= "queuing" then return false end
    handoff_.active = true
    handoff_.timer = 0
    handoff_.customer = first
    first.phase = "served"
    return true
end

local function completeHandoff(w)
    if not handoff_.active then return end
    local c = handoff_.customer
    if c then
        c.holdingSkewer = true
        c.phase = "leaving"
        c.dir = (math.random() > 0.5) and 1 or -1
        c.emoji = ({ "😋", "🤤", "👍", "😍", "🥰", "😊" })[math.random(1, 6)]
        spawnFloatingCoin(
            (stallLayout_.stallX or 100) + (stallLayout_.stallW or 80) * 0.5,
            (stallLayout_.stallY or 100) - 20,
            math.random(5, 25)
        )
        table.remove(queue_, 1)
        leavingCustomers_[#leavingCustomers_ + 1] = c
    end
    handoff_.active = false
    handoff_.customer = nil
end

-- ============================================================================
-- 天气粒子初始化
-- ============================================================================
local function initWeatherParticles(w, h, weather)
    rainDrops_ = {}
    snowFlakes_ = {}
    windLeaves_ = {}
    if weather == "rainy" then
        for i = 1, 60 do
            rainDrops_[i] = {
                x = math.random() * w,
                y = math.random() * h,
                speed = 180 + math.random() * 120,
                len = 6 + math.random() * 8,
                windOffset = math.random() * 0.3 - 0.15,
            }
        end
    elseif weather == "snowy" then
        for i = 1, 50 do
            snowFlakes_[i] = {
                x = math.random() * w,
                y = math.random() * h,
                speed = 15 + math.random() * 25,
                size = 1.5 + math.random() * 3,
                drift = math.random() * 2 - 1,         -- 左右飘
                phase = math.random() * math.pi * 2,    -- 飘动相位
            }
        end
    elseif weather == "windy" then
        for i = 1, 15 do
            windLeaves_[i] = {
                x = math.random() * w,
                y = h * 0.4 + math.random() * h * 0.4,
                speed = 60 + math.random() * 80,
                size = 3 + math.random() * 3,
                rot = math.random() * math.pi * 2,
                rotSpeed = 2 + math.random() * 4,
                yDrift = math.random() * 2 - 1,
                phase = math.random() * math.pi * 2,
                color = math.random() > 0.5
                    and { 120, 160, 50 }  -- 绿叶
                    or  { 180, 120, 40 },  -- 落叶
            }
        end
    end
end

-- ============================================================================
-- 人物绘制（修复：真实行走动画）
-- ============================================================================
function StallScene.drawPerson(nvg, px, py, p, animTime, isWalking, facingDir, windLean)
    local a = p.appear or {
        gender = "male", scale = 1.0, skin = {255,220,185}, clothes = {100,100,200},
        clothes2 = {60,60,80}, hair = {30,25,20}, hasHat = false, hasStroller = false,
    }
    local sc = a.scale or 1.0
    local bH = p.bodyH or 14
    local hR = p.headR or 3.5
    local dir = facingDir or p.dir or 1

    -- ★ 独立步行动画：每人用自己的 walkPhase + walkFreq
    local walkCycle = (p.walkPhase or 0) + animTime * (p.walkFreq or 6)
    local legSwingL = 0
    local legSwingR = 0
    local armSwingL = 0
    local armSwingR = 0

    if isWalking then
        -- 左腿 sin，右腿 -sin（交替）
        legSwingL = math.sin(walkCycle) * 4.0 * sc
        legSwingR = math.sin(walkCycle + math.pi) * 4.0 * sc
        -- 手臂与对侧腿同步（左手配右腿，右手配左腿）
        armSwingL = math.sin(walkCycle + math.pi) * 3.5 * sc    -- 与右腿同步
        armSwingR = math.sin(walkCycle) * 3.5 * sc               -- 与左腿同步
    end

    local legLen = 8 * sc
    local bodyW = 9 * sc

    -- 风的倾斜
    local lean = (windLean or 0) * sc
    if lean ~= 0 then
        nvgSave(nvg)
        nvgTranslate(nvg, px, py)
        nvgRotate(nvg, lean * 0.05)
        nvgTranslate(nvg, -px, -py)
    end

    -- 婴儿车
    if a.hasStroller then
        local stX = px + dir * 13
        local stY = py - 2
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, stX - 6, stY - 8, 12, 8, 2)
        nvgFillColor(nvg, nvgRGBA(100, 130, 180, 220))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, stX - 4, stY + 1, 2)
        nvgCircle(nvg, stX + 4, stY + 1, 2)
        nvgFillColor(nvg, nvgRGBA(50, 50, 55, 255))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, stX, stY - 6, 3)
        nvgFillColor(nvg, nvgRGBA(255, 220, 200, 230))
        nvgFill(nvg)
        nvgStrokeColor(nvg, nvgRGBA(80, 80, 90, 200))
        nvgStrokeWidth(nvg, 1.5)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, stX - dir * 6, stY - 4)
        nvgLineTo(nvg, px + dir * 5, py - bH * 0.5)
        nvgStroke(nvg)
    end

    -- ★ 左腿
    nvgStrokeColor(nvg, nvgRGBA(a.clothes2[1], a.clothes2[2], a.clothes2[3], 220))
    nvgStrokeWidth(nvg, 2.5 * sc)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, px - 2 * sc, py)
    nvgLineTo(nvg, px - 2 * sc + legSwingL * dir, py + legLen)
    nvgStroke(nvg)
    -- 左脚
    nvgBeginPath(nvg)
    nvgEllipse(nvg, px - 2 * sc + legSwingL * dir, py + legLen + 1, 2.5 * sc, 1.2 * sc)
    nvgFillColor(nvg, nvgRGBA(40, 40, 50, 200))
    nvgFill(nvg)

    -- ★ 右腿
    nvgStrokeColor(nvg, nvgRGBA(a.clothes2[1], a.clothes2[2], a.clothes2[3], 220))
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, px + 2 * sc, py)
    nvgLineTo(nvg, px + 2 * sc + legSwingR * dir, py + legLen)
    nvgStroke(nvg)
    -- 右脚
    nvgBeginPath(nvg)
    nvgEllipse(nvg, px + 2 * sc + legSwingR * dir, py + legLen + 1, 2.5 * sc, 1.2 * sc)
    nvgFillColor(nvg, nvgRGBA(40, 40, 50, 200))
    nvgFill(nvg)

    -- 身体
    if a.gender == "female" then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, px - bodyW * 0.5, py - bH, bodyW, bH, 3 * sc)
        nvgFillColor(nvg, nvgRGBA(a.clothes[1], a.clothes[2], a.clothes[3], 230))
        nvgFill(nvg)
        -- 裙摆
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, px - bodyW * 0.6, py)
        nvgLineTo(nvg, px + bodyW * 0.6, py)
        nvgLineTo(nvg, px + bodyW * 0.3, py - bH * 0.15)
        nvgLineTo(nvg, px - bodyW * 0.3, py - bH * 0.15)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(
            math.max(0, a.clothes[1] - 15),
            math.max(0, a.clothes[2] - 15),
            math.max(0, a.clothes[3] - 15), 200))
        nvgFill(nvg)
    elseif a.gender == "child" then
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, px - bodyW * 0.5, py - bH, bodyW, bH, 4 * sc)
        nvgFillColor(nvg, nvgRGBA(a.clothes[1], a.clothes[2], a.clothes[3], 230))
        nvgFill(nvg)
    else
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, px - bodyW * 0.5, py - bH, bodyW, bH, 2 * sc)
        nvgFillColor(nvg, nvgRGBA(a.clothes[1], a.clothes[2], a.clothes[3], 230))
        nvgFill(nvg)
    end

    -- ★ 手臂（与对侧腿交替摆动）
    local armY = py - bH * 0.75
    local armLen = bH * 0.55
    local handR = 1.5 * sc
    nvgStrokeWidth(nvg, 2 * sc)

    -- 左臂
    if not a.hasStroller then
        local lArmEndX = px - bodyW * 0.5 - 3 * sc + armSwingL * dir
        local lArmEndY = armY + armLen
        nvgStrokeColor(nvg, nvgRGBA(a.skin[1], a.skin[2], a.skin[3], 220))
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, px - bodyW * 0.5, armY)
        nvgLineTo(nvg, lArmEndX, lArmEndY)
        nvgStroke(nvg)
        -- 手掌
        nvgBeginPath(nvg)
        nvgCircle(nvg, lArmEndX, lArmEndY, handR)
        nvgFillColor(nvg, nvgRGBA(a.skin[1], a.skin[2], a.skin[3], 230))
        nvgFill(nvg)
    end

    -- 右臂
    local rArmEndX = px + bodyW * 0.5 + 3 * sc + armSwingR * dir
    local rArmEndY = armY + armLen
    nvgStrokeColor(nvg, nvgRGBA(a.skin[1], a.skin[2], a.skin[3], 220))
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, px + bodyW * 0.5, armY)
    nvgLineTo(nvg, rArmEndX, rArmEndY)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, rArmEndX, rArmEndY, handR)
    nvgFillColor(nvg, nvgRGBA(a.skin[1], a.skin[2], a.skin[3], 230))
    nvgFill(nvg)

    -- 脖子
    nvgBeginPath(nvg)
    nvgRect(nvg, px - 1.5 * sc, py - bH - 2 * sc, 3 * sc, 3 * sc)
    nvgFillColor(nvg, nvgRGBA(a.skin[1], a.skin[2], a.skin[3], 220))
    nvgFill(nvg)

    -- 头
    local headY = py - bH - hR - 2 * sc
    nvgBeginPath(nvg)
    nvgCircle(nvg, px, headY, hR)
    nvgFillColor(nvg, nvgRGBA(a.skin[1], a.skin[2], a.skin[3], 240))
    nvgFill(nvg)

    -- 头发
    if a.gender == "female" then
        nvgBeginPath(nvg)
        nvgArc(nvg, px, headY, hR + 0.5, math.rad(-150), math.rad(-30), 1)
        nvgLineTo(nvg, px + hR * 0.5, headY + hR * 1.2)
        nvgLineTo(nvg, px - hR * 0.5, headY + hR * 1.2)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(a.hair[1], a.hair[2], a.hair[3], 220))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgArc(nvg, px, headY, hR + 0.8, math.rad(-160), math.rad(-20), 1)
        nvgFillColor(nvg, nvgRGBA(a.hair[1], a.hair[2], a.hair[3], 180))
        nvgFill(nvg)
    else
        nvgBeginPath(nvg)
        nvgArc(nvg, px, headY, hR + 0.5, math.rad(-170), math.rad(-10), 1)
        nvgFillColor(nvg, nvgRGBA(a.hair[1], a.hair[2], a.hair[3], 200))
        nvgFill(nvg)
    end

    -- 帽子
    if a.hasHat and a.hatColor then
        local hc = a.hatColor
        nvgBeginPath(nvg)
        nvgEllipse(nvg, px, headY - hR * 0.6, hR * 1.6, hR * 0.35)
        nvgFillColor(nvg, nvgRGBA(math.max(0,hc[1]-20), math.max(0,hc[2]-20), math.max(0,hc[3]-20), 230))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, px - hR * 0.9, headY - hR * 1.5, hR * 1.8, hR * 1.0, hR * 0.4)
        nvgFillColor(nvg, nvgRGBA(hc[1], hc[2], hc[3], 240))
        nvgFill(nvg)
    end

    -- 眼睛
    local eyeY = headY - hR * 0.1
    local eyeSpacing = hR * 0.35
    nvgBeginPath(nvg)
    nvgCircle(nvg, px - eyeSpacing, eyeY, 0.8 * sc)
    nvgCircle(nvg, px + eyeSpacing, eyeY, 0.8 * sc)
    nvgFillColor(nvg, nvgRGBA(30, 30, 40, 220))
    nvgFill(nvg)

    -- ★ 雨伞
    if p.hasUmbrella and p.umbrellaColor then
        local uc = p.umbrellaColor
        local umbX = px
        local umbTopY = headY - hR - 8 * sc  -- 伞顶位置
        local umbR = 12 * sc                   -- 伞半径

        -- 伞柄（从手持位置到伞顶）
        nvgStrokeColor(nvg, nvgRGBA(80, 60, 40, 220))
        nvgStrokeWidth(nvg, 1.5 * sc)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, umbX, py - bH * 0.3)   -- 手持位置
        nvgLineTo(nvg, umbX, umbTopY)
        nvgStroke(nvg)

        -- 伞面（半圆）
        nvgBeginPath(nvg)
        nvgArc(nvg, umbX, umbTopY, umbR, math.rad(180), math.rad(360), 1)
        nvgClosePath(nvg)
        nvgFillColor(nvg, nvgRGBA(uc[1], uc[2], uc[3], 210))
        nvgFill(nvg)

        -- 伞面边缘
        nvgBeginPath(nvg)
        nvgArc(nvg, umbX, umbTopY, umbR, math.rad(180), math.rad(360), 1)
        nvgStrokeColor(nvg, nvgRGBA(
            math.max(0, uc[1] - 40),
            math.max(0, uc[2] - 40),
            math.max(0, uc[3] - 40), 180))
        nvgStrokeWidth(nvg, 1.0 * sc)
        nvgStroke(nvg)

        -- 伞面条纹装饰
        for si = 1, 3 do
            local angle1 = math.rad(180 + si * 36)
            local angle2 = math.rad(180 + si * 36 + 12)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, umbX, umbTopY)
            nvgLineTo(nvg, umbX + math.cos(angle1) * umbR, umbTopY + math.sin(angle1) * umbR)
            nvgLineTo(nvg, umbX + math.cos(angle2) * umbR, umbTopY + math.sin(angle2) * umbR)
            nvgClosePath(nvg)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 40))
            nvgFill(nvg)
        end

        -- 伞尖
        nvgBeginPath(nvg)
        nvgCircle(nvg, umbX, umbTopY - 1 * sc, 1.2 * sc)
        nvgFillColor(nvg, nvgRGBA(80, 60, 40, 220))
        nvgFill(nvg)
    end

    if lean ~= 0 then
        nvgRestore(nvg)
    end
end

-- ============================================================================
-- Y 深度排序绘制
-- ============================================================================
function StallScene.drawAllCharactersSorted(nvg, x, y, w, h, gs, animTime)
    local drawList = {}
    local weather = gs.currentWeather or "sunny"
    local windLean = (weather == "windy") and 1.0 or 0

    for _, p in ipairs(pedestrians_) do
        local absY = y + h * p.y + (p.bodyH or 14) + 8 * (p.appear and p.appear.scale or 1)
        drawList[#drawList + 1] = { sortY = absY, type = "ped", data = p }
    end
    for i, c in ipairs(queue_) do
        local absY = y + c.y + (c.bodyH or 14) + 8 * (c.appear and c.appear.scale or 1)
        drawList[#drawList + 1] = { sortY = absY, type = "queue", data = c, index = i }
    end
    for _, c in ipairs(leavingCustomers_) do
        local absY = y + c.y + (c.bodyH or 14) + 8 * (c.appear and c.appear.scale or 1)
        drawList[#drawList + 1] = { sortY = absY, type = "leave", data = c }
    end

    table.sort(drawList, function(a, b) return a.sortY < b.sortY end)

    for _, item in ipairs(drawList) do
        local p = item.data
        if item.type == "ped" then
            StallScene.drawPerson(nvg, x + p.x, y + h * p.y, p, animTime, true, p.dir, windLean)

        elseif item.type == "queue" then
            StallScene.drawPerson(nvg, x + p.x, y + p.y, p, animTime,
                p.phase == "approaching", p.dir, windLean)
            if p.phase == "queuing" then
                local waitEmoji = "🤔"
                if p.patience > 5 then waitEmoji = "😤"
                elseif p.patience > 3 then waitEmoji = "⏳"
                elseif p.patience > 1 then waitEmoji = "😊" end
                local bob = math.sin(animTime * 2 + item.index * 0.8) * 2
                local headTop = y + p.y - p.bodyH - p.headR * 2 - 8 * (p.appear and p.appear.scale or 1)
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 10)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgText(nvg, x + p.x, headTop + bob, waitEmoji, nil)
            elseif p.phase == "served" then
                if math.sin(animTime * 8) > 0 then
                    local headTop = y + p.y - p.bodyH - p.headR * 2 - 8 * (p.appear and p.appear.scale or 1)
                    nvgFontFace(nvg, "sans")
                    nvgFontSize(nvg, 12)
                    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                    nvgFillColor(nvg, nvgRGBA(255, 220, 50, 255))
                    nvgText(nvg, x + p.x, headTop, "❗", nil)
                end
            end

        elseif item.type == "leave" then
            StallScene.drawPerson(nvg, x + p.x, y + p.y, p, animTime, true, p.dir, windLean)
            if p.holdingSkewer then
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 10)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgText(nvg, x + p.x + (p.dir or 1) * 8, y + p.y - p.bodyH * 0.4, "🍢", nil)
            end
            if p.emoji then
                local floatUp = math.sin(animTime * 1.5 + p.x * 0.1) * 3
                local headTop = y + p.y - p.bodyH - p.headR * 2 - 6 * (p.appear and p.appear.scale or 1)
                nvgFontFace(nvg, "sans")
                nvgFontSize(nvg, 11)
                nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
                nvgText(nvg, x + p.x, headTop + floatUp, p.emoji, nil)
            end
        end
    end
end

-- ============================================================================
-- 天气效果绘制
-- ============================================================================

--- 雨
function StallScene.drawRain(nvg, x, y, w, h, dt, animTime)
    for _, d in ipairs(rainDrops_) do
        d.y = d.y + d.speed * dt
        d.x = d.x + d.windOffset * d.speed * dt
        if d.y > h then
            d.y = -d.len
            d.x = math.random() * w
        end
        if d.x > w then d.x = 0 elseif d.x < 0 then d.x = w end

        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x + d.x, y + d.y)
        nvgLineTo(nvg, x + d.x + d.windOffset * d.len, y + d.y + d.len)
        nvgStrokeColor(nvg, nvgRGBA(180, 200, 240, 120))
        nvgStrokeWidth(nvg, 1.2)
        nvgStroke(nvg)
    end
    -- 地面水花
    for i = 1, 6 do
        local sx = x + ((animTime * 40 + i * 67) % w)
        local sy = y + h * 0.80 + math.random() * 5
        local splash = math.sin(animTime * 8 + i * 1.3) * 0.5 + 0.5
        if splash > 0.7 then
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, 2 + splash * 2)
            nvgStrokeColor(nvg, nvgRGBA(180, 200, 240, math.floor(splash * 100)))
            nvgStrokeWidth(nvg, 0.8)
            nvgStroke(nvg)
        end
    end
end

--- 雪
function StallScene.drawSnow(nvg, x, y, w, h, dt, animTime)
    for _, f in ipairs(snowFlakes_) do
        f.y = f.y + f.speed * dt
        f.x = f.x + math.sin(animTime * 1.5 + f.phase) * f.drift * 0.5
        if f.y > h then
            f.y = -f.size
            f.x = math.random() * w
        end
        if f.x > w then f.x = 0 elseif f.x < 0 then f.x = w end

        nvgBeginPath(nvg)
        nvgCircle(nvg, x + f.x, y + f.y, f.size)
        nvgFillColor(nvg, nvgRGBA(240, 245, 255, 180))
        nvgFill(nvg)
    end
    -- 地面积雪
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.78, w, h * 0.03)
    nvgFillColor(nvg, nvgRGBA(230, 235, 245, 60))
    nvgFill(nvg)
end

--- 风（飘叶 + 横线）
function StallScene.drawWind(nvg, x, y, w, h, dt, animTime)
    for _, lf in ipairs(windLeaves_) do
        lf.x = lf.x + lf.speed * dt
        lf.y = lf.y + math.sin(animTime * 2 + lf.phase) * lf.yDrift * 0.3
        lf.rot = lf.rot + lf.rotSpeed * dt
        if lf.x > w + 20 then
            lf.x = -10
            lf.y = h * 0.4 + math.random() * h * 0.4
        end

        nvgSave(nvg)
        nvgTranslate(nvg, x + lf.x, y + lf.y)
        nvgRotate(nvg, lf.rot)
        nvgBeginPath(nvg)
        nvgEllipse(nvg, 0, 0, lf.size, lf.size * 0.5)
        local c = lf.color
        nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 180))
        nvgFill(nvg)
        nvgRestore(nvg)
    end
    -- 风线
    for i = 1, 4 do
        local ly = y + h * (0.35 + i * 0.12)
        local lx = x + ((animTime * 100 + i * 90) % (w + 80)) - 40
        local lineW = 25 + i * 8
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, lx, ly)
        nvgLineTo(nvg, lx + lineW, ly)
        nvgStrokeColor(nvg, nvgRGBA(200, 210, 230, 50))
        nvgStrokeWidth(nvg, 1)
        nvgStroke(nvg)
    end
end

--- 多云暗化遮罩
function StallScene.drawCloudyOverlay(nvg, x, y, w, h, animTime)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h * 0.5)
    nvgFillColor(nvg, nvgRGBA(40, 45, 60, 40))
    nvgFill(nvg)
    -- 低矮乌云
    nvgFillColor(nvg, nvgRGBA(80, 85, 100, 50))
    for i = 1, 4 do
        local cx = x + ((i * 110 + animTime * 4) % (w + 60)) - 30
        local cy = y + h * 0.06 + i * 15
        nvgBeginPath(nvg)
        nvgEllipse(nvg, cx, cy, 35 + i * 5, 12)
        nvgEllipse(nvg, cx + 22, cy - 5, 22, 10)
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 主绘制入口
-- ============================================================================
function StallScene.draw(nvg, x, y, w, h, gs, animTime)
    local dt = animTime - prevAnimTime_
    if dt <= 0 or dt > 0.1 then dt = 0.016 end
    prevAnimTime_ = animTime

    local weather = gs.currentWeather or "sunny"
    local season = gs.currentSeason or "spring"

    -- 更新当前地点（供 drawSkyline 和人物生成使用）
    local locDef = GameConfig.Locations[gs.currentLocation or 1]
    currentLocationId_ = locDef and locDef.id or "school"

    -- 天气或地点变化时重建行人和天气粒子
    if weather ~= lastWeather_ or currentLocationId_ ~= lastLocationId_ then
        initPedestrians(w, h, weather)
        initWeatherParticles(w, h, weather)
        lastWeather_ = weather
        lastLocationId_ = currentLocationId_
    end

    if #pedestrians_ == 0 then initPedestrians(w, h, weather) end

    -- 排队客户生成
    if gs.isStalling then
        local sold = gs.stallTotalSold or 0
        if sold > lastSoldCount_ then
            for i = 1, math.min(3, sold - lastSoldCount_) do
                spawnQueueCustomer(w, h)
            end
            lastSoldCount_ = sold
            startHandoff()
        end
        if not handoff_.active and #queue_ > 0 and queue_[1].phase == "queuing" then
            startHandoff()
        end
    else
        lastSoldCount_ = gs.stallTotalSold or 0
    end

    local dayPhase = (gs.currentDay - 1) / 4

    stallLayout_.stallX = x + w * 0.22
    stallLayout_.stallY = y + h * 0.54
    stallLayout_.stallW = w * 0.28
    stallLayout_.stallH = h * 0.14

    -- ★ 天空颜色受季节影响
    StallScene.drawSky(nvg, x, y, w, h, dayPhase, animTime, season, weather)
    StallScene.drawSkyline(nvg, x, y, w, h, dayPhase)
    StallScene.drawStreet(nvg, x, y, w, h, dayPhase, season, weather)
    StallScene.drawStall(nvg, x, y, w, h, gs, animTime, dayPhase)

    -- 多云遮罩
    if weather == "cloudy" then
        StallScene.drawCloudyOverlay(nvg, x, y, w, h, animTime)
    end

    -- 更新行人位置
    for _, p in ipairs(pedestrians_) do
        p.x = p.x + p.speed * p.dir * dt
        if p.dir > 0 and p.x > w + 20 then p.x = -15
        elseif p.dir < 0 and p.x < -20 then p.x = w + 15 end
    end

    -- 更新排队
    for i, c in ipairs(queue_) do
        local targetX = getQueueX(i, w)
        if c.phase == "approaching" then
            if math.abs(c.x - targetX) > 2 then
                local moveDir = (targetX > c.x) and 1 or -1
                c.x = c.x + c.speed * dt * moveDir
                if (moveDir > 0 and c.x >= targetX) or (moveDir < 0 and c.x <= targetX) then
                    c.x = targetX; c.phase = "queuing"
                end
            else
                c.x = targetX; c.phase = "queuing"
            end
        elseif c.phase == "queuing" then
            if math.abs(c.x - targetX) > 1 then
                c.x = c.x + ((targetX > c.x) and 1 or -1) * 40 * dt
            end
            c.patience = c.patience + dt
        end
    end

    -- 更新离场
    local toRemove = {}
    for i, c in ipairs(leavingCustomers_) do
        c.x = c.x + c.speed * c.dir * 1.3 * dt
        if c.x < -40 or c.x > w + 40 then toRemove[#toRemove + 1] = i end
    end
    for i = #toRemove, 1, -1 do table.remove(leavingCustomers_, toRemove[i]) end

    -- 递烤串
    if handoff_.active then
        handoff_.timer = handoff_.timer + dt
        if not handoff_.customer or handoff_.timer / handoff_.duration >= 1.0 then
            completeHandoff(w)
        end
    end

    -- ★ Y 深度排序绘制人物
    StallScene.drawAllCharactersSorted(nvg, x, y, w, h, gs, animTime)

    -- 递烤串飞行动画
    StallScene.drawHandoffAnimation(nvg, x, y, w, h, animTime)

    -- 飘钱
    local coinRemove = {}
    for i, coin in ipairs(floatingCoins_) do
        coin.life = coin.life + dt
        if coin.life >= coin.maxLife then coinRemove[#coinRemove + 1] = i end
    end
    for i = #coinRemove, 1, -1 do table.remove(floatingCoins_, coinRemove[i]) end
    StallScene.drawFloatingCoins(nvg, x, y, w, h, animTime)

    -- ★ 天气效果（在人物之上绘制）
    if weather == "rainy" then
        StallScene.drawRain(nvg, x, y, w, h, dt, animTime)
    elseif weather == "snowy" then
        StallScene.drawSnow(nvg, x, y, w, h, dt, animTime)
    elseif weather == "windy" then
        StallScene.drawWind(nvg, x, y, w, h, dt, animTime)
    end

    -- 夜灯
    if dayPhase >= 0.5 then
        StallScene.drawNightLights(nvg, x, y, w, h, animTime)
    end
end

-- ============================================================================
-- 递烤串飞行动画
-- ============================================================================
function StallScene.drawHandoffAnimation(nvg, x, y, w, h, animTime)
    if not handoff_.active or not handoff_.customer then return end
    local progress = math.min(1, handoff_.timer / handoff_.duration)
    local stallCenterX = stallLayout_.stallX + stallLayout_.stallW * 0.7
    local stallTopY = stallLayout_.stallY + stallLayout_.stallH * 0.3
    local c = handoff_.customer
    local custX = x + c.x
    local custTopY = y + c.y - c.bodyH

    local skewerX = stallCenterX + (custX - stallCenterX) * progress
    local skewerY = stallTopY + (custTopY - stallTopY) * progress - math.sin(progress * math.pi) * 15

    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 16 - progress * 4)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local alpha = 255
    if progress > 0.9 then alpha = math.floor((1.0 - progress) * 10 * 255) end
    nvgGlobalAlpha(nvg, alpha / 255)
    nvgText(nvg, skewerX, skewerY, "🍢", nil)
    nvgGlobalAlpha(nvg, 1)
end

-- ============================================================================
-- 天空（受季节和天气影响）
-- ============================================================================
function StallScene.drawSky(nvg, x, y, w, h, dayPhase, animTime, season, weather)
    local skyTop, skyBot

    -- 基础天空色（按日相）
    if dayPhase < 0.25 then
        skyTop = nvgRGBA(140, 195, 240, 255)
        skyBot = nvgRGBA(210, 225, 245, 255)
    elseif dayPhase < 0.5 then
        skyTop = nvgRGBA(100, 160, 220, 255)
        skyBot = nvgRGBA(200, 180, 160, 255)
    elseif dayPhase < 0.75 then
        skyTop = nvgRGBA(40, 50, 100, 255)
        skyBot = nvgRGBA(180, 100, 60, 255)
    else
        skyTop = nvgRGBA(15, 18, 40, 255)
        skyBot = nvgRGBA(30, 30, 60, 255)
    end

    local sky = nvgLinearGradient(nvg, x, y, x, y + h * 0.5, skyTop, skyBot)
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h * 0.5)
    nvgFillPaint(nvg, sky)
    nvgFill(nvg)

    -- 雨天/雪天压暗天空
    if weather == "rainy" or weather == "snowy" then
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w, h * 0.5)
        nvgFillColor(nvg, nvgRGBA(30, 35, 50, 60))
        nvgFill(nvg)
    end

    if dayPhase < 0.5 and weather ~= "rainy" and weather ~= "snowy" then
        -- 云朵
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 40))
        for i = 1, 3 do
            local cx = x + ((i * 140 + animTime * 6) % (w + 80)) - 40
            local cy = y + h * 0.08 + i * 18
            nvgBeginPath(nvg)
            nvgEllipse(nvg, cx, cy, 28 + i * 4, 9)
            nvgEllipse(nvg, cx + 18, cy - 4, 18, 7)
            nvgFill(nvg)
        end
    elseif dayPhase >= 0.5 then
        -- 星星
        nvgFillColor(nvg, nvgRGBA(255, 255, 220, 120))
        for i = 1, 12 do
            local sx = x + ((i * 37 + i * i * 7) % math.floor(w))
            local sy = y + ((i * 23 + i * 13) % math.floor(h * 0.35))
            local twinkle = math.sin(animTime * 2 + i * 0.8) * 0.5 + 0.5
            nvgGlobalAlpha(nvg, twinkle * 0.6 + 0.2)
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, 1 + twinkle)
            nvgFill(nvg)
        end
        nvgGlobalAlpha(nvg, 1)
    end

    -- 季节装饰
    if season == "spring" and dayPhase < 0.5 then
        -- 樱花花瓣
        for i = 1, 5 do
            local px = x + ((animTime * 12 + i * 80) % (w + 40)) - 20
            local ppy = y + h * 0.05 + math.sin(animTime * 0.8 + i * 1.5) * 15 + i * 10
            nvgBeginPath(nvg)
            nvgEllipse(nvg, px, ppy, 3, 2)
            nvgFillColor(nvg, nvgRGBA(255, 180, 200, 100))
            nvgFill(nvg)
        end
    end
end

function StallScene.drawSkyline(nvg, x, y, w, h, dayPhase)
    local baseY = y + h * 0.5
    local isNight = dayPhase >= 0.5
    local locId = currentLocationId_

    if locId == "school" then
        -- 学校：教学楼 + 校门 + 围栏
        -- 主教学楼
        local bx, bw, bh = x + w * 0.05, w * 0.35, h * 0.22
        local by = baseY - bh
        nvgBeginPath(nvg)
        nvgRect(nvg, bx, by, bw, bh)
        nvgFillColor(nvg, isNight and nvgRGBA(35,30,50,255) or nvgRGBA(180,170,155,255))
        nvgFill(nvg)
        -- 教学楼窗户（规整的网格）
        nvgFillColor(nvg, isNight and nvgRGBA(255,230,140,100) or nvgRGBA(140,180,220,80))
        for row = 0, 3 do
            for col = 0, 5 do
                nvgBeginPath(nvg)
                nvgRect(nvg, bx + 8 + col * (bw - 16) / 6, by + 8 + row * (bh - 12) / 4, (bw - 16) / 8, (bh - 12) / 6)
                nvgFill(nvg)
            end
        end
        -- 校名牌匾
        nvgBeginPath(nvg)
        nvgRect(nvg, bx + bw * 0.25, by + 2, bw * 0.5, 8)
        nvgFillColor(nvg, nvgRGBA(180, 40, 40, 200))
        nvgFill(nvg)

        -- 副楼
        local b2x, b2w, b2h = x + w * 0.55, w * 0.20, h * 0.16
        nvgBeginPath(nvg)
        nvgRect(nvg, b2x, baseY - b2h, b2w, b2h)
        nvgFillColor(nvg, isNight and nvgRGBA(30,28,45,255) or nvgRGBA(170,165,150,255))
        nvgFill(nvg)
        nvgFillColor(nvg, isNight and nvgRGBA(255,230,140,70) or nvgRGBA(140,180,220,60))
        for row = 0, 2 do
            for col = 0, 3 do
                nvgBeginPath(nvg)
                nvgRect(nvg, b2x + 5 + col * (b2w - 10) / 4, baseY - b2h + 6 + row * (b2h - 8) / 3, (b2w - 10) / 6, (b2h - 8) / 5)
                nvgFill(nvg)
            end
        end

        -- 校门（铁门+门柱）
        local gateX = x + w * 0.42
        local gateW, gateH = w * 0.10, h * 0.12
        -- 门柱
        nvgBeginPath(nvg)
        nvgRect(nvg, gateX, baseY - gateH, 4, gateH)
        nvgRect(nvg, gateX + gateW - 4, baseY - gateH, 4, gateH)
        nvgFillColor(nvg, isNight and nvgRGBA(50,45,60,255) or nvgRGBA(140,130,120,255))
        nvgFill(nvg)
        -- 铁栏杆
        nvgStrokeColor(nvg, isNight and nvgRGBA(60,55,70,255) or nvgRGBA(100,95,85,255))
        nvgStrokeWidth(nvg, 1)
        for ix = gateX + 6, gateX + gateW - 6, 4 do
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, ix, baseY - gateH + 3)
            nvgLineTo(nvg, ix, baseY)
            nvgStroke(nvg)
        end

        -- 围栏延伸
        nvgStrokeColor(nvg, isNight and nvgRGBA(50,45,60,200) or nvgRGBA(120,115,105,200))
        nvgStrokeWidth(nvg, 1.5)
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, baseY - h * 0.04)
        nvgLineTo(nvg, gateX, baseY - h * 0.04)
        nvgMoveTo(nvg, gateX + gateW, baseY - h * 0.04)
        nvgLineTo(nvg, x + w, baseY - h * 0.04)
        nvgStroke(nvg)

        -- 树木装饰
        for _, tx in ipairs({ w * 0.80, w * 0.88, w * 0.95 }) do
            local treeX = x + tx
            nvgBeginPath(nvg)
            nvgRect(nvg, treeX - 2, baseY - h * 0.08, 4, h * 0.08)
            nvgFillColor(nvg, nvgRGBA(80, 60, 40, 200))
            nvgFill(nvg)
            nvgBeginPath(nvg)
            nvgCircle(nvg, treeX, baseY - h * 0.10, 8)
            nvgFillColor(nvg, isNight and nvgRGBA(20, 60, 25, 200) or nvgRGBA(60, 140, 50, 200))
            nvgFill(nvg)
        end

    elseif locId == "community" then
        -- 小区：居民楼群 + 小区门
        local bldgs = {
            { rx=0.02, rw=0.12, rh=0.24 }, { rx=0.16, rw=0.10, rh=0.20 },
            { rx=0.55, rw=0.14, rh=0.26 }, { rx=0.72, rw=0.10, rh=0.18 },
            { rx=0.85, rw=0.12, rh=0.22 },
        }
        for _, b in ipairs(bldgs) do
            local bx2, bw2, bh2 = x + w * b.rx, w * b.rw, h * b.rh
            local by2 = baseY - bh2
            nvgBeginPath(nvg)
            nvgRect(nvg, bx2, by2, bw2, bh2)
            nvgFillColor(nvg, isNight and nvgRGBA(35,30,50,255) or nvgRGBA(190,180,165,255))
            nvgFill(nvg)
            -- 居民楼窗户（暖色）
            nvgFillColor(nvg, isNight and nvgRGBA(255,200,100,90) or nvgRGBA(160,190,220,60))
            local winW2, winH2 = bw2 * 0.15, bh2 * 0.06
            for wy = by2 + bh2 * 0.08, by2 + bh2 * 0.88, bh2 * 0.11 do
                for wx = bx2 + bw2 * 0.12, bx2 + bw2 * 0.78, bw2 * 0.25 do
                    nvgBeginPath(nvg)
                    nvgRect(nvg, wx, wy, winW2, winH2)
                    nvgFill(nvg)
                end
            end
        end
        -- 小区门牌
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, x + w * 0.32, baseY - h * 0.10, w * 0.18, h * 0.10, 2)
        nvgFillColor(nvg, isNight and nvgRGBA(40,35,55,255) or nvgRGBA(160,150,140,255))
        nvgFill(nvg)

    elseif locId == "business" then
        -- 商业街：高楼 + 商铺招牌
        local bldgs = {
            { rx=0.0, rw=0.08, rh=0.28 }, { rx=0.10, rw=0.06, rh=0.20 },
            { rx=0.18, rw=0.10, rh=0.32 }, { rx=0.35, rw=0.07, rh=0.24 },
            { rx=0.50, rw=0.12, rh=0.30 }, { rx=0.65, rw=0.06, rh=0.18 },
            { rx=0.75, rw=0.10, rh=0.26 }, { rx=0.88, rw=0.10, rh=0.22 },
        }
        for _, b in ipairs(bldgs) do
            local bx2, bw2, bh2 = x + w * b.rx, w * b.rw, h * b.rh
            local by2 = baseY - bh2
            nvgBeginPath(nvg)
            nvgRect(nvg, bx2, by2, bw2, bh2)
            nvgFillColor(nvg, isNight and nvgRGBA(25,25,45,255) or nvgRGBA(80,85,100,255))
            nvgFill(nvg)
            -- 写字楼蓝色玻璃窗
            nvgFillColor(nvg, isNight and nvgRGBA(200,220,255,70) or nvgRGBA(150,200,240,50))
            for wy = by2 + bh2 * 0.05, by2 + bh2 * 0.9, bh2 * 0.08 do
                for wx = bx2 + bw2 * 0.1, bx2 + bw2 * 0.85, bw2 * 0.22 do
                    nvgBeginPath(nvg)
                    nvgRect(nvg, wx, wy, bw2 * 0.16, bh2 * 0.04)
                    nvgFill(nvg)
                end
            end
        end
        -- 底部商铺招牌
        local signColors = {
            {220,60,60}, {60,130,220}, {60,180,80}, {220,180,40}, {180,60,180},
        }
        for i = 0, 4 do
            local sx = x + i * w * 0.20
            local sc = signColors[(i % #signColors) + 1]
            nvgBeginPath(nvg)
            nvgRect(nvg, sx + 2, baseY - h * 0.05, w * 0.18, h * 0.04)
            nvgFillColor(nvg, nvgRGBA(sc[1], sc[2], sc[3], isNight and 180 or 120))
            nvgFill(nvg)
        end

    elseif locId == "nightmarket" then
        -- 夜市：低矮棚架 + 灯串 + 烟火气
        -- 低矮建筑
        local bldgs = {
            { rx=0.0, rw=0.15, rh=0.10 }, { rx=0.20, rw=0.12, rh=0.12 },
            { rx=0.40, rw=0.18, rh=0.08 }, { rx=0.65, rw=0.15, rh=0.11 },
            { rx=0.85, rw=0.14, rh=0.09 },
        }
        for _, b in ipairs(bldgs) do
            local bx2, bw2, bh2 = x + w * b.rx, w * b.rw, h * b.rh
            nvgBeginPath(nvg)
            nvgRect(nvg, bx2, baseY - bh2, bw2, bh2)
            nvgFillColor(nvg, isNight and nvgRGBA(40,35,30,255) or nvgRGBA(100,90,75,255))
            nvgFill(nvg)
        end
        -- 灯串（夜间明亮）
        if isNight then
            nvgStrokeColor(nvg, nvgRGBA(200,180,100,80))
            nvgStrokeWidth(nvg, 1)
            nvgBeginPath(nvg)
            nvgMoveTo(nvg, x, baseY - h * 0.14)
            for lx = 0, w, 8 do
                nvgLineTo(nvg, x + lx, baseY - h * 0.14 + math.sin(lx * 0.05) * 3)
            end
            nvgStroke(nvg)
            -- 灯泡
            local bulbColors = { {255,200,50}, {255,100,100}, {100,200,255}, {100,255,100} }
            for lx = 0, w, 16 do
                local bc = bulbColors[(math.floor(lx / 16) % #bulbColors) + 1]
                nvgBeginPath(nvg)
                nvgCircle(nvg, x + lx, baseY - h * 0.14 + math.sin(lx * 0.05) * 3, 2.5)
                nvgFillColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], 200))
                nvgFill(nvg)
            end
        end

    elseif locId == "station" then
        -- 车站：车站大楼 + 钟楼 + 站牌
        -- 主站楼
        local bx, bw, bh = x + w * 0.10, w * 0.50, h * 0.25
        local by = baseY - bh
        nvgBeginPath(nvg)
        nvgRect(nvg, bx, by, bw, bh)
        nvgFillColor(nvg, isNight and nvgRGBA(30,30,50,255) or nvgRGBA(160,155,145,255))
        nvgFill(nvg)
        -- 大窗
        nvgFillColor(nvg, isNight and nvgRGBA(200,220,255,60) or nvgRGBA(140,190,230,50))
        nvgBeginPath(nvg)
        nvgRect(nvg, bx + bw * 0.1, by + bh * 0.1, bw * 0.8, bh * 0.3)
        nvgFill(nvg)
        -- 柱子
        nvgFillColor(nvg, isNight and nvgRGBA(40,38,55,255) or nvgRGBA(140,135,125,255))
        for col = 0, 4 do
            nvgBeginPath(nvg)
            nvgRect(nvg, bx + bw * 0.1 + col * bw * 0.18, by + bh * 0.45, 4, bh * 0.55)
            nvgFill(nvg)
        end
        -- 钟楼
        nvgBeginPath(nvg)
        nvgRect(nvg, x + w * 0.70, baseY - h * 0.30, w * 0.08, h * 0.30)
        nvgFillColor(nvg, isNight and nvgRGBA(35,32,52,255) or nvgRGBA(150,145,135,255))
        nvgFill(nvg)
        -- 钟面
        nvgBeginPath(nvg)
        nvgCircle(nvg, x + w * 0.74, baseY - h * 0.26, 6)
        nvgFillColor(nvg, nvgRGBA(240, 235, 220, 200))
        nvgFill(nvg)
        -- 站前广场树木
        for _, tx in ipairs({ w * 0.85, w * 0.92 }) do
            local treeX = x + tx
            nvgBeginPath(nvg)
            nvgRect(nvg, treeX - 2, baseY - h * 0.07, 4, h * 0.07)
            nvgFillColor(nvg, nvgRGBA(80, 60, 40, 180))
            nvgFill(nvg)
            nvgBeginPath(nvg)
            nvgCircle(nvg, treeX, baseY - h * 0.09, 7)
            nvgFillColor(nvg, isNight and nvgRGBA(20, 55, 25, 180) or nvgRGBA(50, 130, 45, 180))
            nvgFill(nvg)
        end
    else
        -- 默认：通用城市天际线（保持原有逻辑）
        local bldgs = {
            { rx=0.02,rw=0.07,rh=0.16 }, { rx=0.10,rw=0.05,rh=0.22 },
            { rx=0.17,rw=0.09,rh=0.14 }, { rx=0.30,rw=0.06,rh=0.20 },
            { rx=0.42,rw=0.08,rh=0.18 }, { rx=0.55,rw=0.05,rh=0.24 },
            { rx=0.63,rw=0.09,rh=0.13 }, { rx=0.76,rw=0.07,rh=0.21 },
            { rx=0.86,rw=0.10,rh=0.17 },
        }
        for _, b in ipairs(bldgs) do
            local bx2, bw2, bh2 = x + w * b.rx, w * b.rw, h * b.rh
            local by2 = baseY - bh2
            nvgBeginPath(nvg)
            nvgRect(nvg, bx2, by2, bw2, bh2)
            nvgFillColor(nvg, isNight and nvgRGBA(20,22,40,255) or nvgRGBA(55,58,78,255))
            nvgFill(nvg)
            nvgFillColor(nvg, isNight and nvgRGBA(255,230,140,70) or nvgRGBA(200,220,240,60))
            local winW2, winH2 = bw2 * 0.18, bh2 * 0.06
            for wy = by2 + bh2 * 0.1, by2 + bh2 * 0.85, bh2 * 0.13 do
                for wx = bx2 + bw2 * 0.15, bx2 + bw2 * 0.75, bw2 * 0.28 do
                    nvgBeginPath(nvg)
                    nvgRect(nvg, wx, wy, winW2, winH2)
                    nvgFill(nvg)
                end
            end
        end
    end
end

function StallScene.drawStreet(nvg, x, y, w, h, dayPhase, season, weather)
    local isNight = dayPhase >= 0.5
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.5, w, h * 0.5)
    if isNight then
        nvgFillColor(nvg, nvgRGBA(30, 32, 45, 255))
    else
        nvgFillColor(nvg, nvgRGBA(65, 68, 82, 255))
    end
    nvgFill(nvg)

    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.68, w, h * 0.12)
    nvgFillColor(nvg, isNight and nvgRGBA(45,45,55,255) or nvgRGBA(85,82,78,255))
    nvgFill(nvg)

    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.80, w, 3)
    nvgFillColor(nvg, nvgRGBA(120, 115, 105, 200))
    nvgFill(nvg)

    -- 冬天地面积雪效果
    if season == "winter" and weather == "snowy" then
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y + h * 0.79, w, h * 0.05)
        nvgFillColor(nvg, nvgRGBA(220, 225, 240, 80))
        nvgFill(nvg)
    end

    -- 雨天地面反光
    if weather == "rainy" then
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y + h * 0.68, w, h * 0.12)
        nvgFillColor(nvg, nvgRGBA(100, 120, 160, 25))
        nvgFill(nvg)
    end
end

function StallScene.drawStall(nvg, x, y, w, h, gs, animTime, dayPhase)
    local sX = stallLayout_.stallX
    local sY = stallLayout_.stallY
    local sW = stallLayout_.stallW
    local sH = stallLayout_.stallH
    local weather = gs.currentWeather or "sunny"
    local isRaining = (weather == "rainy" or weather == "stormy")

    -- ========== 三轮车主体 ==========
    local cartBottom = sY + sH           -- 车底
    local cartTop = sY                   -- 货箱顶
    local wheelR = sH * 0.28            -- 轮子半径
    local wheelY = cartBottom + wheelR * 0.3  -- 轮子中心Y

    -- 后双轮（右侧）
    for wi = 0, 1 do
        local rwX = sX + sW - sW * 0.12 - wi * (wheelR * 0.5)
        nvgBeginPath(nvg)
        nvgCircle(nvg, rwX, wheelY, wheelR)
        nvgFillColor(nvg, nvgRGBA(50, 50, 55, 240))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgCircle(nvg, rwX, wheelY, wheelR * 0.35)
        nvgFillColor(nvg, nvgRGBA(160, 160, 165, 240))
        nvgFill(nvg)
    end

    -- 前轮（左侧）
    local fwX = sX + sW * 0.08
    nvgBeginPath(nvg)
    nvgCircle(nvg, fwX, wheelY, wheelR * 0.9)
    nvgFillColor(nvg, nvgRGBA(50, 50, 55, 240))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, fwX, wheelY, wheelR * 0.3)
    nvgFillColor(nvg, nvgRGBA(160, 160, 165, 240))
    nvgFill(nvg)

    -- 车架/底盘（连接前轮到货箱）
    nvgStrokeColor(nvg, nvgRGBA(90, 90, 95, 255))
    nvgStrokeWidth(nvg, 2.5)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, fwX, wheelY - wheelR * 0.5)
    nvgLineTo(nvg, sX + sW * 0.25, cartBottom)
    nvgStroke(nvg)

    -- 把手（从前轮上方伸出）
    local handleY = cartTop - sH * 0.3
    nvgStrokeColor(nvg, nvgRGBA(80, 80, 85, 255))
    nvgStrokeWidth(nvg, 2.0)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, fwX, wheelY - wheelR * 0.5)
    nvgLineTo(nvg, fwX - 3, handleY)
    nvgStroke(nvg)
    -- 把手横杆
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, fwX - 8, handleY)
    nvgLineTo(nvg, fwX + 5, handleY)
    nvgStrokeWidth(nvg, 3.0)
    nvgStroke(nvg)

    -- 货箱（主体，木质感）
    local boxX = sX + sW * 0.22
    local boxW = sW * 0.68
    local boxH = sH * 0.85
    local boxY = cartTop + sH * 0.15
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, boxX, boxY, boxW, boxH, 2)
    nvgFillColor(nvg, nvgRGBA(170, 125, 75, 240))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(130, 90, 50, 255))
    nvgStrokeWidth(nvg, 1.2)
    nvgStroke(nvg)

    -- 货箱木纹装饰线
    nvgStrokeColor(nvg, nvgRGBA(140, 100, 55, 100))
    nvgStrokeWidth(nvg, 0.6)
    for li = 1, 2 do
        nvgBeginPath(nvg)
        local lineY = boxY + boxH * (li / 3)
        nvgMoveTo(nvg, boxX + 2, lineY)
        nvgLineTo(nvg, boxX + boxW - 2, lineY)
        nvgStroke(nvg)
    end

    -- 货箱前面板（面向顾客的一面，颜色稍亮）
    nvgBeginPath(nvg)
    nvgRect(nvg, boxX, boxY + boxH - 4, boxW, 4)
    nvgFillColor(nvg, nvgRGBA(190, 145, 90, 240))
    nvgFill(nvg)

    -- ========== 小遮阳伞 ==========
    local umbX = boxX + boxW * 0.5
    local umbTopY = boxY - sH * 0.7
    local umbR = boxW * 0.5

    -- 伞柄
    nvgStrokeColor(nvg, nvgRGBA(100, 90, 80, 230))
    nvgStrokeWidth(nvg, 2.0)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, umbX, boxY)
    nvgLineTo(nvg, umbX, umbTopY)
    nvgStroke(nvg)

    -- 伞面（圆弧 + 条纹）
    local stripes = 6
    local stripeAngle = math.pi / stripes
    for i = 0, stripes - 1 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, umbX, umbTopY)
        nvgArc(nvg, umbX, umbTopY, umbR, math.pi + i * stripeAngle, math.pi + (i + 1) * stripeAngle, 2)
        nvgClosePath(nvg)
        nvgFillColor(nvg, (i % 2 == 0) and nvgRGBA(220, 55, 40, 230) or nvgRGBA(245, 240, 225, 230))
        nvgFill(nvg)
    end

    -- 伞顶小尖
    nvgBeginPath(nvg)
    nvgCircle(nvg, umbX, umbTopY - 1, 2)
    nvgFillColor(nvg, nvgRGBA(200, 45, 35, 255))
    nvgFill(nvg)

    -- ========== 下雨效果（伞上水珠） ==========
    if isRaining then
        for di = 1, 5 do
            local dropAngle = math.pi + (di / 6) * math.pi
            local edgeX = umbX + math.cos(dropAngle) * umbR
            local edgeY = umbTopY + math.sin(dropAngle) * umbR
            local dripPhase = (animTime * 2.5 + di * 1.1) % 1.5
            if dripPhase < 1.0 then
                local dripLen = 2 + dripPhase * 5
                nvgBeginPath(nvg)
                nvgMoveTo(nvg, edgeX, edgeY)
                nvgLineTo(nvg, edgeX, edgeY + dripLen)
                nvgStrokeColor(nvg, nvgRGBA(150, 185, 235, math.floor(180 * (1.0 - dripPhase))))
                nvgStrokeWidth(nvg, 0.8)
                nvgStroke(nvg)
                nvgBeginPath(nvg)
                nvgCircle(nvg, edgeX, edgeY + dripLen + 1, 1.0)
                nvgFillColor(nvg, nvgRGBA(150, 185, 235, math.floor(140 * (1.0 - dripPhase))))
                nvgFill(nvg)
            end
        end
    end

    -- ========== 食物 emoji ==========
    local items = { "🍢", "🌭", "🍳", "🥞", "🧋" }
    local emoji = items[gs.selectedStallItem or 1] or "🍢"
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 14)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    for i = 1, 3 do
        local ix = boxX + boxW * (0.2 + (i - 1) * 0.3)
        local iy = boxY + boxH * 0.4
        nvgText(nvg, ix, iy + math.sin(animTime * 1.5 + i * 0.9) * 1.5, emoji, nil)
    end

    -- ========== 蒸汽 ==========
    if gs.isStalling then
        for i = 1, 4 do
            local sx = boxX + boxW * (0.2 + math.sin(i * 1.5) * 0.3)
            local phase = (animTime * 0.8 + i * 0.7) % 2.0
            local sy = boxY - phase * h * 0.06
            local alpha = math.max(0, 1.0 - phase / 2.0) * 80
            nvgBeginPath(nvg)
            nvgCircle(nvg, sx, sy, 2 + phase * 3)
            nvgFillColor(nvg, nvgRGBA(220, 220, 220, math.floor(alpha)))
            nvgFill(nvg)
        end
    end

    -- ========== 横幅广告语 ==========
    local bannerText = gs.bannerText or ""
    if bannerText ~= "" then
        local bannerW = sW * 1.2
        local bannerH = 14
        local bannerX = sX + (sW - bannerW) * 0.5
        local bannerY = umbTopY + umbR + 2
        -- 横幅布条背景（红底）
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, bannerX, bannerY, bannerW, bannerH, 2)
        nvgFillColor(nvg, nvgRGBA(200, 35, 25, 220))
        nvgFill(nvg)
        -- 横幅文字（黄字）
        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 8)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 240, 80, 255))
        nvgText(nvg, bannerX + bannerW * 0.5, bannerY + bannerH * 0.5, bannerText, nil)
    end

    -- ========== 热卖文字 ==========
    nvgFontSize(nvg, 9)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 240, 200, 220))
    nvgText(nvg, boxX + boxW * 0.5, cartBottom + 3, "热卖中！", nil)

    -- ========== 排队人数 ==========
    if #queue_ > 0 then
        nvgFontSize(nvg, 8)
        nvgFillColor(nvg, nvgRGBA(255, 200, 100, 200))
        nvgText(nvg, sX + sW + 25, sY - 5, string.format("排队 %d 人", #queue_), nil)
    end

    -- ========== 传单飞舞 ==========
    if gs.flyersActive and gs.flyersActive > 0 then
        nvgFillColor(nvg, nvgRGBA(255, 255, 230, 120))
        for i = 1, math.min(gs.flyersActive, 5) do
            local fx = sX - 10 + math.sin(animTime * 1.2 + i * 1.5) * 8
            local fy = sY - 10 - i * 7 + math.cos(animTime * 0.8 + i) * 3
            nvgSave(nvg)
            nvgTranslate(nvg, fx, fy)
            nvgRotate(nvg, math.sin(animTime + i) * 0.3)
            nvgBeginPath(nvg)
            nvgRect(nvg, -3, -2, 6, 4)
            nvgFill(nvg)
            nvgRestore(nvg)
        end
    end

    -- ========== 夜间灯光 ==========
    if dayPhase >= 0.5 then
        local lampGlow = nvgRadialGradient(nvg, umbX, umbTopY + umbR * 0.5, 5, umbR * 1.2,
            nvgRGBA(255, 230, 150, 55), nvgRGBA(255, 230, 150, 0))
        nvgBeginPath(nvg)
        nvgRect(nvg, umbX - umbR * 1.2, umbTopY - umbR * 0.3, umbR * 2.4, umbR * 2.0)
        nvgFillPaint(nvg, lampGlow)
        nvgFill(nvg)
    end
end

function StallScene.drawNightLights(nvg, x, y, w, h, animTime)
    local lampPosts = { 0.10, 0.50, 0.90 }
    for _, lx in ipairs(lampPosts) do
        local px = x + w * lx
        local py = y + h * 0.50
        nvgBeginPath(nvg); nvgRect(nvg, px - 1.5, py, 3, h * 0.20)
        nvgFillColor(nvg, nvgRGBA(80, 80, 90, 255)); nvgFill(nvg)
        nvgBeginPath(nvg); nvgRoundedRect(nvg, px - 5, py - 3, 10, 5, 2)
        nvgFillColor(nvg, nvgRGBA(60, 60, 70, 255)); nvgFill(nvg)
        local glow = nvgRadialGradient(nvg, px, py, 3, 40,
            nvgRGBA(255,240,180,80), nvgRGBA(255,240,180,0))
        nvgBeginPath(nvg); nvgCircle(nvg, px, py + 5, 45)
        nvgFillPaint(nvg, glow); nvgFill(nvg)
    end

    local bulbY = y + h * 0.42
    nvgStrokeColor(nvg, nvgRGBA(80,80,80,150))
    nvgStrokeWidth(nvg, 1)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, x + w * 0.15, bulbY)
    nvgBezierTo(nvg, x + w * 0.35, bulbY + 8, x + w * 0.65, bulbY + 8, x + w * 0.85, bulbY)
    nvgStroke(nvg)

    local bulbColors = {
        {255,80,80},{80,255,100},{255,220,60},{80,180,255},{255,130,200},{255,160,60},
    }
    for i = 1, 6 do
        local t = (i - 1) / 5
        local bx = x + w * (0.15 + t * 0.70)
        local catY = bulbY + math.sin(t * math.pi) * 8
        local bc = bulbColors[i]
        local blink = math.sin(animTime * 3 + i * 1.2) * 0.3 + 0.7
        nvgBeginPath(nvg); nvgCircle(nvg, bx, catY, 3)
        nvgFillColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], math.floor(blink * 255)))
        nvgFill(nvg)
    end
end

-- ============================================================================
-- 飘钱动画
-- ============================================================================
function StallScene.drawFloatingCoins(nvg, x, y, w, h, animTime)
    for _, coin in ipairs(floatingCoins_) do
        local progress = coin.life / coin.maxLife
        local alpha = math.max(0, 1.0 - progress) * 255
        local floatY = coin.y - progress * 40

        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 13 + progress * 3)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(255, 220, 50, math.floor(alpha)))
        nvgText(nvg, coin.x, floatY, string.format("+$%d", coin.amount), nil)

        nvgBeginPath(nvg)
        nvgCircle(nvg, coin.x - 18, floatY, 4)
        nvgFillColor(nvg, nvgRGBA(255, 200, 50, math.floor(alpha * 0.8)))
        nvgFill(nvg)
        nvgFontSize(nvg, 6)
        nvgFillColor(nvg, nvgRGBA(180, 120, 0, math.floor(alpha)))
        nvgText(nvg, coin.x - 18, floatY, "$", nil)
    end
end

return StallScene
