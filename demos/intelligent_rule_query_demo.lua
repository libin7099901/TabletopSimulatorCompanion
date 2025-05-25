--[[
    桌游伴侣智能规则查询演示脚本
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    目的: 演示桌游伴侣的核心智能规则查询功能
    演示内容:
    - LLM服务配置和连接
    - 规则文档加载
    - 多种类型的智能查询
    - 上下文感知问答
    - 查询历史和缓存演示
--]]

-- 导入核心模块
local MainController = require("src.core.main_controller")
local LLMServiceManager = require("src.modules.llm_service_manager")
local RuleQueryManager = require("src.modules.rule_query_manager")

-- 演示脚本主类
local TabletopCompanionDemo = {
    name = "桌游伴侣智能规则查询演示",
    version = "1.0.0",
    
    -- 演示状态
    demo_state = {
        current_step = 1,
        max_steps = 8,
        completed_steps = {},
        demo_active = false
    },
    
    -- 演示数据
    demo_data = {
        -- 模拟游戏规则文档 (简化版国际象棋规则)
        chess_rules = {
            title = "国际象棋基础规则",
            content = [[
# 国际象棋基础规则

## 游戏目标
国际象棋的目标是将对方的王将死 (checkmate)。

## 棋子移动规则

### 王 (King)
- 可以向任意方向移动一格
- 不能移动到会被对方攻击的位置
- 特殊移动：王车易位 (需要王和车都未移动过)

### 后 (Queen)
- 可以沿直线、对角线任意距离移动
- 是最强大的棋子

### 车 (Rook)
- 可以水平或垂直任意距离移动
- 参与王车易位

### 象 (Bishop)
- 只能沿对角线移动
- 始终在同色格子上

### 马 (Knight)
- 走"L"形：两格直线 + 一格垂直，或两格垂直 + 一格直线
- 唯一可以跳过其他棋子的棋子

### 兵 (Pawn)
- 只能向前移动
- 首次移动可以走一格或两格
- 斜向攻击
- 特殊规则：en passant, 升变

## 特殊规则
- 将军 (Check): 王被攻击
- 将死 (Checkmate): 王被攻击且无法逃脱
- 和棋 (Stalemate): 轮到移动但无合法移动
- 王车易位: 王和车的特殊移动
- 兵的升变: 兵到达对方底线时升变为其他棋子
            ]]
        },
        
        -- 模拟游戏状态
        game_context = {
            game_info = {
                name = "国际象棋",
                current_turn = "白方",
                turn_number = 15,
                time_remaining = {white = 600, black = 450}
            },
            player_resources = {
                white_pieces = {"王", "后", "车x2", "象x2", "马x2", "兵x6"},
                black_pieces = {"王", "后", "车x1", "象x2", "马x1", "兵x4"}
            },
            game_objects = {
                {id = "white_king", position = {e = 1}, type = "王", color = "白"},
                {id = "black_king", position = {e = 8}, type = "王", color = "黑"},
                {id = "white_queen", position = {d = 1}, type = "后", color = "白"},
                {id = "selected_piece", position = {f = 4}, type = "马", color = "白"}
            }
        },
        
        -- 演示查询列表
        demo_queries = {
            {
                type = "basic",
                question = "马是如何移动的？",
                description = "基础规则查询"
            },
            {
                type = "contextual", 
                question = "现在轮到谁下棋？",
                description = "上下文感知查询"
            },
            {
                type = "object_specific",
                question = "这个马可以移动到哪些位置？",
                description = "特定对象查询"
            },
            {
                type = "game_state",
                question = "当前双方还有多少棋子？",
                description = "游戏状态查询" 
            },
            {
                type = "clarification",
                question = "什么是王车易位？",
                description = "规则澄清查询"
            }
        }
    }
}

-- 初始化演示系统
function TabletopCompanionDemo:initialize()
    print("=== 桌游伴侣智能规则查询演示 ===")
    print("版本: " .. self.version)
    print("演示步骤: " .. self.demo_state.max_steps .. " 步")
    print("")
    
    -- 模拟必要的全局对象
    self:setupMockEnvironment()
    
    -- 初始化主控制器
    print("步骤 1/8: 初始化桌游伴侣系统...")
    self.main_controller = MainController:new()
    
    -- 启动系统
    local success = self.main_controller:startup()
    if not success then
        print("❌ 系统启动失败")
        return false
    end
    
    print("✅ 桌游伴侣系统启动成功")
    self:markStepCompleted(1)
    return true
end

