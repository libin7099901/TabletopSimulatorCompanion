--[[
    数据持久化集成测试
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    测试覆盖:
    - StorageManager与ConfigManager集成
    - StorageManager与CacheManager集成
    - 完整的数据生命周期
    - 系统重启后数据恢复
--]]

-- 引入测试框架
local TestFramework = require("tests.framework.test_framework")

-- 引入模块
local StorageManager = require("src.modules.storage_manager")
local ConfigManager = require("src.modules.config_manager")
local CacheManager = require("src.modules.cache_manager")
local DataCompressor = require("src.modules.data_compressor")

-- 模拟依赖
local MockLogger = require("tests.mocks.mock_logger")
local MockMainController = require("tests.mocks.mock_main_controller")

-- 集成测试套件
local DataPersistenceTests = TestFramework:createSuite("Data Persistence Integration Tests")

-- 测试设置
function DataPersistenceTests:setUp()
    -- 模拟全局对象
    Logger = MockLogger
    
    JSON = {
        encode = function(data)
            if type(data) == "table" then
                local result = "{"
                local first = true
                for k, v in pairs(data) do
                    if not first then result = result .. "," end
                    result = result .. '"' .. tostring(k) .. '":"' .. tostring(v) .. '"'
                    first = false
                end
                return result .. "}"
            else
                return '"' .. tostring(data) .. '"'
            end
        end,
        decode = function(json_str)
            if type(json_str) == "string" and string.sub(json_str, 1, 1) == "{" then
                return {decoded = true, original = json_str}
            else
                return json_str
            end
        end
    }
    
    -- 模拟时间函数
    self.current_time = 1000000000
    os.time = function() return self.current_time end
    os.clock = function() return self.current_time / 1000 end
    
    -- 模拟Wait对象
    Wait = {
        time = function(callback, delay)
            -- 模拟定时器，立即执行
            if callback then callback() end
        end
    }
    
    -- 创建模块实例
    self.storage_manager = StorageManager:new()
    self.config_manager = ConfigManager:new()
    self.cache_manager = CacheManager:new()
    self.data_compressor = DataCompressor:new()
    
    -- 设置模块间依赖关系（模拟MainController的功能）
    self.storage_manager.getModule = function(_, module_name)
        if module_name == "ConfigManager" then
            return self.config_manager
        elseif module_name == "CacheManager" then
            return self.cache_manager
        elseif module_name == "DataCompressor" then
            return self.data_compressor
        end
        return nil
    end
    
    self.config_manager.getModule = function(_, module_name)
        if module_name == "StorageManager" then
            return self.storage_manager
        end
        return nil
    end
    
    self.cache_manager.getModule = function(_, module_name)
        if module_name == "StorageManager" then
            return self.storage_manager
        end
        return nil
    end
    
    -- 初始化模块
    self.storage_manager:onInitialize({})
    self.config_manager:onInitialize({})
    self.cache_manager:onInitialize({})
    self.data_compressor:onInitialize({})
end

-- 测试清理
function DataPersistenceTests:tearDown()
    -- 关闭模块
    if self.storage_manager then self.storage_manager:onShutdown() end
    if self.config_manager then self.config_manager:onShutdown() end
    if self.cache_manager then self.cache_manager:onShutdown() end
    if self.data_compressor then self.data_compressor:onShutdown() end
    
    -- 清理全局变量
    Logger = nil
    JSON = nil
    Wait = nil
    
    self.storage_manager = nil
    self.config_manager = nil
    self.cache_manager = nil
    self.data_compressor = nil
end

-- 测试配置管理器与存储管理器集成
function DataPersistenceTests:testConfigStorageIntegration()
    local config_mgr = self.config_manager
    local storage_mgr = self.storage_manager
    
    -- 设置一些配置
    config_mgr:setConfig("ui", "theme", "dark")
    config_mgr:setConfig("system", "log_level", "DEBUG")
    config_mgr:setConfig("storage", "compression_enabled", false)
    
    -- 获取配置管理器的保存数据
    local config_save_data = config_mgr:getSaveData()
    
    self:assertNotNil(config_save_data, "配置保存数据不应为空")
    self:assertNotNil(config_save_data.configs, "配置数据应该存在")
    
    -- 验证配置可以通过存储管理器保存
    local save_success = storage_mgr:saveData("system", "config_manager_data", config_save_data)
    self:assertTrue(save_success, "配置数据应该能保存到存储管理器")
    
    -- 模拟系统重启 - 重新初始化配置管理器
    local new_config_mgr = ConfigManager:new()
    new_config_mgr.getModule = self.config_manager.getModule
    
    -- 从存储管理器加载配置数据
    local loaded_config_data = storage_mgr:loadData("system", "config_manager_data")
    self:assertNotNil(loaded_config_data, "应该能从存储管理器加载配置数据")
    
    -- 用加载的数据初始化新的配置管理器
    new_config_mgr:onInitialize(loaded_config_data)
    
    -- 验证配置已恢复
    self:assertEqual(new_config_mgr:getConfig("ui", "theme"), "dark", "UI主题配置应该已恢复")
    self:assertEqual(new_config_mgr:getConfig("system", "log_level"), "DEBUG", "系统日志级别应该已恢复")
    self:assertEqual(new_config_mgr:getConfig("storage", "compression_enabled"), false, "存储压缩配置应该已恢复")
