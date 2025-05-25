--[[
    桌游伴侣默认配置文件
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    说明:
    本文件定义了桌游伴侣所有模块的默认配置。
    用户可以通过UI或配置文件覆盖这些默认值。
--]]

local DefaultConfigs = {
    -- 版本信息
    version = "1.0.0",
    created_time = "2025-01-27",
    
    -- 系统配置
    system = {
        -- 日志系统配置
        log_level = "INFO",                    -- 日志级别 (DEBUG, INFO, WARNING, ERROR, FATAL)
        max_log_entries = 1000,                -- 最大日志条目数
        log_rotation_enabled = true,           -- 启用日志轮转
        
        -- 性能配置
        performance_monitoring = true,         -- 启用性能监控
        max_memory_usage_mb = 50,              -- 最大内存使用量 (MB)
        gc_interval = 300,                     -- 垃圾回收间隔 (秒)
        
        -- 错误处理配置
        max_error_count = 50,                  -- 最大错误计数
        error_recovery_enabled = true,         -- 启用错误恢复
        auto_restart_on_critical_error = false, -- 严重错误时自动重启
        
        -- 自动保存配置
        auto_save_interval = 300,              -- 自动保存间隔 (5分钟)
        backup_count = 3,                      -- 备份文件数量
        
        -- 网络配置
        network_timeout = 30,                  -- 网络超时时间 (秒)
        max_concurrent_requests = 3,           -- 最大并发请求数
        retry_attempts = 3,                    -- 重试次数
        retry_delay = 2                        -- 重试延迟 (秒)
    },
    
    -- UI配置
    ui = {
        -- 主题配置
        theme = "default",                     -- UI主题 (default, dark, light)
        font_size = 14,                        -- 字体大小
        color_scheme = "blue",                 -- 配色方案
        
        -- 窗口配置
        position = {
            x = 100,                           -- 窗口X位置
            y = 100                            -- 窗口Y位置
        },
        size = {
            width = 400,                       -- 窗口宽度
            height = 600                       -- 窗口高度
        },
        
        -- 交互配置
        auto_hide = false,                     -- 自动隐藏UI
        always_on_top = false,                 -- 总在最前
        transparency = 0.95,                   -- 透明度
        animation_enabled = true,              -- 启用动画效果
        
        -- 显示配置
        show_tooltips = true,                  -- 显示工具提示
        show_shortcuts = true,                 -- 显示快捷键提示
        compact_mode = false,                  -- 紧凑模式
        status_bar_enabled = true              -- 显示状态栏
    },
    
    -- 存储配置
    storage = {
        -- 基础存储配置
        compression_enabled = true,            -- 启用数据压缩
        max_storage_size = 98304,              -- 最大存储大小 (96KB)
        storage_encryption = false,            -- 存储加密 (TTS限制暂不启用)
        
        -- 自动保存配置
        auto_save_interval = 300,              -- 自动保存间隔 (秒)
        auto_save_enabled = true,              -- 启用自动保存
        save_on_exit = true,                   -- 退出时保存
        
        -- 备份配置
        backup_enabled = true,                 -- 启用备份
        max_backup_count = 5,                  -- 最大备份数量
        backup_interval = 1800,                -- 备份间隔 (30分钟)
        
        -- 清理配置
        auto_cleanup_enabled = true,           -- 启用自动清理
        cleanup_interval = 3600,               -- 清理间隔 (1小时)
        max_age_days = 30                      -- 数据最大保存天数
    },
    
    -- 配置管理器配置
    config = {
        -- 配置验证
        validation_enabled = true,             -- 启用配置验证
        strict_validation = false,             -- 严格验证模式
        
        -- 配置保存
        auto_save_on_change = true,            -- 配置变更时自动保存
        save_immediately = false,              -- 立即保存配置
        
        -- 配置备份
        backup_configs = true,                 -- 备份配置
        max_backup_count = 5,                  -- 最大配置备份数
        
        -- 配置重置
        allow_reset = true,                    -- 允许重置配置
        confirm_reset = true                   -- 重置时确认
    },
    
    -- 缓存管理器配置
    cache = {
        -- 基础缓存配置
        max_cache_size = 50,                   -- 最大缓存条目数
        default_ttl = 3600,                    -- 默认TTL (1小时)
        enable_persistence = true,             -- 启用缓存持久化
        memory_limit_mb = 5,                   -- 内存限制 (MB)
        
        -- 清理配置
        cleanup_interval = 300,                -- 清理间隔 (5分钟)
        auto_cleanup_enabled = true,           -- 启用自动清理
        aggressive_cleanup = false,            -- 积极清理模式
        
        -- 缓存策略
        eviction_policy = "LRU",               -- 淘汰策略 (LRU, LFU, FIFO)
        compression_enabled = true,            -- 启用缓存压缩
        
        -- 分类缓存配置
        translation_cache = {
            max_size = 200,                    -- 翻译缓存最大条目数
            ttl = 7200,                        -- 翻译缓存TTL (2小时)
            enabled = true                     -- 启用翻译缓存
        },
        rule_query_cache = {
            max_size = 100,                    -- 规则查询缓存最大条目数
            ttl = 3600,                        -- 规则查询缓存TTL (1小时)
            enabled = true                     -- 启用规则查询缓存
        }
    },
    
    -- 数据压缩配置
    compression = {
        -- 基础压缩配置
        compression_enabled = true,            -- 启用压缩
        compression_level = "balanced",        -- 压缩级别 (fast, balanced, max)
        min_compression_size = 1024,           -- 最小压缩数据大小 (1KB)
        compression_threshold = 0.8,           -- 压缩阈值 (80%)
        
        -- 分块配置
        chunk_size = 8192,                     -- 分块大小 (8KB)
        max_chunks = 100,                      -- 最大分块数
        checksum_enabled = true,               -- 启用校验和
        
        -- 压缩算法配置
        default_algorithm = "hybrid",          -- 默认压缩算法
        fallback_algorithm = "rle",            -- 备用压缩算法
        auto_select_algorithm = true,          -- 自动选择最佳算法
        
        -- 性能配置
        max_compression_time = 5,              -- 最大压缩时间 (秒)
        parallel_compression = false,          -- 并行压缩 (暂不支持)
        memory_efficient_mode = true          -- 内存高效模式
    },
    
    -- 调试配置
    debug = {
        -- 调试模式
        enabled = false,                       -- 启用调试模式
        verbose_logging = false,               -- 详细日志记录
        stack_trace_enabled = true,            -- 启用堆栈跟踪
        
        -- 性能调试
        performance_monitoring = true,         -- 性能监控
        memory_monitoring = true,              -- 内存监控
        function_timing = false,               -- 函数计时
        
        -- 开发工具
        console_commands = false,              -- 启用控制台命令
        debug_ui = false,                      -- 调试UI
        hot_reload = false,                    -- 热重载 (开发模式)
        
        -- 测试配置
        unit_tests_enabled = false,           -- 启用单元测试
        integration_tests_enabled = false,    -- 启用集成测试
        benchmark_tests_enabled = false       -- 启用基准测试
    },
    
    -- 安全配置
    security = {
        -- API安全
        api_key_encryption = false,           -- API密钥加密 (TTS限制)
        validate_api_responses = true,        -- 验证API响应
        sanitize_user_input = true,           -- 清理用户输入
        
        -- 数据安全
        secure_storage = false,               -- 安全存储 (TTS限制)
        data_validation = true,               -- 数据验证
        input_sanitization = true,            -- 输入清理
        
        -- 网络安全
        https_only = true,                    -- 仅使用HTTPS
        certificate_validation = true,       -- 证书验证
        request_signing = false               -- 请求签名
    },
    
    -- 模块特定配置
    modules = {
        -- 主控制器配置
        main_controller = {
            startup_delay = 1,                 -- 启动延迟 (秒)
            initialization_timeout = 30,      -- 初始化超时 (秒)
            module_load_timeout = 10,          -- 模块加载超时 (秒)
            health_check_interval = 60         -- 健康检查间隔 (秒)
        },
        
        -- 日志系统配置
        logger = {
            buffer_size = 100,                 -- 缓冲区大小
            flush_interval = 5,                -- 刷新间隔 (秒)
            async_logging = false,             -- 异步日志 (暂不支持)
            console_output = true              -- 控制台输出
        },
        
        -- 错误处理器配置
        error_handler = {
            stack_trace_depth = 10,            -- 堆栈跟踪深度
            error_reporting = true,            -- 错误报告
            auto_recovery = true,              -- 自动恢复
            user_friendly_messages = true      -- 用户友好的错误消息
        },
        
        -- UI管理器配置
        ui_manager = {
            update_interval = 100,             -- UI更新间隔 (毫秒)
            smooth_animations = true,          -- 平滑动画
            responsive_design = true,          -- 响应式设计
            accessibility_features = true      -- 无障碍功能
        }
    }
}

