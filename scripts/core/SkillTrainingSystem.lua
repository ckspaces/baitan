-- ============================================================================
-- SkillTrainingSystem.lua - 技能训练系统
-- 玩家通过学习课程获得技能经验，支持实时CD、广告加速、经验领取
-- ============================================================================

local PlayerSystem = require("core.PlayerSystem")

local SkillTrainingSystem = {}

-- ============================================================================
-- 课程定义（每个技能 3 档：入门 / 系统 / 深度）
-- durationSecs: 真实时间秒数（看广告可减少50%，最多3次）
-- costCash: 报名费（入门免费）
-- xpReward: 完成后获得的技能经验
-- ============================================================================
SkillTrainingSystem.COURSES = {
    management = {
        { id="mgmt_1", name="日常管理练习",  emoji="📋", xpReward=25,  durationSecs=60,  costCash=0,   desc="基础管理入门，提升库存效率" },
        { id="mgmt_2", name="进销存培训",    emoji="📊", xpReward=100, durationSecs=180, costCash=50,  desc="系统学习供应链，改善经营节奏" },
        { id="mgmt_3", name="摊位运营实战",  emoji="🏪", xpReward=320, durationSecs=480, costCash=150, desc="深度实战，大幅提升管理水平" },
    },
    marketing = {
        { id="mkt_1",  name="吆喝口才练习",  emoji="📢", xpReward=25,  durationSecs=60,  costCash=0,   desc="练习叫卖技巧，增强营销说服力" },
        { id="mkt_2",  name="短视频制作课",  emoji="📱", xpReward=100, durationSecs=180, costCash=50,  desc="学习内容营销，吸引更多粉丝" },
        { id="mkt_3",  name="品牌策划培训",  emoji="🎯", xpReward=320, durationSecs=480, costCash=150, desc="系统品牌打造，解锁高级促销" },
    },
    tech = {
        { id="tech_1", name="食材处理练习",  emoji="🔪", xpReward=25,  durationSecs=60,  costCash=0,   desc="提升食材利用率，改善商品品质" },
        { id="tech_2", name="烹饪技巧培训",  emoji="👨‍🍳", xpReward=100, durationSecs=180, costCash=50,  desc="掌握更多制作方法，解锁精品菜品" },
        { id="tech_3", name="专业厨师课程",  emoji="⭐", xpReward=320, durationSecs=480, costCash=150, desc="深度学习厨艺，解锁高端配方" },
    },
    charm = {
        { id="charm_1", name="微笑服务训练", emoji="😊", xpReward=25,  durationSecs=60,  costCash=0,   desc="提升顾客好感，信任度增长加快" },
        { id="charm_2", name="待客之道培训", emoji="🤝", xpReward=100, durationSecs=180, costCash=50,  desc="学习建立顾客关系，城管交涉率提升" },
        { id="charm_3", name="人际关系课程", emoji="💫", xpReward=320, durationSecs=480, costCash=150, desc="深度培训，城管处理成功率大幅提升" },
    },
    negotiation = {
        { id="nego_1", name="口才基础训练",  emoji="🗣️", xpReward=25,  durationSecs=60,  costCash=0,   desc="提升叫卖说服力，吸引更多顾客" },
        { id="nego_2", name="价格谈判技巧",  emoji="💰", xpReward=100, durationSecs=180, costCash=50,  desc="学习讨价还价，叫卖转化率提升" },
        { id="nego_3", name="高级谈判课程",  emoji="🏆", xpReward=320, durationSecs=480, costCash=150, desc="深度培训，叫卖效果质的飞跃" },
    },
}

