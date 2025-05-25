--[[
    配置管理器 (ConfigManager)
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    功能:
    - 分层配置管理 (默认 → 用户 → 运行时)
    - 配置验证和类型检查
    - 配置变更通知
    - 配置导入导出
--]]

-- 基于ModuleBase创建ConfigManager
local ConfigManager = ModuleBase:new({
    name = "ConfigManager",
    version = "1.0.0",
    description = "桌游伴侣配置管理器",
    author = "LeadDeveloperAI",
    dependencies = {"StorageManager"},
    
    default_config = {
        auto_save_on_change = true,
        validation_enabled = true,
        backup_configs = true,
        max_backup_count = 5
    }
})

-- 配置层级定义
ConfigManager.CONFIG_LAYERS = {
    DEFAULT = 1,    -- 默认配置
    USER = 2,       -- 用户配置
    RUNTIME = 3     -- 运行时配置
}

-- 配置类型定义
ConfigManager.CONFIG_TYPES = {
    STRING = "string",
    NUMBER = "number",
    BOOLEAN = "boolean",
    TABLE = "table",
    ARRAY = "array",
    ENUM = "enum"
}

-- 配置状态
ConfigManager.config_layers = {}
ConfigManager.config_schemas = {}
ConfigManager.config_watchers = {}
ConfigManager.validation_rules = {}

-- 初始化方法
function ConfigManager:onInitialize(save_data)
    Logger:info("初始化配置管理器")
    
    -- 初始化配置层级
    self:initializeConfigLayers()
    
    -- 加载配置模式
    self:loadConfigSchemas()
    
    -- 加载保存的配置
    self:loadSavedConfigs(save_data)
    
    -- 注册默认验证规则
    self:registerDefaultValidationRules()
    
    -- 设置事件监听器
    self:setupEventListeners()
    
    Logger:info("配置管理器初始化完成", {
        schemas_count = self:getSchemaCount(),
        layers_count = #self.config_layers
    })
end

-- 初始化配置层级
function ConfigManager:initializeConfigLayers()
    self.config_layers = {
        [self.CONFIG_LAYERS.DEFAULT] = {},
        [self.CONFIG_LAYERS.USER] = {},
        [self.CONFIG_LAYERS.RUNTIME] = {}
    }
    
    self.config_watchers = {}
    
    Logger:debug("配置层级已初始化")
end

-- 加载配置模式
function ConfigManager:loadConfigSchemas()
    -- 为每个核心模块定义配置模式
    self.config_schemas = {
        -- 系统配置模式
        ["system"] = {
            log_level = {
                type = self.CONFIG_TYPES.ENUM,
                values = {"DEBUG", "INFO", "WARNING", "ERROR", "FATAL"},
                default = "INFO",
                description = "系统日志级别"
            },
            auto_save_interval = {
                type = self.CONFIG_TYPES.NUMBER,
                min = 60,
                max = 3600,
                default = 300,
                description = "自动保存间隔(秒)"
            },
            max_error_count = {
                type = self.CONFIG_TYPES.NUMBER,
                min = 10,
                max = 1000,
                default = 50,
                description = "最大错误计数"
            }
        },
        
        -- UI配置模式
        ["ui"] = {
            theme = {
                type = self.CONFIG_TYPES.ENUM,
                values = {"default", "dark", "light"},
                default = "default",
                description = "UI主题"
            },
            position = {
                type = self.CONFIG_TYPES.TABLE,
                schema = {
                    x = {type = self.CONFIG_TYPES.NUMBER, default = 100},
                    y = {type = self.CONFIG_TYPES.NUMBER, default = 100}
                },
                default = {x = 100, y = 100},
                description = "UI位置"
            },
            size = {
                type = self.CONFIG_TYPES.TABLE,
                schema = {
                    width = {type = self.CONFIG_TYPES.NUMBER, default = 400},
                    height = {type = self.CONFIG_TYPES.NUMBER, default = 600}
                },
                default = {width = 400, height = 600},
                description = "UI大小"
            },
            auto_hide = {
                type = self.CONFIG_TYPES.BOOLEAN,
                default = false,
                description = "自动隐藏UI"
            }
        },
        
        -- 调试配置模式
        ["debug"] = {
            enabled = {
                type = self.CONFIG_TYPES.BOOLEAN,
                default = false,
                description = "启用调试模式"
            },
            verbose_logging = {
                type = self.CONFIG_TYPES.BOOLEAN,
                default = false,
                description = "详细日志记录"
            },
            performance_monitoring = {
                type = self.CONFIG_TYPES.BOOLEAN,
                default = true,
                description = "性能监控"
            }
        },
        
        -- 存储配置模式
        ["storage"] = {
            compression_enabled = {
                type = self.CONFIG_TYPES.BOOLEAN,
                default = true,
                description = "启用数据压缩"
            },
            max_storage_size = {
                type = self.CONFIG_TYPES.NUMBER,
                min = 50000,
                max = 200000,
                default = 98304,
                description = "最大存储大小(字节)"
            },
            auto_save_interval = {
                type = self.CONFIG_TYPES.NUMBER,
                min = 60,
                max = 1800,
                default = 300,
                description = "自动保存间隔(秒)"
            }
        }
    }
    
    Logger:debug("配置模式已加载", {count = self:getSchemaCount()})
