--[[
    LLM服务管理器 (LLMServiceManager)
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    功能:
    - 多LLM服务提供商支持 (OpenAI, Ollama, Claude, 自定义)
    - API密钥安全管理
    - 请求路由与负载均衡
    - 错误处理与重试机制
    - 服务状态监控
--]]

-- 引入基础模块
local ModuleBase = require("src.core.module_base")

-- 基于ModuleBase创建LLMServiceManager
local LLMServiceManager = ModuleBase:new({
    name = "LLMServiceManager",
    version = "1.0.0",
    description = "桌游伴侣大语言模型服务管理器",
    author = "LeadDeveloperAI",
    dependencies = {"StorageManager", "ConfigManager", "CacheManager"},
    
    default_config = {
        -- 默认LLM服务
        default_provider = "openai",
        request_timeout = 30,
        max_retries = 3,
        retry_delay = 2,
        
        -- 并发限制
        max_concurrent_requests = 3,
        request_queue_size = 10,
        
        -- 服务健康监控
        health_check_interval = 300, -- 5分钟
        service_timeout_threshold = 60,
        
        -- 响应缓存
        cache_responses = true,
        cache_ttl = 3600, -- 1小时
        
        -- 安全设置
        validate_responses = true,
        sanitize_requests = true
    }
})

-- LLM服务提供商定义
LLMServiceManager.PROVIDERS = {
    OPENAI = "openai",
    OLLAMA = "ollama", 
    CLAUDE = "claude",
    CUSTOM = "custom"
}

-- 请求状态
LLMServiceManager.REQUEST_STATUS = {
    PENDING = "pending",
    PROCESSING = "processing",
    COMPLETED = "completed",
    FAILED = "failed",
    CACHED = "cached"
}

-- 初始化方法
function LLMServiceManager:onInitialize(save_data)
    Logger:info("初始化LLM服务管理器")
    
    -- 初始化服务状态
    self.services = {}
    self.request_queue = {}
    self.active_requests = {}
    self.service_stats = {}
    
    -- 加载保存的数据
    self:loadSavedData(save_data)
    
    -- 初始化服务提供商
    self:initializeProviders()
    
    -- 启动健康监控
    self:startHealthMonitoring()
    
    Logger:info("LLM服务管理器初始化完成", {
        providers_count = self:getProviderCount(),
        default_provider = self.config.default_provider
    })
end

-- 加载保存的数据
function LLMServiceManager:loadSavedData(save_data)
    if save_data then
        -- 恢复服务统计
        if save_data.service_stats then
            self.service_stats = save_data.service_stats
        end
        
        -- 恢复服务配置 (不包含敏感信息)
        if save_data.service_configs then
            for provider_id, config in pairs(save_data.service_configs) do
                if not config.api_key then -- 安全：不恢复API密钥
                    self.services[provider_id] = config
                end
            end
        end
        
        Logger:info("已恢复LLM服务数据")
    end
end

