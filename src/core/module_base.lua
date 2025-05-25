--[[
    模块基类 (ModuleBase)
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    功能:
    - 标准化模块接口
    - 生命周期管理
    - 依赖关系检查
    - 状态跟踪和报告
--]]

local ModuleBase = {
    -- 模块基本信息
    name = "",
    version = "1.0",
    description = "",
    author = "",
    
    -- 模块状态
    status = "UNINITIALIZED", -- UNINITIALIZED, INITIALIZING, READY, ERROR, SHUTDOWN
    
    -- 依赖关系
    dependencies = {}, -- 依赖的模块名称列表
    
    -- 配置信息
    config = {},
    default_config = {},
    
    -- 模块统计
    stats = {
        init_time = 0,
        last_activity = 0,
        operations_count = 0,
        errors_count = 0
    },
    
    -- 事件监听器
    event_listeners = {}
}

-- 创建新的模块实例
function ModuleBase:new(module_info)
    module_info = module_info or {}
    
    local instance = {}
    
    -- 复制基类属性
    for key, value in pairs(self) do
        if type(value) == "table" then
            instance[key] = self:deepCopy(value)
        else
            instance[key] = value
        end
    end
    
    -- 设置模块信息
    instance.name = module_info.name or "UnnamedModule"
    instance.version = module_info.version or "1.0"
    instance.description = module_info.description or ""
    instance.author = module_info.author or ""
    instance.dependencies = module_info.dependencies or {}
    instance.default_config = module_info.default_config or {}
    
    -- 初始化配置
    instance.config = instance:deepCopy(instance.default_config)
    
    -- 设置元表
    setmetatable(instance, {__index = self})
    
    return instance
end

-- 深拷贝工具函数
function ModuleBase:deepCopy(original)
    if type(original) ~= "table" then
        return original
    end
    
    local copy = {}
    for key, value in pairs(original) do
        copy[key] = self:deepCopy(value)
    end
    
    return copy
end

-- 模块初始化 (子类必须重写)
function ModuleBase:initialize(save_data)
    self.status = "INITIALIZING"
    local start_time = os.clock()
    
    Logger:info("模块初始化开始", {module = self.name})
    
    -- 检查依赖
    if not self:checkDependencies() then
        self.status = "ERROR"
        ErrorHandler:handle(ErrorHandler.error_codes.MODULE_LOAD_ERROR, 
                          "模块依赖检查失败", {module = self.name})
        return false
    end
    
    -- 加载配置
    self:loadConfig(save_data)
    
    -- 调用子类的初始化方法
    local success, error_msg = pcall(function()
        self:onInitialize(save_data)
    end)
    
    if not success then
        self.status = "ERROR"
        self.stats.errors_count = self.stats.errors_count + 1
        ErrorHandler:handle(ErrorHandler.error_codes.MODULE_LOAD_ERROR, 
                          "模块初始化失败: " .. tostring(error_msg), 
                          {module = self.name})
        return false
    end
    
    -- 注册事件监听器
    self:registerEventListeners()
    
    -- 更新状态和统计
    self.status = "READY"
    self.stats.init_time = (os.clock() - start_time) * 1000
    self.stats.last_activity = os.time()
    
    Logger:info("模块初始化完成", {
        module = self.name,
        init_time_ms = self.stats.init_time
    })
    
    return true
end

-- 子类初始化方法 (子类重写)
function ModuleBase:onInitialize(save_data)
    -- 子类在这里实现具体的初始化逻辑
end

-- 模块关闭
function ModuleBase:shutdown()
    Logger:info("模块关闭开始", {module = self.name})
    
    -- 调用子类的关闭方法
    local success, error_msg = pcall(function()
        self:onShutdown()
    end)
    
    if not success then
        Logger:error("模块关闭失败", {
            module = self.name,
            error = error_msg
        })
    end
    
    -- 移除事件监听器
    self:unregisterEventListeners()
    
    -- 保存配置
    self:saveConfig()
    
    -- 更新状态
    self.status = "SHUTDOWN"
    
    Logger:info("模块关闭完成", {module = self.name})
end

-- 子类关闭方法 (子类重写)
function ModuleBase:onShutdown()
    -- 子类在这里实现具体的关闭逻辑
end

-- 检查依赖关系
function ModuleBase:checkDependencies()
    if not MainController then
        Logger:error("主控制器不可用", {module = self.name})
        return false
    end
    
    for _, dependency in ipairs(self.dependencies) do
        local module = MainController:getModule(dependency)
        if not module then
            Logger:error("依赖模块不存在", {
                module = self.name,
                missing_dependency = dependency
            })
            return false
        end
        
        if module:getStatus() ~= "READY" then
            Logger:error("依赖模块未就绪", {
                module = self.name,
                dependency = dependency,
                dependency_status = module:getStatus()
            })
            return false
        end
    end
    
    return true
end

-- 获取模块状态
function ModuleBase:getStatus()
    return self.status
end

-- 获取模块信息
function ModuleBase:getInfo()
    return {
        name = self.name,
        version = self.version,
        description = self.description,
        author = self.author,
        status = self.status,
        dependencies = self.dependencies,
        stats = self.stats
    }
