--[[
    StorageManager单元测试
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    测试覆盖:
    - 数据存储和加载
    - 数据压缩和解压
    - 存储统计
    - 错误处理
--]]

-- 引入测试框架 (模拟)
local TestFramework = require("tests.framework.test_framework")

-- 模拟依赖
local MockLogger = require("tests.mocks.mock_logger")
local MockModuleBase = require("tests.mocks.mock_module_base")

-- 引入待测试模块
local StorageManager = require("src.modules.storage_manager")

-- 测试套件
local StorageManagerTests = TestFramework:createSuite("StorageManager Tests")

-- 测试设置
function StorageManagerTests:setUp()
    -- 创建StorageManager实例
    self.storage_manager = StorageManager:new()
    
    -- 模拟配置
    self.storage_manager.config = {
        auto_save_interval = 300,
        compression_enabled = true,
        max_storage_size = 98304,
        backup_enabled = true,
        storage_encryption = false
    }
    
    -- 模拟Logger
    Logger = MockLogger
    
    -- 模拟JSON
    JSON = {
        encode = function(data)
            -- 简单的JSON编码模拟
            if type(data) == "table" then
                local result = "{"
                local first = true
                for k, v in pairs(data) do
                    if not first then result = result .. "," end
                    result = result .. '"' .. tostring(k) .. '":' .. 
                             (type(v) == "string" and '"' .. v .. '"' or tostring(v))
                    first = false
                end
                return result .. "}"
            else
                return tostring(data)
            end
        end,
        decode = function(json_str)
            -- 简单的JSON解码模拟
            if type(json_str) == "string" and string.sub(json_str, 1, 1) == "{" then
                return {decoded = true, original = json_str}
            else
                return json_str
            end
        end
    }
    
    -- 模拟os.time
    os.time = function() return 1234567890 end
    
    -- 模拟os.clock
    os.clock = function() return 123.456 end
    
    -- 初始化存储管理器
    self.storage_manager:onInitialize({})
end

-- 测试清理
function StorageManagerTests:tearDown()
    self.storage_manager = nil
    Logger = nil
    JSON = nil
end

-- 测试基础数据存储和加载
function StorageManagerTests:testBasicDataSaveAndLoad()
    local storage = self.storage_manager
    
    -- 测试数据
    local test_data = {
        name = "test_item",
        value = 123,
        enabled = true
    }
    
    -- 保存数据
    local save_result = storage:saveData("user", "test_key", test_data)
    self:assertTrue(save_result, "数据保存应该成功")
    
    -- 加载数据
    local loaded_data = storage:loadData("user", "test_key")
    self:assertNotNil(loaded_data, "加载的数据不应为空")
    self:assertEqual(loaded_data.name, test_data.name, "数据名称应该匹配")
    self:assertEqual(loaded_data.value, test_data.value, "数据值应该匹配")
    self:assertEqual(loaded_data.enabled, test_data.enabled, "数据状态应该匹配")
end

-- 测试数据不存在的情况
function StorageManagerTests:testLoadNonExistentData()
    local storage = self.storage_manager
    
    -- 尝试加载不存在的数据
    local default_value = "default"
    local loaded_data = storage:loadData("user", "nonexistent_key", default_value)
    
    self:assertEqual(loaded_data, default_value, "应该返回默认值")
end

-- 测试数据删除
function StorageManagerTests:testDataDeletion()
    local storage = self.storage_manager
    
    -- 先保存数据
    local test_data = {test = "value"}
    storage:saveData("user", "delete_test", test_data)
    
    -- 确认数据存在
    local loaded_data = storage:loadData("user", "delete_test")
    self:assertNotNil(loaded_data, "数据应该存在")
    
    -- 删除数据
    local delete_result = storage:deleteData("user", "delete_test")
    self:assertTrue(delete_result, "删除应该成功")
    
    -- 确认数据已删除
    local loaded_after_delete = storage:loadData("user", "delete_test", "not_found")
    self:assertEqual(loaded_after_delete, "not_found", "数据应该已被删除")
end