-- 初始化服务提供商
function LLMServiceManager:initializeProviders()
    -- OpenAI服务配置
    self:registerProvider(self.PROVIDERS.OPENAI, {
        name = "OpenAI GPT",
        base_url = "https://api.openai.com/v1/chat/completions",
        default_model = "gpt-3.5-turbo",
        models = {
            "gpt-3.5-turbo",
            "gpt-4",
            "gpt-4-turbo-preview"
        },
        headers = {
            ["Content-Type"] = "application/json"
        },
        max_tokens = 4096,
        temperature_range = {0.0, 2.0},
        supports_streaming = true
    })
    
    -- Ollama本地服务配置
    self:registerProvider(self.PROVIDERS.OLLAMA, {
        name = "Ollama Local",
        base_url = "http://localhost:11434/api/generate",
        default_model = "llama2",
        models = {
            "llama2",
            "codellama",
            "mistral",
            "neural-chat"
        },
        headers = {
            ["Content-Type"] = "application/json"
        },
        max_tokens = 2048,
        temperature_range = {0.0, 1.0},
        supports_streaming = true,
        local_service = true
    })
    
    -- Claude服务配置
    self:registerProvider(self.PROVIDERS.CLAUDE, {
        name = "Anthropic Claude",
        base_url = "https://api.anthropic.com/v1/messages",
        default_model = "claude-3-sonnet-20240229",
        models = {
            "claude-3-sonnet-20240229",
            "claude-3-opus-20240229",
            "claude-3-haiku-20240307"
        },
        headers = {
            ["Content-Type"] = "application/json",
            ["anthropic-version"] = "2023-06-01"
        },
        max_tokens = 4096,
        temperature_range = {0.0, 1.0},
        supports_streaming = false
    })
    
    Logger:info("LLM服务提供商初始化完成", {
        providers = {self.PROVIDERS.OPENAI, self.PROVIDERS.OLLAMA, self.PROVIDERS.CLAUDE}
    })
end

-- 注册服务提供商
function LLMServiceManager:registerProvider(provider_id, config)
    if not provider_id or not config then
        Logger:error("注册服务提供商参数无效", {provider_id = provider_id})
        return false
    end
    
    -- 设置默认值
    config.provider_id = provider_id
    config.enabled = true
    config.status = "unknown"
    config.last_check = 0
    config.response_times = {}
    config.error_count = 0
    config.success_count = 0
    
    self.services[provider_id] = config
    
    -- 初始化统计
    if not self.service_stats[provider_id] then
        self.service_stats[provider_id] = {
            total_requests = 0,
            successful_requests = 0,
            failed_requests = 0,
            total_response_time = 0,
            average_response_time = 0,
            last_request_time = 0,
            error_rate = 0
        }
    end
    
    Logger:debug("已注册LLM服务提供商", {
        provider_id = provider_id,
        name = config.name,
        base_url = config.base_url
    })
    
    return true
end

-- 配置服务提供商
function LLMServiceManager:configureProvider(provider_id, api_key, custom_config)
    local service = self.services[provider_id]
    if not service then
        Logger:error("未找到服务提供商", {provider_id = provider_id})
        return false
    end
    
    -- 安全存储API密钥
    local storage_manager = self:getModule("StorageManager")
    if storage_manager and api_key then
        local key_storage_key = "llm_api_key_" .. provider_id
        storage_manager:saveData("sensitive", key_storage_key, api_key)
        Logger:info("API密钥已安全存储", {provider_id = provider_id})
    end
    
    -- 应用自定义配置
    if custom_config then
        for key, value in pairs(custom_config) do
            if key ~= "api_key" then -- 安全：不直接存储API密钥
                service[key] = value
            end
        end
    end
    
    -- 标记为已配置
    service.configured = true
    service.last_configured = os.time()
    
    Logger:info("LLM服务提供商配置完成", {
        provider_id = provider_id,
        configured = true
    })
    
    return true
end

