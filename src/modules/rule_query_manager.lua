--[[
    规则查询管理器 (RuleQueryManager)
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    功能:
    - 智能规则查询接口
    - 上下文感知的问答系统
    - 规则文档管理
    - 查询历史追踪
    - 与其他模块的协调
--]]

-- 引入基础模块
local ModuleBase = require("src.core.module_base")

-- 基于ModuleBase创建RuleQueryManager
local RuleQueryManager = ModuleBase:new({
    name = "RuleQueryManager",
    version = "1.0.0",
    description = "桌游伴侣智能规则查询管理器",
    author = "LeadDeveloperAI",
    dependencies = {"LLMServiceManager", "StorageManager", "CacheManager", "ConfigManager"},
    
    default_config = {
        -- 查询设置
        default_model = "gpt-3.5-turbo",
        max_query_length = 500,
        context_window_size = 4000,
        
        -- 查询历史
        max_history_entries = 100,
        history_ttl = 86400, -- 24小时
        
        -- 响应设置
        max_response_tokens = 800,
        temperature = 0.7,
        
        -- 缓存设置
        cache_queries = true,
        cache_duration = 3600, -- 1小时
        
        -- 安全设置
        sanitize_queries = true,
        filter_sensitive_content = true,
        
        -- 规则文档设置
        max_document_size = 1048576, -- 1MB
        document_chunk_size = 2048,
        
        -- 系统提示词
        system_prompt = "你是一个专业的桌游规则助手。请基于提供的游戏规则文档和当前游戏状态，准确、简洁地回答玩家的规则问题。如果规则不明确或你不确定，请诚实说明并建议玩家查阅完整规则书。"
    }
})

-- 查询类型定义
RuleQueryManager.QUERY_TYPES = {
    BASIC = "basic",           -- 基础规则查询
    CONTEXTUAL = "contextual", -- 上下文感知查询
    OBJECT_SPECIFIC = "object_specific", -- 特定对象查询
    GAME_STATE = "game_state", -- 游戏状态相关查询
    CLARIFICATION = "clarification" -- 澄清性查询
}

-- 查询状态
RuleQueryManager.QUERY_STATUS = {
    PENDING = "pending",
    PROCESSING = "processing",
    COMPLETED = "completed",
    FAILED = "failed",
    CACHED = "cached"
}

-- 初始化方法
function RuleQueryManager:onInitialize(save_data)
    Logger:info("初始化规则查询管理器")
    
    -- 初始化查询系统
    self.active_queries = {}
    self.query_history = {}
    self.rule_documents = {}
    self.query_stats = {
        total_queries = 0,
        successful_queries = 0,
        failed_queries = 0,
        cached_queries = 0,
        average_response_time = 0
    }
    
    -- 加载保存的数据
    self:loadSavedData(save_data)
    
    -- 初始化系统提示词模板
    self:initializePromptTemplates()
    
    Logger:info("规则查询管理器初始化完成", {
        documents_loaded = self:getDocumentCount(),
        history_entries = #self.query_history
    })
end

-- 加载保存的数据
function RuleQueryManager:loadSavedData(save_data)
    if save_data then
        -- 恢复查询历史
        if save_data.query_history then
            self.query_history = save_data.query_history
        end
        
        -- 恢复规则文档
        if save_data.rule_documents then
            self.rule_documents = save_data.rule_documents
        end
        
        -- 恢复统计数据
        if save_data.query_stats then
            self.query_stats = save_data.query_stats
        end
        
        Logger:info("已恢复规则查询数据")
    end
end

-- 初始化提示词模板
function RuleQueryManager:initializePromptTemplates()
    self.prompt_templates = {
        -- 基础查询模板
        basic_query = {
            system = self.config.system_prompt,
            user_template = "基于以下游戏规则文档，请回答玩家的问题：\n\n【规则文档】\n{rules_content}\n\n【玩家问题】\n{user_question}\n\n请提供准确、简洁的回答。"
        },
        
        -- 上下文感知查询模板
        contextual_query = {
            system = self.config.system_prompt .. " 特别注意当前的游戏状态和上下文信息。",
            user_template = "基于以下游戏规则文档和当前游戏状态，请回答玩家的问题：\n\n【规则文档】\n{rules_content}\n\n【当前游戏状态】\n{game_context}\n\n【玩家问题】\n{user_question}\n\n请结合游戏状态提供具体的建议。"
        },
        
        -- 对象特定查询模板
        object_specific = {
            system = self.config.system_prompt,
            user_template = "基于以下游戏规则文档和指定游戏对象信息，请回答关于该对象的问题：\n\n【规则文档】\n{rules_content}\n\n【游戏对象信息】\n{object_info}\n\n【玩家问题】\n{user_question}\n\n请专注于该对象的相关规则。"
        },
        
        -- 澄清性查询模板
        clarification = {
            system = self.config.system_prompt .. " 如果问题不明确，请友好地要求澄清。",
            user_template = "玩家问题：{user_question}\n\n请分析这个问题是否明确。如果不明确，请友好地询问需要澄清的具体点。如果明确，请基于规则文档回答：\n\n【规则文档】\n{rules_content}"
        }
    }
    
    Logger:debug("提示词模板已初始化")