end

-- 加载保存的配置
function ConfigManager:loadSavedConfigs(save_data)
    if not save_data or not save_data.configs then
        Logger:info("未找到保存的配置，使用默认配置")
        self:loadDefaultConfigs()
        return
    end
    
    -- 加载用户配置
    if save_data.configs.user then
        self.config_layers[self.CONFIG_LAYERS.USER] = save_data.configs.user
        Logger:info("已加载用户配置")
    end
    
    -- 加载运行时配置（如果有）
    if save_data.configs.runtime then
        self.config_layers[self.CONFIG_LAYERS.RUNTIME] = save_data.configs.runtime
        Logger:info("已加载运行时配置")
    end
    
    -- 确保所有默认配置都已设置
    self:loadDefaultConfigs()
end

-- 加载默认配置
function ConfigManager:loadDefaultConfigs()
    for module_name, schema in pairs(self.config_schemas) do
        if not self.config_layers[self.CONFIG_LAYERS.DEFAULT][module_name] then
            self.config_layers[self.CONFIG_LAYERS.DEFAULT][module_name] = {}
        end
        
        for key, config_def in pairs(schema) do
            if config_def.default ~= nil then
                self.config_layers[self.CONFIG_LAYERS.DEFAULT][module_name][key] = config_def.default
            end
        end
    end
    
    Logger:debug("默认配置已加载")
end

-- 获取配置值
function ConfigManager:getConfig(module_name, key, default_value)
    if not module_name then
        Logger:error("获取配置时模块名为空")
        return default_value
    end
    
    -- 按优先级查找配置值：运行时 → 用户 → 默认
    for layer = self.CONFIG_LAYERS.RUNTIME, self.CONFIG_LAYERS.DEFAULT, -1 do
        local layer_data = self.config_layers[layer]
        if layer_data and layer_data[module_name] and layer_data[module_name][key] ~= nil then
            local value = layer_data[module_name][key]
            Logger:debug("配置值已找到", {
                module = module_name,
                key = key,
                layer = layer,
                value_type = type(value)
            })
            return value
        end
    end
    
    Logger:debug("配置值未找到，使用默认值", {
        module = module_name,
        key = key,
        default = default_value
    })
    
    return default_value
end

-- 设置配置值
function ConfigManager:setConfig(module_name, key, value, layer)
    layer = layer or self.CONFIG_LAYERS.USER
    
    if not module_name or not key then
        Logger:error("设置配置参数无效", {module = module_name, key = key})
        return false
    end
    
    -- 验证配置值
    if self.config.validation_enabled then
        local valid, error_msg = self:validateConfig(module_name, key, value)
        if not valid then
            Logger:error("配置验证失败", {
                module = module_name,
                key = key,
                value = value,
                error = error_msg
            })
            return false
        end
    end
    
    -- 确保层级和模块存在
    if not self.config_layers[layer] then
        self.config_layers[layer] = {}
    end
    if not self.config_layers[layer][module_name] then
        self.config_layers[layer][module_name] = {}
    end
    
    -- 记录旧值
    local old_value = self:getConfig(module_name, key)
    
    -- 设置新值
    self.config_layers[layer][module_name][key] = value
    
    Logger:info("配置已更新", {
        module = module_name,
        key = key,
        old_value = old_value,
        new_value = value,
        layer = layer
    })
    
    -- 触发变更事件
    self:emitConfigChange(module_name, key, old_value, value)
    
    -- 自动保存（如果启用）
    if self.config.auto_save_on_change then
        self:saveConfigs()
    end
    
    return true