end

-- 测试缓存管理器与存储管理器集成
function DataPersistenceTests:testCacheStorageIntegration()
    local cache_mgr = self.cache_manager
    local storage_mgr = self.storage_manager
    
    -- 在缓存中存储一些数据
    cache_mgr:set("translation", "hello_world", "你好世界", 3600)
    cache_mgr:set("rule_query", "can_move_piece", "是的，你可以移动这个棋子", 1800)
    cache_mgr:set("user_data", "last_game", {game = "chess", score = 1500}, 7200)
    
    -- 获取缓存统计
    local cache_stats_before = cache_mgr:getStats()
    self:assertTrue(cache_stats_before.total_size > 0, "缓存中应该有数据")
    
    -- 获取缓存管理器的保存数据
    local cache_save_data = cache_mgr:getSaveData()
    
    self:assertNotNil(cache_save_data, "缓存保存数据不应为空")
    self:assertNotNil(cache_save_data.cache_data, "缓存数据应该存在")
    
    -- 验证缓存可以通过存储管理器保存
    local save_success = storage_mgr:saveData("system", "cache_manager_data", cache_save_data)
    self:assertTrue(save_success, "缓存数据应该能保存到存储管理器")
    
    -- 模拟系统重启 - 清空缓存并重新初始化
    cache_mgr:clear() -- 清空所有缓存
    
    local cache_stats_after_clear = cache_mgr:getStats()
    self:assertEqual(cache_stats_after_clear.total_size, 0, "清空后缓存应该为空")
    
    -- 从存储管理器加载缓存数据
    local loaded_cache_data = storage_mgr:loadData("system", "cache_manager_data")
    self:assertNotNil(loaded_cache_data, "应该能从存储管理器加载缓存数据")
    
    -- 用加载的数据重新初始化缓存管理器
    local new_cache_mgr = CacheManager:new()
    new_cache_mgr.getModule = self.cache_manager.getModule
    new_cache_mgr:onInitialize(loaded_cache_data)
    
    -- 验证缓存数据已恢复
    local restored_translation = new_cache_mgr:get("translation", "hello_world")
    local restored_rule = new_cache_mgr:get("rule_query", "can_move_piece")
    local restored_user_data = new_cache_mgr:get("user_data", "last_game")
    
    self:assertEqual(restored_translation, "你好世界", "翻译缓存应该已恢复")
    self:assertEqual(restored_rule, "是的，你可以移动这个棋子", "规则查询缓存应该已恢复")
    self:assertNotNil(restored_user_data, "用户数据缓存应该已恢复")
    self:assertEqual(restored_user_data.game, "chess", "用户数据内容应该正确")
end

