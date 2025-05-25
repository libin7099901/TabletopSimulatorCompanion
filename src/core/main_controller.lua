--[[
    主控制器 (MainController)
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    功能:
    - 系统初始化和生命周期管理
    - 模块注册和协调
    - 配置和数据持久化
    - 事件分发和处理
--]]

local MainController = {
    -- 系统状态
    system_state = "UNINITIALIZED", -- UNINITIALIZED, INITIALIZING, READY, ERROR, SHUTDOWN
    version = "1.0.0",
    
    -- 模块注册表
    modules = {},
    module_init_order = {}, -- 模块初始化顺序
    
    -- 系统配置
    config = {
        system = {
            log_level = "INFO",
            auto_save_interval = 300, -- 5分钟
            max_error_count = 50
        },
        ui = {
            theme = "default",
            position = {x = 100, y = 100},
            size = {width = 400, height = 600},
            auto_hide = false
        },
        debug = {
            enabled = false,
            verbose_logging = false,
            performance_monitoring = true
        }
    },
    
    -- 数据存储
    save_data = {
        system_config = {},
        modules = {},
        user_data = {},
        timestamp = 0
    },
    
    -- 事件系统
    event_handlers = {},
    
    -- 统计信息
    stats = {
        init_time = 0,
        uptime = 0,
        modules_loaded = 0,
        errors_handled = 0,
        events_processed = 0
    },
    
    -- 初始化标记
    initialized = false
}

-- 初始化主控制器
function MainController:initialize(saved_data)
    self.system_state = "INITIALIZING"
    local start_time = os.clock()
    
    print("[主控制器] 开始初始化...")
    
    -- 初始化核心组件
    self:initializeCoreComponents()
    
    -- 加载保存的数据
    self:loadSaveData(saved_data)
    
    -- 应用系统配置
    self:applySystemConfig()
    
    -- 初始化错误处理系统
    if ErrorHandler then
        ErrorHandler:initialize()
    end
    
    -- 注册核心事件处理器
    self:registerCoreEventHandlers()
    
    -- 初始化已注册的模块
    self:initializeModules()
    
    -- 创建和显示UI
    self:initializeUI()
    
    -- 启动系统监控
    self:startSystemMonitoring()
    
    -- 更新状态和统计
    self.system_state = "READY"
    self.initialized = true
    self.stats.init_time = (os.clock() - start_time) * 1000
    self.stats.uptime = os.time()
    
    Logger:info("主控制器初始化完成", {
        init_time_ms = self.stats.init_time,
        modules_count = #self.module_init_order
    })
    
    return true
end

-- 初始化核心组件
function MainController:initializeCoreComponents()
    -- 确保Logger可用
    if not Logger then
        print("[主控制器] 警告: Logger未初始化，使用基础日志功能")
    else
        Logger:info("主控制器核心组件初始化")
    end
    
    -- 设置全局引用
    _G.MainController = self
end

-- 加载保存的数据
function MainController:loadSaveData(saved_data)
    if saved_data and type(saved_data) == "string" then
        local success, data = pcall(JSON.decode, saved_data)
        if success and data then
            self.save_data = data
            Logger:info("保存数据已加载", {timestamp = data.timestamp or 0})
        else
            Logger:warning("保存数据解析失败，使用默认配置")
        end
    else
        Logger:info("未找到保存数据，使用默认配置")
    end
    
    -- 合并配置
    if self.save_data.system_config then
        self:mergeConfig(self.config, self.save_data.system_config)
    end
end

-- 应用系统配置
function MainController:applySystemConfig()
    -- 设置日志级别
    if Logger and self.config.system.log_level then
        Logger:setLevel(self.config.system.log_level)
    end
    
    -- 应用调试配置
    if self.config.debug.enabled then
        Logger:info("调试模式已启用", {
            verbose_logging = self.config.debug.verbose_logging,
            performance_monitoring = self.config.debug.performance_monitoring
        })
    end
end

