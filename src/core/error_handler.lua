--[[
    错误处理系统 (ErrorHandler)
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    功能:
    - 统一错误处理和分类
    - 用户友好的错误提示
    - 自动恢复机制
    - 错误报告和分析
--]]

local ErrorHandler = {
    -- 错误级别定义
    error_levels = {
        DEBUG = 0,
        INFO = 1,
        WARNING = 2,
        ERROR = 3,
        FATAL = 4
    },
    
    -- 错误代码定义
    error_codes = {
        -- 系统错误
        SYSTEM_INIT_ERROR = 1001,
        MODULE_LOAD_ERROR = 1002,
        CONFIG_ERROR = 1003,
        
        -- 网络错误
        NETWORK_ERROR = 2001,
        LLM_API_ERROR = 2002,
        API_TIMEOUT_ERROR = 2003,
        
        -- 存储错误
        STORAGE_ERROR = 3001,
        SCRIPT_STATE_ERROR = 3002,
        DATA_CORRUPTION_ERROR = 3003,
        
        -- UI错误
        UI_ERROR = 4001,
        UI_RENDER_ERROR = 4002,
        UI_EVENT_ERROR = 4003,
        
        -- 用户错误
        USER_INPUT_ERROR = 5001,
        INVALID_COMMAND_ERROR = 5002,
        PERMISSION_ERROR = 5003
    },
    
    -- 注册的错误处理器
    error_handlers = {},
    
    -- 错误历史记录
    error_history = {},
    max_history_size = 50,
    
    -- 恢复策略
    recovery_strategies = {},
    
    -- 统计信息
    stats = {
        total_errors = 0,
        by_code = {},
        by_level = {},
        recovered_errors = 0
    }
}

-- 初始化错误处理系统
function ErrorHandler:initialize()
    -- 注册默认的错误处理器
    self:registerDefaultHandlers()
    
    -- 注册默认的恢复策略
    self:registerDefaultRecoveryStrategies()
    
    if Logger then
        Logger:info("错误处理系统初始化完成")
    end
end

-- 主要错误处理方法
function ErrorHandler:handle(error_code, message, context)
    context = context or {}
    
    -- 生成错误信息
    local error_info = {
        code = error_code,
        message = message,
        context = context,
        timestamp = os.time(),
        stack_trace = debug.traceback(),
        level = self:getErrorLevel(error_code),
        id = self:generateErrorId()
    }
    
    -- 更新统计
    self:updateStats(error_info)
    
    -- 记录到历史
    self:addToHistory(error_info)
    
    -- 记录日志
    self:logError(error_info)
    
    -- 执行错误处理器
    local handled = self:executeHandler(error_info)
    
    -- 尝试恢复
    if not handled then
        self:attemptRecovery(error_info)
    end
    
    -- 如果是致命错误，执行特殊处理
    if error_info.level == self.error_levels.FATAL then
        self:handleFatalError(error_info)
    end
    
    return error_info.id
end

-- 获取错误级别
function ErrorHandler:getErrorLevel(error_code)
    if error_code >= 1000 and error_code < 2000 then
        return self.error_levels.FATAL -- 系统错误
    elseif error_code >= 2000 and error_code < 3000 then
        return self.error_levels.ERROR -- 网络错误
    elseif error_code >= 3000 and error_code < 4000 then
        return self.error_levels.ERROR -- 存储错误
    elseif error_code >= 4000 and error_code < 5000 then
        return self.error_levels.WARNING -- UI错误
    elseif error_code >= 5000 and error_code < 6000 then
        return self.error_levels.INFO -- 用户错误
    else
        return self.error_levels.ERROR -- 默认
    end
end

-- 生成错误ID
function ErrorHandler:generateErrorId()
    return "ERR_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- 更新统计信息
function ErrorHandler:updateStats(error_info)
    self.stats.total_errors = self.stats.total_errors + 1
    
    -- 按代码统计
    self.stats.by_code[error_info.code] = (self.stats.by_code[error_info.code] or 0) + 1
    
    -- 按级别统计
    self.stats.by_level[error_info.level] = (self.stats.by_level[error_info.level] or 0) + 1
end

