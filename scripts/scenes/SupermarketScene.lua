-- ============================================================================
-- SupermarketScene.lua - 超市场景（NanoVG 绘制）
-- ============================================================================

local SupermarketScene = {}

function SupermarketScene.draw(nvg, x, y, w, h, gs, animTime)
    -- 室内明亮白色背景（超市灯光感）
    local bg = nvgLinearGradient(nvg, x, y, x, y + h,
        nvgRGBA(245, 248, 255, 255), nvgRGBA(225, 230, 240, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h)
    nvgFillPaint(nvg, bg)
    nvgFill(nvg)

    -- 地板（浅米色方格）
    local floorY = y + h * 0.78
    nvgBeginPath(nvg)
    nvgRect(nvg, x, floorY, w, h * 0.22)
    nvgFillColor(nvg, nvgRGBA(230, 225, 210, 255))
    nvgFill(nvg)
    -- 方格纹
    nvgStrokeColor(nvg, nvgRGBA(210, 205, 190, 150))
    nvgStrokeWidth(nvg, 0.5)
    local tileSize = w / 8
    for i = 0, 8 do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x + i * tileSize, floorY)
        nvgLineTo(nvg, x + i * tileSize, y + h)
        nvgStroke(nvg)
    end
    local floorH = h * 0.22
    local rowCount = math.ceil(floorH / tileSize)
    for i = 0, rowCount do
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, x, floorY + i * tileSize)
        nvgLineTo(nvg, x + w, floorY + i * tileSize)
        nvgStroke(nvg)
    end

    -- ========== 超市招牌 ==========
    local signX = x + w * 0.15
    local signY = y + h * 0.02
    local signW = w * 0.70
    local signH = h * 0.08
    -- 招牌底板（蓝色）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, signX, signY, signW, signH, 5)
    nvgFillColor(nvg, nvgRGBA(30, 100, 200, 255))
    nvgFill(nvg)
    -- 招牌文字
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 14)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 255, 250))
    nvgText(nvg, signX + signW / 2, signY + signH / 2, "🛒 便利超市", nil)

    -- ========== 左侧货架（食品区，3层） ==========
    local shelfX = x + w * 0.03
    local shelfY = y + h * 0.16
    local shelfW = w * 0.44
    local shelfH = h * 0.56
    local layerH = shelfH / 3

    -- 货架背板
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, shelfX, shelfY, shelfW, shelfH, 3)
    nvgFillColor(nvg, nvgRGBA(250, 245, 235, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(180, 170, 155, 200))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 分区标签
    nvgFontSize(nvg, 7)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(100, 100, 100, 180))
    nvgText(nvg, shelfX + 3, shelfY + 2, "食品区", nil)

    -- 货架商品
    local foodEmojis = {
        { "🍜", "🍞", "🥤", "🧃" },
        { "🍪", "🍫", "🥚", "🍚" },
        { "🥫", "🍿", "🧈", "🥜" },
    }
    local foodColors = {
        { { 255, 180, 80 }, { 210, 170, 110 }, { 80, 180, 220 }, { 120, 200, 80 } },
        { { 200, 150, 80 }, { 140, 80, 40 }, { 240, 230, 210 }, { 245, 245, 240 } },
        { { 180, 60, 60 }, { 240, 200, 80 }, { 250, 220, 120 }, { 180, 140, 80 } },
    }

    for layer = 1, 3 do
        local ly = shelfY + (layer - 1) * layerH
        -- 隔板
        nvgBeginPath(nvg)
        nvgRect(nvg, shelfX, ly + layerH - 2, shelfW, 3)
        nvgFillColor(nvg, nvgRGBA(170, 160, 140, 255))
        nvgFill(nvg)
        -- 商品盒子
        local itemCount = #foodEmojis[layer]
        local boxW = shelfW / (itemCount + 0.5)
        local boxH = layerH * 0.60
        for i = 1, itemCount do
            local bx = shelfX + (i - 0.5) * boxW
            local by = ly + layerH - boxH - 6
            local c = foodColors[layer][i]
            -- 商品包装
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bx, by, boxW * 0.8, boxH, 2)
            nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 220))
            nvgFill(nvg)
            -- 商品标签
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bx + 2, by + boxH * 0.25, boxW * 0.8 - 4, boxH * 0.4, 1)
            nvgFillColor(nvg, nvgRGBA(255, 255, 255, 160))
            nvgFill(nvg)
        end
    end

    -- ========== 右侧货架（日用区，3层） ==========
    local rshelfX = x + w * 0.52
    local rshelfY = y + h * 0.16
    local rshelfW = w * 0.44
    local rshelfH = h * 0.40
    local rlayerH = rshelfH / 3

    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, rshelfX, rshelfY, rshelfW, rshelfH, 3)
    nvgFillColor(nvg, nvgRGBA(245, 245, 252, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(180, 180, 195, 200))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 分区标签
    nvgFontSize(nvg, 7)
    nvgTextAlign(nvg, NVG_ALIGN_LEFT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(100, 100, 100, 180))
    nvgText(nvg, rshelfX + 3, rshelfY + 2, "日用区", nil)

    -- 日用品（用色块+形状表现）
    local dailyColors = {
        { { 100, 180, 240 }, { 240, 120, 160 }, { 120, 220, 120 } },
        { { 255, 200, 60 }, { 180, 140, 220 }, { 60, 200, 200 } },
        { { 240, 160, 80 }, { 80, 160, 200 }, { 200, 200, 80 } },
    }
    for layer = 1, 3 do
        local ly = rshelfY + (layer - 1) * rlayerH
        -- 隔板
        nvgBeginPath(nvg)
        nvgRect(nvg, rshelfX, ly + rlayerH - 2, rshelfW, 2)
        nvgFillColor(nvg, nvgRGBA(170, 170, 185, 255))
        nvgFill(nvg)
        -- 瓶瓶罐罐
        local colors = dailyColors[layer]
        for i = 1, 3 do
            local bx = rshelfX + (i - 1) * rshelfW / 3 + 6
            local bw = rshelfW / 4 - 2
            local bh = rlayerH * 0.62
            local by = ly + rlayerH - bh - 5
            local c = colors[i]
            -- 瓶子主体
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bx, by + bh * 0.2, bw, bh * 0.8, 3)
            nvgFillColor(nvg, nvgRGBA(c[1], c[2], c[3], 200))
            nvgFill(nvg)
            -- 瓶盖
            nvgBeginPath(nvg)
            nvgRoundedRect(nvg, bx + bw * 0.2, by, bw * 0.6, bh * 0.25, 2)
            nvgFillColor(nvg, nvgRGBA(c[1] * 0.7, c[2] * 0.7, c[3] * 0.7, 220))
            nvgFill(nvg)
        end
    end

    -- ========== 收银台 ==========
    local counterX = x + w * 0.54
    local counterY = floorY - h * 0.10
    local counterW = w * 0.40
    local counterH = h * 0.10
    -- 柜台主体
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, counterX, counterY, counterW, counterH, 4)
    nvgFillColor(nvg, nvgRGBA(160, 140, 110, 255))
    nvgFill(nvg)
    -- 柜台顶面（浅色）
    nvgBeginPath(nvg)
    nvgRect(nvg, counterX, counterY, counterW, 4)
    nvgFillColor(nvg, nvgRGBA(200, 185, 160, 255))
    nvgFill(nvg)
    -- 收银机
    local regX = counterX + counterW * 0.55
    local regY = counterY - h * 0.04
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, regX, regY, counterW * 0.3, h * 0.05, 2)
    nvgFillColor(nvg, nvgRGBA(60, 60, 60, 240))
    nvgFill(nvg)
    -- 收银机屏幕
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, regX + 3, regY + 2, counterW * 0.3 - 6, h * 0.025, 1)
    nvgFillColor(nvg, nvgRGBA(80, 200, 120, 200))
    nvgFill(nvg)

    -- ========== 促销价签 ==========
    SupermarketScene.drawPriceTag(nvg, x + w * 0.08, y + h * 0.14, "特价", animTime)
    SupermarketScene.drawPriceTag(nvg, x + w * 0.85, y + h * 0.12, "促销", animTime + 1.0)

    -- ========== 购物车（底部装饰） ==========
    SupermarketScene.drawCart(nvg, x + w * 0.10, floorY - h * 0.02, w * 0.12, animTime)

    -- ========== 顶部灯光效果 ==========
    for i = 1, 3 do
        local lx = x + w * (0.15 + (i - 1) * 0.30)
        local ly2 = y + h * 0.10
        -- 灯管
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, lx, ly2, w * 0.18, 3, 1)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 200))
        nvgFill(nvg)
        -- 灯光光晕
        local glow = nvgRadialGradient(nvg, lx + w * 0.09, ly2 + 2, 2, w * 0.12,
            nvgRGBA(255, 255, 240, 40), nvgRGBA(255, 255, 240, 0))
        nvgBeginPath(nvg)
        nvgRect(nvg, lx - w * 0.03, ly2, w * 0.24, h * 0.15)
        nvgFillPaint(nvg, glow)
        nvgFill(nvg)
    end
