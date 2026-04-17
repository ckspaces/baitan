-- ============================================================================
-- GameConfig.lua - 游戏常量与数值平衡（重构版：线性升级 + 真实成本）
-- ============================================================================

local GameConfig = {}

-- 游戏总体
GameConfig.Game = {
    TITLE = "摆摊大亨",
    TOTAL_MONTHS = 60,            -- 5年
    DAYS_PER_MONTH = 7,           -- 每月7天行动回合
    INITIAL_DEBT = 500000,        -- 50万启动贷款
    INITIAL_CASH = 5000,          -- 启动资金5千
    MONTHLY_LIVING_COST = 1500,   -- 基本生活费
    WIN_FAME = 5000,              -- 达到此名气值即成为网红，赢得游戏
}

-- 财务
GameConfig.Finance = {
    BANK_RATE = 0.005,            -- 银行月息 0.5%
    LOAN_SHARK_RATE = 0.02,       -- 民间月息 2%（降低压力）
    INITIAL_BANK_DEBT = 350000,   -- 银行贷款35万
    INITIAL_SHARK_DEBT = 150000,  -- 民间借贷15万
    MIN_REPAY = 5000,             -- 每月最低还款5千
}

-- 角色
GameConfig.Player = {
    MAX_ENERGY = 100,
    MAX_MOOD = 100,
    MAX_HEALTH = 100,
    ENERGY_REST = 35,
    MOOD_DECAY = 2,               -- 每天心情自然衰减（7天/月，减缓节奏）
    LOW_MOOD = 20,
    LOW_ENERGY = 10,
    GOOD_MOOD_THRESHOLD = 60,     -- 心情大于此值时每天自动恢复体力
    GOOD_MOOD_ENERGY_REGEN = 5,   -- 心情好时每天恢复体力量
}

-- 技能
GameConfig.Skills = {
    TYPES = { "management", "marketing", "tech", "charm", "negotiation" },
    NAMES = {
        management = "管理",
        marketing = "营销",
        tech = "技术",
        charm = "魅力",
        negotiation = "谈判",
    },
    XP_PER_LEVEL = { 100, 250, 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000 },
    MAX_LEVEL = 10,
}

-- 休息
GameConfig.Rest = {
    ENERGY_GAIN = 35,
    MOOD_GAIN = 15,
}

-- 娱乐
GameConfig.Relax = {
    ENERGY_COST = 10,
    MOOD_GAIN = 25,
    CASH_COST = 200,
}

-- 钓鱼
GameConfig.Fishing = {
    ENERGY_COST = 15,
    MOOD_GAIN = 20,
    DURATION_MINUTES = 30,
    MAX_FISH_PER_SESSION = 3,
    FISH_CATCH_BASE_RATE = 0.6,
}

-- ============================================================================
-- 主业升级系统（4级线性递进）
-- ============================================================================
GameConfig.MainBusinessTiers = {
    {
        id = "stall", name = "街边摆摊", emoji = "🛒",
        tier = 1,
        upgradeCost = 0,
        monthlyOverhead = 0,     -- 无固定开支
        passiveIncome = nil,     -- 纯靠手动操作
        scene = "stall",
        unlockReq = { month = 1 },
    },
}

-- ============================================================================
-- 各等级菜品（批次进货模型）
-- batchCost=进货成本, yield=产量, unitPrice=单价, salesRange=每次销量范围
-- ============================================================================

-- Tier 1: 街边摆摊（通用商品 + 地点专属商品）
GameConfig.StallItems = {
    { id = "bbq",     name = "烤串",   emoji = "🍢", image = "items/bbq.png",
      batchCost = 40,  yield = 50, unitPrice = 3,  salesRange = { 25, 50 },
      energyCost = 6,  moodCost = 1,  unlockMonth = 1, unlockDay = 0, skillReq = {} },
    { id = "pancake", name = "煎饼",   emoji = "🥞", image = "items/pancake.png",
      batchCost = 30,  yield = 20, unitPrice = 8,  salesRange = { 12, 22 },
      energyCost = 5,  moodCost = 1,  unlockMonth = 1, unlockDay = 0, skillReq = {} },
    { id = "sausage", name = "烤肠",   emoji = "🌭", image = "items/sausage.png",
      batchCost = 25,  yield = 30, unitPrice = 5,  salesRange = { 15, 30 },
      energyCost = 5,  moodCost = 1,  unlockMonth = 1, unlockDay = 3, skillReq = {} },
    { id = "rice",    name = "炒饭",   emoji = "🍳", image = "items/rice.png",
      batchCost = 35,  yield = 15, unitPrice = 12, salesRange = { 8, 16 },
      energyCost = 7,  moodCost = 2,  unlockMonth = 1, unlockDay = 7, skillReq = {} },
    { id = "tea",     name = "奶茶",   emoji = "🧋", image = "items/tea.png",
      batchCost = 20,  yield = 15, unitPrice = 10, salesRange = { 8, 18 },
      energyCost = 4,  moodCost = 1,  unlockMonth = 1, unlockDay = 14, skillReq = { marketing = 1 } },
    { id = "grilled_fish", name = "烤鱼", emoji = "🐟", image = "items/grilled_fish.png",
      batchCost = 0,   yield = 3,  unitPrice = 35, salesRange = { 2, 5 },
      energyCost = 15, moodCost = 2,  unlockMonth = 1, unlockDay = 0, skillReq = {},
      requiresFish = true, fishNeeded = 1,
      desc = "新鲜钓来的鱼现烤，香气四溢" },
}