end

-- 主要查询接口
function RuleQueryManager:queryRule(question, options, callback)
    if not question or string.len(question) == 0 then
        Logger:error("查询问题为空")
        if callback then callback(nil, "问题不能为空") end
        return false
    end
    
    -- 设置默认选项
    options = options or {}
    local query_type = options.query_type or self.QUERY_TYPES.BASIC
    local context_data = options.context_data
    local object_info = options.object_info
    
    -- 生成查询ID
    local query_id = self:generateQueryId()
    
    -- 创建查询对象
    local query = {
        id = query_id,
        question = question,
        query_type = query_type,
        context_data = context_data,
        object_info = object_info,
        options = options,
        callback = callback,
        status = self.QUERY_STATUS.PENDING,
        created_time = os.time(),
        start_time = os.clock()
    }
    
    Logger:info("收到规则查询", {
        query_id = query_id,
        query_type = query_type,
        question_length = string.len(question)
    })
    
    -- 检查缓存
    if self.config.cache_queries then
        local cached_response = self:getCachedQuery(question, context_data)
        if cached_response then
            Logger:debug("使用缓存的查询结果", {query_id = query_id})
            query.status = self.QUERY_STATUS.CACHED
            self:recordQueryInHistory(query, cached_response)
            self:updateQueryStats(true, 0, true)
            if callback then callback(cached_response, nil) end
            return true
        end
    end
    
    -- 添加到活跃查询列表
    self.active_queries[query_id] = query
    
    -- 处理查询
    return self:processQuery(query)
end

-- 处理查询
function RuleQueryManager:processQuery(query)
    query.status = self.QUERY_STATUS.PROCESSING
    
    -- 构建LLM请求
    local llm_request = self:buildLLMRequest(query)
    if not llm_request then
        self:handleQueryError(query, "LLM请求构建失败")
        return false
    end
    
    -- 获取LLM服务管理器
    local llm_manager = self:getModule("LLMServiceManager")
    if not llm_manager then
        self:handleQueryError(query, "LLM服务管理器不可用")
        return false
    end
    
    Logger:debug("发送查询到LLM服务", {
        query_id = query.id,
        model = llm_request.model
    })
    
    -- 发送LLM请求
    llm_manager:sendRequest(llm_request, function(response, error)
        self:handleLLMResponse(query, response, error)
    end, {
        provider = query.options.provider
    })
    
    return true
end

-- 构建LLM请求
function RuleQueryManager:buildLLMRequest(query)
    -- 选择合适的提示词模板
    local template = self:selectPromptTemplate(query.query_type)
    if not template then
        Logger:error("未找到合适的提示词模板", {query_type = query.query_type})
        return nil
    end
    
    -- 构建用户消息
    local user_message = self:buildUserMessage(query, template)
    if not user_message then
        Logger:error("用户消息构建失败")
        return nil
    end
    
    -- 构建消息序列
    local messages = {
        {
            role = "system",
            content = template.system
        },
        {
            role = "user", 
            content = user_message
        }
    }
    
    -- 添加查询历史作为上下文 (如果启用)
    if query.options.include_history then
        self:addHistoryContext(messages, query)
    end
    
    return {
        model = query.options.model or self.config.default_model,
        messages = messages,
        max_tokens = query.options.max_tokens or self.config.max_response_tokens,
        temperature = query.options.temperature or self.config.temperature,
        top_p = query.options.top_p,
        stop = query.options.stop_sequences
    }
end

-- 选择提示词模板
function RuleQueryManager:selectPromptTemplate(query_type)
    if query_type == self.QUERY_TYPES.BASIC then
        return self.prompt_templates.basic_query
    elseif query_type == self.QUERY_TYPES.CONTEXTUAL then
        return self.prompt_templates.contextual_query
    elseif query_type == self.QUERY_TYPES.OBJECT_SPECIFIC then
        return self.prompt_templates.object_specific
    elseif query_type == self.QUERY_TYPES.CLARIFICATION then
        return self.prompt_templates.clarification
    else
        return self.prompt_templates.basic_query -- 默认模板
    end
