--[[
    缓存管理器 (CacheManager)
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    功能:
    - LRU (最近最少使用) 缓存算法
    - TTL (生存时间) 支持
    - 分类缓存管理
    - 缓存统计和监控
--]]

-- 基于ModuleBase创建CacheManager
local CacheManager = ModuleBase:new({
    name = "CacheManager",
    version = "1.0.0",
    description = "桌游伴侣缓存管理器",
    author = "LeadDeveloperAI",
    dependencies = {"StorageManager"},
    
    default_config = {
        max_cache_size = 50,        -- 最大缓存条目数
        default_ttl = 3600,         -- 默认TTL (1小时)
        cleanup_interval = 300,     -- 清理间隔 (5分钟)
        enable_persistence = true,  -- 启用缓存持久化
        memory_limit_mb = 5         -- 内存限制 (MB)
    }
})

-- 缓存类型定义
CacheManager.CACHE_TYPES = {
    TRANSLATION = "translation",    -- 翻译缓存
    RULE_QUERY = "rule_query",     -- 规则查询缓存
    USER_DATA = "user_data",       -- 用户数据缓存
    SYSTEM = "system"              -- 系统缓存
}

-- 缓存状态
CacheManager.cache_data = {}
CacheManager.access_order = {}
CacheManager.cache_stats = {
    hits = 0,
    misses = 0,
    evictions = 0,
    total_size = 0,
    last_cleanup = 0
}

-- 初始化方法
function CacheManager:onInitialize(save_data)
    Logger:info("初始化缓存管理器")
    
    -- 初始化缓存系统
    self:initializeCacheSystem()
    
    -- 加载持久化缓存数据
    self:loadCachedData(save_data)
    
    -- 启动清理任务
    if self.config.cleanup_interval > 0 then
        self:startCleanupTask()
    end
    
    -- 设置事件监听器
    self:setupEventListeners()
    
    Logger:info("缓存管理器初始化完成", {
        cache_types = #self.CACHE_TYPES,
        max_size = self.config.max_cache_size
    })
end

-- 初始化缓存系统
function CacheManager:initializeCacheSystem()
    -- 为每种缓存类型初始化存储
    for _, cache_type in pairs(self.CACHE_TYPES) do
        self.cache_data[cache_type] = {}
        self.access_order[cache_type] = {}
    end
    
    -- 重置统计
    self.cache_stats = {
        hits = 0,
        misses = 0,
        evictions = 0,
        total_size = 0,
        last_cleanup = os.time()
    }
    
    Logger:debug("缓存系统已初始化")
end

-- 加载持久化缓存数据
function CacheManager:loadCachedData(save_data)
    if not self.config.enable_persistence then
        Logger:info("缓存持久化已禁用")
        return
    end
    
    if not save_data or not save_data.cache_data then
        Logger:info("未找到缓存数据")
        return
    end
    
    local loaded_count = 0
    local expired_count = 0
    local current_time = os.time()
    
    for cache_type, type_data in pairs(save_data.cache_data) do
        if self.cache_data[cache_type] then
            for key, cache_entry in pairs(type_data) do
                -- 检查是否过期
                if cache_entry.expires_at and current_time > cache_entry.expires_at then
                    expired_count = expired_count + 1
                else
                    self.cache_data[cache_type][key] = cache_entry
                    -- 添加到访问顺序（按时间戳排序）
                    table.insert(self.access_order[cache_type], key)
                    loaded_count = loaded_count + 1
                end
            end
        end
    end
    
    -- 如果有统计数据，也加载
    if save_data.cache_stats then
        -- 只保留部分统计，重置计数器
        self.cache_stats.total_size = save_data.cache_stats.total_size or 0
    end
    
    Logger:info("缓存数据已加载", {
        loaded = loaded_count,
        expired = expired_count
    })
end