-- ============================================================================
-- 地点专属商品（仅在特定地点出现的额外商品）
-- ============================================================================
GameConfig.LocationItems = {
    school = {
        { id = "fried_chicken", name = "炸鸡",    emoji = "🍗", image = "items/fried_chicken.png",
          batchCost = 45,  yield = 25, unitPrice = 8,  salesRange = { 15, 28 },
          energyCost = 7,  moodCost = 2,  unlockMonth = 1, unlockDay = 0, skillReq = {} },
        { id = "chicken_strip", name = "鸡柳",   emoji = "🍖", image = "items/chicken_strip.png",
          batchCost = 35,  yield = 30, unitPrice = 5,  salesRange = { 20, 35 },
          energyCost = 5,  moodCost = 1,  unlockMonth = 1, unlockDay = 3, skillReq = {} },
        { id = "chicken_steak", name = "鸡排",   emoji = "🥩", image = "items/chicken_steak.png",
          batchCost = 50,  yield = 20, unitPrice = 10, salesRange = { 12, 22 },
          energyCost = 6,  moodCost = 1,  unlockMonth = 1, unlockDay = 7, skillReq = {} },
        { id = "bubble_tea",    name = "珍珠奶茶", emoji = "🧋", image = "items/bubble_tea.png",
          batchCost = 25,  yield = 20, unitPrice = 8,  salesRange = { 12, 24 },
          energyCost = 4,  moodCost = 1,  unlockMonth = 1, unlockDay = 10, skillReq = {} },
    },
    community = {
        { id = "jianbing",  name = "手抓饼",  emoji = "🫓", image = "items/jianbing.png",
          batchCost = 30,  yield = 20, unitPrice = 7,  salesRange = { 12, 22 },
          energyCost = 5,  moodCost = 1,  unlockMonth = 1, unlockDay = 0, skillReq = {} },
        { id = "congbing",  name = "葱油饼",  emoji = "🥞", image = "items/congbing.png",
          batchCost = 20,  yield = 25, unitPrice = 5,  salesRange = { 15, 28 },
          energyCost = 5,  moodCost = 1,  unlockMonth = 1, unlockDay = 5, skillReq = {} },
    },
    nightmarket = {
        { id = "stinky_tofu", name = "臭豆腐",  emoji = "🫕", image = "items/stinky_tofu.png",
          batchCost = 30,  yield = 20, unitPrice = 10, salesRange = { 12, 22 },
          energyCost = 6,  moodCost = 1,  unlockMonth = 3, unlockDay = 0, skillReq = {} },
        { id = "squid",       name = "铁板鱿鱼", emoji = "🦑", image = "items/squid.png",
          batchCost = 40,  yield = 15, unitPrice = 12, salesRange = { 10, 18 },
          energyCost = 7,  moodCost = 2,  unlockMonth = 3, unlockDay = 5, skillReq = {} },
    },
    business = {
        { id = "coffee",   name = "手冲咖啡",  emoji = "☕", image = "items/coffee.png",
          batchCost = 35,  yield = 15, unitPrice = 15, salesRange = { 8, 16 },
          energyCost = 5,  moodCost = 1,  unlockMonth = 2, unlockDay = 0, skillReq = { tech = 1 } },
    },
    station = {
        { id = "boxlunch", name = "便当盒饭",  emoji = "🍱", image = "items/boxlunch.png",
          batchCost = 50,  yield = 20, unitPrice = 15, salesRange = { 12, 22 },
          energyCost = 7,  moodCost = 2,  unlockMonth = 5, unlockDay = 0, skillReq = {} },
    },
}

-- 摆摊事件（所有tier通用）
GameConfig.StallEvents = {
    { id = "chengguan", name = "城管来了！",   type = "negative", prob = 0.15, desc = "城管朝你走过来了！",           effect = "chengguan_encounter" },
    { id = "rain",      name = "突然下雨",     type = "negative", prob = 0.12, desc = "人都走了，收入减半...",        effect = "half_income" },
    { id = "compete",   name = "同行竞争",     type = "negative", prob = 0.10, desc = "隔壁摆了同样的摊，客人分流了", effect = "reduce_30" },
    { id = "broken",    name = "设备故障",     type = "negative", prob = 0.08, desc = "设备坏了，修理花了点钱",       effect = "repair_cost" },
    { id = "bigorder",  name = "大客户上门",   type = "positive", prob = 0.10, desc = "有人一口气买了很多！收入翻倍", effect = "double_income" },
    { id = "praise",    name = "好评如潮",     type = "positive", prob = 0.08, desc = "顾客纷纷好评，声望大涨！",     effect = "reputation_up" },
    { id = "influencer",name = "网红路过",     type = "positive", prob = 0.05, desc = "网红拍了你的摊位，涨粉了！",   effect = "fans_up" },

    -- 新增摆摊事件
    { id = "snow",      name = "下大雪了",    type = "negative", prob = 0.06, desc = "大雪飘飘，路上没人了，生意惨淡", effect = "half_income" },
    { id = "wind",      name = "大风刮摊",    type = "negative", prob = 0.08, desc = "大风把展示物吹翻，忙着收拾没顾客", effect = "half_income" },
    { id = "blackout",  name = "周边停电",    type = "negative", prob = 0.06, desc = "附近突然停电，天黑客人全跑了！",   effect = "half_income" },
    { id = "gas_issue", name = "煤气报警",    type = "negative", prob = 0.05, desc = "设备发出警报，被迫中止营业修理",   effect = "repair_cost" },
    { id = "lowprice",  name = "隔壁大甩卖",  type = "negative", prob = 0.08, desc = "对面摊位搞降价活动，你的客人被抢走", effect = "reduce_30" },
    { id = "peakhour",  name = "黄金时段",    type = "positive", prob = 0.08, desc = "晚高峰人特别多，排队买买买！",     effect = "double_income" },
    { id = "school_out",name = "学生放学潮",  type = "positive", prob = 0.07, desc = "附近学校放学，学生蜂拥而来！",     effect = "double_income" },
    { id = "short_video",name = "被拍短视频", type = "positive", prob = 0.06, desc = "路人把你摊位拍下来发网上，涨粉！", effect = "fans_up" },
    { id = "sample_success", name = "试吃大成功", type = "positive", prob = 0.07, desc = "发出去的试吃让一大波人回来下单！", effect = "double_income" },
    { id = "vip_customer",   name = "大V顾客",     type = "positive", prob = 0.04, desc = "一位有影响力的大V来吃并发帖推荐！", effect = "fans_up" },
    { id = "community_event",name = "社区活动",    type = "positive", prob = 0.05, desc = "社区举办活动，周边客流量暴增！",    effect = "reputation_up" },
}