end

-- 配置管理
function ModuleBase:loadConfig(save_data)
    if save_data and save_data.modules and save_data.modules[self.name] then
        local saved_config = save_data.modules[self.name].config
        if saved_config then
            -- 合并保存的配置和默认配置
            self.config = self:mergeConfigs(self.default_config, saved_config)
        end
    end
    
    Logger:debug("模块配置已加载", {module = self.name})
end

-- 保存配置
function ModuleBase:saveConfig()
    if MainController and MainController.saveModuleConfig then
        MainController:saveModuleConfig(self.name, self.config)
    end
end

-- 合并配置
function ModuleBase:mergeConfigs(default, saved)
    local merged = self:deepCopy(default)
    
    if saved and type(saved) == "table" then
        for key, value in pairs(saved) do
            if type(value) == "table" and type(merged[key]) == "table" then
                merged[key] = self:mergeConfigs(merged[key], value)
            else
                merged[key] = value
            end
        end
    end
    
    return merged
end

-- 获取配置值
function ModuleBase:getConfig(key)
    if key then
        return self:getNestedValue(self.config, key)
    else
        return self.config
    end
end

-- 设置配置值
function ModuleBase:setConfig(key, value)
    self:setNestedValue(self.config, key, value)
    self:saveConfig()
    
    -- 通知配置变更
    self:onConfigChanged(key, value)
end

-- 配置变更回调 (子类可重写)
function ModuleBase:onConfigChanged(key, value)
    Logger:debug("模块配置已更新", {
        module = self.name,
        key = key,
        value = tostring(value)
    })
end

-- 获取嵌套值
function ModuleBase:getNestedValue(table, key_path)
    local keys = {}
    for key in string.gmatch(key_path, "([^%.]+)") do
        table.insert(keys, key)
    end
    
    local current = table
    for _, key in ipairs(keys) do
        if type(current) == "table" and current[key] ~= nil then
            current = current[key]
        else
            return nil
        end
    end
    
    return current
end

-- 设置嵌套值
function ModuleBase:setNestedValue(table, key_path, value)
    local keys = {}
    for key in string.gmatch(key_path, "([^%.]+)") do
        table.insert(keys, key)
    end
    
    local current = table
    for i = 1, #keys - 1 do
        local key = keys[i]
        if type(current[key]) ~= "table" then
            current[key] = {}
        end
        current = current[key]
    end
    
    current[keys[#keys]] = value
end

-- 事件系统
function ModuleBase:addEventListener(event_type, callback)
    if not self.event_listeners[event_type] then
        self.event_listeners[event_type] = {}
    end
    
    table.insert(self.event_listeners[event_type], callback)
    
    -- 向全局事件管理器注册
    if EventManager then
        EventManager:addEventListener(event_type, self.name, callback)
    end
end

-- 移除事件监听器
function ModuleBase:removeEventListener(event_type)
    self.event_listeners[event_type] = nil
    
    if EventManager then
        EventManager:removeEventListener(event_type, self.name)
    end
end

-- 注册事件监听器 (子类重写)
function ModuleBase:registerEventListeners()
    -- 子类在这里注册需要的事件监听器
end

-- 移除事件监听器
function ModuleBase:unregisterEventListeners()
    for event_type, _ in pairs(self.event_listeners) do
        self:removeEventListener(event_type)
    end
    self.event_listeners = {}
end

-- 发送事件
function ModuleBase:emitEvent(event_type, event_data)
    if EventManager then
        EventManager:emitEvent(event_type, event_data, {source = self.name})
    end
end

-- 更新活动时间戳
function ModuleBase:updateActivity()
    self.stats.last_activity = os.time()
    self.stats.operations_count = self.stats.operations_count + 1
end

-- 报告错误
function ModuleBase:reportError(message, context)
    self.stats.errors_count = self.stats.errors_count + 1
    
    local error_context = context or {}
    error_context.module = self.name
    
    ErrorHandler:handle(ErrorHandler.error_codes.MODULE_LOAD_ERROR, message, error_context)
end

-- 健康检查
function ModuleBase:healthCheck()
    local health = {
        status = self.status,
        healthy = self.status == "READY",
        last_activity = self.stats.last_activity,
        errors_count = self.stats.errors_count,
        warnings = {}
    }
    
    -- 检查是否长时间无活动 (超过1小时)
    local inactive_time = os.time() - self.stats.last_activity
    if inactive_time > 3600 then
        table.insert(health.warnings, "长时间无活动 (" .. inactive_time .. "秒)")
    end
    
    -- 检查错误率
    if self.stats.errors_count > 10 then
        table.insert(health.warnings, "错误数量较高 (" .. self.stats.errors_count .. ")")
    end
    
    return health
end

-- 调试信息
function ModuleBase:getDebugInfo()
    return {
        name = self.name,
        version = self.version,
        status = self.status,
        dependencies = self.dependencies,
        config = self.config,
        stats = self.stats,
        event_listeners = {}  -- 不包含实际的回调函数，只返回事件类型
    }
end

-- 导出ModuleBase
_G.ModuleBase = ModuleBase
return ModuleBase 