-- 获取缓存值
function CacheManager:get(cache_type, key)
    if not cache_type or not key then
        Logger:error("获取缓存参数无效", {cache_type = cache_type, key = key})
        return nil
    end
    
    -- 检查缓存类型是否存在
    if not self.cache_data[cache_type] then
        Logger:warning("未知的缓存类型", {cache_type = cache_type})
        self.cache_stats.misses = self.cache_stats.misses + 1
        return nil
    end
    
    local cache_entry = self.cache_data[cache_type][key]
    
    -- 缓存未命中
    if not cache_entry then
        self.cache_stats.misses = self.cache_stats.misses + 1
        Logger:debug("缓存未命中", {cache_type = cache_type, key = key})
        return nil
    end
    
    -- 检查是否过期
    if cache_entry.expires_at and os.time() > cache_entry.expires_at then
        Logger:debug("缓存已过期", {
            cache_type = cache_type,
            key = key,
            expired_time = os.time() - cache_entry.expires_at
        })
        self:invalidate(cache_type, key)
        self.cache_stats.misses = self.cache_stats.misses + 1
        return nil
    end
    
    -- 缓存命中，更新访问时间和顺序
    cache_entry.last_accessed = os.time()
    self:updateAccessOrder(cache_type, key)
    
    self.cache_stats.hits = self.cache_stats.hits + 1
    
    Logger:debug("缓存命中", {cache_type = cache_type, key = key})
    
    return cache_entry.value
end

-- 设置缓存值
function CacheManager:set(cache_type, key, value, ttl)
    if not cache_type or not key then
        Logger:error("设置缓存参数无效", {cache_type = cache_type, key = key})
        return false
    end
    
    -- 检查缓存类型是否存在
    if not self.cache_data[cache_type] then
        Logger:warning("未知的缓存类型", {cache_type = cache_type})
        return false
    end
    
    ttl = ttl or self.config.default_ttl
    local current_time = os.time()
    
    -- 创建缓存条目
    local cache_entry = {
        value = value,
        created_at = current_time,
        last_accessed = current_time,
        expires_at = ttl > 0 and (current_time + ttl) or nil,
        size = self:calculateCacheEntrySize(value)
    }
    
    -- 检查是否已存在，如果存在则更新
    local is_update = self.cache_data[cache_type][key] ~= nil
    
    self.cache_data[cache_type][key] = cache_entry
    
    if not is_update then
        -- 新增条目，添加到访问顺序
        table.insert(self.access_order[cache_type], key)
        
        -- 检查是否需要淘汰旧条目
        self:enforceMaxSize(cache_type)
    else
        -- 更新现有条目，更新访问顺序
        self:updateAccessOrder(cache_type, key)
    end
    
    -- 更新统计
    self:updateCacheStats()
    
    Logger:debug("缓存已设置", {
        cache_type = cache_type,
        key = key,
        size = cache_entry.size,
        ttl = ttl,
        is_update = is_update
    })
    
    return true
end

-- 删除缓存条目
function CacheManager:invalidate(cache_type, key)
    if not cache_type or not key then
        Logger:error("删除缓存参数无效", {cache_type = cache_type, key = key})
        return false
    end
    
    if not self.cache_data[cache_type] or not self.cache_data[cache_type][key] then
        Logger:debug("缓存条目不存在", {cache_type = cache_type, key = key})
        return false
    end
    
    -- 从缓存数据中删除
    self.cache_data[cache_type][key] = nil
    
    -- 从访问顺序中删除
    local access_list = self.access_order[cache_type]
    for i, access_key in ipairs(access_list) do
        if access_key == key then
            table.remove(access_list, i)
            break
        end
    end
    
    -- 更新统计
    self:updateCacheStats()
    
    Logger:debug("缓存条目已删除", {cache_type = cache_type, key = key})
    
    return true
end

-- 清空指定类型的缓存
function CacheManager:clear(cache_type)
    if cache_type then
        -- 清空指定类型
        if self.cache_data[cache_type] then
            local count = self:getCacheTypeSize(cache_type)
            self.cache_data[cache_type] = {}
            self.access_order[cache_type] = {}
            
            Logger:info("缓存类型已清空", {cache_type = cache_type, cleared_count = count})
        end
    else
        -- 清空所有缓存
        local total_count = self:getTotalCacheSize()
        for _, type_name in pairs(self.CACHE_TYPES) do
            self.cache_data[type_name] = {}
            self.access_order[type_name] = {}
        end
        
        Logger:info("所有缓存已清空", {cleared_count = total_count})
    end
    
    -- 更新统计
    self:updateCacheStats()
    
    return true