-- ============================================================================
-- 城管对话系统
-- ============================================================================
GameConfig.Chengguan = {
    -- 城管开场白（随机选一个）
    OPENING_LINES = {
        "这位老板，这里不允许摆摊，你知道吧？",
        "喂，说你呢！这块不让摆摊，赶紧收了！",
        "老板，接到投诉了，你这摊得撤。",
        "例行检查，你有摊位许可证吗？",
    },
    -- 玩家应对选项
    CHOICES = {
        {
            id = "sweet_talk",
            text = "😏 大哥行行好，我就卖完这点收工…",
            -- 魅力检定：charm >= 2 时 70% 成功，否则 30%
            charmThreshold = 2,
            successRate = { high = 0.70, low = 0.30 },
            -- 成功：城管走了，继续摆
            onSuccess = { msg = "行吧，赶紧的，下次别让我看见！", moodChange = 5 },
            -- 失败：没收部分货物
            onFail = { msg = "少来这套！没收一批货，赶紧走！", inventoryLoss = 0.30, moodChange = -10, cooldownDays = 0 },
        },
        {
            id = "beg",
            text = "🙏 大哥我真不容易，上有老下有小…",
            -- 50%概率放走，50%罚款
            successRate = 0.50,
            onSuccess = { msg = "…算了，下不为例啊。赶紧收拾收拾。", moodChange = 3 },
            onFail = { msg = "不容易谁都不容易，罚款交了就行。", fineRange = { 500, 2000 }, moodChange = -8, cooldownDays = 0 },
        },
        {
            id = "run",
            text = "🏃 推车就跑！三十六计走为上！",
            -- 必定逃脱，但有代价
            inventoryLoss = 0.20,       -- 逃跑丢20%货
            forceClose = true,          -- 强制收摊
            cooldownDays = 2,           -- 地点冷却2天
            moodChange = -5,
            msg = "跑是跑掉了，但丢了不少东西…这地方暂时不能来了！",
        },
        {
            id = "argue",
            text = "😤 凭什么？我在这卖东西碍着谁了！",
            -- 最差结果
            fineRange = { 2000, 4000 },
            forceClose = true,
            cooldownDays = 3,
            moodChange = -20,
            negotiationXP = { 8, 15 },  -- 但涨谈判经验
            msg = "态度这么差？罚款！再来这片我天天查你！",
        },
    },
}

-- ============================================================================
-- 渐进式叫卖系统（顾客一个个来，不是一次卖完）
-- ============================================================================
GameConfig.Hawking = {
    CUSTOMERS_PER_HAWK = { 1, 3 },   -- 每次叫卖吸引的顾客数
    UNITS_PER_CUSTOMER = { 1, 3 },   -- 每位顾客购买的份数
    -- 顾客购买时的描述（随机选一个）
    CUSTOMER_LINES = {
        "大哥，来%d份！",
        "老板，给我来%d份尝尝！",
        "闻着真香，来%d份！",
        "这个多少钱？来%d份试试！",
        "给我也来%d份！",
        "看着不错，要%d份！",
        "帮我装%d份，打包带走！",
    },
}

-- 摆摊熟练度系统
GameConfig.Proficiency = {
    XP_PER_HAWK = { 10, 25 },       -- 每次叫卖获得的经验
    LEVELS = { 0, 50, 150, 350, 700, 1200, 2000, 3500, 6000, 10000 }, -- 各等级经验阈值
    MAX_LEVEL = 10,
    SALES_BONUS_PER_LEVEL = 0.05,   -- 每级增加5%销量
    FANS_PER_HAWK = { 1, 5 },       -- 每次叫卖基础涨粉
    FANS_BONUS_PER_LEVEL = 3,       -- 每级额外涨粉
    LEVEL_NAMES = { "新手", "学徒", "熟练", "老手", "高手", "大师", "宗师", "传奇", "神话", "烤神" },
}

-- 单品制作与顺序解锁系统
GameConfig.RecipeProgression = {
    XP_PER_CRAFT = 1,
    XP_PER_SALE = 1,
    UNLOCK_XP_BASE = 16,
    UNLOCK_XP_STEP = 10,
    COOK_UNITS_PER_ACTION = 4,
    COOK_BONUS_EVERY_LEVELS = 2,
    COOK_BONUS_UNITS = 1,
    COOK_MAX_UNITS = 8,
}

-- 信任度与被动销售系统
GameConfig.Trust = {
    -- 信任度增长（每次动作）
    HAWK_TRUST_GAIN = { 3, 8 },      -- 叫卖获得的信任度
    WAIT_TRUST_GAIN = { 1, 3 },      -- 等待观望获得的信任度
    CHAT_TRUST_GAIN = { 5, 12 },     -- 与顾客交流获得的信任度（未来扩展）
    -- 信任度上限与衰减
    MAX_TRUST = 100,                  -- 信任度上限
    MONTHLY_DECAY = 5,                -- 每月衰减（不出摊则口碑慢慢降）
    -- 被动销售参数（渐进式叫卖下降低被动量）
    PASSIVE_BASE_SELL = { 0, 1 },     -- 信任度0时的被动销售量（几乎没人买）
    PASSIVE_MAX_SELL = { 2, 5 },      -- 信任度满时的被动销售量（回头客少量购买）
    -- 等待观望动作
    WAIT_ENERGY_COST = 5,             -- 等待消耗少量体力
    WAIT_MOOD_COST = 2,               -- 等待消耗少量心情
    -- 信任度等级名称
    TRUST_NAMES = {
        { threshold = 0,  name = "无人问津",   emoji = "😶" },
        { threshold = 15, name = "偶有路人",   emoji = "🚶" },
        { threshold = 30, name = "略有名气",   emoji = "👀" },
        { threshold = 50, name = "小有口碑",   emoji = "👍" },
        { threshold = 70, name = "远近闻名",   emoji = "🌟" },
        { threshold = 90, name = "金字招牌",   emoji = "👑" },
    },
}

-- 发传单
GameConfig.Flyer = {
    COST = 500,
    ENERGY_COST = 10,
    BONUS_PER_STACK = 0.15,
    MAX_STACKS = 5,
    MONTHLY_DECAY = 2,
}

