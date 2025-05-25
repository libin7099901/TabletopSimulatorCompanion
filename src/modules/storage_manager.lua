--[[
    数据存储管理器 (StorageManager)
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    功能:
    - TTS script_state持久化机制
    - 分层存储策略 (内存 → script_state → 用户输入)
    - 数据压缩和分块处理
    - 存储统计和监控
--]]

-- 基于ModuleBase创建StorageManager
local StorageManager = ModuleBase:new({
    name = "StorageManager",
    version = "1.0.0",
    description = "桌游伴侣数据存储管理器",
    author = "LeadDeveloperAI",
    dependencies = {"MainController"},
    
    default_config = {
        auto_save_interval = 300, -- 5分钟自动保存
        compression_enabled = true,
        max_storage_size = 98304, -- 96KB (安全阈值)
        backup_enabled = true,
        storage_encryption = false -- TTS环境限制，暂不启用
    }
})

-- 存储层级定义
StorageManager.STORAGE_LAYERS = {
    MEMORY = 1,        -- 运行时缓存
    SCRIPT_STATE = 2,  -- TTS持久化存储
    USER_INPUT = 3     -- 用户每次输入(敏感数据)
}

-- 数据分类策略
StorageManager.DATA_CATEGORIES = {
    SYSTEM_CONFIG = "system",      -- 系统配置
    USER_PREFERENCES = "user",     -- 用户偏好
    TRANSLATION_CACHE = "cache",   -- 翻译缓存
    SENSITIVE_DATA = "sensitive",  -- 敏感数据(API密钥等)
    MODULE_DATA = "modules"        -- 模块专用数据
}

-- 存储状态
StorageManager.storage_data = {}
StorageManager.memory_cache = {}
StorageManager.storage_stats = {
    total_size = 0,
    data_count = 0,
    last_save_time = 0,
    save_count = 0,
    load_count = 0,
    compression_ratio = 0
}

-- 初始化方法
function StorageManager:onInitialize(save_data)
    Logger:info("初始化存储管理器")
    
    -- 初始化存储系统
    self:initializeStorage()
    
    -- 加载持久化数据
    self:loadPersistedData(save_data)
    
    -- 启动自动保存
    if self.config.auto_save_interval > 0 then
        self:startAutoSave()
    end
    
    -- 注册事件监听器
    self:setupEventListeners()
    
    Logger:info("存储管理器初始化完成", {
        total_size = self.storage_stats.total_size,
        data_count = self.storage_stats.data_count
    })
end

-- 初始化存储系统
function StorageManager:initializeStorage()
    -- 初始化存储数据结构
    self.storage_data = {
        [self.DATA_CATEGORIES.SYSTEM_CONFIG] = {},
        [self.DATA_CATEGORIES.USER_PREFERENCES] = {},
        [self.DATA_CATEGORIES.TRANSLATION_CACHE] = {},
        [self.DATA_CATEGORIES.MODULE_DATA] = {},
        metadata = {
            version = self.version,
            created_time = os.time(),
            last_updated = os.time()
        }
    }
    
    -- 初始化内存缓存
    self.memory_cache = {}
    
    Logger:debug("存储系统已初始化")
end

-- 加载持久化数据
function StorageManager:loadPersistedData(save_data)
    if not save_data or type(save_data) ~= "table" then
        Logger:info("未找到保存数据，使用默认存储结构")
        return
    end
    
    -- 如果有压缩数据，先解压
    if save_data.compressed_storage then
        local success, decompressed = pcall(function()
            return self:decompressData(save_data.compressed_storage)
        end)
        
        if success and decompressed then
            self.storage_data = decompressed
            Logger:info("已加载压缩存储数据", {
                compressed_size = string.len(save_data.compressed_storage),
                decompressed_size = self:calculateDataSize(self.storage_data)
            })
        else
            Logger:warning("压缩数据解压失败，使用默认存储")
        end
    elseif save_data.storage_data then
        -- 直接加载未压缩数据
        self.storage_data = save_data.storage_data
        Logger:info("已加载存储数据")
    end
    
    -- 更新统计信息
    self:updateStorageStats()
    
    self.storage_stats.load_count = self.storage_stats.load_count + 1
end

-- 保存数据
function StorageManager:saveData(category, key, data, options)
    options = options or {}
    
    -- 验证参数
    if not category or not key then
        Logger:error("保存数据参数无效", {category = category, key = key})
        return false
    end
    
    -- 确保分类存在
    if not self.storage_data[category] then
        self.storage_data[category] = {}
    end
    
    -- 构造数据条目
    local data_entry = {
        value = data,
        timestamp = os.time(),
        size = self:calculateDataSize(data),
        compressed = false,
        ttl = options.ttl, -- 生存时间
        metadata = options.metadata or {}
    }
    
    -- 如果启用压缩且数据较大
    if self.config.compression_enabled and data_entry.size > 1024 then
        local compressed = self:compressData(data)
        if compressed and string.len(compressed) < data_entry.size then
            data_entry.value = compressed
            data_entry.compressed = true
            data_entry.size = string.len(compressed)
            Logger:debug("数据已压缩", {
                key = key,
                original_size = self:calculateDataSize(data),
                compressed_size = data_entry.size
            })
        end
    end
    
    -- 保存数据
    self.storage_data[category][key] = data_entry
    
    -- 更新到内存缓存
    local cache_key = category .. ":" .. key
    self.memory_cache[cache_key] = data
    
    -- 更新统计
    self:updateStorageStats()
    
    Logger:debug("数据已保存", {
        category = category,
        key = key,
        size = data_entry.size,
        compressed = data_entry.compressed
    })
    
    return true
