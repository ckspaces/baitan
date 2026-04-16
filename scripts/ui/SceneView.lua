-- ============================================================================
-- SceneView.lua - 自定义 Widget: NanoVG 场景渲染器
-- ============================================================================

local UI = require("urhox-libs/UI")
local Widget = UI.Widget

---@class SceneViewWidget : Widget
local SceneViewWidget = Widget:Extend("SceneViewWidget")

function SceneViewWidget:Init(props)
    props = props or {}
    props.flex = props.flex or 1
    props.width = props.width or "100%"
    props.maxHeight = props.maxHeight or 320
    Widget.Init(self, props)
    self.gameState_ = props.gameState
    self.sceneRenderer_ = props.sceneRenderer
    self.animTime_ = 0
end

function SceneViewWidget:Render(nvg)
    local l = self:GetAbsoluteLayout()
    if l.w <= 0 or l.h <= 0 then return end

    nvgSave(nvg)
    nvgIntersectScissor(nvg, l.x, l.y, l.w, l.h)

    -- 委托给场景渲染器
    if self.sceneRenderer_ then
        self.sceneRenderer_.draw(nvg, l.x, l.y, l.w, l.h, self.gameState_, self.animTime_)
    else
        -- 默认渐变背景
        local bg = nvgLinearGradient(nvg, l.x, l.y, l.x, l.y + l.h,
            nvgRGBA(30, 40, 60, 255), nvgRGBA(15, 20, 35, 255))
        nvgBeginPath(nvg)
        nvgRect(nvg, l.x, l.y, l.w, l.h)
        nvgFillPaint(nvg, bg)
        nvgFill(nvg)

        nvgFontFace(nvg, "sans")
        nvgFontSize(nvg, 16)
        nvgTextAlign(nvg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(nvg, nvgRGBA(120, 120, 160, 200))
        nvgText(nvg, l.x + l.w / 2, l.y + l.h / 2, "场景加载中...", nil)
    end

    nvgRestore(nvg)
end

function SceneViewWidget:Update(dt)
    self.animTime_ = self.animTime_ + dt
    if self.gameState_ then
        self.gameState_.animTime = self.animTime_
    end
end

function SceneViewWidget:IsStateful()
    return true
end

-- 工厂模块
local SceneView = {}

function SceneView.create(gameState, sceneRenderer)
    return SceneViewWidget {
        gameState = gameState,
        sceneRenderer = sceneRenderer,
    }
end

return SceneView