-- ============================================================================
-- 天气与季节系统
-- ============================================================================
GameConfig.Weather = {
    -- 季节映射（按月份 1~12）
    SEASON_MAP = {
        "winter", "winter", "spring", "spring", "spring", "summer",
        "summer", "summer", "autumn", "autumn", "autumn", "winter",
    },
    SEASON_NAMES = {
        spring = "春", summer = "夏", autumn = "秋", winter = "冬",
    },
    SEASON_EMOJI = {
        spring = "🌸", summer = "☀️", autumn = "🍂", winter = "❄️",
    },
    -- 天气类型概率（按季节）
    WEATHER_PROBS = {
        spring = { sunny = 0.35, cloudy = 0.25, rainy = 0.30, windy = 0.10, snowy = 0 },
        summer = { sunny = 0.45, cloudy = 0.20, rainy = 0.25, windy = 0.05, snowy = 0 },
        autumn = { sunny = 0.30, cloudy = 0.30, rainy = 0.15, windy = 0.25, snowy = 0 },
        winter = { sunny = 0.20, cloudy = 0.25, rainy = 0.10, windy = 0.15, snowy = 0.30 },
    },
    WEATHER_NAMES = {
        sunny = "晴天", cloudy = "多云", rainy = "下雨", windy = "大风", snowy = "下雪",
    },
    WEATHER_EMOJI = {
        sunny = "☀️", cloudy = "⛅", rainy = "🌧️", windy = "💨", snowy = "🌨️",
    },
    -- 天气对收入的影响
    INCOME_MODIFIER = {
        sunny = 1.1, cloudy = 1.0, rainy = 0.7, windy = 0.85, snowy = 0.6,
    },
}

-- ============================================================================
-- 健康系统
-- ============================================================================
GameConfig.Health = {
    DAILY_DECAY = 1,                -- 每天自然健康衰减
    LOW_ENERGY_DECAY = 2,           -- 低体力时额外衰减
    BAD_WEATHER_DECAY = 2,          -- 恶劣天气额外衰减（雨/雪）
    OVERWORK_THRESHOLD = 20,        -- 体力低于此值算过劳
    SICK_THRESHOLD = 30,            -- 健康低于此值可能生病
    SICK_CHANCE = 0.35,             -- 健康低时每天生病概率
    SICK_INCOME_PENALTY = 0.5,      -- 生病时收入减半
    SICK_ENERGY_PENALTY = 1.5,      -- 生病时体力消耗×1.5
    HOSPITAL_COST = 2000,           -- 去医院费用
    HOSPITAL_HEAL = 80,             -- 医院恢复健康量
    PHARMACY_COST = 500,            -- 药店费用
    PHARMACY_HEAL = 30,             -- 药店恢复健康量
    GOOD_MOOD_REGEN = 2,            -- 心情好时健康自然恢复
}