-- 技能元信息（名称、图标、每级解锁效果描述）
SkillTrainingSystem.SKILL_META = {
    management  = { name="管理", emoji="📋", color={100,180,255,255},
        levelEffects={
            -- 每级: 产量×+11%，尾货回收率+3%
            [2]="每批产量+11%，尾货可回收3%成本",
            [3]="每批产量+22%，尾货可回收6%成本",
            [4]="每批产量+33%，尾货可回收9%成本",
            [5]="每批产量+44%，尾货可回收12%成本",
            [6]="每批产量+55%，尾货可回收15%成本",
            [7]="每批产量+66%，尾货可回收18%成本",
            [8]="每批产量+77%，尾货可回收21%成本",
            [9]="每批产量+88%，尾货可回收24%成本",
            [10]="每批产量翻番，尾货可回收27%成本",
        }},
    marketing   = { name="营销", emoji="📢", color={255,160,80,255},
        levelEffects={
            [2]="传单效果+20%，解锁更多促销",
            [3]="粉丝增长+15%，直播收益提升",
            [4]="口碑增长加快，解锁高级促销",
            [5]="名气加成翻倍，解锁全平台推广",
            [6]="直播间热度+30%，爆单概率提升",
            [7]="社群运营解锁，粉丝自发传播",
            [8]="品牌效应显现，顾客主动介绍",
            [9]="头部网红资源，合作推广机会",
            [10]="全域营销大师，流量自然涌入",
        }},
    tech        = { name="技术", emoji="🔪", color={100,220,150,255},
        levelEffects={
            -- 每级: 尾货回收率+2%（配合管理技能叠加）
            [2]="尾货保鲜回收+2%，解锁新品类",
            [3]="尾货保鲜回收+4%，食材利用率提升",
            [4]="尾货保鲜回收+6%，解锁高端商品",
            [5]="尾货保鲜回收+8%，设备损耗减半",
            [6]="尾货保鲜回收+10%，工艺精进",
            [7]="尾货保鲜回收+12%，出品稳定性大增",
            [8]="尾货保鲜回收+14%，冷链储存能力",
            [9]="尾货保鲜回收+16%，接近零损耗",
            [10]="尾货保鲜回收+18%，大师级食材掌控",
        }},
    charm       = { name="魅力", emoji="😊", color={255,130,180,255},
        levelEffects={
            [2]="城管交涉成功率+20%，顾客好感提升",
            [3]="吸引回头客，信任度衰减减少",
            [4]="城管处理成功率大幅提升",
            [5]="解锁VIP顾客，每日额外收益",
            [6]="顾客单价自愿上浮，口碑飞涨",
            [7]="负面事件概率降低，人缘极佳",
            [8]="媒体主动报道，品牌形象溢价",
            [9]="粉丝忠诚度满，核心客群稳固",
            [10]="个人IP成型，自带流量效应",
        }},
    negotiation = { name="谈判", emoji="🗣️", color={200,160,255,255},
        levelEffects={
            -- 每级: 采购折扣-3%（配合经营天数最高-41%）
            [2]="采购折扣-3%，叫卖转化率提升",
            [3]="采购折扣-6%，讨价还价胜率上升",
            [4]="采购折扣-9%，供应商主动联系",
            [5]="采购折扣-12%，稳定长期供货价",
            [6]="采购折扣-15%，批量议价能力强",
            [7]="采购折扣-18%，可拒绝不合理涨价",
            [8]="采购折扣-21%，成为供应商优质客户",
            [9]="采购折扣-24%，获得独家供货渠道",
            [10]="采购折扣-27%，行业顶级采购谈判",
        }},
}

-- ============================================================================
-- 开始训练
-- ============================================================================
---@param gs table GameState
---@param config table GameConfig
---@param skillType string 技能类型
---@param courseIdx number 课程索引（1/2/3）
---@return boolean, string
function SkillTrainingSystem.startTraining(gs, config, skillType, courseIdx)
    -- 检查是否已有训练（已完成未领取也算）
    if gs.training then
        if gs.training.remainSecs > 0 then
            return false, "已有课程在学习中，请先等待完成"
        else
            return false, "上一门课程已完成，请先领取经验"
        end
    end

    local courses = SkillTrainingSystem.COURSES[skillType]
    if not courses then return false, "无效技能类型" end

    local course = courses[courseIdx]
    if not course then return false, "无效课程" end

    -- 检查报名费
    if (course.costCash or 0) > 0 then
        if gs.cash < course.costCash then
            return false, string.format("报名费不足，需要 $%d", course.costCash)
        end
        gs.cash = gs.cash - course.costCash
        local addCash = gs.cashLedger and true or false
        if addCash then
            table.insert(gs.cashLedger, 1, {
                amount   = -course.costCash,
                category = "training",
                reason   = "技能培训：" .. course.name,
                balance  = gs.cash,
                date     = gs.getDateText and gs.getDateText() or "",
                timeText = gs.getTimeText and gs.getTimeText() or "",
            })
        end
    end

    gs.training = {
        skillType   = skillType,
        courseIdx   = courseIdx,
        courseId    = course.id,
        courseName  = course.name,
        emoji       = course.emoji,
        totalSecs   = course.durationSecs,
        remainSecs  = course.durationSecs,
        xpReward    = course.xpReward,
        adSpeedUps  = 0,   -- 本次已使用广告加速次数（上限3次）
    }

    local meta = SkillTrainingSystem.SKILL_META[skillType]
    gs.addMessage(string.format(
        "开始学习：%s %s（%s，CD %ds）",
        course.emoji, course.name,
        meta and meta.name or skillType,
        course.durationSecs
    ), "success")
    return true, "ok"
