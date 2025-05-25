--[[
    系统启动集成测试
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    测试内容:
    - 完整系统启动流程
    - 模块依赖关系
    - UI初始化
    - 事件系统集成
--]]

local IntegrationTest = {
    tests = {},
    passed = 0,
    failed = 0,
    total = 0,
    test_environment = {}
}

function IntegrationTest:addTest(name, test_func)
    table.insert(self.tests, {name = name, func = test_func})
end

function IntegrationTest:assert(condition, message)
    if condition then
        print("✅ " .. (message or "集成测试断言通过"))
        return true
    else
        print("❌ " .. (message or "集成测试断言失败"))
        error(message or "集成测试断言失败")
    end
end

function IntegrationTest:runTests()
    print("=" .. string.rep("=", 60) .. "=")
    print("开始运行系统启动集成测试")
    print("=" .. string.rep("=", 60) .. "=")
    
    for _, test in ipairs(self.tests) do
        self.total = self.total + 1
        print("\n🔧 运行集成测试: " .. test.name)
        
        local success, error_msg = pcall(test.func, self)
        
        if success then
            self.passed = self.passed + 1
            print("✅ 集成测试通过: " .. test.name)
        else
            self.failed = self.failed + 1
            print("❌ 集成测试失败: " .. test.name)
            print("   错误信息: " .. tostring(error_msg))
        end
    end
    
    print("\n" .. string.rep("=", 60))
    print(string.format("集成测试结果: %d/%d 通过, %d 失败", 
                       self.passed, self.total, self.failed))
    print(string.rep("=", 60))
    
    return self.failed == 0
end

-- 设置完整的TTS模拟环境
function IntegrationTest:setupFullTTSEnvironment()
    print("设置完整TTS模拟环境...")
    
    -- 全局变量和函数
    _G.print = _G.print or function(msg) print(msg) end
    
    _G.Wait = _G.Wait or {
        time = function(func, delay) 
            print("模拟等待 " .. delay .. " 秒，立即执行")
            func()
        end
    }
    
    _G.UI = _G.UI or {
        setXml = function(xml) 
            self.test_environment.ui_xml = xml
            print("UI XML已设置: " .. (xml and string.len(xml) or 0) .. " 字符")
        end
    }
    
    _G.JSON = _G.JSON or {
        encode = function(data)
            -- 简单的JSON编码
            if type(data) == "table" then
                return '{"test":"data"}'
            else
                return tostring(data)
            end
        end,
        decode = function(str)
            -- 简单的JSON解码
            return {test = "data"}
        end
    }
    
    _G.broadcastToAll = _G.broadcastToAll or function(message, color)
        table.insert(self.test_environment.broadcasts, {
            message = message,
            color = color,
            timestamp = os.time()
        })
        print("广播: " .. message)
    end
    
    _G.os = _G.os or {
        time = function() return os.time() end,
        clock = function() return os.clock() end,
        date = function(format) return os.date(format) end
    }
    
    -- 初始化测试环境状态
    self.test_environment.broadcasts = {}
    self.test_environment.ui_xml = nil
    self.test_environment.modules_loaded = {}
    
    print("TTS模拟环境设置完成")
end

-- 加载所有系统模块
function IntegrationTest:loadAllModules()
    print("加载系统模块...")
    
    -- 按依赖顺序加载模块
    local modules = {
        "Logger",
        "ErrorHandler", 
        "ModuleBase",
        "MainController",
        "UIManager"
    }
    
    for _, module_name in ipairs(modules) do
        if module_name == "Logger" and not Logger then
            Logger = require("src/core/logger")
            self.test_environment.modules_loaded.Logger = true
        elseif module_name == "ErrorHandler" and not ErrorHandler then
            ErrorHandler = require("src/core/error_handler")
            self.test_environment.modules_loaded.ErrorHandler = true
        elseif module_name == "ModuleBase" and not ModuleBase then
            ModuleBase = require("src/core/module_base")
            self.test_environment.modules_loaded.ModuleBase = true
        elseif module_name == "MainController" and not MainController then
            MainController = require("src/core/main_controller")
            self.test_environment.modules_loaded.MainController = true
        elseif module_name == "UIManager" and not UIManager then
            UIManager = require("src/ui/ui_manager")
            self.test_environment.modules_loaded.UIManager = true
        end
        
        print("✅ 模块加载成功: " .. module_name)
    end
    
    print("所有模块加载完成")
end