-- ============================================================================
-- 微信随机事件（弹窗选择型）
-- ============================================================================
GameConfig.WechatEvents = {
    DAILY_TRIGGER_CHANCE = 0.12,    -- 每天触发概率
    EVENTS = {
        {
            id = "debt_old_friend",
            sender = "老王",
            avatar = "😤",
            message = "兄弟，之前借你那笔钱都快一年了，什么时候能还啊？孩子要上学了急用！",
            amountRange = { 500, 3000 },
            choices = {
                { text = "转账还他", effect = "pay",    moodChange = 8,   repChange = 5 },
                { text = "先还一半", effect = "half",   moodChange = 3,   repChange = 1 },
                { text = "再等等吧", effect = "delay",  moodChange = -8,  repChange = -3 },
                { text = "已读不回", effect = "ignore", moodChange = -15, repChange = -8 },
            },
        },
        {
            id = "debt_relative",
            sender = "表哥",
            avatar = "😠",
            message = "表弟，过年那会儿借的钱还记得吧？家里装修急需用钱，麻烦尽快处理下！",
            amountRange = { 1000, 5000 },
            choices = {
                { text = "马上转账", effect = "pay",    moodChange = 10,  repChange = 6 },
                { text = "先还一部分", effect = "half", moodChange = 2,   repChange = 0 },
                { text = "下个月还", effect = "delay",  moodChange = -5,  repChange = -2 },
                { text = "装没看见", effect = "ignore", moodChange = -12, repChange = -6 },
            },
        },
        {
            id = "debt_classmate",
            sender = "大学室友",
            avatar = "🙁",
            message = "哥们，之前说好一个月就还的，现在都三个月了…我也不宽裕啊",
            amountRange = { 300, 2000 },
            choices = {
                { text = "全额奉还", effect = "pay",    moodChange = 6,   repChange = 4 },
                { text = "还一半表诚意", effect = "half", moodChange = 2,  repChange = 1 },
                { text = "月底一定还", effect = "delay", moodChange = -6,  repChange = -2 },
                { text = "不回消息", effect = "ignore",  moodChange = -10, repChange = -5 },
            },
        },
        {
            id = "debt_business",
            sender = "供货商李总",
            avatar = "💼",
            message = "上批货款还没结清，再不付我只能停止供货了。请尽快安排！",
            amountRange = { 2000, 8000 },
            choices = {
                { text = "全额支付", effect = "pay",    moodChange = 5,   repChange = 8 },
                { text = "先付一半", effect = "half",    moodChange = 0,   repChange = 2 },
                { text = "宽限几天", effect = "delay",   moodChange = -5,  repChange = -5 },
                { text = "无视",     effect = "ignore",  moodChange = -8,  repChange = -10 },
            },
        },
        {
            id = "debt_neighbor",
            sender = "隔壁张姐",
            avatar = "😟",
            message = "小伙子，上次救急借你那几百块…我退休金就这点，方便的话还给我行吗？",
            amountRange = { 200, 800 },
            choices = {
                { text = "立马还！抱歉", effect = "pay", moodChange = 12,  repChange = 6 },
                { text = "先还一半",    effect = "half",  moodChange = 5,   repChange = 2 },
                { text = "过两天还您",  effect = "delay", moodChange = -10, repChange = -4 },
                { text = "假装没看到",  effect = "ignore",moodChange = -20, repChange = -10 },
            },
        },
        {
            id = "surprise_gift",
            sender = "高中同学",
            avatar = "🎉",
            message = "听说你最近创业辛苦了！这是我们几个同学凑的，不多但是心意，加油！",
            amountRange = { 500, 2000 },
            isGift = true,
            choices = {
                { text = "感动收下", effect = "accept_gift", moodChange = 25, repChange = 3 },
                { text = "客气拒绝", effect = "refuse_gift", moodChange = 10, repChange = 5 },
            },
        },
        {
            id = "scam_call",
            sender = "未知号码",
            avatar = "📞",
            message = "恭喜您中了大奖！请先转500元手续费到指定账户领取奖金10000元！",
            amountRange = { 500, 500 },
            choices = {
                { text = "这是诈骗！拉黑", effect = "block",   moodChange = 2,   repChange = 1 },
                { text = "居然信了…转账", effect = "scammed",  moodChange = -30, repChange = 0 },
            },
        },
        -- 老妈汇款慰问
        {
            id = "mom_support",
            sender = "老妈",
            avatar = "👩",
            message = "孩子，在外面辛苦了吧？妈给你转点生活费，照顾好自己，吃饱穿暖最重要！",
            amountRange = { 2000, 8000 },
            isGift = true,
            choices = {
                { text = "🥹 妈你最好了！收下啦",   effect = "accept_gift", moodChange = 30, repChange = 0 },
                { text = "妈我够用的，你留着用",    effect = "refuse_gift", moodChange = 18, repChange = 5 },
            },
        },
        -- 前老板嘲讽
        {
            id = "ex_boss_mock",
            sender = "前老板陈总",
            avatar = "😏",
            message = "听说你出去自己搞了？大街上摆摊？哈哈，什么时候想通了随时回来，位置给你留着。",
            amountRange = { 0, 0 },
            choices = {
                { text = "谢谢，我走我自己的路！", effect = "block", moodChange = 15, repChange = 0 },
                { text = "这话刺激到我了……",       effect = "delay", moodChange = -12, repChange = 0 },
            },
        },
        -- 粉丝感谢信
        {
            id = "fan_thanks",
            sender = "粉丝 小鱼",
            avatar = "🐟",
            message = "博主！你的视频陪我度过了最难熬的一段时间，谢谢你一直坚持！你一定会成功的！",
            amountRange = { 0, 0 },
            choices = {
                { text = "谢谢你！我会继续加油的！", effect = "block", moodChange = 28, repChange = 2 },
                { text = "默默看完，感触良多……",     effect = "block", moodChange = 15, repChange = 0 },
            },
        },
        -- 发小借钱（你借出去）
        {
            id = "friend_borrow",
            sender = "发小 阿强",
            avatar = "🤝",
            message = "兄弟！我最近周转不过来，能借我一点应急吗？有钱了一定第一时间还你！",
            amountRange = { 500, 3000 },
            choices = {
                { text = "朋友一场，借给你！",  effect = "pay",    moodChange = 10, repChange = 8 },
                { text = "先借你一半吧",        effect = "half",   moodChange = 5,  repChange = 3 },
                { text = "我也很紧张，帮不上",  effect = "ignore", moodChange = -8, repChange = -3 },
            },
        },
        -- 美食博主联合探店
        {
            id = "collab_foodie",
            sender = "美食博主 吃货君",
            avatar = "🍽️",
            message = "博主你好！我在做城市小吃探店系列，想来拍你摊位，合作一期内容，流量共享！",
            amountRange = { 800, 3000 },
            isGift = true,
            choices = {
                { text = "求之不得！欢迎来拍！", effect = "accept_gift", moodChange = 22, repChange = 5 },
                { text = "最近太忙，下次吧",     effect = "refuse_gift", moodChange = 3,  repChange = 0 },
            },
        },
        -- 老顾客介绍大客户
        {
            id = "customer_referral",
            sender = "老顾客 李姐",
            avatar = "😊",
            message = "老板！我帮你介绍了个大单，附近公司要订你们外卖，谈好了两百份，接不接？",
            amountRange = { 1500, 6000 },
            isGift = true,
            choices = {
                { text = "太感谢了！接单！",      effect = "accept_gift", moodChange = 22, repChange = 6 },
                { text = "数量太多，忙不过来",    effect = "refuse_gift", moodChange = -5, repChange = 2 },
            },
        },
        -- 同学聚会邀请
        {
            id = "class_reunion",
            sender = "班长 小明",
            avatar = "🎓",
            message = "毕业五周年同学聚会！人都齐了就差你！AA制每人出三百，来吗？",
            amountRange = { 300, 600 },
            choices = {
                { text = "参加！好久不见了！",  effect = "pay",    moodChange = 18, repChange = 4 },
                { text = "太忙了，心意到就行",  effect = "ignore", moodChange = -6, repChange = -1 },
            },
        },
        -- 食品安全专项检查
        {
            id = "food_safety_check",
            sender = "市场监督管理局",
            avatar = "🔍",
            message = "您好，近期开展食品安全专项整治，需缴纳卫生整改材料手续费，请配合办理。",
            amountRange = { 500, 2000 },
            choices = {
                { text = "配合缴费，合规经营", effect = "pay",    moodChange = -5,  repChange = 5  },
                { text = "拖着，到时候再说",   effect = "ignore", moodChange = -12, repChange = -8 },
            },
        },
        -- 失散旧友重新联系
        {
            id = "old_friend_contact",
            sender = "初中同学 小慧",
            avatar = "💌",
            message = "好几年没联系啦！刷到你摆摊的视频找到你了！感觉你变了好多，越来越好了！",
            amountRange = { 0, 0 },
            choices = {
                { text = "好久不见！快聊起来！", effect = "block", moodChange = 22, repChange = 3 },
                { text = "互关，偶尔点个赞",     effect = "block", moodChange = 10, repChange = 0 },
            },
        },
        -- 假冒账号出现
        {
            id = "fake_account",
            sender = "热心粉丝",
            avatar = "😡",
            message = "博主！有人用假账号冒充你骗粉丝买货！已经截图了，你快去投诉！",
            amountRange = { 0, 0 },
            choices = {
                { text = "立刻申诉维权，绝不姑息", effect = "block", moodChange = 8,   repChange = 5  },
                { text = "心好累，先不管了……",    effect = "delay", moodChange = -18, repChange = -5 },
            },
        },
        -- 投资人询问
        {
            id = "investor_inquiry",
            sender = "创业基金 王总",
            avatar = "💼",
            message = "您好！我们关注您很久了，您的账号很有潜力，有没有兴趣谈谈早期投资合作？",
            amountRange = { 0, 0 },
            choices = {
                { text = "非常有兴趣！约个时间！", effect = "block", moodChange = 20, repChange = 3 },
                { text = "我还想自己走走，谢了",   effect = "block", moodChange = 8,  repChange = 0 },
            },
        },
        -- 外卖平台合作邀请
        {
            id = "delivery_invite",
            sender = "外卖平台商务",
            avatar = "🛵",
            message = "您好！我们注意到您的摊位评价很高，有兴趣入驻我们平台开外卖店吗？流量免费导入！",
            amountRange = { 0, 0 },
            choices = {
                { text = "开通！线上线下一起搞", effect = "block", moodChange = 15, repChange = 5 },
                { text = "先专注线下摊位",        effect = "block", moodChange = 3,  repChange = 0 },
            },
        },
        -- 自媒体平台签约邀请
        {
            id = "platform_contract",
            sender = "抖音MCN机构",
            avatar = "🎬",
            message = "您好！我们是抖音头部MCN机构，希望与您签约，提供专业运营支持，保底收益！",
            amountRange = { 3000, 8000 },
            isGift = true,
            choices = {
                { text = "签！要专业运营支持！",   effect = "accept_gift", moodChange = 25, repChange = 5 },
                { text = "我想保持独立，不签",     effect = "refuse_gift", moodChange = 5,  repChange = 3 },
            },
        },
    },
}