-- 设置模拟环境
function TabletopCompanionDemo:setupMockEnvironment()
    -- 模拟Logger (简化版)
    _G.Logger = {
        debug = function(self, msg, ctx) print("[DEBUG] " .. tostring(msg)) end,
        info = function(self, msg, ctx) print("[INFO] " .. tostring(msg)) end,
        warning = function(self, msg, ctx) print("[WARNING] " .. tostring(msg)) end,
        error = function(self, msg, ctx) print("[ERROR] " .. tostring(msg)) end
    }
    
    -- 模拟JSON
    _G.JSON = {
        encode = function(data)
            -- 简化的JSON编码
            if type(data) == "table" then
                local parts = {}
                for k, v in pairs(data) do
                    table.insert(parts, '"' .. tostring(k) .. '":"' .. tostring(v) .. '"')
                end
                return "{" .. table.concat(parts, ",") .. "}"
            else
                return '"' .. tostring(data) .. '"'
            end
        end,
        decode = function(json_str)
            -- 简化的JSON解码
            return {decoded = true, original = json_str}
        end
    }
    
    -- 模拟Wait对象
    _G.Wait = {
        time = function(callback, delay)
            print("⏰ 等待 " .. delay .. " 秒...")
            if callback then callback() end
        end
    }
    
    -- 模拟WebRequest (关键测试点)
    _G.WebRequest = {
        get = function(url, callback)
            print("🌐 发送GET请求到: " .. url)
            -- 模拟延迟
            Wait.time(function()
                callback({
                    is_error = false,
                    response_code = 200,
                    text = '{"status":"success","message":"模拟响应"}'
                })
            end, 0.5)
        end,
        post = function(url, data, callback)
            print("🌐 发送POST请求到: " .. url)
            print("📤 请求数据大小: " .. string.len(data) .. " 字节")
            
            -- 模拟不同的LLM API响应
            Wait.time(function()
                local mock_response = nil
                
                if string.find(url, "openai") then
                    mock_response = {
                        is_error = false,
                        response_code = 200,
                        text = '{"choices":[{"message":{"content":"这是OpenAI GPT的模拟回答。马在国际象棋中走L形移动：先走两格直线再走一格垂直，或先走两格垂直再走一格直线。马是唯一可以跳过其他棋子的棋子。"}}],"model":"gpt-3.5-turbo","usage":{"total_tokens":150}}'
                    }
                elseif string.find(url, "ollama") then
                    mock_response = {
                        is_error = false,
                        response_code = 200,
                        text = '{"response":"这是Ollama本地模型的回答。根据当前游戏状态，现在是白方的回合，轮到白方下棋。"}'
                    }
                else
                    mock_response = {
                        is_error = false,
                        response_code = 200,
                        text = '{"content":[{"text":"这是Claude的回答。根据规则文档，王车易位是一种特殊移动，需要王和车都未移动过。"}]}'
                    }
                end
                
                callback(mock_response)
            end, 1.5)
        end
    }
    
    print("🔧 模拟环境设置完成")
end

