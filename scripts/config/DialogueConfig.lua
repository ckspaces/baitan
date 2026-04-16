-- ============================================================================
-- DialogueConfig.lua - 顾客对话系统配置
-- 叫卖时随机触发顾客对话，通过对话提升名气和信任度
-- ============================================================================

local DialogueConfig = {}

-- 对话触发概率（每次叫卖有此概率触发一次对话）
DialogueConfig.TRIGGER_CHANCE = 0.35

-- 对话类型与配置
-- category: 对话类别（影响触发条件）
-- lines: 顾客台词列表，每条包含：
--   text: 顾客说的话
--   avatar: 顾客头像 emoji
--   replies: 可选的回复选项
--     text: 回复文本
--     trustGain: 信任度增益
--     fameGain: 名气增益
--     moodChange: 心情变化
--     tag: 标签（good/neutral/bad）影响按钮样式
DialogueConfig.DIALOGUES = {
    -- === 新顾客（随机路人） ===
    {
        category = "new_customer",
        minTrust = 0,
        lines = {
            {
                text = "老板，你这%s看着不错啊，好吃吗？",
                avatar = "🧑",
                replies = {
                    { text = "必须好吃！我用的都是新鲜食材", trustGain = 3, fameGain = 2, moodChange = 2, tag = "good" },
                    { text = "还行吧，你尝尝就知道了", trustGain = 1, fameGain = 0, moodChange = 0, tag = "neutral" },
                    { text = "不好吃不要钱！", trustGain = 5, fameGain = 3, moodChange = -1, tag = "good" },
                },
            },
            {
                text = "这个怎么卖的？贵不贵啊？",
                avatar = "👩",
                replies = {
                    { text = "很实惠的！量大管饱", trustGain = 3, fameGain = 1, moodChange = 1, tag = "good" },
                    { text = "一分钱一分货，品质保证", trustGain = 2, fameGain = 2, moodChange = 0, tag = "neutral" },
                    { text = "嫌贵别买", trustGain = -2, fameGain = -1, moodChange = -3, tag = "bad" },
                },
            },
            {
                text = "第一次路过这儿，你在这摆摊多久了？",
                avatar = "👨",
                replies = {
                    { text = "有一段时间了，老顾客都说好吃！", trustGain = 4, fameGain = 2, moodChange = 2, tag = "good" },
                    { text = "刚开始干，多多关照", trustGain = 3, fameGain = 1, moodChange = 1, tag = "good" },
                    { text = "不记得了，你到底买不买？", trustGain = -1, fameGain = -1, moodChange = -2, tag = "bad" },
                },
            },
        },
    },
    -- === 回头客（需要一定信任度） ===
    {
        category = "returning",
        minTrust = 20,
        lines = {
            {
                text = "老板我又来了！上次买的%s太好吃了！",
                avatar = "😊",
                replies = {
                    { text = "欢迎欢迎！今天给你多加点", trustGain = 5, fameGain = 3, moodChange = 3, tag = "good" },
                    { text = "谢谢支持，常来啊！", trustGain = 3, fameGain = 2, moodChange = 2, tag = "good" },
                    { text = "嗯，赶紧点吧", trustGain = 0, fameGain = 0, moodChange = 0, tag = "neutral" },
                },
            },
            {
                text = "老板，你这%s能不能少点辣？我朋友不太能吃辣",
                avatar = "👧",
                replies = {
                    { text = "没问题！我给你做个微辣版", trustGain = 6, fameGain = 3, moodChange = 2, tag = "good" },
                    { text = "口味没法改，就这一种", trustGain = 0, fameGain = 0, moodChange = -1, tag = "neutral" },
                    { text = "不能吃辣别吃啊", trustGain = -3, fameGain = -2, moodChange = -3, tag = "bad" },
                },
            },
            {
                text = "老板，我带同事一起来的，你给打个折呗？",
                avatar = "🧑‍💼",
                replies = {
                    { text = "老顾客带朋友，当然优惠！", trustGain = 6, fameGain = 5, moodChange = 3, tag = "good" },
                    { text = "折扣给不了，但多送你一份", trustGain = 4, fameGain = 3, moodChange = 1, tag = "good" },
                    { text = "已经很便宜了，不能再少了", trustGain = 1, fameGain = 0, moodChange = -1, tag = "neutral" },
                },
            },
        },
    },
    -- === 挑剔顾客（需要较高信任度才出现，但加成也高） ===
    {
        category = "picky",
        minTrust = 40,
        lines = {
            {
                text = "你这卫生条件怎么样啊？食材新鲜吗？",
                avatar = "🧐",
                replies = {
                    { text = "您放心，每天新进货，绝不用隔夜的", trustGain = 8, fameGain = 5, moodChange = 2, tag = "good" },
                    { text = "街边摊就这条件，将就吃吧", trustGain = -2, fameGain = -3, moodChange = -2, tag = "bad" },
                    { text = "欢迎您来检查，我对品质很自信", trustGain = 10, fameGain = 6, moodChange = 3, tag = "good" },
                },
            },
            {
                text = "我在网上看到有人推荐你家，特意来尝尝的",
                avatar = "📱",
                replies = {
                    { text = "太感谢了！我一定不让您失望", trustGain = 6, fameGain = 8, moodChange = 5, tag = "good" },
                    { text = "网红推荐的都靠谱，尝尝就知道", trustGain = 3, fameGain = 4, moodChange = 2, tag = "neutral" },
                    { text = "是吗？那赶紧买吧", trustGain = 0, fameGain = 1, moodChange = 0, tag = "neutral" },
                },
            },
        },
    },
    -- === 特殊顾客（高名气时触发） ===
    {
        category = "special",
        minTrust = 0,
        minFame = 300,
        lines = {
            {
                text = "你就是那个网上很火的摊主吧？能合个影不？",
                avatar = "🤳",
                replies = {
                    { text = "可以可以！来，一起拍！", trustGain = 3, fameGain = 15, moodChange = 5, tag = "good" },
                    { text = "不好意思，我在忙呢", trustGain = 0, fameGain = -2, moodChange = -1, tag = "neutral" },
                },
            },
            {
                text = "老板，我是做美食自媒体的，能采访你几个问题吗？",
                avatar = "🎤",
                replies = {
                    { text = "当然！我很乐意分享创业故事", trustGain = 5, fameGain = 20, moodChange = 5, tag = "good" },
                    { text = "可以，但别耽误我做生意", trustGain = 2, fameGain = 8, moodChange = 0, tag = "neutral" },
                    { text = "算了，不想被拍", trustGain = 0, fameGain = -5, moodChange = -2, tag = "bad" },
                },
            },
        },
    },
}

return DialogueConfig