-- ============================================================================
-- 摆摊地点系统
-- ============================================================================
GameConfig.Locations = {
    {
        id = "school",    name = "学校门口",   emoji = "🏫",
        desc = "学生多，消费能力一般，下午放学时段客流大",
        rentCost = 0,                       -- 每次出摊无租金（占道）
        customerMod = 1.0,                  -- 基础客流倍率
        priceMod = 0.85,                    -- 学生价，单价稍低
        peakDays = { 1, 2, 3, 4, 5 },      -- 工作日客流好
        peakBonus = 0.25,                   -- 高峰期额外客流
        trustGainMod = 1.2,                 -- 学生爱传口碑，信任涨得快
        weatherPenalty = 1.2,               -- 下雨时学生更不愿出来
        unlockMonth = 1,                    -- 默认解锁
        riskMod = 1.3,                      -- 城管来的概率更高
        maxSlots = 3,                       -- 放学时段短，3轮后学生走光
    },
    {
        id = "community", name = "小区门口",   emoji = "🏘️",
        desc = "居民稳定，回头客多，早晚客流最好",
        rentCost = 500,                     -- 每次出摊交物业费
        customerMod = 1.1,
        priceMod = 1.0,
        peakDays = { 1, 2, 3, 4, 5, 6, 7 },
        peakBonus = 0.15,
        trustGainMod = 1.5,                 -- 小区居民更容易成为回头客
        weatherPenalty = 1.0,
        unlockMonth = 1,
        riskMod = 0.7,                      -- 小区内城管少来
        maxSlots = 4,                       -- 早晚有人，持续稍长
    },
    {
        id = "business",  name = "商业街",     emoji = "🏬",
        desc = "人流量大，消费力强，但竞争激烈",
        rentCost = 2000,                    -- 摊位费
        customerMod = 1.4,
        priceMod = 1.15,                    -- 能卖更贵
        peakDays = { 5, 6, 7 },             -- 周末好
        peakBonus = 0.30,
        trustGainMod = 0.8,                 -- 人来人去，不容易积累回头客
        weatherPenalty = 0.8,               -- 有商业街遮挡，天气影响小
        unlockMonth = 2,
        riskMod = 1.0,
        maxSlots = 5,                       -- 人流持续，时间窗口最长
    },
    {
        id = "nightmarket", name = "夜市",    emoji = "🌙",
        desc = "晚上热闹，年轻人多，适合小吃烧烤",
        rentCost = 1500,
        customerMod = 1.3,
        priceMod = 1.1,
        peakDays = { 5, 6, 7 },
        peakBonus = 0.35,
        trustGainMod = 1.0,
        weatherPenalty = 1.5,               -- 夜市露天，下雨影响大
        unlockMonth = 3,
        riskMod = 0.5,                      -- 夜市合法摊位
        maxSlots = 4,                       -- 晚上热闹但也有尽头
    },
    {
        id = "station",   name = "车站附近",   emoji = "🚉",
        desc = "流动人口大，不容易有回头客但客流稳定",
        rentCost = 3000,
        customerMod = 1.5,
        priceMod = 1.2,
        peakDays = { 1, 2, 3, 4, 5, 6, 7 },
        peakBonus = 0.10,
        trustGainMod = 0.5,                 -- 都是过路客
        weatherPenalty = 0.9,
        unlockMonth = 5,
        riskMod = 1.2,
        skillReq = { marketing = 1 },
        maxSlots = 5,                       -- 全天有人，窗口长
    },
}

