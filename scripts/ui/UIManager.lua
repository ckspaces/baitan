-- ============================================================================
-- UIManager.lua - 根 UI 树构建和管理（重构版）
-- ============================================================================

local UI = require("urhox-libs/UI")
local TopBar = require("ui.TopBar")
local BottomActions = require("ui.BottomActions")
local SceneView = require("ui.SceneView")

local UIManager = {}

---@type Widget
local uiRoot_ = nil
local currentTab_ = "main"

--- 构建完整 UI
function UIManager.build(gs, config, sceneRenderer, callbacks)
    local C = config.Colors

    -- 包装 callbacks，注入 tab 切换逻辑
    local wrappedCallbacks = {
        onAction = callbacks.onAction,
        onTabChange = function(tabId)
            currentTab_ = tabId
            UIManager.refreshActions(gs, config, callbacks)
        end,
    }

    uiRoot_ = UI.Panel {
        id = "root",
        width = "100%",
        height = "100%",
        flexDirection = "column",
        backgroundColor = C.BG_DARK,
        children = {
            UI.SafeAreaView {
                width = "100%",
                flex = 1,
                flexDirection = "column",
                children = {
                    -- 顶部 HUD
                    TopBar.create(gs, C),
                    -- 中间场景
                    SceneView.create(gs, sceneRenderer),
                    -- 底部操作
                    BottomActions.create(gs, config, C, wrappedCallbacks),
                },
            },
        },
    }

    UI.SetRoot(uiRoot_)
    return uiRoot_
end

--- 刷新所有 UI 数据
function UIManager.refresh(gs, config, callbacks)
    if not uiRoot_ then return end
    local C = config.Colors
    TopBar.refresh(uiRoot_, gs, C)
    UIManager.refreshActions(gs, config, callbacks)
    UIManager.refreshMessage(gs, config)
end

--- 刷新操作区内容（Tab切换或状态变化时）
function UIManager.refreshActions(gs, config, callbacks)
    if not uiRoot_ then return end
    local C = config.Colors
    local actionContent = uiRoot_:FindById("actionContent")
    if not actionContent then return end

    local wrappedCallbacks = {
        onAction = callbacks.onAction,
        onTabChange = function(tabId)
            currentTab_ = tabId
            UIManager.refreshActions(gs, config, callbacks)
        end,
    }

    -- 清除旧内容
    actionContent:ClearChildren()

    -- 根据当前 Tab 构建新内容
    local content
    if currentTab_ == "main" then
        content = BottomActions.buildMainTab(gs, config, C, wrappedCallbacks)
    elseif currentTab_ == "life" then
        content = BottomActions.buildLifeTab(gs, config, C, wrappedCallbacks)
    elseif currentTab_ == "finance" then
        content = BottomActions.buildFinanceTab(gs, config, C, wrappedCallbacks)
    elseif currentTab_ == "growth" then
        content = BottomActions.buildGrowthTab(gs, config, C, wrappedCallbacks)
    else
        content = BottomActions.buildMainTab(gs, config, C, wrappedCallbacks)
    end

    actionContent:AddChild(content)

    -- 更新 Tab 高亮
    for _, tab in ipairs({"main", "life", "finance", "growth"}) do
        local btn = uiRoot_:FindById("tab_" .. tab)
        if btn then
            btn:SetStyle({ variant = (tab == currentTab_) and "primary" or "ghost" })
        end
    end
end

--- 刷新消息栏
function UIManager.refreshMessage(gs, config)
    if not uiRoot_ then return end
    local C = config.Colors
    local msgLabel = uiRoot_:FindById("messageLabel")
    if not msgLabel then return end

    local msg = gs.messages[1]
    if msg then
        local msgColor = C.TEXT_DIM
        if msg.type == "success" then msgColor = C.SUCCESS
        elseif msg.type == "warning" then msgColor = C.WARNING
        elseif msg.type == "danger" then msgColor = C.DANGER
        end
        msgLabel:SetText(msg.text)
        msgLabel:SetStyle({ fontColor = msgColor })
    end
end

--- 获取 UI 根节点
function UIManager.getRoot()
    return uiRoot_
end

return UIManager
