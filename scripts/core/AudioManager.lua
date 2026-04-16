-- ============================================================================
-- AudioManager.lua - 音频管理器（BGM/SFX，基于 Effects 库）
-- ============================================================================

local Effects = require("urhox-libs.Effects.Effects")

local AudioManager = {}

---@type Scene
local audioScene_ = nil
---@type table|nil
local bgmHandle_ = nil
local currentBGM_ = ""

--- 初始化音频系统（创建专用 Scene 承载 SoundSource）
function AudioManager.init()
    if audioScene_ then return end
    audioScene_ = Scene()
    audioScene_:CreateComponent("Octree")
    print("[AudioManager] 音频系统初始化完成")
end

--- 播放背景音乐（循环，自动替换旧 BGM）
---@param path string 音乐文件路径（如 "Sounds/bgm_main.ogg"）
---@param gain? number 音量（默认 0.5）
function AudioManager.playBGM(path, gain)
    if not audioScene_ then AudioManager.init() end
    if currentBGM_ == path and bgmHandle_ then return end -- 相同曲目不重复播放

    -- 停止旧 BGM
    AudioManager.stopBGM()

    bgmHandle_ = Effects.PlaySoundLooped(audioScene_, path, {
        gain = gain or 0.5,
        soundType = SOUND_MUSIC,
    })

    if bgmHandle_ then
        currentBGM_ = path
        print("[AudioManager] BGM: " .. path)
    else
        print("[AudioManager] BGM 加载失败: " .. path)
    end
end

--- 停止 BGM
function AudioManager.stopBGM()
    if bgmHandle_ then
        bgmHandle_:Stop()
        bgmHandle_ = nil
        currentBGM_ = ""
    end
end

--- 淡出 BGM
---@param duration? number 淡出时间秒（默认 1.0）
function AudioManager.fadeOutBGM(duration)
    if bgmHandle_ then
        bgmHandle_:FadeOut(duration or 1.0)
        bgmHandle_ = nil
        currentBGM_ = ""
    end
end

--- 播放音效（一次性）
---@param path string 音效文件路径
---@param gain? number 音量（默认 0.8）
function AudioManager.playSFX(path, gain)
    if not audioScene_ then AudioManager.init() end
    Effects.PlaySound(audioScene_, path, {
        gain = gain or 0.8,
    })
end

--- 获取当前 BGM 路径
function AudioManager.getCurrentBGM()
    return currentBGM_
end

--- 关闭音频系统
function AudioManager.shutdown()
    AudioManager.stopBGM()
    if audioScene_ then
        audioScene_:Remove()
        audioScene_ = nil
    end
end

return AudioManager