-- 测试数据压缩集成
function DataPersistenceTests:testCompressionIntegration()
    local storage_mgr = self.storage_manager
    local compressor = self.data_compressor
    
    -- 创建大量重复数据进行压缩测试
    local large_data = {}
    for i = 1, 100 do
        large_data["key_" .. i] = "这是一个重复的字符串，用于测试压缩效果。"
    end
    
    -- 通过存储管理器保存大数据（应该自动触发压缩）
    local save_success = storage_mgr:saveData("cache", "large_dataset", large_data)
    self:assertTrue(save_success, "大数据应该能成功保存")
    
    -- 获取存储统计，验证压缩效果
    local storage_stats = storage_mgr:getStorageStats()
    self:assertTrue(storage_stats.compression_ratio > 0, "应该有压缩效果")
    
    -- 加载数据并验证完整性
    local loaded_data = storage_mgr:loadData("cache", "large_dataset")
    self:assertNotNil(loaded_data, "应该能加载压缩后的数据")
    self:assertEqual(#loaded_data, #large_data, "数据条目数应该匹配")
    
    -- 验证数据内容完整性
    for i = 1, 10 do -- 检查前10项
        local key = "key_" .. i
        self:assertEqual(loaded_data[key], large_data[key], "数据内容应该匹配")
    end
    
    -- 测试压缩器独立功能
    local test_data = {message = "Hello World", count = 42, enabled = true}
    local compressed_data, compression_type = compressor:compress(test_data)
    
    self:assertNotNil(compressed_data, "数据应该能被压缩")
    
    local decompressed_data = compressor:decompress(compressed_data, compression_type)
    self:assertNotNil(decompressed_data, "数据应该能被解压")
    self:assertEqual(decompressed_data.message, test_data.message, "解压后数据应该匹配")
end

-- 测试完整的数据生命周期
function DataPersistenceTests:testCompleteDataLifecycle()
    local storage_mgr = self.storage_manager
    local config_mgr = self.config_manager
    local cache_mgr = self.cache_manager
    
    -- 阶段1：设置初始数据
    print("阶段1：设置初始数据")
    
    -- 配置数据
    config_mgr:setConfig("ui", "theme", "dark")
    config_mgr:setConfig("system", "debug_enabled", true)
    
    -- 缓存数据  
    cache_mgr:set("translation", "greeting", "您好", 3600)
    cache_mgr:set("user_data", "preferences", {lang = "zh", volume = 0.8}, 7200)
    
    -- 存储数据
    storage_mgr:saveData("user", "profile", {name = "玩家1", level = 5})
    storage_mgr:saveData("system", "statistics", {games_played = 10, wins = 7})
    
    -- 阶段2：获取所有模块的保存数据
    print("阶段2：收集保存数据")
    
    local all_save_data = {
        storage_manager = storage_mgr:getSaveData(),
        config_manager = config_mgr:getSaveData(),
        cache_manager = cache_mgr:getSaveData(),
        data_compressor = self.data_compressor:getSaveData()
    }
    
    -- 验证保存数据的完整性
    self:assertNotNil(all_save_data.storage_manager, "存储管理器保存数据应该存在")
    self:assertNotNil(all_save_data.config_manager, "配置管理器保存数据应该存在")
    self:assertNotNil(all_save_data.cache_manager, "缓存管理器保存数据应该存在")
    
    -- 阶段3：模拟系统完全重启
    print("阶段3：模拟系统重启")
    
    -- 关闭所有模块
    storage_mgr:onShutdown()
    config_mgr:onShutdown()
    cache_mgr:onShutdown()
    self.data_compressor:onShutdown()
    
    -- 创建新的模块实例
    local new_storage_mgr = StorageManager:new()
    local new_config_mgr = ConfigManager:new()
    local new_cache_mgr = CacheManager:new()
    local new_compressor = DataCompressor:new()
    
    -- 设置模块间依赖关系
    new_storage_mgr.getModule = function(_, module_name)
        if module_name == "ConfigManager" then return new_config_mgr
        elseif module_name == "CacheManager" then return new_cache_mgr
        elseif module_name == "DataCompressor" then return new_compressor
        end
        return nil
    end
    
    new_config_mgr.getModule = function(_, module_name)
        if module_name == "StorageManager" then return new_storage_mgr end
        return nil
    end
    
    new_cache_mgr.getModule = function(_, module_name)
        if module_name == "StorageManager" then return new_storage_mgr end
        return nil
    end
    
    -- 用保存的数据初始化新模块
    new_storage_mgr:onInitialize(all_save_data.storage_manager)
    new_config_mgr:onInitialize(all_save_data.config_manager)
    new_cache_mgr:onInitialize(all_save_data.cache_manager)
    new_compressor:onInitialize(all_save_data.data_compressor)
    
    -- 阶段4：验证数据已完全恢复
    print("阶段4：验证数据恢复")
    
    -- 验证配置恢复
    self:assertEqual(new_config_mgr:getConfig("ui", "theme"), "dark", "UI主题应该已恢复")
    self:assertEqual(new_config_mgr:getConfig("system", "debug_enabled"), true, "调试设置应该已恢复")
    
    -- 验证缓存恢复
    self:assertEqual(new_cache_mgr:get("translation", "greeting"), "您好", "翻译缓存应该已恢复")
    local restored_prefs = new_cache_mgr:get("user_data", "preferences")
    self:assertNotNil(restored_prefs, "用户偏好应该已恢复")
    self:assertEqual(restored_prefs.lang, "zh", "语言设置应该正确")
    
    -- 验证存储数据恢复
    local restored_profile = new_storage_mgr:loadData("user", "profile")
    local restored_stats = new_storage_mgr:loadData("system", "statistics")
    
    self:assertNotNil(restored_profile, "用户档案应该已恢复")
    self:assertEqual(restored_profile.name, "玩家1", "用户名应该正确")
    self:assertEqual(restored_profile.level, 5, "用户等级应该正确")
    
    self:assertNotNil(restored_stats, "统计数据应该已恢复")
    self:assertEqual(restored_stats.games_played, 10, "游戏次数应该正确")
    self:assertEqual(restored_stats.wins, 7, "胜利次数应该正确")
    
    print("完整数据生命周期测试通过！")
end

-- 测试多模块数据协调
function DataPersistenceTests:testMultiModuleDataCoordination()
    local storage_mgr = self.storage_manager
    local config_mgr = self.config_manager
    local cache_mgr = self.cache_manager
    
    -- 测试配置变更对其他模块的影响
    config_mgr:setConfig("cache", "max_cache_size", 100)
    config_mgr:setConfig("storage", "compression_enabled", true)
    
    -- 模拟配置变更事件传播
    cache_mgr.config.max_cache_size = 100
    storage_mgr.config.compression_enabled = true
    
    -- 验证配置协调
    local cache_stats = cache_mgr:getStats()
    local storage_stats = storage_mgr:getStorageStats()
    
    self:assertNotNil(cache_stats, "缓存统计应该可用")
    self:assertNotNil(storage_stats, "存储统计应该可用")
    
    -- 测试缓存与存储的数据一致性
    cache_mgr:set("translation", "test_phrase", "测试短语", 3600)
    
    -- 通过存储管理器直接保存同样的翻译
    storage_mgr:saveData("cache", "translation_backup", {
        key = "test_phrase",
        value = "测试短语", 
        timestamp = os.time()
    })
    
    -- 验证两种方式保存的数据一致性
    local cached_value = cache_mgr:get("translation", "test_phrase")
    local stored_backup = storage_mgr:loadData("cache", "translation_backup")
    
    self:assertEqual(cached_value, stored_backup.value, "缓存和存储的翻译数据应该一致")
end

-- 测试错误恢复和数据完整性
function DataPersistenceTests:testErrorRecoveryAndDataIntegrity()
    local storage_mgr = self.storage_manager
    
    -- 保存一些重要数据
    storage_mgr:saveData("user", "important_data", {critical = true, value = "重要数据"})
    
    -- 模拟部分数据损坏
    local save_data = storage_mgr:getSaveData()
    
    -- 创建新实例并尝试加载损坏的数据
    local new_storage_mgr = StorageManager:new()
    
    -- 模拟部分损坏的保存数据
    local corrupted_save_data = {
        storage_data = {
            user = {
                important_data = "corrupted_format" -- 错误格式
            }
        },
        version = save_data.version
    }
    
    -- 初始化时应该能处理损坏的数据
    new_storage_mgr:onInitialize(corrupted_save_data)
    
    -- 验证系统仍然可以正常工作
    local save_result = new_storage_mgr:saveData("user", "recovery_test", {recovered = true})
    self:assertTrue(save_result, "系统应该能在数据损坏后恢复正常工作")
    
    local loaded_recovery = new_storage_mgr:loadData("user", "recovery_test")
    self:assertNotNil(loaded_recovery, "恢复后的数据应该能正常加载")
    self:assertTrue(loaded_recovery.recovered, "恢复标志应该正确")
end

-- 运行所有集成测试
function DataPersistenceTests:runAllTests()
    print("开始运行数据持久化集成测试...")
    
    local tests = {
        "testConfigStorageIntegration",
        "testCacheStorageIntegration", 
        "testCompressionIntegration",
        "testCompleteDataLifecycle",
        "testMultiModuleDataCoordination",
        "testErrorRecoveryAndDataIntegrity"
    }
    
    local passed = 0
    local failed = 0
    
    for _, test_name in ipairs(tests) do
        print("\n运行测试: " .. test_name)
        
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
    
    print(string.format("\n集成测试完成: %d 通过, %d 失败", passed, failed))
    
    return failed == 0
end

-- 导出测试套件
return DataPersistenceTests 