end

-- 构建用户消息
function RuleQueryManager:buildUserMessage(query, template)
    local user_template = template.user_template
    
    -- 获取规则文档内容
    local rules_content = self:getRulesContent(query)
    
    -- 替换模板变量
    user_template = string.gsub(user_template, "{user_question}", query.question)
    user_template = string.gsub(user_template, "{rules_content}", rules_content or "无可用规则文档")
    
    -- 处理上下文信息
    if query.context_data then
        local context_str = self:formatContextData(query.context_data)
        user_template = string.gsub(user_template, "{game_context}", context_str)
    end
    
    -- 处理对象信息
    if query.object_info then
        local object_str = self:formatObjectInfo(query.object_info)
        user_template = string.gsub(user_template, "{object_info}", object_str)
    end
    
    return user_template
end

-- 获取规则文档内容
function RuleQueryManager:getRulesContent(query)
    -- 如果指定了文档ID
    if query.options.document_id then
        local doc = self.rule_documents[query.options.document_id]
        return doc and doc.content or nil
    end
    
    -- 使用所有可用文档 (根据context_window_size限制)
    local all_content = {}
    local total_length = 0
    
    for doc_id, doc in pairs(self.rule_documents) do
        if doc.content and doc.enabled ~= false then
            local content_length = string.len(doc.content)
            if total_length + content_length <= self.config.context_window_size then
                table.insert(all_content, "=== " .. (doc.title or doc_id) .. " ===")
                table.insert(all_content, doc.content)
                total_length = total_length + content_length + 50 -- 标题开销
            else
                break
            end
        end
    end
    
    return #all_content > 0 and table.concat(all_content, "\n\n") or nil
end

-- 格式化上下文数据
function RuleQueryManager:formatContextData(context_data)
    if not context_data then
        return ""
    end
    
    local context_parts = {}
    
    -- 游戏基本信息
    if context_data.game_info then
        table.insert(context_parts, "游戏信息：" .. JSON.encode(context_data.game_info))
    end
    
    -- 当前玩家信息
    if context_data.current_player then
        table.insert(context_parts, "当前玩家：" .. tostring(context_data.current_player))
    end
    
    -- 回合信息
    if context_data.turn_info then
        table.insert(context_parts, "回合信息：" .. JSON.encode(context_data.turn_info))
    end
    
    -- 游戏对象状态
    if context_data.game_objects then
        table.insert(context_parts, "游戏对象状态：" .. JSON.encode(context_data.game_objects))
    end
    
    -- 玩家资源
    if context_data.player_resources then
        table.insert(context_parts, "玩家资源：" .. JSON.encode(context_data.player_resources))
    end
    
    return table.concat(context_parts, "\n")
end

-- 格式化对象信息
function RuleQueryManager:formatObjectInfo(object_info)
    if not object_info then
        return ""
    end
    
    local info_parts = {}
    
    -- 对象基本信息
    if object_info.name then
        table.insert(info_parts, "对象名称：" .. object_info.name)
    end
    
    if object_info.type then
        table.insert(info_parts, "对象类型：" .. object_info.type)
    end
    
    if object_info.position then
        table.insert(info_parts, "位置：" .. JSON.encode(object_info.position))
    end
    
    if object_info.properties then
        table.insert(info_parts, "属性：" .. JSON.encode(object_info.properties))
    end
    
    if object_info.description then
        table.insert(info_parts, "描述：" .. object_info.description)
    end
    
    return table.concat(info_parts, "\n")
end

-- 添加历史上下文
function RuleQueryManager:addHistoryContext(messages, query)
    -- 获取最近的相关查询历史
    local relevant_history = self:getRelevantHistory(query.question, 3)
    
    if #relevant_history > 0 then
        local history_content = "相关查询历史：\n"
        for _, hist in ipairs(relevant_history) do
            history_content = history_content .. "问：" .. hist.question .. "\n答：" .. (hist.answer or "无答案") .. "\n\n"
        end
        
        -- 插入历史上下文消息
        table.insert(messages, #messages, {
            role = "assistant",
            content = history_content
        })
    end
end

