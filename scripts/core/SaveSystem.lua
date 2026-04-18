-- ============================================================================
-- SaveSystem.lua - 存档系统
-- 单机模式：使用 UrhoX File API + cjson 本地存档
-- 网络模式：通过 SendRemoteEvent 上传到常驻服务器
-- ============================================================================

---@diagnostic disable: undefined-global

local GameState = require "core.GameState"

local SaveSystem = {}

local SAVE_FILE = "save.json"

-- 网络连接引用（网络模式下由 main.lua 注入）
local _serverConn = nil

-- ============================================================================
-- 网络模式注入
-- ============================================================================

--- 注入服务器连接（网络模式下调用，切换为云端存档）
---@param conn any Connection 对象
function SaveSystem.setServerConnection(conn)
    _serverConn = conn
    log:Write(LOG_INFO, "[SaveSystem] 切换为云端存档模式")
end

--- 清除服务器连接（断线时调用，回退到本地存档）
function SaveSystem.clearServerConnection()
    _serverConn = nil
    log:Write(LOG_INFO, "[SaveSystem] 回退到本地存档模式")
end

--- 当前是否为网络模式
function SaveSystem.isNetworkMode()
    return _serverConn ~= nil
end

-- ============================================================================
-- 保存
-- ============================================================================

--- 保存游戏状态
--- 网络模式：上传到服务器 | 单机模式：写入本地文件
---@return boolean success
function SaveSystem.save()
    local saveData = GameState.toSaveData()
    local ok, jsonStr = pcall(cjson.encode, saveData)
    if not ok then
        log:Write(LOG_ERROR, "[SaveSystem] encode failed: " .. tostring(jsonStr))
        return false
    end

    -- 网络模式：发给服务器
    if _serverConn then
        local payload = VariantMap()
        payload["data"] = Variant(jsonStr)
        _serverConn:SendRemoteEvent("SaveDataUpdate", true, payload)
        log:Write(LOG_INFO, "[SaveSystem] 云端存档上传（" .. #jsonStr .. " 字节）")
        return true
    end

    -- 单机模式：本地文件
    local file = File(SAVE_FILE, FILE_WRITE)
    if not file:IsOpen() then
        log:Write(LOG_ERROR, "[SaveSystem] 无法打开本地文件写入")
        return false
    end
    file:WriteString(jsonStr)
    file:Close()
    log:Write(LOG_INFO, "[SaveSystem] 本地存档已保存")
    return true
end

-- ============================================================================
-- 加载（仅单机模式使用；网络模式由 main.lua 的 HandleSaveDataLoad 接管）
-- ============================================================================

--- 从本地文件加载游戏状态
---@param config table GameConfig
---@return boolean success
function SaveSystem.load(config)
    if not fileSystem:FileExists(SAVE_FILE) then
        log:Write(LOG_INFO, "[SaveSystem] 无本地存档")
        return false
    end

    local file = File(SAVE_FILE, FILE_READ)
    if not file:IsOpen() then
        log:Write(LOG_ERROR, "[SaveSystem] 无法打开本地文件读取")
        return false
    end

    local jsonStr = file:ReadString()
    file:Close()

    if not jsonStr or #jsonStr == 0 then
        log:Write(LOG_WARNING, "[SaveSystem] 本地存档文件为空")
        return false
    end

    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok then
        log:Write(LOG_ERROR, "[SaveSystem] decode failed: " .. tostring(data))
        return false
    end

    GameState.init(config)
    local loaded = GameState.fromSaveData(data)
    if loaded then
        GameState.syncTrustToLocation(config)
        log:Write(LOG_INFO, "[SaveSystem] 本地存档加载成功，month=" .. GameState.currentMonth)
    end
    return loaded
end

--- 从 JSON 字符串加载（网络模式：服务器发来的存档数据）
---@param config table GameConfig
---@param jsonStr string JSON 字符串
---@return boolean success
function SaveSystem.loadFromJson(config, jsonStr)
    if not jsonStr or #jsonStr == 0 then return false end

    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok then
        log:Write(LOG_ERROR, "[SaveSystem] loadFromJson decode failed: " .. tostring(data))
        return false
    end

    GameState.init(config)
    local loaded = GameState.fromSaveData(data)
    if loaded then
        GameState.syncTrustToLocation(config)
        log:Write(LOG_INFO, "[SaveSystem] 云端存档加载成功，month=" .. GameState.currentMonth)
    end
    return loaded
end

-- ============================================================================
-- 删除 / 检查
-- ============================================================================

--- 删除本地存档
---@return boolean success
function SaveSystem.delete()
    if fileSystem:FileExists(SAVE_FILE) then
        local file = File(SAVE_FILE, FILE_WRITE)
        if file:IsOpen() then
            file:WriteString("")
            file:Close()
            log:Write(LOG_INFO, "[SaveSystem] 本地存档已删除")
            return true
        end
    end
    return false
end

--- 检查是否有本地存档
---@return boolean
function SaveSystem.hasSave()
    return fileSystem:FileExists(SAVE_FILE)
end

return SaveSystem
