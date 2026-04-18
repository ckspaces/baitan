-- ============================================================================
-- server_main.lua - 摆摊大亨 · 常驻服务器
-- 职责：接收客户端连接，从 serverCloud 读写存档数据
-- ============================================================================

---@diagnostic disable: undefined-global

-- serverCloud key（版本化，方便后续存档格式升级时迁移）
local SAVE_KEY = "stall_save_v1"

-- uid → connection 映射（断线时清理）
local connections = {}

-- ============================================================================
-- 启动
-- ============================================================================

function Start()
    print("[Server] 摆摊大亨 常驻服务器启动")

    -- 注册所有远程事件（必须！否则引擎静默丢弃）
    network:RegisterRemoteEvent("ClientReady")
    network:RegisterRemoteEvent("SaveDataLoad")
    network:RegisterRemoteEvent("SaveDataUpdate")

    SubscribeToEvent("ClientConnected",    "HandleClientConnected")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")
    SubscribeToEvent("ClientReady",        "HandleClientReady")
end

function Stop()
    print("[Server] 服务器关闭，当前在线玩家数: " .. CountConnections())
end

-- ============================================================================
-- 连接事件
-- ============================================================================

function HandleClientConnected(eventType, eventData)
    print("[Server] 新客户端连接")
end

function HandleClientDisconnected(eventType, eventData)
    local conn = eventData["Connection"]:GetPtr("Connection")
    -- 从缓存移除
    for uid, c in pairs(connections) do
        if c == conn then
            connections[uid] = nil
            print(string.format("[Server] 玩家 %s 断线", tostring(uid)))
            break
        end
    end
end

-- ClientReady 时：读取存档并发给客户端，同时注册存档更新监听
function HandleClientReady(eventType, eventData)
    local conn = eventData["Connection"]:GetPtr("Connection")
    local uidVariant = conn.identity["user_id"]
    local uid = uidVariant and uidVariant:GetInt64() or 10001  -- dev 模式回退
    connections[uid] = conn

    print(string.format("[Server] 玩家 %s 就绪，正在加载存档...", tostring(uid)))

    -- 订阅存档更新（全局订阅，远程事件通过 eventData["Connection"] 区分玩家）
    SubscribeToEvent("SaveDataUpdate", "HandleSaveDataUpdate")

    -- 从 serverCloud 加载存档
    serverCloud:Get(uid, SAVE_KEY, {
        ok = function(scores, iscores, sscores)
            -- serverCloud:Set() 写入 scores bucket，从 scores 读取
            local saveJson = scores and scores[SAVE_KEY]
            -- 兼容旧的 sscores bucket（历史数据）
            if not saveJson or saveJson == "" then
                saveJson = sscores and sscores[SAVE_KEY]
            end
            local hasData  = saveJson ~= nil and saveJson ~= ""

            local payload = VariantMap()
            payload["data"]     = Variant(saveJson or "")
            payload["has_save"] = Variant(hasData)

            if conn then
                conn:SendRemoteEvent("SaveDataLoad", true, payload)
                print(string.format("[Server] 玩家 %s 存档已发送（%s）",
                    tostring(uid), hasData and "有存档" or "新游戏"))
            end
        end,
        error = function(code, reason)
            print(string.format("[Server] 玩家 %s 存档加载失败: %s %s",
                tostring(uid), tostring(code), tostring(reason)))
            -- 发送空存档，让客户端以新游戏模式启动
            local payload = VariantMap()
            payload["data"]     = Variant("")
            payload["has_save"] = Variant(false)
            if conn then
                conn:SendRemoteEvent("SaveDataLoad", true, payload)
            end
        end,
    })
end

-- ============================================================================
-- 接收客户端上传的存档
-- ============================================================================

function HandleSaveDataUpdate(eventType, eventData)
    local conn     = eventData["Connection"]:GetPtr("Connection")
    local saveJson = eventData["data"]:GetString()

    -- 找到对应 uid
    local uid = nil
    for u, c in pairs(connections) do
        if c == conn then
            uid = u
            break
        end
    end

    if not uid then
        print("[Server] SaveDataUpdate: 无法识别玩家 uid，跳过")
        return
    end
    if not saveJson or #saveJson == 0 then
        print("[Server] SaveDataUpdate: 存档数据为空，跳过")
        return
    end

    -- 写入 serverCloud（sscores 使用 Set，支持任意字符串）
    serverCloud:Set(uid, SAVE_KEY, saveJson, {
        ok = function()
            print(string.format("[Server] 玩家 %s 存档保存成功（%d 字节）",
                tostring(uid), #saveJson))
        end,
        error = function(code, reason)
            print(string.format("[Server] 玩家 %s 存档保存失败: %s %s",
                tostring(uid), tostring(code), tostring(reason)))
        end,
    })
end

-- ============================================================================
-- 工具
-- ============================================================================

function CountConnections()
    local n = 0
    for _ in pairs(connections) do n = n + 1 end
    return n
end
