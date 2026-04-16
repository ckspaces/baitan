-- ============================================================================
-- FameSystem.lua - 粉丝/声望/直播/短视频系统
-- ============================================================================

local FameSystem = {}

--- 获取粉丝收入预估
function FameSystem.getPassiveIncomePreview(gs)
    if gs.followers <= 0 then return 0 end
    return math.floor(gs.followers * 0.01)
end

return FameSystem