-- 注册核心事件处理器
function MainController:registerCoreEventHandlers()
    -- 系统事件
    self:addEventListener("system_error", function(event_data)
        self:handleSystemError(event_data)
    end)
    
    self:addEventListener("module_error", function(event_data)
        self:handleModuleError(event_data)
    end)
    
    self:addEventListener("config_changed", function(event_data)
        self:handleConfigChanged(event_data)
    end)
    
    Logger:debug("核心事件处理器已注册")
end

-- 模块注册
function MainController:registerModule(name, module)
    if self.modules[name] then
        Logger:warning("模块已存在，将被覆盖", {module = name})
    end
    
    self.modules[name] = module
    table.insert(self.module_init_order, name)
    
    Logger:info("模块已注册", {module = name, total_modules = #self.module_init_order})
    
    -- 如果系统已初始化，立即初始化新模块
    if self.system_state == "READY" then
        self:initializeModule(name)
    end
end

-- 获取模块
function MainController:getModule(name)
    return self.modules[name]
end

-- 初始化所有模块
function MainController:initializeModules()
    Logger:info("开始初始化模块", {count = #self.module_init_order})
    
    for _, module_name in ipairs(self.module_init_order) do
        self:initializeModule(module_name)
    end
    
    self.stats.modules_loaded = #self.module_init_order
    Logger:info("模块初始化完成", {loaded = self.stats.modules_loaded})
end

-- 初始化单个模块
function MainController:initializeModule(module_name)
    local module = self.modules[module_name]
    if not module then
        Logger:error("模块不存在", {module = module_name})
        return false
    end
    
    Logger:debug("初始化模块", {module = module_name})
    
    local success, error_msg = pcall(function()
        if module.initialize then
            return module:initialize(self.save_data)
        else
            Logger:warning("模块缺少initialize方法", {module = module_name})
            return true
        end
    end)
    
    if not success then
        Logger:error("模块初始化失败", {
            module = module_name,
            error = error_msg
        })
        return false
    end
    
    return true
end

-- 初始化UI
function MainController:initializeUI()
    Logger:info("初始化用户界面")
    
    -- 创建主UI面板
    self:createMainUI()
    
    -- 如果有UI管理器模块，初始化它
    local ui_manager = self:getModule("UIManager")
    if ui_manager then
        ui_manager:initializeMainPanel(self.config.ui)
    end
end

-- 创建主UI
function MainController:createMainUI()
    local ui_xml = string.format([[
<Defaults>
    <Panel class="MainPanel" 
           width="%d" height="%d"
           offsetXY="%d %d"
           allowDragging="true"
           returnToOriginalPositionWhenReleased="false"/>
</Defaults>
<Panel class="MainPanel" id="TabletopCompanionMain">
    <Text fontSize="16" color="#FFFFFF">桌游伴侣 v%s</Text>
    <Text fontSize="12" color="#CCCCCC">状态: %s</Text>
    <Button onClick="MainController.showMenu">菜单</Button>
    <Button onClick="MainController.showStatus">状态</Button>
    <Button onClick="MainController.showHelp">帮助</Button>
</Panel>
]], 
    self.config.ui.size.width, 
    self.config.ui.size.height,
    self.config.ui.position.x, 
    self.config.ui.position.y,
    self.version,
    self.system_state
)
    
    UI.setXml(ui_xml)
    Logger:debug("主UI已创建")
end

-- UI事件处理器
function MainController.showMenu()
    if MainController.initialized then
        Logger:info("显示主菜单")
        -- TODO: 实现菜单显示逻辑
        broadcastToAll("[桌游伴侣] 菜单功能开发中...", {0.8, 0.8, 0.8})
    end
end

function MainController.showStatus()
    if MainController.initialized then
        Logger:info("显示系统状态")
        local status = MainController:getSystemStatus()
        local message = string.format("状态: %s | 模块: %d | 运行时间: %d秒", 
                                     status.state, status.modules_count, status.uptime)
        broadcastToAll("[桌游伴侣] " .. message, {0.3, 0.8, 0.3})
    end
end

function MainController.showHelp()
    if MainController.initialized then
        Logger:info("显示帮助信息")
        broadcastToAll("[桌游伴侣] 帮助: 输入 /tc help 查看命令列表", {0.3, 0.3, 0.8})
    end
end

-- 聊天命令处理
function MainController:handleChatCommand(message, player)
    Logger:debug("处理聊天命令", {message = message, player = player.steam_name})
    
    local command_parts = {}
    for part in string.gmatch(message, "([^%s]+)") do
        table.insert(command_parts, part)
    end
    
    if #command_parts < 2 then
        self:sendHelpMessage(player)
        return
    end
    
    local command = command_parts[2]:lower()
    
    if command == "help" then
        self:sendHelpMessage(player)
    elseif command == "status" then
        self:sendStatusMessage(player)
    elseif command == "debug" then
        self:handleDebugCommand(command_parts, player)
    elseif command == "reload" then
        self:handleReloadCommand(player)
    else
        player.print("[桌游伴侣] 未知命令: " .. command .. ". 输入 /tc help 查看帮助")
    end
end

-- 发送帮助消息
function MainController:sendHelpMessage(player)
    local help_text = [[
[桌游伴侣] 可用命令:
/tc help - 显示此帮助信息
/tc status - 显示系统状态
/tc debug on/off - 开启/关闭调试模式
/tc reload - 重新加载系统
]]
    player.print(help_text)
end

-- 发送状态消息
function MainController:sendStatusMessage(player)
    local status = self:getSystemStatus()
    local status_text = string.format([[
[桌游伴侣] 系统状态:
- 版本: %s
- 状态: %s
- 已加载模块: %d
- 运行时间: %d秒
- 处理错误数: %d
]], status.version, status.state, status.modules_count, status.uptime, status.errors_handled)
    
    player.print(status_text)
end

-- 处理调试命令
function MainController:handleDebugCommand(command_parts, player)
    if #command_parts < 3 then
        player.print("[桌游伴侣] 用法: /tc debug on|off")
        return
    end
    
    local action = command_parts[3]:lower()
    if action == "on" then
        self.config.debug.enabled = true
        Logger:setLevel("DEBUG")
        player.print("[桌游伴侣] 调试模式已开启")
        Logger:debug("调试模式已开启", {player = player.steam_name})
    elseif action == "off" then
        self.config.debug.enabled = false
        Logger:setLevel("INFO")
        player.print("[桌游伴侣] 调试模式已关闭")
        Logger:info("调试模式已关闭", {player = player.steam_name})
    else
        player.print("[桌游伴侣] 无效参数: " .. action .. ". 使用 on 或 off")
    end
end

-- 处理重载命令
function MainController:handleReloadCommand(player)
    player.print("[桌游伴侣] 正在重新加载系统...")
    Logger:info("用户请求系统重载", {player = player.steam_name})
    
    -- 重新初始化
    self:shutdown()
    Wait.time(function()
        self:initialize()
        player.print("[桌游伴侣] 系统重载完成")
    end, 1)
end

-- 启动系统监控
function MainController:startSystemMonitoring()
    -- 定期自动保存
    if self.config.system.auto_save_interval > 0 then
        self:startAutoSave()
    end
    
    -- 性能监控
    if self.config.debug.performance_monitoring then
        self:startPerformanceMonitoring()
    end
    
    Logger:debug("系统监控已启动")
end

-- 启动自动保存
function MainController:startAutoSave()
    local function autoSave()
        if self.system_state == "READY" then
            self:saveCurrentState()
            Logger:debug("自动保存完成")
        end
        
        -- 安排下次自动保存
        Wait.time(autoSave, self.config.system.auto_save_interval)
    end
    
    Wait.time(autoSave, self.config.system.auto_save_interval)
end

-- 启动性能监控
function MainController:startPerformanceMonitoring()
    local function performanceCheck()
        local current_time = os.time()
        self.stats.uptime = current_time - self.stats.uptime
        
        -- 记录性能统计
        Logger:debug("性能统计", {
            uptime = self.stats.uptime,
            modules_loaded = self.stats.modules_loaded,
            errors_handled = self.stats.errors_handled,
            events_processed = self.stats.events_processed
        })
        
        -- 每5分钟检查一次
        Wait.time(performanceCheck, 300)
    end
    
    Wait.time(performanceCheck, 300)
end

-- 获取系统状态
function MainController:getSystemStatus()
    return {
        version = self.version,
        state = self.system_state,
        modules_count = #self.module_init_order,
        uptime = os.time() - self.stats.uptime,
        errors_handled = self.stats.errors_handled,
        events_processed = self.stats.events_processed,
        initialized = self.initialized
    }
end

-- 保存当前状态
function MainController:saveCurrentState()
    self.save_data.timestamp = os.time()
    self.save_data.system_config = self.config
    
    -- 收集模块数据
    for name, module in pairs(self.modules) do
        if module.getSaveData then
            self.save_data.modules[name] = module:getSaveData()
        end
    end
end

-- 获取保存数据
function MainController:getSaveData()
    self:saveCurrentState()
    return self.save_data
end

-- 系统关闭
function MainController:shutdown()
    if self.system_state == "SHUTDOWN" then
        return
    end
    
    Logger:info("主控制器开始关闭")
    self.system_state = "SHUTDOWN"
    
    -- 关闭所有模块
    for _, module_name in ipairs(self.module_init_order) do
        local module = self.modules[module_name]
        if module and module.shutdown then
            local success, error_msg = pcall(module.shutdown, module)
            if not success then
                Logger:error("模块关闭失败", {
                    module = module_name,
                    error = error_msg
                })
            end
        end
    end
    
    -- 保存当前状态
    self:saveCurrentState()
    
    -- 清理UI
    UI.setXml("")
    
    Logger:info("主控制器关闭完成")
end

-- 事件系统
function MainController:addEventListener(event_type, handler)
    if not self.event_handlers[event_type] then
        self.event_handlers[event_type] = {}
    end
    table.insert(self.event_handlers[event_type], handler)
end

function MainController:removeEventListener(event_type, handler)
    if self.event_handlers[event_type] then
        for i, h in ipairs(self.event_handlers[event_type]) do
            if h == handler then
                table.remove(self.event_handlers[event_type], i)
                break
            end
        end
    end
end

function MainController:emitEvent(event_type, event_data)
    if self.event_handlers[event_type] then
        for _, handler in ipairs(self.event_handlers[event_type]) do
            local success, error_msg = pcall(handler, event_data)
            if not success then
                Logger:error("事件处理器执行失败", {
                    event_type = event_type,
                    error = error_msg
                })
            end
        end
    end
    
    self.stats.events_processed = self.stats.events_processed + 1
end

-- 错误处理
function MainController:handleSystemError(event_data)
    self.stats.errors_handled = self.stats.errors_handled + 1
    Logger:error("系统错误", event_data)
end

function MainController:handleModuleError(event_data)
    self.stats.errors_handled = self.stats.errors_handled + 1
    Logger:error("模块错误", event_data)
end

function MainController:handleConfigChanged(event_data)
    Logger:info("配置已变更", event_data)
    self:applySystemConfig()
end

-- 配置管理
function MainController:mergeConfig(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            self:mergeConfig(target[key], value)
        else
            target[key] = value
        end
    end
end

function MainController:saveModuleConfig(module_name, config)
    self.save_data.modules[module_name] = self.save_data.modules[module_name] or {}
    self.save_data.modules[module_name].config = config
end

-- 对象交互处理
function MainController:handleObjectDrop(player_color, dropped_object)
    Logger:debug("对象放置事件", {
        player = player_color,
        object = dropped_object.getName()
    })
    
    self:emitEvent("object_dropped", {
        player_color = player_color,
        object = dropped_object
    })
end

-- 玩家连接处理
function MainController:handlePlayerConnect(player)
    Logger:info("玩家加入", {player = player.steam_name})
    
    self:emitEvent("player_connected", {player = player})
    
    -- 向新玩家发送欢迎消息
    player.print("[桌游伴侣] 欢迎！输入 /tc help 查看可用命令")
end

-- UI重新加载
function MainController:reloadUI()
    Logger:info("重新加载UI")
    
    local success, error_msg = pcall(function()
        self:createMainUI()
    end)
    
    if not success then
        Logger:error("UI重新加载失败", {error = error_msg})
        return false
    end
    
    return true
end

-- 导出MainController模块
_G.MainController = MainController
return MainController 