end

-- 加载数据
function StorageManager:loadData(category, key, default_value)
    -- 验证参数
    if not category or not key then
        Logger:error("加载数据参数无效", {category = category, key = key})
        return default_value
    end
    
    -- 先检查内存缓存
    local cache_key = category .. ":" .. key
    if self.memory_cache[cache_key] then
        Logger:debug("从内存缓存加载数据", {key = cache_key})
        return self.memory_cache[cache_key]
    end
    
    -- 检查持久化存储
    if not self.storage_data[category] or not self.storage_data[category][key] then
        Logger:debug("数据不存在", {category = category, key = key})
        return default_value
    end
    
    local data_entry = self.storage_data[category][key]
    
    -- 检查TTL
    if data_entry.ttl and os.time() > (data_entry.timestamp + data_entry.ttl) then
        Logger:debug("数据已过期", {
            key = key,
            expired_time = os.time() - (data_entry.timestamp + data_entry.ttl)
        })
        self:deleteData(category, key)
        return default_value
    end
    
    -- 解压数据（如果需要）
    local data = data_entry.value
    if data_entry.compressed then
        local success, decompressed = pcall(function()
            return self:decompressData(data)
        end)
        
        if success then
            data = decompressed
        else
            Logger:error("数据解压失败", {category = category, key = key})
            return default_value
        end
    end
    
    -- 更新内存缓存
    self.memory_cache[cache_key] = data
    
    -- 更新统计
    self.storage_stats.load_count = self.storage_stats.load_count + 1
    
    Logger:debug("数据已加载", {category = category, key = key})
    
    return data
end

-- 删除数据
function StorageManager:deleteData(category, key)
    if not category or not key then
        Logger:error("删除数据参数无效", {category = category, key = key})
        return false
    end
    
    -- 从持久化存储删除
    if self.storage_data[category] and self.storage_data[category][key] then
        self.storage_data[category][key] = nil
        Logger:debug("已从持久化存储删除数据", {category = category, key = key})
    end
    
    -- 从内存缓存删除
    local cache_key = category .. ":" .. key
    if self.memory_cache[cache_key] then
        self.memory_cache[cache_key] = nil
        Logger:debug("已从内存缓存删除数据", {key = cache_key})
    end
    
    -- 更新统计
    self:updateStorageStats()
    
    return true
end

-- 获取存储统计
function StorageManager:getStorageStats()
    self:updateStorageStats()
    return {
        total_size = self.storage_stats.total_size,
        data_count = self.storage_stats.data_count,
        last_save_time = self.storage_stats.last_save_time,
        save_count = self.storage_stats.save_count,
        load_count = self.storage_stats.load_count,
        compression_ratio = self.storage_stats.compression_ratio,
        max_storage_size = self.config.max_storage_size,
        usage_percentage = math.floor(self.storage_stats.total_size / self.config.max_storage_size * 100)
    }
end

-- 压缩并保存大数据
function StorageManager:compressAndSave(category, key, data, options)
    options = options or {}
    options.force_compression = true
    
    return self:saveData(category, key, data, options)
end

-- 加载并解压数据
function StorageManager:loadAndDecompress(category, key, default_value)
    return self:loadData(category, key, default_value)
end

-- 获取完整保存数据
function StorageManager:getSaveData()
    -- 更新元数据
    self.storage_data.metadata.last_updated = os.time()
    
    local save_data = {
        storage_data = self.storage_data,
        stats = self.storage_stats,
        version = self.version
    }
    
    -- 如果启用压缩，压缩整个存储数据
    if self.config.compression_enabled then
        local compressed = self:compressData(self.storage_data)
        if compressed then
            save_data = {
                compressed_storage = compressed,
                stats = self.storage_stats,
                version = self.version
            }
            Logger:debug("存储数据已压缩保存", {
                original_size = self:calculateDataSize(self.storage_data),
                compressed_size = string.len(compressed)
            })
        end
    end
    
    self.storage_stats.last_save_time = os.time()
    self.storage_stats.save_count = self.storage_stats.save_count + 1
    
    return save_data
end

