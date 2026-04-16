-- ============================================================================
-- TopBar.lua - 顶部 HUD 状态栏
-- ============================================================================

local UI = require("urhox-libs/UI")

local TopBar = {}

--- 创建顶栏
function TopBar.create(gs, colors)
    return UI.Panel {
        id = "topBar",
        width = "100%",
        paddingTop = 4,
        paddingBottom = 4,
        paddingLeft = 10,
        paddingRight = 10,
        backgroundColor = colors.BG_TOPBAR,
        borderBottomWidth = 1,
        borderBottomColor = colors.BORDER,
        flexDirection = "column",
        gap = 3,
        children = {
            -- 第一行：日期 + 天气 + 现金
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                justifyContent = "space-between",
                alignItems = "center",
                children = {
                    UI.Panel {
                        flexDirection = "row", gap = 4, alignItems = "center",
                        children = {
                            UI.Label {
                                id = "dateLabel",
                                text = gs.getDateText(),
                                fontSize = 11,
                                fontColor = colors.TEXT_GRAY,
                            },
                            UI.Label {
                                id = "weatherLabel",
                                text = TopBar.getWeatherText(gs),
                                fontSize = 10,
                                fontColor = { 200, 220, 255, 255 },
                            },
                        },
                    },
                    UI.Panel {
                        flexDirection = "row",
                        gap = 12,
                        children = {
                            UI.Label {
                                id = "cashLabel",
                                text = "$" .. gs.formatMoney(gs.cash),
                                fontSize = 13,
                                fontColor = colors.CASH_GREEN,
                            },
                            UI.Label {
                                id = "debtLabel",
                                text = "欠:" .. gs.formatMoney(gs.totalDebt),
                                fontSize = 11,
                                fontColor = colors.DEBT_RED,
                            },
                        },
                    },
                },
            },
            -- 第二行：体力条 + 心情条
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                gap = 6,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "体力",
                        fontSize = 9,
                        fontColor = colors.ENERGY_BLUE,
                        width = 22,
                    },
                    UI.ProgressBar {
                        id = "energyBar",
                        value = gs.energy / 100,
                        flex = 1,
                        height = 6,
                        borderRadius = 3,
                        fillColor = colors.ENERGY_BLUE,
                    },
                    UI.Label {
                        text = "心情",
                        fontSize = 9,
                        fontColor = colors.MOOD_YELLOW,
                        width = 22,
                        marginLeft = 4,
                    },
                    UI.ProgressBar {
                        id = "moodBar",
                        value = gs.mood / 100,
                        flex = 1,
                        height = 6,
                        borderRadius = 3,
                        fillColor = colors.MOOD_YELLOW,
                    },
                },
            },
            -- 第三行：健康条 + 生病状态
            UI.Panel {
                width = "100%",
                flexDirection = "row",
                gap = 6,
                alignItems = "center",
                children = {
                    UI.Label {
                        text = "健康",
                        fontSize = 9,
                        fontColor = { 120, 220, 180, 255 },
                        width = 22,
                    },
                    UI.ProgressBar {
                        id = "healthBar",
                        value = (gs.health or 100) / 100,
                        flex = 1,
                        height = 6,
                        borderRadius = 3,
                        fillColor = (gs.health or 100) > 30
                            and { 120, 220, 180, 255 }
                            or { 255, 80, 80, 255 },
                    },
                    UI.Label {
                        id = "sickLabel",
                        text = gs.isSick and "🤒生病中" or "",
                        fontSize = 9,
                        fontColor = { 255, 100, 100, 255 },
                        width = gs.isSick and 50 or 0,
                    },
                },
            },
        },
    }
end

--- 获取天气显示文本
function TopBar.getWeatherText(gs)
    local GameConfig = require("config.GameConfig")
    local W = GameConfig.Weather
    if not W then return "" end
    local sEmoji = W.SEASON_EMOJI[gs.currentSeason] or ""
    local wEmoji = W.WEATHER_EMOJI[gs.currentWeather] or ""
    local sName = W.SEASON_NAMES[gs.currentSeason] or ""
    local wName = W.WEATHER_NAMES[gs.currentWeather] or ""
    return string.format("%s%s %s%s", sEmoji, sName, wEmoji, wName)
end

--- 刷新顶栏数据
function TopBar.refresh(uiRoot, gs, colors)
    local dateLabel = uiRoot:FindById("dateLabel")
    if dateLabel then dateLabel:SetText(gs.getDateText()) end

    local cashLabel = uiRoot:FindById("cashLabel")
    if cashLabel then cashLabel:SetText("$" .. gs.formatMoney(gs.cash)) end

    local debtLabel = uiRoot:FindById("debtLabel")
    if debtLabel then debtLabel:SetText("欠:" .. gs.formatMoney(gs.totalDebt)) end

    local weatherLabel = uiRoot:FindById("weatherLabel")
    if weatherLabel then weatherLabel:SetText(TopBar.getWeatherText(gs)) end

    local energyBar = uiRoot:FindById("energyBar")
    if energyBar then energyBar:SetValue(gs.energy / 100) end

    local moodBar = uiRoot:FindById("moodBar")
    if moodBar then moodBar:SetValue(gs.mood / 100) end

    local healthBar = uiRoot:FindById("healthBar")
    if healthBar then healthBar:SetValue((gs.health or 100) / 100) end

    local sickLabel = uiRoot:FindById("sickLabel")
    if sickLabel then sickLabel:SetText(gs.isSick and "🤒生病中" or "") end
end

return TopBar