-- 获取相关历史
function RuleQueryManager:getRelevantHistory(question, max_count)
    local relevant = {}
    local question_lower = string.lower(question)
    
    for _, hist in ipairs(self.query_history) do
        if hist.question and hist.answer then
            local hist_question_lower = string.lower(hist.question)
            
            -- 简单的相关性检查 (关键词匹配)
            local relevance_score = 0
            for word in string.gmatch(question_lower, "%w+") do
                if string.find(hist_question_lower, word, 1, true) then
                    relevance_score = relevance_score + 1
                end
            end
            
            if relevance_score > 0 then
                table.insert(relevant, {
                    history = hist,
                    score = relevance_score
                })
            end
        end
    end
    
    -- 按相关性分数排序
    table.sort(relevant, function(a, b) return a.score > b.score end)
    
    -- 返回最相关的条目
    local result = {}
    for i = 1, math.min(max_count, #relevant) do
        table.insert(result, relevant[i].history)
    end
    
    return result
end

-- 处理LLM响应
function RuleQueryManager:handleLLMResponse(query, response, error)
    query.end_time = os.clock()
    query.response_time = query.end_time - query.start_time
    
    -- 从活跃查询列表中移除
    self.active_queries[query.id] = nil
    
    if error then
        self:handleQueryError(query, error)
        return
    end
    
    if not response or not response.content then
        self:handleQueryError(query, "LLM响应无效")
        return
    end
    
    -- 处理成功响应
    self:handleQuerySuccess(query, response)
end

-- 处理查询成功
function RuleQueryManager:handleQuerySuccess(query, response)
    query.status = self.QUERY_STATUS.COMPLETED
    query.answer = response.content
    query.model_used = response.model
    query.token_usage = response.usage
    
    -- 记录到历史
    self:recordQueryInHistory(query, response)
    
    -- 缓存响应
    if self.config.cache_queries then
        self:cacheQuery(query.question, query.context_data, response)
    end
    
    -- 更新统计
    self:updateQueryStats(true, query.response_time, false)
    
    Logger:info("规则查询成功", {
        query_id = query.id,
        response_time = string.format("%.2f", query.response_time),
        answer_length = string.len(response.content)
    })
    
    -- 调用回调
    if query.callback then
        query.callback(response, nil)
    end
end

-- 处理查询错误
function RuleQueryManager:handleQueryError(query, error_message)
    query.status = self.QUERY_STATUS.FAILED
    query.error = error_message
    
    -- 从活跃查询列表中移除
    self.active_queries[query.id] = nil
    
    -- 更新统计
    self:updateQueryStats(false, 0, false)
    
    Logger:error("规则查询失败", {
        query_id = query.id,
        error = error_message
    })
    
    -- 调用回调
    if query.callback then
        query.callback(nil, error_message)
    end
end

-- 记录查询历史
function RuleQueryManager:recordQueryInHistory(query, response)
    local history_entry = {
        id = query.id,
        question = query.question,
        answer = response.content,
        query_type = query.query_type,
        timestamp = query.created_time,
        response_time = query.response_time,
        model_used = response.model,
        token_usage = response.usage
    }
    
    -- 添加到历史列表
    table.insert(self.query_history, 1, history_entry) -- 插入到开头
    
    -- 维护历史大小限制
    if #self.query_history > self.config.max_history_entries then
        table.remove(self.query_history, #self.query_history)
    end
end

-- 更新查询统计
function RuleQueryManager:updateQueryStats(success, response_time, from_cache)
    self.query_stats.total_queries = self.query_stats.total_queries + 1
    
    if from_cache then
        self.query_stats.cached_queries = self.query_stats.cached_queries + 1
    elseif success then
        self.query_stats.successful_queries = self.query_stats.successful_queries + 1
        
        -- 更新平均响应时间
        local total_response_time = self.query_stats.average_response_time * (self.query_stats.successful_queries - 1) + response_time
        self.query_stats.average_response_time = total_response_time / self.query_stats.successful_queries
    else
        self.query_stats.failed_queries = self.query_stats.failed_queries + 1
    end
end

-- 缓存查询结果
function RuleQueryManager:cacheQuery(question, context_data, response)
    local cache_manager = self:getModule("CacheManager")
    if not cache_manager then
        return
    end
    
    local cache_key = self:generateQueryCacheKey(question, context_data)
    cache_manager:set("rule_query", cache_key, response, self.config.cache_duration)
end

-- 获取缓存的查询结果
function RuleQueryManager:getCachedQuery(question, context_data)
    local cache_manager = self:getModule("CacheManager")
    if not cache_manager then
        return nil
    end
    
    local cache_key = self:generateQueryCacheKey(question, context_data)
    return cache_manager:get("rule_query", cache_key)
end

-- 生成查询缓存键
function RuleQueryManager:generateQueryCacheKey(question, context_data)
    local key_parts = {question}
    
    -- 添加上下文数据的哈希
    if context_data then
        local context_str = JSON.encode(context_data)
        -- 简单哈希
        local hash = 0
        for i = 1, string.len(context_str) do
            hash = (hash + string.byte(context_str, i)) % 10000
        end
        table.insert(key_parts, tostring(hash))
    end
    
    return table.concat(key_parts, "_")
end

-- 生成查询ID
function RuleQueryManager:generateQueryId()
    return "query_" .. os.time() .. "_" .. math.random(1000, 9999)
end

-- 加载规则文档
function RuleQueryManager:loadRuleDocument(document_data, document_id, options)
    if not document_data then
        Logger:error("规则文档数据为空")
        return false
    end
    
    document_id = document_id or ("doc_" .. os.time())
    options = options or {}
    
    -- 验证文档大小
    local content_size = string.len(document_data.content or "")
    if content_size > self.config.max_document_size then
        Logger:error("规则文档过大", {
            size = content_size,
            max_size = self.config.max_document_size
        })
        return false
    end
    
    -- 创建文档对象
    local document = {
        id = document_id,
        title = document_data.title or document_id,
        content = document_data.content,
        format = document_data.format or "text",
        language = document_data.language or "zh",
        created_time = os.time(),
        enabled = true,
        metadata = document_data.metadata or {}
    }
    
    -- 保存文档
    self.rule_documents[document_id] = document
    
    -- 持久化存储
    local storage_manager = self:getModule("StorageManager")
    if storage_manager then
        storage_manager:saveData("modules", "rule_documents", self.rule_documents)
    end
    
    Logger:info("规则文档已加载", {
        document_id = document_id,
        title = document.title,
        content_size = content_size
    })
    
    return true
end

-- 删除规则文档
function RuleQueryManager:removeRuleDocument(document_id)
    if not self.rule_documents[document_id] then
        Logger:warning("未找到要删除的规则文档", {document_id = document_id})
        return false
    end
    
    self.rule_documents[document_id] = nil
    
    -- 更新持久化存储
    local storage_manager = self:getModule("StorageManager")
    if storage_manager then
        storage_manager:saveData("modules", "rule_documents", self.rule_documents)
    end
    
    Logger:info("规则文档已删除", {document_id = document_id})
    return true
end

-- 获取查询历史
function RuleQueryManager:getQueryHistory(limit)
    limit = limit or 20
    local history = {}
    
    for i = 1, math.min(limit, #self.query_history) do
        table.insert(history, self.query_history[i])
    end
    
    return history
end

-- 清除查询缓存
function RuleQueryManager:clearQueryCache()
    local cache_manager = self:getModule("CacheManager")
    if cache_manager then
        cache_manager:clearByType("rule_query")
        Logger:info("查询缓存已清除")
        return true
    end
    return false
end

-- 获取查询统计
function RuleQueryManager:getQueryStats()
    local stats = {}
    for key, value in pairs(self.query_stats) do
        stats[key] = value
    end
    
    -- 计算成功率
    if stats.total_queries > 0 then
        stats.success_rate = math.floor((stats.successful_queries / stats.total_queries) * 100)
        stats.cache_hit_rate = math.floor((stats.cached_queries / stats.total_queries) * 100)
    else
        stats.success_rate = 0
        stats.cache_hit_rate = 0
    end
    
    return stats
end

-- 获取文档数量
function RuleQueryManager:getDocumentCount()
    local count = 0
    for _ in pairs(self.rule_documents) do
        count = count + 1
    end
    return count
end

-- 便捷方法：基础规则查询
function RuleQueryManager:basicQuery(question, callback)
    return self:queryRule(question, {query_type = self.QUERY_TYPES.BASIC}, callback)
end

-- 便捷方法：上下文感知查询
function RuleQueryManager:contextualQuery(question, context_data, callback)
    return self:queryRule(question, {
        query_type = self.QUERY_TYPES.CONTEXTUAL,
        context_data = context_data
    }, callback)
end

-- 便捷方法：对象特定查询
function RuleQueryManager:objectQuery(question, object_info, callback)
    return self:queryRule(question, {
        query_type = self.QUERY_TYPES.OBJECT_SPECIFIC,
        object_info = object_info
    }, callback)
end

-- 获取保存数据
function RuleQueryManager:getSaveData()
    return {
        query_history = self.query_history,
        rule_documents = self.rule_documents,
        query_stats = self.query_stats,
        version = self.version
    }
end

-- 子类关闭方法
function RuleQueryManager:onShutdown()
    -- 清理活跃查询
    for query_id, query in pairs(self.active_queries) do
        if query.callback then
            query.callback(nil, "服务正在关闭")
        end
    end
    
    Logger:info("规则查询管理器已关闭", {
        final_stats = self:getQueryStats()
    })
end

-- 导出RuleQueryManager模块
return RuleQueryManager 