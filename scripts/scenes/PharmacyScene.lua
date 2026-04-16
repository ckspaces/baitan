-- ============================================================================
-- PharmacyScene.lua - 药店场景（NanoVG 绘制）
-- ============================================================================

local PharmacyScene = {}

function PharmacyScene.draw(nvg, x, y, w, h, gs, animTime)
    -- 室内暖白背景
    local bg = nvgLinearGradient(nvg, x, y, x, y + h,
        nvgRGBA(240, 245, 240, 255), nvgRGBA(210, 220, 210, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, bg)
    nvgFill(nvg)

    -- 地板（浅灰色瓷砖感）
    local floorY = y + h * 0.78
    nvgBeginPath(nvg)
    nvgRect(nvg, x, floorY, w, h * 0.22)
    nvgFillColor(nvg, nvgRGBA(200, 205, 195, 255))
    nvgFill(nvg)
    -- 瓷砖线
    nvgStrokeColor(nvg, nvgRGBA(180, 185, 175, 150))
    nvgStrokeWidth(nvg, 0.5)
    for i = 1, 6 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x + i * w / 7, floorY)
        nvgLineTo(nvg, x + i * w / 7, y + h)
        nvgStroke(nvg)
    end

    -- ========== 绿十字招牌 ==========
    local signX = x + w * 0.35
    local signY = y + h * 0.04
    local signSize = math.min(w * 0.3, h * 0.12)
    -- 招牌底板
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, signX, signY, signSize, signSize * 0.7, 4)
    nvgFillColor(nvg, nvgRGBA(30, 140, 60, 255))
    nvgFill(nvg)
    -- 绿十字
    local cx = signX + signSize * 0.5
    local cy = signY + signSize * 0.35
    local crossW = signSize * 0.12
    local crossH = signSize * 0.35
    nvgBeginPath(nvg)
    nvgRect(nvg, cx - crossW, cy - crossH, crossW * 2, crossH * 2)
    nvgRect(nvg, cx - crossH, cy - crossW, crossH * 2, crossW * 2)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 240))
    nvgFill(nvg)
    -- 招牌文字
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 9)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 220))
    nvgText(nvg, cx, signY + signSize * 0.58, "健康药房", nil)

    -- ========== 药品货架（3层） ==========
    local shelfX = x + w * 0.05
    local shelfY = y + h * 0.22
    local shelfW = w * 0.55
    local shelfH = h * 0.52
    local layerH = shelfH / 3

    -- 货架背板
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, shelfX, shelfY, shelfW, shelfH, 3)
    nvgFillColor(nvg, nvgRGBA(240, 235, 220, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(180, 170, 150, 200))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 每层货架 + 药盒
    local boxColors = {
        { { 220, 60, 60 }, { 60, 130, 220 }, { 80, 180, 80 }, { 200, 160, 60 }, { 180, 80, 180 } },
        { { 60, 180, 180 }, { 220, 120, 40 }, { 100, 100, 200 }, { 200, 80, 80 }, { 60, 160, 100 } },
        { { 180, 140, 60 }, { 80, 80, 180 }, { 200, 60, 100 }, { 60, 200, 160 }, { 160, 100, 60 } },
    }

    for layer = 1, 3 do
        local ly = shelfY + (layer - 1) * layerH
        -- 隔板
        nvgBeginPath(nvg)
        nvgRect(nvg, shelfX, ly + layerH - 2, shelfW, 3)
        nvgFillColor(nvg, nvgRGBA(160, 150, 130, 255))
        nvgFill(nvg)

        -- 药盒（每层5个）
        local boxW = shelfW / 6
        local boxH = layerH * 0.65
        local colors = boxColors[layer]
        for i = 1, 5 do
            local bx = shelfX + (i - 1) * (shelfW / 5) + 4
            local by = ly + layerH - boxH - 5
            local c = colors[i]
            -- 药盒
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bx, by, boxW, boxH, 2)
            nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 230))
            nvgFill(nvg)
            -- 标签
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bx + 2, by + boxH * 0.3, boxW - 4, boxH * 0.35, 1)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 180))
            nvgFill(nvg)
        end
    end

    -- ========== 玻璃柜台 ==========
    local counterX = x + w * 0.08
    local counterY = floorY - h * 0.08
    local counterW = w * 0.50
    local counterH = h * 0.08
    -- 柜台主体
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, counterX, counterY, counterW, counterH, 3)
    nvgFillColor(nvg, nvgRGBA(180, 220, 240, 200))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(140, 180, 200, 200))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    -- 柜台顶面
    nvgBeginPath(nvg)
    nvgRect(nvg, counterX, counterY, counterW, 3)
    nvgFillColor(nvg, nvgRGBA(200, 230, 245, 255))
    nvgFill(nvg)

    -- ========== 药剂师人物剪影 ==========
    local pharmacistX = x + w * 0.75
    local pharmacistY = y + h * 0.35
    -- 身体（白大褂）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, pharmacistX, pharmacistY + 15, 30, 45, 4)
    nvgFillColor(nvg, nvgRGBA(245, 245, 250, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(200, 200, 210, 200))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)
    -- 头
    nvgBeginPath(nvg)
    nvgCircle(nvg, pharmacistX + 15, pharmacistY + 8, 10)
    nvgFillColor(nvg, nvgRGBA(230, 200, 170, 255))
    nvgFill(nvg)
    -- 眼镜
    nvgStrokeColor(nvg, nvgRGBA(80, 80, 80, 200))
    nvgStrokeWidth(nvg, 1)
    nvgBeginPath(nvg)
    nvgCircle(nvg, pharmacistX + 11, pharmacistY + 7, 3)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, pharmacistX + 19, pharmacistY + 7, 3)
    nvgStroke(nvg)
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, pharmacistX + 14, pharmacistY + 7)
    nvgLineTo(nvg, pharmacistX + 16, pharmacistY + 7)
    nvgStroke(nvg)
    -- 绿十字胸章
    nvgFillColor(nvg, nvgRGBA(30, 140, 60, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, pharmacistX + 13, pharmacistY + 22, 4, 8)
    nvgRect(nvg, pharmacistX + 11, pharmacistY + 24, 8, 4)
    nvgFill(nvg)

    -- ========== 浮动胶囊动画 ==========
    PharmacyScene.drawFloatingCapsule(nvg, x + w * 0.82, y + h * 0.20, animTime)
    PharmacyScene.drawFloatingCapsule(nvg, x + w * 0.70, y + h * 0.65, animTime + 1.5)

    -- ========== 右侧小货架 ==========
    local rshelfX = x + w * 0.68
    local rshelfY = y + h * 0.45
    local rshelfW = w * 0.25
    local rshelfH = h * 0.30
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, rshelfX, rshelfY, rshelfW, rshelfH, 2)
    nvgFillColor(nvg, nvgRGBA(235, 230, 215, 255))
    nvgFill(nvg)
    -- 小货架隔板
    for i = 1, 2 do
        nvgBeginPath(nvg)
        nvgRect(nvg, rshelfX, rshelfY + i * rshelfH / 3 - 1, rshelfW, 2)
        nvgFillColor(nvg, nvgRGBA(160, 150, 130, 255))
        nvgFill(nvg)
    end
    -- 小瓶子
    local bottleColors = { { 60, 160, 220 }, { 220, 100, 60 }, { 80, 200, 80 } }
    for i = 1, 3 do
        local by = rshelfY + (i - 1) * rshelfH / 3 + 4
        for j = 1, 3 do
            local bx = rshelfX + (j - 1) * rshelfW / 3 + 5
            local bc = bottleColors[((i + j - 1) % 3) + 1]
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bx, by + 5, rshelfW / 4 - 2, rshelfH / 3 - 12, 2)
            nvgFillColor(nvg, nvgRGBA(bc[1], bc[2], bc[3], 200))
            nvgFill(nvg)
        end
    end
end

--- 浮动胶囊动画
function PharmacyScene.drawFloatingCapsule(nvg, cx, cy, animTime)
    local floatY = cy + math.sin(animTime * 2.0) * 6
    local rot = math.sin(animTime * 1.5) * 0.3

    nvgSave(nvg)
    nvgTranslate(nvg, cx, floatY)
    nvgRotate(nvg, rot)

    -- 胶囊左半（红色）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, -10, -4, 10, 8, 4)
    nvgFillColor(nvg, nvgRGBA(220, 60, 60, 200))
    nvgFill(nvg)
    -- 胶囊右半（白色）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, 0, -4, 10, 8, 4)
    nvgFillColor(nvg, nvgRGBA(245, 240, 230, 200))
    nvgFill(nvg)
    -- 高光
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, -8, -3, 16, 2, 1)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 80))
    nvgFill(nvg)

    nvgRestore(nvg)
end

return PharmacyScene