-- 添加到历史记录
function ErrorHandler:addToHistory(error_info)
    table.insert(self.error_history, error_info)
    
    -- 维护历史记录大小
    if #self.error_history > self.max_history_size then
        table.remove(self.error_history, 1)
    end
end

-- 记录错误日志
function ErrorHandler:logError(error_info)
    if not Logger then
        print("ERROR: " .. error_info.message)
        return
    end
    
    local level_name = self:getLevelName(error_info.level)
    Logger:log(error_info.level, error_info.message, {
        error_code = error_info.code,
        error_id = error_info.id,
        context = error_info.context
    })
end

-- 获取级别名称
function ErrorHandler:getLevelName(level)
    for name, value in pairs(self.error_levels) do
        if value == level then
            return name
        end
    end
    return "UNKNOWN"
end

-- 执行错误处理器
function ErrorHandler:executeHandler(error_info)
    local handler = self.error_handlers[error_info.code]
    if handler then
        local success, result = pcall(handler, error_info)
        if success then
            return result
        else
            if Logger then
                Logger:error("错误处理器执行失败", {
                    error_code = error_info.code,
                    handler_error = result
                })
            end
        end
    end
    
    -- 如果没有特定处理器，使用默认处理器
    return self:defaultErrorHandler(error_info)
end

-- 默认错误处理器
function ErrorHandler:defaultErrorHandler(error_info)
    local user_message = self:getUserFriendlyMessage(error_info.code, error_info.message)
    
    -- 显示用户友好的错误消息
    self:showErrorToUser(user_message, error_info)
    
    return true
end

-- 获取用户友好的错误消息
function ErrorHandler:getUserFriendlyMessage(error_code, original_message)
    local friendly_messages = {
        [self.error_codes.SYSTEM_INIT_ERROR] = "系统初始化失败，请重新加载Mod",
        [self.error_codes.MODULE_LOAD_ERROR] = "模块加载失败，请检查Mod完整性",
        [self.error_codes.NETWORK_ERROR] = "网络连接异常，请检查网络设置",
        [self.error_codes.LLM_API_ERROR] = "AI服务连接失败，请检查API配置",
        [self.error_codes.STORAGE_ERROR] = "数据保存失败，请检查存储空间",
        [self.error_codes.UI_ERROR] = "界面显示异常，正在尝试恢复",
        [self.error_codes.USER_INPUT_ERROR] = "输入格式错误，请检查命令格式",
        [self.error_codes.INVALID_COMMAND_ERROR] = "未知命令，输入 /tc help 查看帮助"
    }
    
    return friendly_messages[error_code] or ("发生未知错误: " .. original_message)
end

-- 显示错误给用户
function ErrorHandler:showErrorToUser(message, error_info)
    -- 在TTS聊天框显示错误
    broadcastToAll("[桌游伴侣] ❌ " .. message, {1, 0.3, 0.3})
    
    -- 如果错误级别较高，显示UI提示
    if error_info.level >= self.error_levels.ERROR then
        self:showErrorUI(message, error_info)
    end
end

-- 显示错误UI
function ErrorHandler:showErrorUI(message, error_info)
    local ui_xml = string.format([[
<Defaults>
    <Panel class="ErrorNotification" width="350" height="120" offsetXY="0 200"/>
</Defaults>
<Panel class="ErrorNotification" id="TabletopCompanionErrorNotification">
    <Text fontSize="14" color="#FF6B6B">桌游伴侣错误</Text>
    <Text fontSize="12" color="#FFFFFF">%s</Text>
    <Text fontSize="10" color="#CCCCCC">错误ID: %s</Text>
    <Button onClick="ErrorHandler.closeErrorNotification">关闭</Button>
</Panel>
]], message, error_info.id)
    
    UI.setXml(ui_xml)
    
    -- 5秒后自动关闭
    Wait.time(function()
        UI.setXml("")
    end, 5)
end

-- 关闭错误通知UI
function ErrorHandler.closeErrorNotification()
    UI.setXml("")
end

-- 尝试恢复
function ErrorHandler:attemptRecovery(error_info)
    local strategy = self.recovery_strategies[error_info.code]
    if strategy then
        local success, result = pcall(strategy, error_info)
        if success and result then
            self.stats.recovered_errors = self.stats.recovered_errors + 1
            if Logger then
                Logger:info("错误恢复成功", {
                    error_id = error_info.id,
                    error_code = error_info.code
                })
            end
            return true
        end
    end
    
    return false