-- 配置验证规则
DefaultConfigs.validation_rules = {
    -- 数值范围验证
    numeric_ranges = {
        log_level = {"DEBUG", "INFO", "WARNING", "ERROR", "FATAL"},
        theme = {"default", "dark", "light"},
        compression_level = {"fast", "balanced", "max"},
        eviction_policy = {"LRU", "LFU", "FIFO"}
    },
    
    -- 数值限制
    numeric_limits = {
        max_memory_usage_mb = {min = 10, max = 500},
        auto_save_interval = {min = 60, max = 3600},
        network_timeout = {min = 5, max = 120},
        max_cache_size = {min = 10, max = 1000},
        chunk_size = {min = 1024, max = 65536}
    }
}

-- 配置描述信息
DefaultConfigs.descriptions = {
    system = "系统核心配置，包括日志、性能、错误处理等",
    ui = "用户界面配置，包括主题、布局、交互等",
    storage = "数据存储配置，包括压缩、备份、清理等",
    cache = "缓存管理配置，包括大小、TTL、清理策略等",
    compression = "数据压缩配置，包括算法、性能、分块等",
    debug = "调试和开发配置，包括日志、性能监控等",
    security = "安全配置，包括数据保护、网络安全等"
}

-- 获取模块默认配置
function DefaultConfigs.getModuleConfig(module_name)
    if not module_name then
        return nil
    end
    
    -- 返回指定模块的配置
    if DefaultConfigs[module_name] then
        return DefaultConfigs[module_name]
    end
    
    -- 检查modules部分
    if DefaultConfigs.modules and DefaultConfigs.modules[module_name] then
        return DefaultConfigs.modules[module_name]
    end
    
    return {}