-- 数据压缩 (简单的字符串压缩)
function StorageManager:compressData(data)
    if type(data) ~= "string" then
        data = JSON.encode(data)
    end
    
    -- 简单的RLE压缩实现
    local compressed = ""
    local i = 1
    local len = string.len(data)
    
    while i <= len do
        local char = string.sub(data, i, i)
        local count = 1
        
        -- 计算连续字符数量
        while i + count <= len and string.sub(data, i + count, i + count) == char and count < 255 do
            count = count + 1
        end
        
        if count > 3 then
            -- 如果连续字符超过3个，使用压缩格式
            compressed = compressed .. "\255" .. string.char(count) .. char
            i = i + count
        else
            -- 否则直接添加字符
            compressed = compressed .. char
            i = i + 1
        end
    end
    
    -- 只有在压缩效果明显时才返回压缩数据
    if string.len(compressed) < string.len(data) * 0.9 then
        return compressed
    else
        return nil
    end
end

-- 数据解压
function StorageManager:decompressData(compressed_data)
    local decompressed = ""
    local i = 1
    local len = string.len(compressed_data)
    
    while i <= len do
        local char = string.sub(compressed_data, i, i)
        
        if char == "\255" and i + 2 <= len then
            -- 解压格式
            local count = string.byte(string.sub(compressed_data, i + 1, i + 1))
            local repeat_char = string.sub(compressed_data, i + 2, i + 2)
            decompressed = decompressed .. string.rep(repeat_char, count)
            i = i + 3
        else
            decompressed = decompressed .. char
            i = i + 1
        end
    end
    
    -- 尝试JSON解码
    local success, decoded = pcall(JSON.decode, decompressed)
    if success then
        return decoded
    else
        return decompressed
    end
end

-- 计算数据大小
function StorageManager:calculateDataSize(data)
    if type(data) == "string" then
        return string.len(data)
    elseif type(data) == "table" then
        local json_str = JSON.encode(data)
        return string.len(json_str)
    else
        return string.len(tostring(data))
    end
end

-- 更新存储统计
function StorageManager:updateStorageStats()
    local total_size = 0
    local data_count = 0
    local compressed_count = 0
    local uncompressed_size = 0
    
    for category, category_data in pairs(self.storage_data) do
        if category ~= "metadata" then
            for key, data_entry in pairs(category_data) do
                if type(data_entry) == "table" and data_entry.size then
                    total_size = total_size + data_entry.size
                    data_count = data_count + 1
                    
                    if data_entry.compressed then
                        compressed_count = compressed_count + 1
                        -- 估算未压缩大小
                        uncompressed_size = uncompressed_size + math.floor(data_entry.size * 1.5)
                    else
                        uncompressed_size = uncompressed_size + data_entry.size
                    end
                end
            end
        end
    end
    
    self.storage_stats.total_size = total_size
    self.storage_stats.data_count = data_count
    
    -- 计算压缩比
    if uncompressed_size > 0 then
        self.storage_stats.compression_ratio = math.floor((1 - total_size / uncompressed_size) * 100)
    end
    
    Logger:debug("存储统计已更新", {
        total_size = total_size,
        data_count = data_count,
        compression_ratio = self.storage_stats.compression_ratio
    })
end

-- 启动自动保存
function StorageManager:startAutoSave()
    local function autoSave()
        if self.system_state == "READY" then
            local save_data = self:getSaveData()
            
            -- 触发保存事件
            self:emitEvent("storage_auto_save", {
                data = save_data,
                stats = self:getStorageStats()
            })
            
            Logger:debug("自动保存已触发")
        end
        
        -- 安排下次自动保存
        Wait.time(autoSave, self.config.auto_save_interval)
    end
    
    Wait.time(autoSave, self.config.auto_save_interval)
    Logger:info("自动保存已启动", {interval = self.config.auto_save_interval})
end

-- 设置事件监听器
function StorageManager:setupEventListeners()
    -- 监听系统关闭事件
    self:addEventListener("system_shutdown", function(event_data)
        Logger:info("收到系统关闭信号，执行最终保存")
        local save_data = self:getSaveData()
        -- 这里的保存将由MainController处理
    end)
    
    -- 监听配置变更事件
    self:addEventListener("config_changed", function(event_data)
        if event_data.module == self.name then
            Logger:info("存储管理器配置已变更", event_data.config)
            self:applyConfig(event_data.config)
        end
    end)
end

-- 清理过期数据
function StorageManager:cleanupExpiredData()
    local cleaned_count = 0
    local current_time = os.time()
    
    for category, category_data in pairs(self.storage_data) do
        if category ~= "metadata" then
            for key, data_entry in pairs(category_data) do
                if type(data_entry) == "table" and data_entry.ttl then
                    if current_time > (data_entry.timestamp + data_entry.ttl) then
                        self:deleteData(category, key)
                        cleaned_count = cleaned_count + 1
                    end
                end
            end
        end
    end
    
    if cleaned_count > 0 then
        Logger:info("已清理过期数据", {cleaned_count = cleaned_count})
    end
    
    return cleaned_count
end

-- 子类关闭方法
function StorageManager:onShutdown()
    Logger:info("存储管理器开始关闭")
    
    -- 清理过期数据
    self:cleanupExpiredData()
    
    -- 最终保存
    local save_data = self:getSaveData()
    Logger:info("存储管理器关闭完成", {
        final_size = self.storage_stats.total_size,
        data_count = self.storage_stats.data_count
    })
    
    return save_data
end

-- 导出StorageManager模块
return StorageManager 