-- 测试1: 系统完整启动流程
IntegrationTest:addTest("系统完整启动流程", function(self)
    -- 重置所有系统状态
    if MainController then
        MainController.system_state = "UNINITIALIZED"
        MainController.initialized = false
        MainController.modules = {}
        MainController.module_init_order = {}
    end
    
    -- 注册UIManager模块
    if MainController and UIManager then
        MainController:registerModule("UIManager", UIManager)
    end
    
    -- 执行系统初始化
    local init_result = MainController:initialize()
    
    -- 验证系统状态
    self:assert(init_result, "系统初始化应该成功")
    self:assert(MainController.system_state == "READY", "系统状态应该为READY")
    self:assert(MainController.initialized, "系统应该标记为已初始化")
    self:assert(MainController.stats.init_time > 0, "初始化时间应该大于0")
    
    -- 验证模块加载
    self:assert(#MainController.module_init_order > 0, "应该有模块被注册")
    self:assert(MainController:getModule("UIManager") ~= nil, "UIManager应该已注册")
    
    print("✅ 系统启动流程验证完成")
end)

-- 测试2: UI系统集成
IntegrationTest:addTest("UI系统集成", function(self)
    -- 验证UI系统是否已初始化
    local ui_manager = MainController:getModule("UIManager")
    self:assert(ui_manager ~= nil, "UIManager应该已加载")
    
    -- 验证UI XML是否已设置
    self:assert(self.test_environment.ui_xml ~= nil, "UI XML应该已设置")
    self:assert(string.len(self.test_environment.ui_xml) > 0, "UI XML应该有内容")
    
    -- 测试UI事件处理
    local old_broadcast_count = #self.test_environment.broadcasts
    
    -- 模拟UI按钮点击
    if UIManager.showMenu then
        UIManager.showMenu()
    end
    
    if UIManager.showStatus then
        UIManager.showStatus()
    end
    
    if UIManager.showHelp then
        UIManager.showHelp()
    end
    
    -- 验证事件处理
    local new_broadcast_count = #self.test_environment.broadcasts
    self:assert(new_broadcast_count > old_broadcast_count, "UI事件应该产生广播消息")
    
    print("✅ UI系统集成验证完成")
end)

-- 测试3: 错误处理集成
IntegrationTest:addTest("错误处理集成", function(self)
    -- 验证ErrorHandler已初始化
    self:assert(ErrorHandler ~= nil, "ErrorHandler应该可用")
    
    -- 测试错误处理
    local error_count_before = ErrorHandler.stats.total_errors
    
    -- 触发一个测试错误
    ErrorHandler:handle(ErrorHandler.error_codes.SYSTEM_INIT_ERROR, "集成测试错误", {test = true})
    
    -- 验证错误统计
    self:assert(ErrorHandler.stats.total_errors > error_count_before, "错误统计应该增加")
    
    -- 验证错误历史
    local history = ErrorHandler:getErrorHistory(1)
    self:assert(#history > 0, "错误历史应该包含记录")
    self:assert(history[#history].message == "集成测试错误", "最新错误消息应该正确")
    
    print("✅ 错误处理集成验证完成")
end)

-- 测试4: 配置持久化集成
IntegrationTest:addTest("配置持久化集成", function(self)
    -- 测试配置保存
    MainController.config.test_setting = "test_value"
    MainController.save_data.user_data.test_key = "user_test_value"
    
    -- 获取保存数据
    local save_data = MainController:getSaveData()
    
    -- 验证保存数据完整性
    self:assert(save_data ~= nil, "保存数据不应该为空")
    self:assert(save_data.timestamp > 0, "保存时间戳应该有效")
    self:assert(save_data.system_config ~= nil, "系统配置应该已保存")
    self:assert(save_data.user_data.test_key == "user_test_value", "用户数据应该正确保存")
    
    -- 测试JSON序列化
    local json_str = JSON.encode(save_data)
    self:assert(json_str ~= nil, "保存数据应该能序列化为JSON")
    self:assert(string.len(json_str) > 0, "JSON字符串应该有内容")
    
    print("✅ 配置持久化集成验证完成")
end)

-- 测试5: 聊天命令集成
IntegrationTest:addTest("聊天命令集成", function(self)
    -- 模拟玩家对象
    local mock_player = {
        steam_name = "TestPlayer",
        print = function(self, message)
            table.insert(self.messages, message)
        end,
        messages = {}
    }
    
    -- 测试帮助命令
    MainController:handleChatCommand("/tc help", mock_player)
    self:assert(#mock_player.messages > 0, "帮助命令应该产生响应")
    
    -- 重置消息
    mock_player.messages = {}
    
    -- 测试状态命令
    MainController:handleChatCommand("/tc status", mock_player)
    self:assert(#mock_player.messages > 0, "状态命令应该产生响应")
    
    print("✅ 聊天命令集成验证完成")
end)

-- 测试6: 系统关闭流程
IntegrationTest:addTest("系统关闭流程", function(self)
    -- 记录关闭前状态
    local modules_count = #MainController.module_init_order
    
    -- 执行系统关闭
    MainController:shutdown()
    
    -- 验证关闭状态
    self:assert(MainController.system_state == "SHUTDOWN", "系统状态应该为SHUTDOWN")
    
    -- 验证UI清理
    self:assert(self.test_environment.ui_xml == "", "UI应该已清理")
    
    print("✅ 系统关闭流程验证完成")
end)

-- 主集成测试函数
function runSystemStartupIntegrationTests()
    local test = IntegrationTest
    
    -- 设置环境
    test:setupFullTTSEnvironment()
    
    -- 加载模块
    test:loadAllModules()
    
    -- 运行测试
    local success = test:runTests()
    
    if success then
        print("\n🎉 所有集成测试通过！系统启动流程正常！")
    else
        print("\n💥 集成测试失败，系统存在问题！")
    end
    
    return success
end

-- 导出
return {
    runSystemStartupIntegrationTests = runSystemStartupIntegrationTests,
    IntegrationTest = IntegrationTest
} 