end

--- 促销价签动画（轻微摇摆）
function SupermarketScene.drawPriceTag(nvg, cx, cy, text, animTime)
    local swing = math.sin(animTime * 3.0) * 0.15

    nvgSave(nvg)
    nvgTranslate(nvg, cx, cy)
    nvgRotate(nvg, swing)

    -- 价签主体（黄色）
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, -14, -8, 28, 16, 2)
    nvgFillColor(nvg, nvgRGBA(255, 220, 40, 240))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(220, 160, 20, 200))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 文字
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 8)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(200, 30, 30, 255))
    nvgText(nvg, 0, 0, text, nil)

    -- 悬挂线
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, 0, -8)
    nvgLineTo(nvg, 0, -14)
    nvgStrokeColor(nvg, nvgRGBA(150, 150, 150, 200))
    nvgStrokeWidth(nvg, 0.8)
    nvgStroke(nvg)

    nvgRestore(nvg)
end

--- 购物车
function SupermarketScene.drawCart(nvg, cx, cy, size, animTime)
    local s = size
    -- 车身
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx, cy)
    nvgLineTo(nvg, cx + s * 0.2, cy - s * 0.6)
    nvgLineTo(nvg, cx + s * 0.9, cy - s * 0.6)
    nvgLineTo(nvg, cx + s, cy - s * 0.1)
    nvgLineTo(nvg, cx + s * 0.15, cy - s * 0.1)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(180, 180, 190, 180))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(140, 140, 150, 200))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 网格线
    nvgStrokeColor(nvg, nvgRGBA(160, 160, 170, 120))
    nvgStrokeWidth(nvg, 0.5)
    for i = 1, 3 do
        local t = i / 4
        local lx1 = cx + s * (0.2 + (0.15 - 0.2) * t) -- 左边垂直
        nvgBeginPath(nvg)
        nvgMoveTo(nvg, cx + s * (0.17 + t * 0.21), cy - s * 0.55)
        nvgLineTo(nvg, cx + s * (0.15 + t * 0.22), cy - s * 0.12)
        nvgStroke(nvg)
    end

    -- 轮子
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx + s * 0.3, cy + s * 0.05, s * 0.06)
    nvgFillColor(nvg, nvgRGBA(80, 80, 80, 220))
    nvgFill(nvg)
    nvgBeginPath(nvg)
    nvgCircle(nvg, cx + s * 0.85, cy + s * 0.05, s * 0.06)
    nvgFillColor(nvg, nvgRGBA(80, 80, 80, 220))
    nvgFill(nvg)

    -- 推手
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, cx, cy)
    nvgLineTo(nvg, cx - s * 0.15, cy - s * 0.8)
    nvgStrokeColor(nvg, nvgRGBA(140, 140, 150, 200))
    nvgStrokeWidth(nvg, 1.5)
    nvgStroke(nvg)
end

return SupermarketScene