-- ============================================================================
-- 促销活动系统
-- ============================================================================
GameConfig.Promotions = {
    {
        id = "discount10",  name = "九折优惠",    emoji = "🏷️",
        desc = "全场九折，薄利多销",
        cost = 200,                          -- 广告/材料费
        duration = 3,                        -- 持续3个回合
        priceMod = 0.9,                      -- 售价打9折
        salesMod = 1.25,                     -- 销量+25%
        trustGainBonus = 2,                  -- 信任额外+2
        unlockStallDays = 0,                 -- 立即可用
    },
    {
        id = "tasting",     name = "免费试吃",    emoji = "🥢",
        desc = "提供免费试吃，大幅提升信任度",
        cost = 1000,
        duration = 2,
        priceMod = 1.0,
        salesMod = 1.1,
        trustGainBonus = 10,                 -- 信任大增
        unlockStallDays = 3,                 -- 摆摊3天解锁
        fameGainBonus = 5,                   -- 促销期间每次叫卖额外+5名气
    },
    {
        id = "bogo",        name = "买一送一",    emoji = "🎁",
        desc = "买一送一，客流翻倍但利润减半",
        cost = 500,
        duration = 2,
        priceMod = 0.5,                      -- 相当于半价
        salesMod = 2.0,                      -- 销量翻倍
        trustGainBonus = 5,
        unlockStallDays = 5,                 -- 摆摊5天解锁
        fameGainBonus = 3,
    },
    {
        id = "combo",       name = "套餐优惠",    emoji = "🍱",
        desc = "搭配套餐组合，提高客单价",
        cost = 800,
        duration = 3,
        priceMod = 1.3,                      -- 客单价提升
        salesMod = 0.9,                      -- 销量微降
        trustGainBonus = 3,
        unlockStallDays = 8,                 -- 摆摊8天解锁
        unlockTrust = 15,                    -- 需要信任度15
        skillReq = { marketing = 1 },
    },
    {
        id = "lucky",       name = "幸运抽奖",    emoji = "🎰",
        desc = "消费满额抽奖，增加客户粘性",
        cost = 1500,
        duration = 4,
        priceMod = 1.0,
        salesMod = 1.35,
        trustGainBonus = 4,
        unlockStallDays = 12,                -- 摆摊12天解锁
        unlockTrust = 25,
        skillReq = { charm = 1, marketing = 2 },
        fameGainBonus = 8,
    },
    {
        id = "member",      name = "会员日特价",  emoji = "💳",
        desc = "老顾客专属折扣，高信任时效果更好",
        cost = 2000,
        duration = 3,
        priceMod = 0.85,
        salesMod = 1.15,
        trustGainBonus = 6,
        trustRequired = 40,                  -- 需要信任度40以上才有效
        unlockStallDays = 18,                -- 摆摊18天解锁
        unlockTrust = 40,
        skillReq = { management = 2 },
    },
}

-- ============================================================================
-- 地点专属促销活动（学校针对小孩的特殊活动）
-- ============================================================================
GameConfig.LocationPromotions = {
    school = {
        {
            id = "kids_combo",    name = "学生套餐",    emoji = "🎒",
            desc = "学生专属套餐价，小朋友抢着买",
            cost = 300,
            duration = 3,
            priceMod = 0.8,
            salesMod = 1.5,
            trustGainBonus = 4,
            unlockStallDays = 0,             -- 立即可用
            fameGainBonus = 3,
        },
        {
            id = "after_school",  name = "放学特惠",    emoji = "🔔",
            desc = "下午放学时段限时折扣，客流爆发",
            cost = 400,
            duration = 3,
            priceMod = 0.85,
            salesMod = 1.8,
            trustGainBonus = 5,
            unlockStallDays = 0,             -- 立即可用
        },
        {
            id = "sticker_gift",  name = "集卡送玩具",  emoji = "🃏",
            desc = "消费集贴纸，满5张送小玩具，小孩天天来",
            cost = 600,
            duration = 5,
            priceMod = 1.0,
            salesMod = 1.4,
            trustGainBonus = 8,
            unlockStallDays = 5,             -- 摆摊5天解锁
            fameGainBonus = 5,
        },
    },
}

-- ============================================================================
-- 名气/网红系统
-- ============================================================================
GameConfig.Fame = {
    -- 名气等级阈值
    LEVELS = {
        { threshold = 0,    name = "无人知晓",   emoji = "😶", bonus = 0 },
        { threshold = 100,  name = "街坊认识",   emoji = "👋", bonus = 0.05 },
        { threshold = 300,  name = "小有名气",   emoji = "📱", bonus = 0.10 },
        { threshold = 800,  name = "本地网红",   emoji = "🌟", bonus = 0.20 },
        { threshold = 2000, name = "城市红人",   emoji = "🔥", bonus = 0.35 },
        { threshold = 5000, name = "美食达人",   emoji = "👑", bonus = 0.50 },
    },
    MAX_FAME = 10000,
    -- 名气获取
    HAWK_FAME_GAIN = { 1, 3 },         -- 叫卖获得名气
    WAIT_FAME_GAIN = { 0, 1 },         -- 等待获得名气
    LIVESTREAM_FAME_MULT = 3.0,        -- 直播时名气获取倍率
    -- 名气衰减
    MONTHLY_DECAY = 15,                -- 每月名气自然衰减（降低，让人气更容易积累）
    -- 名气对客流的影响（名气越高，慕名而来的人越多）
    FAME_CUSTOMER_BASE = 0,            -- 名气0时额外客流
    FAME_CUSTOMER_MAX = 10,            -- 名气满时额外客流
    -- 直播增强（高名气时直播效果更好）
    LIVESTREAM_BASE_BONUS = 0.30,      -- 基础直播加成（已有）
    LIVESTREAM_FAME_EXTRA = 0.005,     -- 每点名气额外直播加成
    LIVESTREAM_FAME_CAP = 0.50,        -- 名气带来的直播加成上限
}

GameConfig.LiveStream = {
    BASE_VIEWERS = { 6, 15 },          -- 开播初始观众
    MAX_VIEWERS = 5000,
    FOLLOWERS_PER_VIEWER = 40,         -- 每40粉丝额外换来1名观众
    FAME_PER_VIEWER = 80,              -- 每80点名气额外换来1名观众
    TRUST_PER_VIEWER = 20,             -- 口碑越高，直播间越容易进人
    HAWK_VIEWER_BONUS = 6,             -- 叫卖时观众更爱围观
    COMMENT_VIEWERS_STEP = 25,         -- 每25名观众多刷一批弹幕
    MAX_COMMENTS_PER_TURN = 2,
    TIP_CHANCE_BASE = 0.18,
    TIP_CHANCE_PER_50_VIEWERS = 0.05,
    TIP_CHANCE_CAP = 0.60,
    TIP_RANGE = { 6, 36 },
    FOLLOWERS_GAIN_BASE = { 2, 8 },
    FOLLOWERS_GAIN_PER_20_VIEWERS = 1,
    ORDER_CHANCE_BASE = 0.20,
    ORDER_CHANCE_HAWK_BONUS = 0.10,
    ORDER_CHANCE_CAP = 0.65,
    ORDER_UNITS = { 1, 3 },
    VIEWER_NAMES = {
        "老铁阿豪", "深夜路人", "吃货小雨", "隔壁王姐", "下班老张",
        "学生阿乐", "美食探探", "今天不减肥", "夜市常客", "追更小李",
    },
    COMMENT_LINES = {
        "%s看起来是真香啊！",
        "这个%s多少钱，想下单！",
        "老板这%s还有吗？",
        "直播刷到你了，专门来看看%s。",
        "这摊气氛不错，给%s点个赞。",
        "弹幕打卡，今天能不能冲一波热度？",
    },
}