end

-- 获取模块的完整配置
function ConfigManager:getModuleConfig(module_name)
    if not module_name then
        Logger:error("获取模块配置时模块名为空")
        return {}
    end
    
    local config = {}
    
    -- 获取该模块的所有配置键
    local all_keys = {}
    for layer = self.CONFIG_LAYERS.DEFAULT, self.CONFIG_LAYERS.RUNTIME do
        local layer_data = self.config_layers[layer]
        if layer_data and layer_data[module_name] then
            for key, _ in pairs(layer_data[module_name]) do
                all_keys[key] = true
            end
        end
    end
    
    -- 按优先级构建配置
    for key, _ in pairs(all_keys) do
        config[key] = self:getConfig(module_name, key)
    end
    
    return config
end

-- 重置模块配置
function ConfigManager:resetModuleConfig(module_name, layer)
    layer = layer or self.CONFIG_LAYERS.USER
    
    if not module_name then
        Logger:error("重置配置时模块名为空")
        return false
    end
    
    if self.config_layers[layer] and self.config_layers[layer][module_name] then
        local old_config = self.config_layers[layer][module_name]
        self.config_layers[layer][module_name] = {}
        
        Logger:info("模块配置已重置", {
            module = module_name,
            layer = layer,
            reset_keys = self:getTableKeys(old_config)
        })
        
        -- 触发重置事件
        self:emitEvent("config_reset", {
            module = module_name,
            layer = layer,
            old_config = old_config
        })
        
        return true
    end
    
    return false
end

-- 合并多个配置对象
function ConfigManager:mergeConfigs(...)
    local configs = {...}
    local merged = {}
    
    for _, config in ipairs(configs) do
        if type(config) == "table" then
            for key, value in pairs(config) do
                if type(value) == "table" and type(merged[key]) == "table" then
                    merged[key] = self:mergeConfigs(merged[key], value)
                else
                    merged[key] = value
                end
            end
        end
    end
    
    return merged
end

-- 验证配置值
function ConfigManager:validateConfig(module_name, key, value)
    -- 检查模式是否存在
    local schema = self.config_schemas[module_name]
    if not schema or not schema[key] then
        -- 如果没有定义模式，允许任何值
        return true, nil
    end
    
    local config_def = schema[key]
    
    -- 类型检查
    if config_def.type then
        local value_type = type(value)
        
        if config_def.type == self.CONFIG_TYPES.ARRAY then
            if value_type ~= "table" then
                return false, "期望数组类型，得到 " .. value_type
            end
        elseif config_def.type ~= value_type then
            return false, "期望类型 " .. config_def.type .. "，得到 " .. value_type
        end
    end
    
    -- 枚举值检查
    if config_def.type == self.CONFIG_TYPES.ENUM and config_def.values then
        local valid = false
        for _, valid_value in ipairs(config_def.values) do
            if value == valid_value then
                valid = true
                break
            end
        end
        if not valid then
            return false, "值必须是以下之一：" .. table.concat(config_def.values, ", ")
        end
    end
    
    -- 数值范围检查
    if config_def.type == self.CONFIG_TYPES.NUMBER then
        if config_def.min and value < config_def.min then
            return false, "值不能小于 " .. config_def.min
        end
        if config_def.max and value > config_def.max then
            return false, "值不能大于 " .. config_def.max
        end
    end
    
    -- 表结构检查
    if config_def.type == self.CONFIG_TYPES.TABLE and config_def.schema then
        for sub_key, sub_config in pairs(config_def.schema) do
            if value[sub_key] ~= nil then
                local valid, error_msg = self:validateConfigValue(sub_config, value[sub_key])
                if not valid then
                    return false, "字段 " .. sub_key .. ": " .. error_msg
                end
            end
        end
    end
    
    return true, nil
end