-- 配置LLM服务
function TabletopCompanionDemo:configureLLMServices()
    print("\n步骤 2/8: 配置LLM服务...")
    
    local llm_manager = self.main_controller:getModule("LLMServiceManager")
    if not llm_manager then
        print("❌ LLM服务管理器未找到")
        return false
    end
    
    -- 配置OpenAI服务 (演示用密钥)
    print("📝 配置OpenAI GPT服务...")
    llm_manager:configureProvider("openai", "demo_api_key_12345", {
        base_url = "https://api.openai.com/v1/chat/completions",
        enabled = true
    })
    
    -- 配置Ollama服务
    print("📝 配置Ollama本地服务...")
    llm_manager:configureProvider("ollama", nil, {
        base_url = "http://localhost:11434/api/generate",
        enabled = true
    })
    
    -- 配置Claude服务
    print("📝 配置Claude服务...")
    llm_manager:configureProvider("claude", "demo_claude_key", {
        enabled = true
    })
    
    -- 检查服务状态
    local status = llm_manager:getServiceStatus()
    print("✅ LLM服务配置完成")
    print("   - 已配置提供商: " .. (#status.providers > 0 and "是" or "否"))
    print("   - 活跃请求: " .. status.active_requests)
    
    self:markStepCompleted(2)
    return true
end

-- 加载规则文档
function TabletopCompanionDemo:loadRuleDocuments()
    print("\n步骤 3/8: 加载游戏规则文档...")
    
    local rule_manager = self.main_controller:getModule("RuleQueryManager")
    if not rule_manager then
        print("❌ 规则查询管理器未找到")
        return false
    end
    
    -- 加载象棋规则文档
    print("📚 加载国际象棋规则文档...")
    local success = rule_manager:loadRuleDocument(
        self.demo_data.chess_rules,
        "chess_basic_rules",
        {format = "markdown"}
    )
    
    if success then
        print("✅ 规则文档加载成功")
        print("   - 文档标题: " .. self.demo_data.chess_rules.title)
        print("   - 内容大小: " .. string.len(self.demo_data.chess_rules.content) .. " 字符")
        print("   - 文档数量: " .. rule_manager:getDocumentCount())
    else
        print("❌ 规则文档加载失败")
        return false
    end
    
    self:markStepCompleted(3)
    return true
end

-- 演示基础规则查询
function TabletopCompanionDemo:demonstrateBasicQuery()
    print("\n步骤 4/8: 演示基础规则查询...")
    
    local rule_manager = self.main_controller:getModule("RuleQueryManager")
    local query = self.demo_data.demo_queries[1]
    
    print("❓ 玩家问题: " .. query.question)
    print("🔍 查询类型: " .. query.description)
    print("⏳ 正在查询...")
    
    rule_manager:basicQuery(query.question, function(response, error)
        if error then
            print("❌ 查询失败: " .. error)
        else
            print("✅ 查询成功!")
            print("🤖 AI回答: " .. (response.content or "无回答"))
            print("📊 使用模型: " .. (response.model or "未知"))
        end
        
        self:markStepCompleted(4)
        self:continueDemo(5)
    end)
end

-- 演示上下文感知查询
function TabletopCompanionDemo:demonstrateContextualQuery()
    print("\n步骤 5/8: 演示上下文感知查询...")
    
    local rule_manager = self.main_controller:getModule("RuleQueryManager")
    local query = self.demo_data.demo_queries[2]
    
    print("❓ 玩家问题: " .. query.question)
    print("🎮 当前游戏状态:")
    print("   - 游戏: " .. self.demo_data.game_context.game_info.name)
    print("   - 当前回合: " .. self.demo_data.game_context.game_info.current_turn)
    print("   - 回合数: " .. self.demo_data.game_context.game_info.turn_number)
    print("⏳ 正在进行上下文查询...")
    
    rule_manager:contextualQuery(
        query.question,
        self.demo_data.game_context,
        function(response, error)
            if error then
                print("❌ 上下文查询失败: " .. error)
            else
                print("✅ 上下文查询成功!")
                print("🤖 AI回答: " .. (response.content or "无回答"))
                print("🧠 上下文理解: 已结合当前游戏状态")
            end
            
            self:markStepCompleted(5)
            self:continueDemo(6)
        end
    )
end

-- 演示对象特定查询
function TabletopCompanionDemo:demonstrateObjectQuery()
    print("\n步骤 6/8: 演示对象特定查询...")
    
    local rule_manager = self.main_controller:getModule("RuleQueryManager")
    local query = self.demo_data.demo_queries[3]
    
    -- 模拟选中的游戏对象
    local selected_object = {
        name = "白方马",
        type = "马",
        position = {file = "f", rank = 4},
        color = "白",
        properties = {
            moved = true,
            can_jump = true
        },
        description = "位于f4位置的白方马"
    }
    
    print("❓ 玩家问题: " .. query.question)
    print("🎯 选中对象:")
    print("   - 名称: " .. selected_object.name)
    print("   - 位置: " .. selected_object.position.file .. selected_object.position.rank)
    print("   - 类型: " .. selected_object.type)
    print("⏳ 正在进行对象查询...")
    
    rule_manager:objectQuery(
        query.question,
        selected_object,
        function(response, error)
            if error then
                print("❌ 对象查询失败: " .. error)
            else
                print("✅ 对象查询成功!")
                print("🤖 AI回答: " .. (response.content or "无回答"))
                print("🎯 对象分析: 已针对特定棋子进行分析")
            end
            
            self:markStepCompleted(6)
            self:continueDemo(7)
        end
    )
end

-- 演示查询历史和缓存
function TabletopCompanionDemo:demonstrateHistoryAndCache()
    print("\n步骤 7/8: 演示查询历史和缓存功能...")
    
    local rule_manager = self.main_controller:getModule("RuleQueryManager")
    
    -- 获取查询统计
    local stats = rule_manager:getQueryStats()
    print("📈 查询统计:")
    print("   - 总查询数: " .. stats.total_queries)
    print("   - 成功查询: " .. stats.successful_queries)
    print("   - 缓存命中: " .. stats.cached_queries)
    print("   - 成功率: " .. stats.success_rate .. "%")
    print("   - 缓存命中率: " .. stats.cache_hit_rate .. "%")
    
    -- 获取查询历史
    local history = rule_manager:getQueryHistory(3)
    print("\n📚 最近查询历史:")
    for i, hist in ipairs(history) do
        print("   " .. i .. ". " .. hist.question)
        print("      回答: " .. string.sub(hist.answer or "无", 1, 50) .. "...")
    end
    
    -- 测试缓存命中
    print("\n🔄 测试缓存机制 - 重复第一个查询...")
    local first_query = self.demo_data.demo_queries[1]
    rule_manager:basicQuery(first_query.question, function(response, error)
        if error then
            print("❌ 缓存测试失败: " .. error)
        else
            print("✅ 缓存测试成功!")
            print("⚡ 快速响应 (来自缓存)")
        end
        
        self:markStepCompleted(7)
        self:continueDemo(8)
    end)
end

-- 演示完成总结
function TabletopCompanionDemo:demonstrateCompletion()
    print("\n步骤 8/8: 演示完成总结...")
    
    -- 获取系统整体状态
    local llm_manager = self.main_controller:getModule("LLMServiceManager")
    local rule_manager = self.main_controller:getModule("RuleQueryManager")
    local cache_manager = self.main_controller:getModule("CacheManager")
    
    print("🎉 桌游伴侣智能规则查询演示完成!")
    print("\n📊 系统状态总结:")
    
    -- LLM服务状态
    if llm_manager then
        local llm_status = llm_manager:getServiceStatus()
        print("🤖 LLM服务:")
        print("   - 配置的服务商: " .. llm_manager:getProviderCount())
        print("   - 总请求数: " .. llm_status.total_requests_today)
    end
    
    -- 规则查询状态
    if rule_manager then
        local query_stats = rule_manager:getQueryStats()
        print("📖 规则查询:")
        print("   - 加载的文档: " .. rule_manager:getDocumentCount())
        print("   - 查询成功率: " .. query_stats.success_rate .. "%")
        print("   - 平均响应时间: " .. string.format("%.2f", query_stats.average_response_time) .. "秒")
    end
    
    -- 缓存状态
    if cache_manager then
        local cache_stats = cache_manager:getStats()
        print("💾 缓存系统:")
        print("   - 缓存条目数: " .. cache_stats.total_size)
        print("   - 命中率: " .. math.floor(cache_stats.hit_rate * 100) .. "%")
    end
    
    print("\n🌟 演示亮点:")
    print("   ✅ 多LLM服务无缝切换")
    print("   ✅ 上下文感知智能问答")
    print("   ✅ 游戏对象特定查询")
    print("   ✅ 查询历史智能管理")
    print("   ✅ 高效缓存机制")
    print("   ✅ 完整错误处理")
    
    print("\n🚀 下一步发展方向:")
    print("   📱 图形化UI界面")
    print("   🌍 多语言文档支持")
    print("   🎯 TTS深度集成")
    print("   📸 OCR图像识别")
    print("   🔊 语音交互支持")
    
    self:markStepCompleted(8)
    self.demo_state.demo_active = false
    
    print("\n" .. string.rep("=", 50))
    print("感谢体验桌游伴侣智能规则查询演示!")
    print("项目开源地址: https://github.com/your-repo/tabletop-companion")
    print(string.rep("=", 50))
end

-- 标记步骤完成
function TabletopCompanionDemo:markStepCompleted(step)
    self.demo_state.completed_steps[step] = true
    print("✓ 步骤 " .. step .. "/" .. self.demo_state.max_steps .. " 完成")
end

-- 继续演示
function TabletopCompanionDemo:continueDemo(next_step)
    if next_step == 5 then
        self:demonstrateContextualQuery()
    elseif next_step == 6 then
        self:demonstrateObjectQuery()
    elseif next_step == 7 then
        self:demonstrateHistoryAndCache()
    elseif next_step == 8 then
        self:demonstrateCompletion()
    end
end

-- 运行完整演示
function TabletopCompanionDemo:runDemo()
    print("🚀 启动桌游伴侣智能规则查询演示...")
    self.demo_state.demo_active = true
    
    -- 步骤1-3: 系统初始化
    if not self:initialize() then
        return false
    end
    
    if not self:configureLLMServices() then
        return false
    end
    
    if not self:loadRuleDocuments() then
        return false
    end
    
    -- 步骤4: 开始异步演示流程
    self:demonstrateBasicQuery()
    
    return true
end

-- 主入口函数
function startTabletopCompanionDemo()
    local demo = TabletopCompanionDemo
    return demo:runDemo()
end

-- 导出演示脚本
return TabletopCompanionDemo 