-- 测试数据压缩
function StorageManagerTests:testDataCompression()
    local storage = self.storage_manager
    
    -- 创建大数据用于测试压缩
    local large_data = ""
    for i = 1, 200 do
        large_data = large_data .. "This is a repeated string for compression testing. "
    end
    
    local test_data = {
        content = large_data,
        size = "large"
    }
    
    -- 保存大数据（应该触发压缩）
    local save_result = storage:saveData("cache", "large_data", test_data)
    self:assertTrue(save_result, "大数据保存应该成功")
    
    -- 加载并验证数据完整性
    local loaded_data = storage:loadData("cache", "large_data")
    self:assertNotNil(loaded_data, "加载的数据不应为空")
    self:assertEqual(loaded_data.content, test_data.content, "压缩后的数据内容应该匹配")
    self:assertEqual(loaded_data.size, test_data.size, "压缩后的数据属性应该匹配")
end

-- 测试存储统计
function StorageManagerTests:testStorageStats()
    local storage = self.storage_manager
    
    -- 保存一些测试数据
    storage:saveData("system", "config1", {setting = "value1"})
    storage:saveData("user", "pref1", {theme = "dark"})
    storage:saveData("cache", "cache1", {data = "cached_value"})
    
    -- 获取存储统计
    local stats = storage:getStorageStats()
    
    self:assertNotNil(stats, "统计信息不应为空")
    self:assertTrue(stats.data_count > 0, "数据计数应大于0")
    self:assertTrue(stats.total_size > 0, "总大小应大于0")
    self:assertNotNil(stats.usage_percentage, "使用百分比应存在")
end

-- 测试TTL (生存时间)
function StorageManagerTests:testTTLExpiration()
    local storage = self.storage_manager
    
    -- 模拟时间变化
    local current_time = 1000
    os.time = function() return current_time end
    
    -- 保存带TTL的数据
    local test_data = {temp = "data"}
    local options = {ttl = 60} -- 60秒TTL
    
    storage:saveData("cache", "ttl_test", test_data, options)
    
    -- 立即加载应该成功
    local loaded_data = storage:loadData("cache", "ttl_test")
    self:assertNotNil(loaded_data, "在TTL内数据应该存在")
    
    -- 模拟时间过期
    current_time = current_time + 120 -- 超过TTL
    
    -- 加载过期数据应该返回默认值
    local expired_data = storage:loadData("cache", "ttl_test", "expired")
    self:assertEqual(expired_data, "expired", "过期数据应该被删除")
end

-- 测试分类存储
function StorageManagerTests:testCategoryStorage()
    local storage = self.storage_manager
    
    -- 在不同分类中保存数据
    storage:saveData("system", "sys_key", {type = "system"})
    storage:saveData("user", "user_key", {type = "user"})
    storage:saveData("cache", "cache_key", {type = "cache"})
    storage:saveData("modules", "mod_key", {type = "module"})
    
    -- 验证数据在正确的分类中
    local sys_data = storage:loadData("system", "sys_key")
    local user_data = storage:loadData("user", "user_key")
    local cache_data = storage:loadData("cache", "cache_key")
    local mod_data = storage:loadData("modules", "mod_key")
    
    self:assertEqual(sys_data.type, "system", "系统数据应在系统分类中")
    self:assertEqual(user_data.type, "user", "用户数据应在用户分类中")
    self:assertEqual(cache_data.type, "cache", "缓存数据应在缓存分类中")
    self:assertEqual(mod_data.type, "module", "模块数据应在模块分类中")
end

-- 测试错误处理
function StorageManagerTests:testErrorHandling()
    local storage = self.storage_manager
    
    -- 测试无效参数
    local result1 = storage:saveData(nil, "key", "data")
    self:assertFalse(result1, "空分类应该导致保存失败")
    
    local result2 = storage:saveData("user", nil, "data")
    self:assertFalse(result2, "空键应该导致保存失败")
    
    local result3 = storage:loadData(nil, "key")
    self:assertNil(result3, "空分类应该返回nil")
    
    local result4 = storage:loadData("user", nil)
    self:assertNil(result4, "空键应该返回nil")
    
    local result5 = storage:deleteData(nil, "key")
    self:assertFalse(result5, "空分类应该导致删除失败")
end