-- 验证单个配置值
function ConfigManager:validateConfigValue(config_def, value)
    local value_type = type(value)
    
    if config_def.type and config_def.type ~= value_type then
        return false, "期望类型 " .. config_def.type .. "，得到 " .. value_type
    end
    
    if config_def.min and value < config_def.min then
        return false, "值不能小于 " .. config_def.min
    end
    
    if config_def.max and value > config_def.max then
        return false, "值不能大于 " .. config_def.max
    end
    
    return true, nil
end

-- 注册配置变更监听器
function ConfigManager:watchConfig(module_name, key, callback)
    if not module_name or not callback then
        Logger:error("注册配置监听器参数无效")
        return false
    end
    
    local watch_key = module_name .. ":" .. (key or "*")
    
    if not self.config_watchers[watch_key] then
        self.config_watchers[watch_key] = {}
    end
    
    table.insert(self.config_watchers[watch_key], callback)
    
    Logger:debug("配置监听器已注册", {watch_key = watch_key})
    
    return true
end

-- 触发配置变更事件
function ConfigManager:emitConfigChange(module_name, key, old_value, new_value)
    -- 触发具体键的监听器
    local specific_key = module_name .. ":" .. key
    if self.config_watchers[specific_key] then
        for _, callback in ipairs(self.config_watchers[specific_key]) do
            local success, error_msg = pcall(callback, module_name, key, old_value, new_value)
            if not success then
                Logger:error("配置监听器执行失败", {
                    watch_key = specific_key,
                    error = error_msg
                })
            end
        end
    end
    
    -- 触发模块级监听器
    local module_key = module_name .. ":*"
    if self.config_watchers[module_key] then
        for _, callback in ipairs(self.config_watchers[module_key]) do
            local success, error_msg = pcall(callback, module_name, key, old_value, new_value)
            if not success then
                Logger:error("模块配置监听器执行失败", {
                    watch_key = module_key,
                    error = error_msg
                })
            end
        end
    end
    
    -- 触发系统配置变更事件
    self:emitEvent("config_changed", {
        module = module_name,
        key = key,
        old_value = old_value,
        new_value = new_value
    })
end

-- 保存配置
function ConfigManager:saveConfigs()
    local storage_manager = self:getModule("StorageManager")
    if not storage_manager then
        Logger:error("无法保存配置：StorageManager不可用")
        return false
    end
    
    local config_data = {
        user = self.config_layers[self.CONFIG_LAYERS.USER],
        runtime = self.config_layers[self.CONFIG_LAYERS.RUNTIME],
        timestamp = os.time()
    }
    
    local success = storage_manager:saveData(
        storage_manager.DATA_CATEGORIES.SYSTEM_CONFIG,
        "configs",
        config_data
    )
    
    if success then
        Logger:info("配置已保存")
    else
        Logger:error("配置保存失败")
    end
    
    return success
end

-- 注册默认验证规则
function ConfigManager:registerDefaultValidationRules()
    -- 这里可以添加自定义验证规则
    self.validation_rules = {}
    
    Logger:debug("默认验证规则已注册")
end

-- 设置事件监听器
function ConfigManager:setupEventListeners()
    -- 监听存储管理器的自动保存事件
    self:addEventListener("storage_auto_save", function(event_data)
        Logger:debug("收到存储自动保存事件")
    end)
end

-- 获取模式数量
function ConfigManager:getSchemaCount()
    local count = 0
    for _, _ in pairs(self.config_schemas) do
        count = count + 1
    end
    return count
end

-- 获取表的键列表
function ConfigManager:getTableKeys(tbl)
    local keys = {}
    if type(tbl) == "table" then
        for key, _ in pairs(tbl) do
            table.insert(keys, key)
        end
    end
    return keys
end

-- 获取保存数据
function ConfigManager:getSaveData()
    return {
        configs = {
            user = self.config_layers[self.CONFIG_LAYERS.USER],
            runtime = self.config_layers[self.CONFIG_LAYERS.RUNTIME]
        },
        schemas = self.config_schemas,
        version = self.version
    }
end

-- 子类关闭方法
function ConfigManager:onShutdown()
    Logger:info("配置管理器开始关闭")
    
    -- 保存配置
    self:saveConfigs()
    
    -- 清理监听器
    self.config_watchers = {}
    
    Logger:info("配置管理器关闭完成")
end

-- 导出ConfigManager模块
return ConfigManager 