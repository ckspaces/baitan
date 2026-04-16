-- ============================================================================
-- ShopScene.lua - 门店场景
-- ============================================================================

local ShopScene = {}

function ShopScene.draw(nvg, x, y, w, h, gs, animTime)
    -- 天空
    local sky = nvgLinearGradient(nvg, x, y, x, y + h * 0.35,
        nvgRGBA(130, 185, 230, 255), nvgRGBA(195, 215, 240, 255))
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y, w, h * 0.35)
    nvgFillPaint(nvg, sky)
    nvgFill(nvg)

    -- 地面/人行道
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.55, w, h * 0.45)
    nvgFillColor(nvg, nvgRGBA(180, 175, 160, 255))
    nvgFill(nvg)

    -- 马路
    nvgBeginPath(nvg)
    nvgRect(nvg, x, y + h * 0.78, w, h * 0.08)
    nvgFillColor(nvg, nvgRGBA(80, 80, 90, 255))
    nvgFill(nvg)

    -- 店铺建筑
    local shopX = x + w * 0.12
    local shopY = y + h * 0.2
    local shopW = w * 0.76
    local shopH = h * 0.42

    -- 建筑主体
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, shopX, shopY, shopW, shopH, 4)
    nvgFillColor(nvg, nvgRGBA(245, 240, 225, 255))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(180, 175, 160, 255))
    nvgStrokeWidth(nvg, 2)
    nvgStroke(nvg)

    -- 屋顶
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, shopX - 5, shopY)
    nvgLineTo(nvg, shopX + shopW / 2, shopY - 25)
    nvgLineTo(nvg, shopX + shopW + 5, shopY)
    nvgClosePath(nvg)
    nvgFillColor(nvg, nvgRGBA(180, 70, 50, 255))
    nvgFill(nvg)

    -- 招牌
    local signW = shopW * 0.7
    local signX = shopX + (shopW - signW) / 2
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, signX, shopY + 5, signW, 24, 4)
    nvgFillColor(nvg, nvgRGBA(200, 50, 40, 255))
    nvgFill(nvg)

    -- 招牌文字
    local shopName = (#gs.businesses > 0) and gs.businesses[1].name or "我的小店"
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 13)
    nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(nvg, nvgRGBA(255, 255, 230, 255))
    nvgText(nvg, signX + signW / 2, shopY + 17, shopName, nil)

    -- 大玻璃窗
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, shopX + 15, shopY + 35, shopW * 0.4, shopH * 0.5, 3)
    nvgFillColor(nvg, nvgRGBA(170, 210, 250, 180))
    nvgFill(nvg)
    nvgStrokeColor(nvg, nvgRGBA(150, 150, 160, 255))
    nvgStrokeWidth(nvg, 1)
    nvgStroke(nvg)

    -- 窗户里的货架
    for i = 0, 2 do
        nvgBeginPath(nvg)
        nvgRect(nvg, shopX + 20, shopY + 45 + i * 18, shopW * 0.35, 2)
        nvgFillColor(nvg, nvgRGBA(160, 140, 100, 120))
        nvgFill(nvg)
    end

    -- 门
    local doorW = shopW * 0.2
    local doorX = shopX + shopW * 0.6
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, doorX, shopY + 35, doorW, shopH * 0.58, 3)
    nvgFillColor(nvg, nvgRGBA(140, 100, 60, 255))
    nvgFill(nvg)
    -- 门玻璃
    nvgBeginPath(nvg)
    nvgRoundedRect(nvg, doorX + 4, shopY + 40, doorW - 8, shopH * 0.25, 2)
    nvgFillColor(nvg, nvgRGBA(180, 215, 245, 160))
    nvgFill(nvg)
    -- 门把手
    nvgBeginPath(nvg)
    nvgCircle(nvg, doorX + doorW - 8, shopY + 35 + shopH * 0.35, 3)
    nvgFillColor(nvg, nvgRGBA(220, 200, 100, 255))
    nvgFill(nvg)

    -- 遮阳棚
    nvgBeginPath(nvg)
    nvgMoveTo(nvg, shopX, shopY + 32)
    for i = 0, 8 do
        local px = shopX + shopW * i / 8
        local py = shopY + 32 + ((i % 2 == 0) and 0 or 8)
        nvgLineTo(nvg, px, py)
    end
    nvgLineTo(nvg, shopX + shopW, shopY + 32)
    nvgFillColor(nvg, nvgRGBA(220, 60, 40, 200))
    nvgFill(nvg)

    -- 路边行人（小圆点代表）
    ShopScene.drawPassersby(nvg, x, y, w, h, animTime)
end

--- 绘制路人
function ShopScene.drawPassersby(nvg, x, y, w, h, animTime)
    local baseY = y + h * 0.7
    for i = 1, 4 do
        local speed = 15 + i * 8
        local px = x + ((i * 100 + animTime * speed) % (w + 40)) - 20
        -- 身体
        nvgBeginPath(nvg)
        nvgCircle(nvg, px, baseY - 8, 4)
        nvgFillColor(nvg, nvgRGBA(100 + i * 30, 80 + i * 20, 120, 180))
        nvgFill(nvg)
        nvgBeginPath(nvg)
        nvgRoundedRect(nvg, px - 3, baseY - 4, 6, 10, 2)
        nvgFill(nvg)
    end
end

return ShopScene