end

-- ============================================================================
-- 实时更新训练 CD（在 HandleUpdate 中每帧调用）
-- 返回 true 表示刚完成（可触发 UI 刷新）
-- ============================================================================
---@param gs table GameState
---@param config table GameConfig
---@param dt number 帧时间（秒）
---@return boolean justCompleted
function SkillTrainingSystem.updateTraining(gs, config, dt)
    local t = gs.training
    if not t then return false end
    if t.remainSecs <= 0 then return false end  -- 已完成待领取，不再倒计时

    local wasAbove = t.remainSecs > 0
    t.remainSecs = math.max(0, t.remainSecs - dt)
    local justCompleted = wasAbove and t.remainSecs <= 0

    if justCompleted then
        local meta = SkillTrainingSystem.SKILL_META[t.skillType]
        gs.addMessage(string.format(
            "🎓 %s %s 学习完成！回到成长页面领取经验 +%d",
            t.emoji, t.courseName, t.xpReward
        ), "success")
    end
    return justCompleted
end

-- ============================================================================
-- 广告加速（看完广告减少50%剩余CD，每次训练最多3次）
-- ============================================================================
---@param gs table GameState
---@return boolean, string
function SkillTrainingSystem.speedUpWithAd(gs)
    local t = gs.training
    if not t then return false, "当前没有训练中的课程" end
    if t.remainSecs <= 0 then return false, "课程已完成，请领取经验" end
    if (t.adSpeedUps or 0) >= 3 then
        return false, "本次训练广告加速已达上限（3次）"
    end

    local reduction = math.max(5, math.floor(t.remainSecs * 0.5))
    t.remainSecs  = math.max(0, t.remainSecs - reduction)
    t.adSpeedUps  = (t.adSpeedUps or 0) + 1

    local remaining = SkillTrainingSystem.formatRemaining(t.remainSecs)
    gs.addMessage(string.format(
        "⚡ 广告加速！减少 %ds，剩余 %s（还可加速 %d 次）",
        reduction, remaining, 3 - t.adSpeedUps
    ), "success")
    return true, "ok"
end

-- ============================================================================
-- 领取训练奖励
-- ============================================================================
---@param gs table GameState
---@param config table GameConfig
---@return boolean, string
function SkillTrainingSystem.claimTraining(gs, config)
    local t = gs.training
    if not t then return false, "没有进行中的训练" end
    if t.remainSecs > 0 then
        return false, string.format("训练尚未完成，还剩 %s",
            SkillTrainingSystem.formatRemaining(t.remainSecs))
    end

    local leveled = PlayerSystem.addSkillXP(gs, t.skillType, t.xpReward, config)
    local skill   = gs.skills[t.skillType]
    local meta    = SkillTrainingSystem.SKILL_META[t.skillType]
    local skillName = meta and meta.name or t.skillType

    if leveled then
        local effect = (meta and meta.levelEffects and meta.levelEffects[skill.level]) or ""
        gs.addMessage(string.format(
            "🎉 %s %s 升到 Lv.%d！%s",
            meta and meta.emoji or "", skillName, skill.level, effect
        ), "success")
        gs.addLog(string.format("技能 %s 升至 Lv.%d", skillName, skill.level), "levelup")
    else
        gs.addMessage(string.format(
            "✅ %s %s 经验 +%d（Lv.%d）",
            meta and meta.emoji or "", skillName, t.xpReward, skill.level
        ), "success")
    end

    gs.training = nil
    return true, "ok"
end

-- ============================================================================
-- 辅助查询
-- ============================================================================

--- 是否有训练在进行（含已完成待领取）
function SkillTrainingSystem.isTraining(gs)
    return gs.training ~= nil
end

--- 是否训练完成待领取
function SkillTrainingSystem.isCompleted(gs)
    return gs.training ~= nil and gs.training.remainSecs <= 0
end

--- 训练进度 0~1
function SkillTrainingSystem.getProgress(gs)
    local t = gs.training
    if not t or t.totalSecs <= 0 then return 1 end
    return 1 - (t.remainSecs / t.totalSecs)
end

--- 格式化剩余时间
function SkillTrainingSystem.formatRemaining(secs)
    local s = math.ceil(secs or 0)
    if s <= 0 then return "已完成" end
    if s < 60 then return string.format("%d秒", s) end
    local m = math.floor(s / 60)
    local r = s % 60
    if r == 0 then return string.format("%d分钟", m) end
    return string.format("%d分%02d秒", m, r)
end

return SkillTrainingSystem
