--[[
    主控制器单元测试
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    测试内容:
    - 主控制器初始化
    - 模块注册和管理
    - 配置管理
    - 事件系统
--]]

-- 测试框架 (简单实现)
local TestFramework = {
    tests = {},
    passed = 0,
    failed = 0,
    total = 0
}

function TestFramework:addTest(name, test_func)
    table.insert(self.tests, {name = name, func = test_func})
end

function TestFramework:assert(condition, message)
    if condition then
        print("✅ " .. (message or "断言通过"))
        return true
    else
        print("❌ " .. (message or "断言失败"))
        error(message or "断言失败")
    end
end

function TestFramework:assertEqual(expected, actual, message)
    if expected == actual then
        print("✅ " .. (message or "值相等断言通过"))
        return true
    else
        local error_msg = string.format("%s - 期望: %s, 实际: %s", 
                                       message or "值相等断言失败", 
                                       tostring(expected), 
                                       tostring(actual))
        print("❌ " .. error_msg)
        error(error_msg)
    end
end

function TestFramework:runTests()
    print("=" .. string.rep("=", 50) .. "=")
    print("开始运行主控制器单元测试")
    print("=" .. string.rep("=", 50) .. "=")
    
    for _, test in ipairs(self.tests) do
        self.total = self.total + 1
        print("\n🧪 运行测试: " .. test.name)
        
        local success, error_msg = pcall(test.func)
        
        if success then
            self.passed = self.passed + 1
            print("✅ 测试通过: " .. test.name)
        else
            self.failed = self.failed + 1
            print("❌ 测试失败: " .. test.name)
            print("   错误信息: " .. tostring(error_msg))
        end
    end
    
    print("\n" .. string.rep("=", 50))
    print(string.format("测试结果: %d/%d 通过, %d 失败", 
                       self.passed, self.total, self.failed))
    print(string.rep("=", 50))
    
    return self.failed == 0
end

-- 模拟TTS环境
local function setupMockTTSEnvironment()
    -- 模拟全局函数
    _G.print = _G.print or function(msg) print(msg) end
    _G.Wait = _G.Wait or {
        time = function(func, delay) 
            -- 简单模拟，立即执行
            func()
        end
    }
    
    _G.UI = _G.UI or {
        setXml = function(xml) 
            print("设置UI XML: " .. (xml and "有内容" or "空"))
        end
    }
    
    _G.JSON = _G.JSON or {
        encode = function(data)
            -- 简单的JSON编码模拟
            return "{}"
        end,
        decode = function(str)
            -- 简单的JSON解码模拟
            return {}
        end
    }
    
    _G.broadcastToAll = _G.broadcastToAll or function(message, color)
        print("广播消息: " .. message)
    end
    
    _G.os = _G.os or {
        time = function() return 1640995200 end, -- 固定时间戳
        clock = function() return 0.001 end,
        date = function(format) return "[12:00:00]" end
    }
end

-- 加载要测试的模块
local function loadTestModules()
    -- 在测试环境中，我们需要手动加载模块
    -- 这里假设模块文件存在于相对路径中
    
    -- 加载Logger
    if not Logger then
        Logger = require("src/core/logger")
    end
    
    -- 加载ErrorHandler
    if not ErrorHandler then
        ErrorHandler = require("src/core/error_handler")
    end
    
    -- 加载ModuleBase
    if not ModuleBase then
        ModuleBase = require("src/core/module_base")
    end
    
    -- 加载MainController
    if not MainController then
        MainController = require("src/core/main_controller")
    end
end

-- 测试用例

-- 测试1: 主控制器基本初始化
TestFramework:addTest("主控制器基本初始化", function()
    -- 重置主控制器状态
    MainController.system_state = "UNINITIALIZED"
    MainController.initialized = false
    MainController.modules = {}
    MainController.module_init_order = {}
    
    -- 执行初始化
    local result = MainController:initialize()
    
    -- 验证结果
    TestFramework:assert(result, "初始化应该返回true")
    TestFramework:assertEqual("READY", MainController.system_state, "系统状态应该为READY")
    TestFramework:assert(MainController.initialized, "初始化标记应该为true")
    TestFramework:assert(MainController.stats.init_time > 0, "初始化时间应该大于0")
end)