-- 测试数据计算大小
function StorageManagerTests:testDataSizeCalculation()
    local storage = self.storage_manager
    
    -- 测试字符串大小计算
    local string_size = storage:calculateDataSize("hello")
    self:assertEqual(string_size, 5, "字符串大小应该正确")
    
    -- 测试表大小计算
    local table_data = {key = "value", number = 123}
    local table_size = storage:calculateDataSize(table_data)
    self:assertTrue(table_size > 0, "表大小应该大于0")
    
    -- 测试数字大小计算
    local number_size = storage:calculateDataSize(123)
    self:assertTrue(number_size > 0, "数字大小应该大于0")
end

-- 测试内存缓存
function StorageManagerTests:testMemoryCache()
    local storage = self.storage_manager
    
    -- 保存数据（应该同时存储在内存缓存中）
    local test_data = {cached = true}
    storage:saveData("user", "cache_test", test_data)
    
    -- 验证内存缓存中的数据
    local cache_key = "user:cache_test"
    self:assertNotNil(storage.memory_cache[cache_key], "数据应该在内存缓存中")
    
    -- 删除数据应该也清除内存缓存
    storage:deleteData("user", "cache_test")
    self:assertNil(storage.memory_cache[cache_key], "删除后内存缓存应该被清除")
end

-- 测试数据持久化格式
function StorageManagerTests:testDataPersistence()
    local storage = self.storage_manager
    
    -- 保存一些测试数据
    storage:saveData("system", "persistent_test", {value = "persistent"})
    
    -- 获取保存数据
    local save_data = storage:getSaveData()
    
    self:assertNotNil(save_data, "保存数据不应为空")
    self:assertNotNil(save_data.version, "版本信息应该存在")
    
    -- 验证数据结构
    if save_data.storage_data then
        self:assertNotNil(save_data.storage_data.system, "系统分类应该存在")
        self:assertNotNil(save_data.storage_data.metadata, "元数据应该存在")
    elseif save_data.compressed_storage then
        self:assertTrue(type(save_data.compressed_storage) == "string", "压缩存储应该是字符串")
    end
end

-- 测试过期数据清理
function StorageManagerTests:testExpiredDataCleanup()
    local storage = self.storage_manager
    
    -- 保存一些带TTL的数据
    local current_time = 1000
    os.time = function() return current_time end
    
    storage:saveData("cache", "temp1", {data = "value1"}, {ttl = 60})
    storage:saveData("cache", "temp2", {data = "value2"}, {ttl = 120})
    
    -- 模拟时间过去
    current_time = current_time + 90 -- temp1过期，temp2未过期
    
    -- 执行清理
    local cleaned_count = storage:cleanupExpiredData()
    
    self:assertTrue(cleaned_count > 0, "应该清理了一些过期数据")
    
    -- 验证清理结果
    local temp1 = storage:loadData("cache", "temp1", "not_found")
    local temp2 = storage:loadData("cache", "temp2", "not_found")
    
    self:assertEqual(temp1, "not_found", "过期数据应该被清理")
    self:assertNotEqual(temp2, "not_found", "未过期数据应该保留")
end

-- 运行所有测试
function StorageManagerTests:runAllTests()
    print("开始运行StorageManager单元测试...")
    
    local tests = {
        "testBasicDataSaveAndLoad",
        "testLoadNonExistentData", 
        "testDataDeletion",
        "testDataCompression",
        "testStorageStats",
        "testTTLExpiration",
        "testCategoryStorage",
        "testErrorHandling",
        "testDataSizeCalculation",
        "testMemoryCache",
        "testDataPersistence",
        "testExpiredDataCleanup"
    }
    
    local passed = 0
    local failed = 0
    
    for _, test_name in ipairs(tests) do
        self:setUp()
        
        local success, error_msg = pcall(function()
            self[test_name](self)
        end)
        
        if success then
            print("✓ " .. test_name .. " - 通过")
            passed = passed + 1
        else
            print("✗ " .. test_name .. " - 失败: " .. (error_msg or "未知错误"))
            failed = failed + 1
        end
        
        self:tearDown()
    end
    
    print(string.format("\n测试完成: %d 通过, %d 失败", passed, failed))
    
    return failed == 0
end

-- 导出测试套件
return StorageManagerTests 