-- 网红/爆红事件（信任度或名气达到阈值时触发）
GameConfig.ViralEvents = {
    {
        id = "passerby_photo",
        name = "路人随手拍",
        trigger = { trustMin = 0 },          -- 无门槛，第一天就能触发
        prob = 0.05,
        fameGain = { 10, 40 },
        followersGain = { 20, 100 },
        desc = "有路人觉得你的摊位有趣，随手拍了一张发朋友圈",
        emoji = "📸",
    },
    {
        id = "douyin_filmed",
        name = "路人拍上抖音",
        trigger = { trustMin = 10 },         -- 降低：30→10
        prob = 0.12,                         -- 提高：0.08→0.12
        fameGain = { 50, 150 },
        followersGain = { 100, 500 },
        desc = "有人偷偷拍了你的摊位发到抖音，突然火了！",
        emoji = "📹",
    },
    {
        id = "food_blogger",
        name = "美食博主探店",
        trigger = { trustMin = 30, fameMin = 100 },  -- 降低：trust 50→30, fame 200→100
        prob = 0.06,
        fameGain = { 100, 300 },
        followersGain = { 300, 1000 },
        desc = "美食博主专门来拍视频推荐你的摊位！",
        emoji = "🎬",
    },
    {
        id = "local_news",
        name = "本地新闻报道",
        trigger = { fameMin = 300 },         -- 降低：500→300
        prob = 0.04,
        fameGain = { 200, 500 },
        followersGain = { 500, 2000 },
        desc = "本地电视台来采访你的创业故事！",
        emoji = "📺",
    },
    {
        id = "hot_search",
        name = "微博热搜",
        trigger = { fameMin = 1000 },        -- 降低：1500→1000
        prob = 0.02,
        fameGain = { 500, 1500 },
        followersGain = { 2000, 8000 },
        desc = "你的故事上了微博热搜，全网关注！",
        emoji = "🔥",
    },
    {
        id = "celebrity_visit",
        name = "明星打卡",
        trigger = { fameMin = 2000 },        -- 降低：3000→2000
        prob = 0.01,
        fameGain = { 800, 2000 },
        followersGain = { 5000, 20000 },
        desc = "某位明星来你摊位打卡，全网刷屏！",
        emoji = "⭐",
    },
}

-- ============================================================================
-- 破产检查系统
-- ============================================================================
GameConfig.Bankruptcy = {
    WARNING_THRESHOLD   = -10000,   -- 现金低于此值：黄色警告
    SEVERE_THRESHOLD    = -30000,   -- 现金低于此值：红色严重警告
    GAMEOVER_THRESHOLD  = -50000,   -- 现金低于此值：立即游戏结束
}

-- ============================================================================
-- 超市商品系统
-- ============================================================================
GameConfig.Supermarket = {
    MAX_PURCHASES_PER_DAY = 3,     -- 每天最多购买3件
    DAILY_DISPLAY_COUNT = 6,       -- 每天展示6种商品
    ITEMS = {
        { id = "instant_noodle", name = "方便面",    emoji = "🍜",  price = 50,   effects = { energy = 15, mood = 3,  health = -2 } },
        { id = "bread",          name = "面包",      emoji = "🍞",  price = 30,   effects = { energy = 10, mood = 2,  health = 0 } },
        { id = "boxed_meal",     name = "便当",      emoji = "🍱",  price = 120,  effects = { energy = 25, mood = 8,  health = 2 } },
        { id = "fruit",          name = "水果拼盘",  emoji = "🍎",  price = 80,   effects = { energy = 8,  mood = 5,  health = 5 } },
        { id = "water",          name = "矿泉水",    emoji = "💧",  price = 15,   effects = { energy = 5,  mood = 1,  health = 1 } },
        { id = "energy_drink",   name = "功能饮料",  emoji = "⚡",  price = 60,   effects = { energy = 20, mood = 3,  health = -1 } },
        { id = "bandaid",        name = "创可贴",    emoji = "🩹",  price = 40,   effects = { energy = 0,  mood = 0,  health = 8 } },
        { id = "cold_medicine",  name = "感冒药",    emoji = "💊",  price = 100,  effects = { energy = 0,  mood = -2, health = 15 } },
        { id = "vitamins",       name = "维生素",    emoji = "💎",  price = 150,  effects = { energy = 5,  mood = 3,  health = 10 } },
        { id = "sunscreen",      name = "防晒霜",    emoji = "🧴",  price = 70,   effects = { energy = 0,  mood = 5,  health = 3 } },
    },
}

-- 颜色主题
GameConfig.Colors = {
    BG_DARK     = { 20, 22, 35, 255 },
    BG_PANEL    = { 28, 32, 50, 245 },
    BG_TOPBAR   = { 15, 18, 30, 240 },
    TEXT_WHITE  = { 255, 255, 255, 255 },
    TEXT_GRAY   = { 180, 180, 200, 255 },
    TEXT_DIM    = { 120, 120, 150, 200 },
    CASH_GREEN  = { 100, 255, 130, 255 },
    DEBT_RED    = { 255, 100, 100, 255 },
    ENERGY_BLUE = { 80, 180, 255, 255 },
    MOOD_YELLOW = { 255, 220, 80, 255 },
    ACCENT      = { 100, 140, 255, 255 },
    ACCENT_DIM  = { 60, 80, 160, 255 },
    BORDER      = { 60, 65, 90, 255 },
    SUCCESS     = { 80, 200, 120, 255 },
    WARNING     = { 255, 180, 50, 255 },
    DANGER      = { 255, 80, 80, 255 },
    GOLD        = { 255, 200, 50, 255 },
}

return GameConfig