-- 测试2: 模块注册功能
TestFramework:addTest("模块注册功能", function()
    -- 创建测试模块
    local testModule = {
        name = "TestModule",
        initialize = function(self, save_data) 
            self.initialized = true
            return true
        end,
        getStatus = function(self)
            return "READY"
        end,
        initialized = false
    }
    
    -- 注册模块
    MainController:registerModule("TestModule", testModule)
    
    -- 验证注册
    TestFramework:assert(MainController.modules["TestModule"] ~= nil, "模块应该已注册")
    TestFramework:assertEqual(1, #MainController.module_init_order, "模块初始化顺序应该包含1个模块")
    
    -- 验证获取模块
    local retrieved = MainController:getModule("TestModule")
    TestFramework:assertEqual(testModule, retrieved, "获取的模块应该与原模块相同")
end)

-- 测试3: 配置管理
TestFramework:addTest("配置管理", function()
    -- 测试默认配置
    TestFramework:assert(MainController.config.system ~= nil, "系统配置应该存在")
    TestFramework:assert(MainController.config.ui ~= nil, "UI配置应该存在")
    TestFramework:assert(MainController.config.debug ~= nil, "调试配置应该存在")
    
    -- 测试配置合并
    local test_config = {
        system = {
            log_level = "DEBUG",
            test_setting = "test_value"
        }
    }
    
    MainController:mergeConfig(MainController.config, test_config)
    
    TestFramework:assertEqual("DEBUG", MainController.config.system.log_level, "日志级别应该已更新")
    TestFramework:assertEqual("test_value", MainController.config.system.test_setting, "新设置应该已添加")
end)

-- 测试4: 事件系统
TestFramework:addTest("事件系统", function()
    local event_received = false
    local event_data_received = nil
    
    -- 注册事件监听器
    MainController:addEventListener("test_event", function(event_data)
        event_received = true
        event_data_received = event_data
    end)
    
    -- 发送事件
    local test_data = {message = "test"}
    MainController:emitEvent("test_event", test_data)
    
    -- 验证事件处理
    TestFramework:assert(event_received, "事件应该已被接收")
    TestFramework:assertEqual(test_data, event_data_received, "事件数据应该正确传递")
end)

-- 测试5: 保存数据功能
TestFramework:addTest("保存数据功能", function()
    -- 添加一些测试数据
    MainController.save_data.user_data.test_key = "test_value"
    
    -- 获取保存数据
    local save_data = MainController:getSaveData()
    
    -- 验证保存数据
    TestFramework:assert(save_data ~= nil, "保存数据不应该为空")
    TestFramework:assert(save_data.timestamp > 0, "时间戳应该大于0")
    TestFramework:assertEqual("test_value", save_data.user_data.test_key, "用户数据应该正确保存")
end)

-- 测试6: 错误处理
TestFramework:addTest("错误处理", function()
    -- 创建一个会出错的模块
    local errorModule = {
        name = "ErrorModule",
        initialize = function(self, save_data)
            error("测试错误")
        end
    }
    
    -- 注册并尝试初始化模块
    MainController:registerModule("ErrorModule", errorModule)
    
    -- 由于模块初始化在registerModule中不会立即执行（系统已READY），
    -- 我们手动测试初始化
    local result = MainController:initializeModule("ErrorModule")
    
    -- 验证错误处理
    TestFramework:assert(not result, "出错的模块初始化应该返回false")
end)

-- 主测试函数
function runMainControllerTests()
    print("设置测试环境...")
    setupMockTTSEnvironment()
    
    print("加载测试模块...")
    loadTestModules()
    
    print("运行测试...")
    local success = TestFramework:runTests()
    
    if success then
        print("\n🎉 所有测试通过！")
    else
        print("\n💥 有测试失败，请检查代码！")
    end
    
    return success
end

-- 如果直接运行此文件，执行测试
if ... == nil then
    runMainControllerTests()
end

-- 导出测试函数
return {
    runMainControllerTests = runMainControllerTests,
    TestFramework = TestFramework
} 