-- 发送LLM请求
function LLMServiceManager:sendRequest(request_data, callback, options)
    if not request_data or not callback then
        Logger:error("LLM请求参数无效")
        if callback then callback(nil, "请求参数无效") end
        return false
    end
    
    -- 使用指定提供商或默认提供商
    local provider_id = (options and options.provider) or self.config.default_provider
    local service = self.services[provider_id]
    
    if not service or not service.configured then
        local error_msg = "LLM服务未配置: " .. tostring(provider_id)
        Logger:error(error_msg)
        if callback then callback(nil, error_msg) end
        return false
    end
    
    -- 生成请求ID
    local request_id = self:generateRequestId()
    
    -- 创建请求对象
    local request = {
        id = request_id,
        provider_id = provider_id,
        data = request_data,
        callback = callback,
        options = options or {},
        status = self.REQUEST_STATUS.PENDING,
        created_time = os.time(),
        retry_count = 0
    }
    
    -- 检查缓存
    if self.config.cache_responses then
        local cached_response = self:getCachedResponse(request_data, provider_id)
        if cached_response then
            Logger:debug("使用缓存的LLM响应", {request_id = request_id})
            request.status = self.REQUEST_STATUS.CACHED
            callback(cached_response, nil)
            return true
        end
    end
    
    -- 检查并发限制
    if #self.active_requests >= self.config.max_concurrent_requests then
        if #self.request_queue < self.config.request_queue_size then
            table.insert(self.request_queue, request)
            Logger:debug("请求已加入队列", {request_id = request_id, queue_size = #self.request_queue})
            return true
        else
            local error_msg = "请求队列已满"
            Logger:warning(error_msg, {request_id = request_id})
            callback(nil, error_msg)
            return false
        end
    end
    
    -- 立即处理请求
    return self:processRequest(request)
end

-- 处理请求
function LLMServiceManager:processRequest(request)
    request.status = self.REQUEST_STATUS.PROCESSING
    request.start_time = os.clock()
    
    -- 添加到活跃请求列表
    table.insert(self.active_requests, request)
    
    -- 获取服务配置
    local service = self.services[request.provider_id]
    
    -- 构建HTTP请求
    local http_request = self:buildHttpRequest(request, service)
    if not http_request then
        self:handleRequestError(request, "HTTP请求构建失败")
        return false
    end
    
    Logger:debug("发送LLM HTTP请求", {
        request_id = request.id,
        provider = request.provider_id,
        url = service.base_url
    })
    
    -- 发送HTTP请求
    self:sendHttpRequest(http_request, request, service)
    
    return true
end

-- 构建HTTP请求
function LLMServiceManager:buildHttpRequest(request, service)
    -- 获取API密钥
    local api_key = self:getApiKey(service.provider_id)
    if not api_key and not service.local_service then
        Logger:error("未找到API密钥", {provider_id = service.provider_id})
        return nil
    end
    
    -- 构建请求头
    local headers = {}
    for key, value in pairs(service.headers) do
        headers[key] = value
    end
    
    -- 添加认证头
    if api_key then
        if service.provider_id == self.PROVIDERS.OPENAI then
            headers["Authorization"] = "Bearer " .. api_key
        elseif service.provider_id == self.PROVIDERS.CLAUDE then
            headers["x-api-key"] = api_key
        end
    end
    
    -- 构建请求体
    local request_body = self:buildRequestBody(request, service)
    if not request_body then
        Logger:error("请求体构建失败", {provider_id = service.provider_id})
        return nil
    end
    
    return {
        url = service.base_url,
        method = "POST",
        headers = headers,
        body = JSON.encode(request_body),
        timeout = self.config.request_timeout
    }
end

-- 构建请求体
function LLMServiceManager:buildRequestBody(request, service)
    local data = request.data
    
    if service.provider_id == self.PROVIDERS.OPENAI then
        return {
            model = data.model or service.default_model,
            messages = data.messages,
            max_tokens = data.max_tokens or service.max_tokens,
            temperature = data.temperature or 0.7,
            top_p = data.top_p,
            n = data.n or 1,
            stop = data.stop,
            presence_penalty = data.presence_penalty,
            frequency_penalty = data.frequency_penalty
        }
    elseif service.provider_id == self.PROVIDERS.OLLAMA then
        -- Ollama格式：转换messages为prompt
        local prompt = self:convertMessagesToPrompt(data.messages)
        return {
            model = data.model or service.default_model,
            prompt = prompt,
            stream = false,
            options = {
                temperature = data.temperature or 0.7,
                top_p = data.top_p,
                top_k = data.top_k,
                num_predict = data.max_tokens or service.max_tokens
            }
        }
    elseif service.provider_id == self.PROVIDERS.CLAUDE then
        return {
            model = data.model or service.default_model,
            max_tokens = data.max_tokens or service.max_tokens,
            messages = data.messages,
            temperature = data.temperature or 0.7,
            top_p = data.top_p,
            top_k = data.top_k,
            stop_sequences = data.stop
        }
    end
    
    return nil
end

-- 发送HTTP请求
function LLMServiceManager:sendHttpRequest(http_request, request, service)
    -- 使用TTS WebRequest
    if not WebRequest then
        self:handleRequestError(request, "WebRequest不可用")
        return
    end
    
    -- 发送POST请求
    WebRequest.post(http_request.url, http_request.body, function(web_request)
        self:handleHttpResponse(web_request, request, service)
    end)
end

-- 处理HTTP响应
function LLMServiceManager:handleHttpResponse(web_request, request, service)
    request.end_time = os.clock()
    request.response_time = request.end_time - request.start_time
    
    -- 从活跃请求列表中移除
    self:removeActiveRequest(request.id)
    
    if web_request.is_error then
        -- 处理网络错误
        local error_msg = "网络请求失败: " .. (web_request.error or "未知错误")
        self:handleRequestError(request, error_msg)
        return
    end
    
    -- 检查HTTP状态码
    if web_request.response_code and web_request.response_code >= 400 then
        local error_msg = "HTTP错误: " .. web_request.response_code
        self:handleRequestError(request, error_msg)
        return
    end
    
    -- 解析响应
    local response_data, parse_error = self:parseResponse(web_request.text, service)
    if not response_data then
        self:handleRequestError(request, "响应解析失败: " .. (parse_error or "未知错误"))
        return
    end
    
    -- 处理成功响应
    self:handleRequestSuccess(request, response_data, service)
end

-- 解析响应
function LLMServiceManager:parseResponse(response_text, service)
    if not response_text then
        return nil, "响应为空"
    end
    
    -- 尝试解析JSON
    local success, response_data = pcall(JSON.decode, response_text)
    if not success then
        return nil, "JSON解析失败"
    end
    
    -- 提取响应内容
    local content = nil
    if service.provider_id == self.PROVIDERS.OPENAI then
        if response_data.choices and response_data.choices[1] and response_data.choices[1].message then
            content = response_data.choices[1].message.content
        end
    elseif service.provider_id == self.PROVIDERS.OLLAMA then
        content = response_data.response
    elseif service.provider_id == self.PROVIDERS.CLAUDE then
        if response_data.content and response_data.content[1] then
            content = response_data.content[1].text
        end
    end
    
    if not content then
        return nil, "无法提取响应内容"
    end
    
    return {
        content = content,
        raw_response = response_data,
        model = response_data.model,
        usage = response_data.usage
    }, nil
end

-- 处理请求成功
function LLMServiceManager:handleRequestSuccess(request, response_data, service)
    request.status = self.REQUEST_STATUS.COMPLETED
    
    -- 更新统计
    self:updateServiceStats(service.provider_id, true, request.response_time)
    
    -- 缓存响应
    if self.config.cache_responses then
        self:cacheResponse(request.data, service.provider_id, response_data)
    end
    
    Logger:info("LLM请求成功", {
        request_id = request.id,
        provider = service.provider_id,
        response_time = string.format("%.2f", request.response_time),
        content_length = string.len(response_data.content)
    })
    
    -- 调用回调
    request.callback(response_data, nil)
    
    -- 处理队列中的下一个请求
    self:processNextQueuedRequest()
end

-- 处理请求错误
function LLMServiceManager:handleRequestError(request, error_message)
    request.status = self.REQUEST_STATUS.FAILED
    
    -- 检查是否需要重试
    if request.retry_count < self.config.max_retries then
        request.retry_count = request.retry_count + 1
        
        Logger:warning("LLM请求失败，准备重试", {
            request_id = request.id,
            retry_count = request.retry_count,
            error = error_message
        })
        
        -- 延迟重试
        Wait.time(function()
            self:processRequest(request)
        end, self.config.retry_delay)
        
        return
    end
    
    -- 重试次数耗尽，标记为最终失败
    local service = self.services[request.provider_id]
    self:updateServiceStats(request.provider_id, false, 0)
    
    Logger:error("LLM请求最终失败", {
        request_id = request.id,
        provider = request.provider_id,
        error = error_message,
        retry_count = request.retry_count
    })
    
    -- 从活跃请求列表中移除
    self:removeActiveRequest(request.id)
    
    -- 调用回调
    request.callback(nil, error_message)
    
    -- 处理队列中的下一个请求
    self:processNextQueuedRequest()
end

-- 获取API密钥
function LLMServiceManager:getApiKey(provider_id)
    local storage_manager = self:getModule("StorageManager")
    if not storage_manager then
        Logger:error("StorageManager不可用")
        return nil
    end
    
    local key_storage_key = "llm_api_key_" .. provider_id
    return storage_manager:loadData("sensitive", key_storage_key)
end

-- 生成请求ID
function LLMServiceManager:generateRequestId()
    return "llm_req_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- 转换消息为提示文本 (用于Ollama)
function LLMServiceManager:convertMessagesToPrompt(messages)
    if not messages then
        return ""
    end
    
    local prompt_parts = {}
    for _, message in ipairs(messages) do
        if message.role == "system" then
            table.insert(prompt_parts, "System: " .. message.content)
        elseif message.role == "user" then
            table.insert(prompt_parts, "User: " .. message.content)
        elseif message.role == "assistant" then
            table.insert(prompt_parts, "Assistant: " .. message.content)
        end
    end
    
    return table.concat(prompt_parts, "\n\n")
end

-- 更新服务统计
function LLMServiceManager:updateServiceStats(provider_id, success, response_time)
    local stats = self.service_stats[provider_id]
    if not stats then
        return
    end
    
    stats.total_requests = stats.total_requests + 1
    stats.last_request_time = os.time()
    
    if success then
        stats.successful_requests = stats.successful_requests + 1
        if response_time then
            stats.total_response_time = stats.total_response_time + response_time
            stats.average_response_time = stats.total_response_time / stats.successful_requests
        end
    else
        stats.failed_requests = stats.failed_requests + 1
    end
    
    -- 计算错误率
    stats.error_rate = stats.failed_requests / stats.total_requests
end

-- 获取缓存的响应
function LLMServiceManager:getCachedResponse(request_data, provider_id)
    local cache_manager = self:getModule("CacheManager")
    if not cache_manager then
        return nil
    end
    
    local cache_key = self:generateCacheKey(request_data, provider_id)
    return cache_manager:get("rule_query", cache_key)
end

-- 缓存响应
function LLMServiceManager:cacheResponse(request_data, provider_id, response_data)
    local cache_manager = self:getModule("CacheManager")
    if not cache_manager then
        return
    end
    
    local cache_key = self:generateCacheKey(request_data, provider_id)
    cache_manager:set("rule_query", cache_key, response_data, self.config.cache_ttl)
end

-- 生成缓存键
function LLMServiceManager:generateCacheKey(request_data, provider_id)
    -- 基于请求内容生成缓存键
    local key_parts = {
        provider_id,
        request_data.model or "default"
    }
    
    -- 添加消息内容的哈希
    if request_data.messages then
        local messages_str = JSON.encode(request_data.messages)
        -- 简单哈希函数
        local hash = 0
        for i = 1, string.len(messages_str) do
            hash = (hash + string.byte(messages_str, i)) % 10000
        end
        table.insert(key_parts, tostring(hash))
    end
    
    return table.concat(key_parts, "_")
end

-- 移除活跃请求
function LLMServiceManager:removeActiveRequest(request_id)
    for i, req in ipairs(self.active_requests) do
        if req.id == request_id then
            table.remove(self.active_requests, i)
            break
        end
    end
end

-- 处理队列中的下一个请求
function LLMServiceManager:processNextQueuedRequest()
    if #self.request_queue > 0 and #self.active_requests < self.config.max_concurrent_requests then
        local next_request = table.remove(self.request_queue, 1)
        self:processRequest(next_request)
    end
end

-- 启动健康监控
function LLMServiceManager:startHealthMonitoring()
    if self.health_timer then
        return
    end
    
    self.health_timer = Wait.time(function()
        self:performHealthChecks()
        self:startHealthMonitoring() -- 递归调用实现循环
    end, self.config.health_check_interval)
    
    Logger:debug("LLM服务健康监控已启动")
end

-- 执行健康检查
function LLMServiceManager:performHealthChecks()
    Logger:debug("执行LLM服务健康检查")
    
    for provider_id, service in pairs(self.services) do
        if service.configured and service.enabled then
            self:checkServiceHealth(provider_id)
        end
    end
end

-- 检查服务健康状态
function LLMServiceManager:checkServiceHealth(provider_id)
    local stats = self.service_stats[provider_id]
    if not stats then
        return
    end
    
    local service = self.services[provider_id]
    local current_time = os.time()
    
    -- 基于错误率判断健康状态
    if stats.error_rate > 0.5 then
        service.status = "unhealthy"
    elseif stats.error_rate > 0.2 then
        service.status = "degraded"
    else
        service.status = "healthy"
    end
    
    -- 基于响应时间判断
    if stats.average_response_time > self.config.service_timeout_threshold then
        if service.status == "healthy" then
            service.status = "slow"
        end
    end
    
    service.last_check = current_time
    
    Logger:debug("服务健康检查完成", {
        provider_id = provider_id,
        status = service.status,
        error_rate = math.floor(stats.error_rate * 100) .. "%",
        avg_response_time = string.format("%.2f", stats.average_response_time or 0)
    })
end

-- 获取服务状态
function LLMServiceManager:getServiceStatus()
    local status = {
        providers = {},
        active_requests = #self.active_requests,
        queued_requests = #self.request_queue,
        total_requests_today = 0
    }
    
    for provider_id, service in pairs(self.services) do
        local stats = self.service_stats[provider_id] or {}
        
        status.providers[provider_id] = {
            name = service.name,
            status = service.status or "unknown",
            configured = service.configured or false,
            enabled = service.enabled or false,
            stats = {
                total_requests = stats.total_requests or 0,
                successful_requests = stats.successful_requests or 0,
                failed_requests = stats.failed_requests or 0,
                error_rate = math.floor((stats.error_rate or 0) * 100),
                average_response_time = stats.average_response_time or 0
            }
        }
        
        status.total_requests_today = status.total_requests_today + (stats.total_requests or 0)
    end
    
    return status
end

-- 获取提供商数量
function LLMServiceManager:getProviderCount()
    local count = 0
    for _ in pairs(self.services) do
        count = count + 1
    end
    return count
end

-- 获取保存数据
function LLMServiceManager:getSaveData()
    -- 保存非敏感数据
    local service_configs = {}
    for provider_id, service in pairs(self.services) do
        service_configs[provider_id] = {
            name = service.name,
            base_url = service.base_url,
            configured = service.configured,
            enabled = service.enabled,
            status = service.status
        }
    end
    
    return {
        service_stats = self.service_stats,
        service_configs = service_configs,
        version = self.version
    }
end

-- 子类关闭方法
function LLMServiceManager:onShutdown()
    -- 停止健康监控
    if self.health_timer then
        self.health_timer = nil
    end
    
    -- 清理活跃请求
    for _, request in ipairs(self.active_requests) do
        if request.callback then
            request.callback(nil, "服务正在关闭")
        end
    end
    
    Logger:info("LLM服务管理器已关闭", {
        final_stats = self:getServiceStatus()
    })
end

-- 导出LLMServiceManager模块
return LLMServiceManager 