end

-- 更新访问顺序 (LRU算法核心)
function CacheManager:updateAccessOrder(cache_type, key)
    local access_list = self.access_order[cache_type]
    
    -- 从当前位置移除
    for i, access_key in ipairs(access_list) do
        if access_key == key then
            table.remove(access_list, i)
            break
        end
    end
    
    -- 添加到末尾（最近使用）
    table.insert(access_list, key)
end

-- 执行最大大小限制 (LRU淘汰)
function CacheManager:enforceMaxSize(cache_type)
    local access_list = self.access_order[cache_type]
    local max_size = self.config.max_cache_size
    
    while #access_list > max_size do
        -- 淘汰最久未使用的条目（列表开头）
        local oldest_key = table.remove(access_list, 1)
        if self.cache_data[cache_type][oldest_key] then
            self.cache_data[cache_type][oldest_key] = nil
            self.cache_stats.evictions = self.cache_stats.evictions + 1
            
            Logger:debug("缓存条目已淘汰", {
                cache_type = cache_type,
                key = oldest_key,
                reason = "LRU"
            })
        end
    end
end

-- 计算缓存条目大小
function CacheManager:calculateCacheEntrySize(value)
    if type(value) == "string" then
        return string.len(value)
    elseif type(value) == "table" then
        local json_str = JSON.encode(value)
        return string.len(json_str)
    else
        return string.len(tostring(value))
    end
end

-- 获取缓存类型大小
function CacheManager:getCacheTypeSize(cache_type)
    local count = 0
    if self.cache_data[cache_type] then
        for _, _ in pairs(self.cache_data[cache_type]) do
            count = count + 1
        end
    end
    return count
end

-- 获取总缓存大小
function CacheManager:getTotalCacheSize()
    local total = 0
    for _, cache_type in pairs(self.CACHE_TYPES) do
        total = total + self:getCacheTypeSize(cache_type)
    end
    return total
end

-- 更新缓存统计
function CacheManager:updateCacheStats()
    local total_size = 0
    local total_memory = 0
    
    for _, cache_type in pairs(self.CACHE_TYPES) do
        if self.cache_data[cache_type] then
            for _, cache_entry in pairs(self.cache_data[cache_type]) do
                total_size = total_size + 1
                total_memory = total_memory + cache_entry.size
            end
        end
    end
    
    self.cache_stats.total_size = total_size
    self.cache_stats.total_memory = total_memory
end

-- 获取缓存统计
function CacheManager:getStats(cache_type)
    self:updateCacheStats()
    
    local stats = {
        total_hits = self.cache_stats.hits,
        total_misses = self.cache_stats.misses,
        total_evictions = self.cache_stats.evictions,
        hit_rate = 0,
        total_size = self.cache_stats.total_size,
        total_memory = self.cache_stats.total_memory,
        last_cleanup = self.cache_stats.last_cleanup
    }
    
    -- 计算命中率
    local total_requests = stats.total_hits + stats.total_misses
    if total_requests > 0 then
        stats.hit_rate = math.floor(stats.total_hits / total_requests * 100)
    end
    
    -- 如果指定了缓存类型，添加详细信息
    if cache_type and self.cache_data[cache_type] then
        stats.type_size = self:getCacheTypeSize(cache_type)
        stats.type_memory = 0
        
        for _, cache_entry in pairs(self.cache_data[cache_type]) do
            stats.type_memory = stats.type_memory + cache_entry.size
        end
    end
    
    return stats
end

-- 清理过期缓存
function CacheManager:cleanupExpiredEntries()
    local current_time = os.time()
    local cleaned_count = 0
    
    for cache_type, type_data in pairs(self.cache_data) do
        local keys_to_remove = {}
        
        for key, cache_entry in pairs(type_data) do
            if cache_entry.expires_at and current_time > cache_entry.expires_at then
                table.insert(keys_to_remove, key)
            end
        end
        
        -- 删除过期条目
        for _, key in ipairs(keys_to_remove) do
            self:invalidate(cache_type, key)
            cleaned_count = cleaned_count + 1
        end
    end
    
    self.cache_stats.last_cleanup = current_time
    
    if cleaned_count > 0 then
        Logger:info("已清理过期缓存", {cleaned_count = cleaned_count})
    else
        Logger:debug("缓存清理完成，无过期条目")
    end
    
    return cleaned_count