end

-- 获取所有配置
function DefaultConfigs.getAllConfigs()
    local configs = {}
    
    -- 复制所有非函数字段
    for key, value in pairs(DefaultConfigs) do
        if type(value) ~= "function" then
            configs[key] = value
        end
    end
    
    return configs
end

-- 验证配置值
function DefaultConfigs.validateConfig(module_name, key, value)
    local rules = DefaultConfigs.validation_rules
    
    -- 检查枚举值
    if rules.numeric_ranges[key] then
        local valid_values = rules.numeric_ranges[key]
        for _, valid_value in ipairs(valid_values) do
            if value == valid_value then
                return true, nil
            end
        end
        return false, "值必须是以下之一：" .. table.concat(valid_values, ", ")
    end
    
    -- 检查数值范围
    if rules.numeric_limits[key] and type(value) == "number" then
        local limits = rules.numeric_limits[key]
        if limits.min and value < limits.min then
            return false, "值不能小于 " .. limits.min
        end
        if limits.max and value > limits.max then
            return false, "值不能大于 " .. limits.max
        end
    end
    
    return true, nil
end

-- 获取配置描述
function DefaultConfigs.getConfigDescription(module_name)
    return DefaultConfigs.descriptions[module_name] or "无描述信息"
end

-- 导出默认配置
return DefaultConfigs 