end

-- 处理致命错误
function ErrorHandler:handleFatalError(error_info)
    if Logger then
        Logger:fatal("致命错误", {
            error_code = error_info.code,
            message = error_info.message,
            context = error_info.context
        })
    end
    
    -- 显示致命错误UI
    local ui_xml = string.format([[
<Defaults>
    <Panel class="FatalErrorPanel" width="450" height="250" offsetXY="0 0"/>
</Defaults>
<Panel class="FatalErrorPanel" id="TabletopCompanionFatalError">
    <Text fontSize="16" color="#FF0000">桌游伴侣致命错误</Text>
    <Text fontSize="12" color="#FFFFFF">%s</Text>
    <Text fontSize="10" color="#CCCCCC">错误代码: %d</Text>
    <Text fontSize="10" color="#CCCCCC">错误ID: %s</Text>
    <Button onClick="ErrorHandler.restartSystem">重启系统</Button>
    <Button onClick="ErrorHandler.closeFatalError">关闭</Button>
</Panel>
]], error_info.message, error_info.code, error_info.id)
    
    UI.setXml(ui_xml)
end

-- 重启系统
function ErrorHandler.restartSystem()
    UI.setXml("")
    
    if Logger then
        Logger:info("用户请求重启系统")
    end
    
    -- 尝试重新初始化主控制器
    if MainController then
        MainController:shutdown()
        Wait.time(function()
            MainController:initialize()
        end, 1)
    end
end

-- 关闭致命错误UI
function ErrorHandler.closeFatalError()
    UI.setXml("")
end

-- 注册错误处理器
function ErrorHandler:registerHandler(error_code, handler)
    self.error_handlers[error_code] = handler
    if Logger then
        Logger:debug("错误处理器已注册", {error_code = error_code})
    end
end

-- 注册恢复策略
function ErrorHandler:registerRecoveryStrategy(error_code, strategy)
    self.recovery_strategies[error_code] = strategy
    if Logger then
        Logger:debug("恢复策略已注册", {error_code = error_code})
    end
end

-- 注册默认处理器
function ErrorHandler:registerDefaultHandlers()
    -- UI错误处理器
    self:registerHandler(self.error_codes.UI_ERROR, function(error_info)
        -- 尝试重置UI
        UI.setXml("")
        return true
    end)
    
    -- 网络错误处理器
    self:registerHandler(self.error_codes.NETWORK_ERROR, function(error_info)
        broadcastToAll("[桌游伴侣] 网络连接异常，请稍后重试", {1, 0.8, 0})
        return true
    end)
end

-- 注册默认恢复策略
function ErrorHandler:registerDefaultRecoveryStrategies()
    -- UI错误恢复
    self:registerRecoveryStrategy(self.error_codes.UI_ERROR, function(error_info)
        -- 重新加载UI
        if MainController and MainController.reloadUI then
            return MainController:reloadUI()
        end
        return false
    end)
    
    -- 存储错误恢复
    self:registerRecoveryStrategy(self.error_codes.STORAGE_ERROR, function(error_info)
        -- 尝试清理损坏的数据
        if StorageManager and StorageManager.repairStorage then
            return StorageManager:repairStorage()
        end
        return false
    end)
end

-- 获取错误统计
function ErrorHandler:getStats()
    return {
        total_errors = self.stats.total_errors,
        recovered_errors = self.stats.recovered_errors,
        recovery_rate = self.stats.total_errors > 0 and 
                       (self.stats.recovered_errors / self.stats.total_errors * 100) or 0,
        by_code = self.stats.by_code,
        by_level = self.stats.by_level,
        recent_errors = #self.error_history
    }
end

-- 获取错误历史
function ErrorHandler:getErrorHistory(limit)
    limit = limit or 10
    local history = {}
    
    local start_index = math.max(1, #self.error_history - limit + 1)
    for i = start_index, #self.error_history do
        table.insert(history, self.error_history[i])
    end
    
    return history
end

-- 导出ErrorHandler模块
_G.ErrorHandler = ErrorHandler
return ErrorHandler 