end

-- 启动清理任务
function CacheManager:startCleanupTask()
    local function cleanupTask()
        if self.system_state == "READY" then
            self:cleanupExpiredEntries()
        end
        
        -- 安排下次清理
        Wait.time(cleanupTask, self.config.cleanup_interval)
    end
    
    Wait.time(cleanupTask, self.config.cleanup_interval)
    Logger:info("缓存清理任务已启动", {interval = self.config.cleanup_interval})
end

-- 设置事件监听器
function CacheManager:setupEventListeners()
    -- 监听系统关闭事件
    self:addEventListener("system_shutdown", function(event_data)
        Logger:info("收到系统关闭信号，清理缓存")
        self:cleanupExpiredEntries()
    end)
    
    -- 监听内存压力事件（如果有）
    self:addEventListener("memory_pressure", function(event_data)
        Logger:info("收到内存压力信号，执行缓存压缩")
        self:compressCache()
    end)
end

-- 压缩缓存（释放内存）
function CacheManager:compressCache()
    local removed_count = 0
    local target_size = math.floor(self.config.max_cache_size * 0.7) -- 减少到70%
    
    for cache_type, access_list in pairs(self.access_order) do
        while #access_list > target_size do
            local oldest_key = table.remove(access_list, 1)
            if self.cache_data[cache_type][oldest_key] then
                self.cache_data[cache_type][oldest_key] = nil
                removed_count = removed_count + 1
            end
        end
    end
    
    self:updateCacheStats()
    
    Logger:info("缓存压缩完成", {
        removed_count = removed_count,
        new_size = self.cache_stats.total_size
    })
    
    return removed_count
end

-- 获取保存数据
function CacheManager:getSaveData()
    if not self.config.enable_persistence then
        return {}
    end
    
    -- 清理过期数据
    self:cleanupExpiredEntries()
    
    return {
        cache_data = self.cache_data,
        cache_stats = self.cache_stats,
        version = self.version
    }
end

-- 子类关闭方法
function CacheManager:onShutdown()
    Logger:info("缓存管理器开始关闭")
    
    -- 最终清理
    local cleaned = self:cleanupExpiredEntries()
    
    -- 输出统计信息
    local stats = self:getStats()
    Logger:info("缓存管理器关闭完成", {
        final_size = stats.total_size,
        hit_rate = stats.hit_rate,
        cleaned_on_shutdown = cleaned
    })
end

-- 翻译缓存专用方法
function CacheManager:setTranslation(source_text, target_lang, translated_text, ttl)
    local cache_key = source_text .. ":" .. target_lang
    return self:set(self.CACHE_TYPES.TRANSLATION, cache_key, translated_text, ttl)
end

function CacheManager:getTranslation(source_text, target_lang)
    local cache_key = source_text .. ":" .. target_lang
    return self:get(self.CACHE_TYPES.TRANSLATION, cache_key)
end

-- 规则查询缓存专用方法
function CacheManager:setRuleQuery(query_text, response, ttl)
    local cache_key = self:generateQueryKey(query_text)
    return self:set(self.CACHE_TYPES.RULE_QUERY, cache_key, response, ttl)
end

function CacheManager:getRuleQuery(query_text)
    local cache_key = self:generateQueryKey(query_text)
    return self:get(self.CACHE_TYPES.RULE_QUERY, cache_key)
end

-- 生成查询键（简单哈希）
function CacheManager:generateQueryKey(text)
    local hash = 0
    for i = 1, string.len(text) do
        local char = string.byte(text, i)
        hash = ((hash * 31) + char) % 1000000 -- 简单哈希算法
    end
    return tostring(hash)
end

-- 导出CacheManager模块
return CacheManager 