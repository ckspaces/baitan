-- ============================================================================
-- SaveSystem.lua - 本地存档系统
-- 使用 UrhoX File API + cjson 实现本地存档
-- 后续可迁移至 clientCloud 云端存档
-- ============================================================================

---@diagnostic disable: undefined-global
-- cjson 是引擎内置全局变量，启动时自动注册

local GameState = require "core.GameState"

local SaveSystem = {}

local SAVE_FILE = "save.json"

--- 保存游戏状态到本地文件
---@return boolean success
function SaveSystem.save()
    local saveData = GameState.toSaveData()
    local ok, jsonStr = pcall(cjson.encode, saveData)
    if not ok then
        log:Write(LOG_ERROR, "[SaveSystem] encode failed: " .. tostring(jsonStr))
        return false
    end

    local file = File(SAVE_FILE, FILE_WRITE)
    if not file:IsOpen() then
        log:Write(LOG_ERROR, "[SaveSystem] cannot open file for writing")
        return false
    end
    file:WriteString(jsonStr)
    file:Close()
    log:Write(LOG_INFO, "[SaveSystem] saved OK")
    return true
end

--- 从本地文件加载游戏状态
---@param config table GameConfig
---@return boolean success
function SaveSystem.load(config)
    if not fileSystem:FileExists(SAVE_FILE) then
        log:Write(LOG_INFO, "[SaveSystem] no save file found")
        return false
    end

    local file = File(SAVE_FILE, FILE_READ)
    if not file:IsOpen() then
        log:Write(LOG_ERROR, "[SaveSystem] cannot open file for reading")
        return false
    end

    local jsonStr = file:ReadString()
    file:Close()

    if not jsonStr or #jsonStr == 0 then
        log:Write(LOG_WARNING, "[SaveSystem] save file is empty")
        return false
    end

    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok then
        log:Write(LOG_ERROR, "[SaveSystem] decode failed: " .. tostring(data))
        return false
    end

    -- 先 init 以确保所有字段有默认值，再用存档覆盖
    GameState.init(config)
    local loaded = GameState.fromSaveData(data)
    if loaded then
        -- 同步信任度到当前地点
        GameState.syncTrustToLocation(config)
        log:Write(LOG_INFO, "[SaveSystem] loaded OK, month=" .. GameState.currentMonth)
    end
    return loaded
end

--- 删除存档
---@return boolean success
function SaveSystem.delete()
    if fileSystem:FileExists(SAVE_FILE) then
        -- 写入空文件覆盖（UrhoX 沙箱不提供 os.remove）
        local file = File(SAVE_FILE, FILE_WRITE)
        if file:IsOpen() then
            file:WriteString("")
            file:Close()
            log:Write(LOG_INFO, "[SaveSystem] save deleted")
            return true
        end
    end
    return false
end

--- 检查是否有存档
---@return boolean
function SaveSystem.hasSave()
    return fileSystem:FileExists(SAVE_FILE)
end

return SaveSystem
