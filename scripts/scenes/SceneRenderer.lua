-- ============================================================================
-- SceneRenderer.lua - 场景绘制调度器（重构版：移除 office 默认）
-- ============================================================================

local CharacterRenderer = require("scenes.CharacterRenderer")

local SceneRenderer = {}

-- 场景绘制器注册表
local sceneDrawers_ = {}

--- 注册场景绘制器
function SceneRenderer.register(name, drawer)
    sceneDrawers_[name] = drawer
end

--- 主绘制入口
function SceneRenderer.draw(nvg, x, y, w, h, gs, animTime)
    animTime = animTime or 0

    -- 获取当前场景的绘制器
    local drawer = sceneDrawers_[gs.currentScene] or sceneDrawers_["stall"]

    -- 绘制场景背景
    if drawer and drawer.draw then
        drawer.draw(nvg, x, y, w, h, gs, animTime)
    else
        -- 默认渐变背景
        local bg = nvgLinearGradient(nvg, x, y, x, y + h,
            nvgRGBA(40, 50, 80, 255), nvgRGBA(20, 25, 40, 255))
        nvgBeginPath(nvg)
        nvgRect(nvg, x, y, w, h)
        nvgFillPaint(nvg, bg)
        nvgFill(nvg)
    end

    -- 在场景上绘制角色
    CharacterRenderer.draw(nvg, x, y, w, h, gs, animTime)

    -- 绘制浮动信息
    SceneRenderer.drawFloatingInfo(nvg, x, y, w, h, gs, animTime)
end

--- 绘制浮动信息（日期、活动状态）
function SceneRenderer.drawFloatingInfo(nvg, x, y, w, h, gs, animTime)
    -- 右上角显示进度
    nvgFontFace(nvg, "sans")
    nvgFontSize(nvg, 10)
    nvgTextAlign(nvg, NVG_ALIGN_RIGHT + NVG_ALIGN_TOP)
    nvgFillColor(nvg, nvgRGBA(200, 200, 220, 120))
    local progress = string.format("剩余%d个月", math.max(0, 60 - gs.currentMonth + 1))
    nvgText(nvg, x + w - 8, y + 8, progress, nil)

    -- 当前活动状态（底部居中）
    local activityNames = {
        idle = "等待中...",
        working = "努力工作中",
        studying = "认真学习",
        resting = "好好休息",
        eating = "享用美食",
        streaming = "直播中",
        filming = "拍摄视频",
        stalling = "摆摊中",
        pharmacy = "在药店买药",
        shopping = "在超市购物",
    }
    local actText = activityNames[gs.currentActivity] or ""
    if actText ~= "" then
        nvgFontSize(nvg, 12)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_BOTTOM)
        nvgFillColor(nvg, nvgRGBA(255, 255, 255, 150))
        nvgText(nvg, x + w / 2, y + h - 10, actText, nil)
    end
end

return SceneRenderer
