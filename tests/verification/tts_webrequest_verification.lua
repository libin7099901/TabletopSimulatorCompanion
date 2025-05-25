--[[
    TTS WebRequest API 验证脚本
    版本: 1.0.0
    作者: LeadDeveloperAI (达里奥)
    创建时间: 2025-01-27
    
    目的: 验证TTS的WebRequest功能是否满足LLM集成需求
    关键验证点:
    - HTTPS POST请求能力
    - JSON数据传输
    - 大请求体支持 (上下文数据)
    - 异步响应处理
    - 错误处理机制
--]]

-- TTS WebRequest验证套件
local TTSWebRequestVerification = {}

-- 测试配置
TTSWebRequestVerification.test_config = {
    -- 测试用的公开API端点
    test_endpoints = {
        -- JSONPlaceholder - 测试REST API
        json_test = "https://jsonplaceholder.typicode.com/posts",
        -- HTTPBin - 测试HTTP功能
        httpbin_post = "https://httpbin.org/post",
        httpbin_headers = "https://httpbin.org/headers",
        -- 模拟OpenAI API格式 (用于测试请求格式)
        mock_openai = "https://httpbin.org/post"
    },
    
    -- 测试超时设置
    timeout = 30,
    
    -- 测试结果存储
    results = {},
    current_test = nil
}

-- 初始化验证
function TTSWebRequestVerification:initialize()
    Logger:info("开始TTS WebRequest API验证")
    
    -- 检查WebRequest是否可用
    if not WebRequest then
        Logger:error("WebRequest对象不可用，TTS可能不支持网络请求")
        return false
    end
    
    -- 检查必要的WebRequest方法
    local required_methods = {"get", "post", "put"}
    for _, method in ipairs(required_methods) do
        if not WebRequest[method] then
            Logger:error("WebRequest." .. method .. " 方法不可用")
            return false
        end
    end
    
    Logger:info("WebRequest基础检查通过")
    return true
end

-- 测试1: 基础GET请求
function TTSWebRequestVerification:testBasicGetRequest()
    self.current_test = "基础GET请求测试"
    Logger:info("开始" .. self.current_test)
    
    local test_result = {
        test_name = self.current_test,
        start_time = os.clock(),
        success = false,
        error_message = nil,
        response_data = nil
    }
    
    -- 发送GET请求
    WebRequest.get(self.test_config.test_endpoints.json_test, function(request)
        test_result.end_time = os.clock()
        test_result.response_time = test_result.end_time - test_result.start_time
        
        if request.is_error then
            test_result.error_message = "请求失败: " .. (request.error or "未知错误")
            Logger:error(test_result.error_message)
        else
            test_result.success = true
            test_result.response_data = {
                status_code = request.response_code,
                content_length = string.len(request.text or ""),
                has_json = request.text and string.sub(request.text, 1, 1) == "["
            }
            Logger:info("GET请求成功", test_result.response_data)
        end
        
        table.insert(self.test_config.results, test_result)
        
        -- 继续下一个测试
        self:testBasicPostRequest()
    end)
end

-- 测试2: 基础POST请求
function TTSWebRequestVerification:testBasicPostRequest()
    self.current_test = "基础POST请求测试"
    Logger:info("开始" .. self.current_test)
    
    local test_result = {
        test_name = self.current_test,
        start_time = os.clock(),
        success = false,
        error_message = nil,
        response_data = nil
    }
    
    -- 准备POST数据
    local post_data = JSON.encode({
        title = "TTS API Test",
        body = "Testing WebRequest POST functionality",
        userId = 1
    })
    
    -- 发送POST请求
    WebRequest.post(self.test_config.test_endpoints.httpbin_post, post_data, function(request)
        test_result.end_time = os.clock()
        test_result.response_time = test_result.end_time - test_result.start_time
        
        if request.is_error then
            test_result.error_message = "POST请求失败: " .. (request.error or "未知错误")
            Logger:error(test_result.error_message)
        else
            test_result.success = true
            test_result.response_data = {
                status_code = request.response_code,
                content_length = string.len(request.text or ""),
                echo_detected = request.text and string.find(request.text, "TTS API Test") ~= nil
            }
            Logger:info("POST请求成功", test_result.response_data)
        end
        
        table.insert(self.test_config.results, test_result)
        
        -- 继续下一个测试
        self:testJsonRequest()
    end)
end

-- 测试3: JSON格式请求 (模拟LLM API)
function TTSWebRequestVerification:testJsonRequest()
    self.current_test = "JSON格式请求测试"
    Logger:info("开始" .. self.current_test)
    
    local test_result = {
        test_name = self.current_test,
        start_time = os.clock(),
        success = false,
        error_message = nil,
        response_data = nil
    }
    
    -- 模拟OpenAI API请求格式
    local llm_request = {
        model = "gpt-3.5-turbo",
        messages = {
            {
                role = "system",
                content = "You are a helpful tabletop game rules assistant."
            },
            {
                role = "user", 
                content = "Can I move my piece diagonally in chess?"
            }
        },
        max_tokens = 150,
        temperature = 0.7
    }
    
    local json_data = JSON.encode(llm_request)
    
    -- 设置请求头 (如果TTS支持)
    local headers = {
        ["Content-Type"] = "application/json",
        ["User-Agent"] = "TabletopCompanion/1.0"
    }
    
    -- 尝试带头信息的POST请求
    WebRequest.post(self.test_config.test_endpoints.mock_openai, json_data, function(request)
        test_result.end_time = os.clock()
        test_result.response_time = test_result.end_time - test_result.start_time
        
        if request.is_error then
            test_result.error_message = "JSON请求失败: " .. (request.error or "未知错误")
            Logger:error(test_result.error_message)
        else
            test_result.success = true
            test_result.response_data = {
                status_code = request.response_code,
                content_length = string.len(request.text or ""),
                json_echoed = request.text and string.find(request.text, "gpt-3.5-turbo") ~= nil,
                request_size = string.len(json_data)
            }
            Logger:info("JSON请求成功", test_result.response_data)
        end
        
        table.insert(self.test_config.results, test_result)
        
        -- 继续下一个测试
        self:testLargeRequest()
    end)
end

-- 测试4: 大请求测试 (模拟大上下文)
function TTSWebRequestVerification:testLargeRequest()
    self.current_test = "大请求测试"
    Logger:info("开始" .. self.current_test)
    
    local test_result = {
        test_name = self.current_test,
        start_time = os.clock(),
        success = false,
        error_message = nil,
        response_data = nil
    }
    
    -- 生成大量上下文数据 (模拟复杂游戏状态)
    local large_context = {}
    for i = 1, 100 do
        table.insert(large_context, {
            object_id = "game_piece_" .. i,
            position = {x = math.random(1, 10), y = math.random(1, 10)},
            properties = {
                color = "red",
                type = "pawn", 
                owner = "player_" .. math.random(1, 4),
                description = "This is a detailed description of game piece " .. i .. " with various properties and states that players need to know about."
            }
        })
    end
    
    local large_request = {
        model = "gpt-4",
        messages = {
            {
                role = "system",
                content = "You are an expert tabletop game assistant. Use the provided game state context to answer questions accurately."
            },
            {
                role = "user",
                content = "Given the current game state, what moves are available for player_1?"
            }
        },
        context = {
            game_state = large_context,
            current_player = "player_1",
            game_phase = "main_phase",
            turn_number = 15
        }
    }
    
    local large_json = JSON.encode(large_request)
    
    WebRequest.post(self.test_config.test_endpoints.httpbin_post, large_json, function(request)
        test_result.end_time = os.clock()
        test_result.response_time = test_result.end_time - test_result.start_time
        
        if request.is_error then
            test_result.error_message = "大请求失败: " .. (request.error or "未知错误")
            Logger:error(test_result.error_message)
        else
            test_result.success = true
            test_result.response_data = {
                status_code = request.response_code,
                request_size_kb = math.floor(string.len(large_json) / 1024),
                response_size_kb = math.floor(string.len(request.text or "") / 1024),
                large_data_handled = string.len(large_json) > 10000
            }
            Logger:info("大请求成功", test_result.response_data)
        end
        
        table.insert(self.test_config.results, test_result)
        
        -- 继续下一个测试
        self:testErrorHandling()
    end)
end

-- 测试5: 错误处理测试
function TTSWebRequestVerification:testErrorHandling()
    self.current_test = "错误处理测试"
    Logger:info("开始" .. self.current_test)
    
    local test_result = {
        test_name = self.current_test,
        start_time = os.clock(),
        success = false,
        error_message = nil,
        response_data = nil
    }
    
    -- 故意发送到无效端点
    WebRequest.get("https://invalid-domain-for-testing-12345.com/test", function(request)
        test_result.end_time = os.clock()
        test_result.response_time = test_result.end_time - test_result.start_time
        
        -- 这次我们期望错误发生
        if request.is_error then
            test_result.success = true -- 错误处理正确工作
            test_result.response_data = {
                error_detected = true,
                error_message = request.error or "未知错误",
                proper_error_handling = true
            }
            Logger:info("错误处理测试通过", test_result.response_data)
        else
            test_result.error_message = "错误处理测试失败: 应该产生错误但没有"
            Logger:error(test_result.error_message)
        end
        
        table.insert(self.test_config.results, test_result)
        
        -- 完成所有测试
        self:generateReport()
    end)
end

-- 生成验证报告
function TTSWebRequestVerification:generateReport()
    Logger:info("生成TTS WebRequest验证报告")
    
    local report = {
        total_tests = #self.test_config.results,
        passed_tests = 0,
        failed_tests = 0,
        average_response_time = 0,
        capabilities = {
            basic_get = false,
            basic_post = false,
            json_handling = false,
            large_requests = false,
            error_handling = false
        },
        recommendations = {},
        overall_verdict = "UNKNOWN"
    }
    
    local total_response_time = 0
    
    -- 分析测试结果
    for _, result in ipairs(self.test_config.results) do
        if result.success then
            report.passed_tests = report.passed_tests + 1
            
            -- 标记能力
            if result.test_name == "基础GET请求测试" then
                report.capabilities.basic_get = true
            elseif result.test_name == "基础POST请求测试" then
                report.capabilities.basic_post = true
            elseif result.test_name == "JSON格式请求测试" then
                report.capabilities.json_handling = true
            elseif result.test_name == "大请求测试" then
                report.capabilities.large_requests = true
            elseif result.test_name == "错误处理测试" then
                report.capabilities.error_handling = true
            end
        else
            report.failed_tests = report.failed_tests + 1
        end
        
        if result.response_time then
            total_response_time = total_response_time + result.response_time
        end
    end
    
    if report.total_tests > 0 then
        report.average_response_time = total_response_time / report.total_tests
    end
    
    -- 生成建议和最终判断
    if report.capabilities.basic_get and report.capabilities.basic_post and report.capabilities.json_handling then
        if report.capabilities.large_requests and report.capabilities.error_handling then
            report.overall_verdict = "EXCELLENT"
            table.insert(report.recommendations, "TTS WebRequest功能完全满足LLM集成需求")
            table.insert(report.recommendations, "可以立即开始DEV-003开发")
        else
            report.overall_verdict = "GOOD"
            table.insert(report.recommendations, "TTS WebRequest基本功能可用，需要优化大请求处理")
            table.insert(report.recommendations, "建议实现请求分块和重试机制")
        end
    elseif report.capabilities.basic_get and report.capabilities.basic_post then
        report.overall_verdict = "LIMITED"
        table.insert(report.recommendations, "基础网络功能可用，但JSON处理可能有问题")
        table.insert(report.recommendations, "需要实现自定义JSON编码/解码")
        table.insert(report.recommendations, "考虑简化LLM集成方案")
    else
        report.overall_verdict = "INSUFFICIENT"
        table.insert(report.recommendations, "TTS WebRequest功能不足以支持LLM集成")
        table.insert(report.recommendations, "需要考虑替代方案：")
        table.insert(report.recommendations, "1. 用户手动输入API响应")
        table.insert(report.recommendations, "2. 使用外部代理服务")
        table.insert(report.recommendations, "3. 简化为静态规则查询")
    end
    
    -- 输出报告
    Logger:info("=== TTS WebRequest API 验证报告 ===")
    Logger:info("测试概况: " .. report.passed_tests .. "/" .. report.total_tests .. " 通过")
    Logger:info("平均响应时间: " .. string.format("%.2f", report.average_response_time) .. " 秒")
    Logger:info("最终判断: " .. report.overall_verdict)
    
    Logger:info("功能能力评估:")
    for capability, available in pairs(report.capabilities) do
        Logger:info("  " .. capability .. ": " .. (available and "✅" or "❌"))
    end
    
    Logger:info("建议:")
    for _, recommendation in ipairs(report.recommendations) do
        Logger:info("  • " .. recommendation)
    end
    
    Logger:info("=== 验证报告结束 ===")
    
    -- 保存报告到存储系统 (如果可用)
    if _G.TabletopCompanion and TabletopCompanion.getModule then
        local storage_manager = TabletopCompanion:getModule("StorageManager")
        if storage_manager then
            storage_manager:saveData("system", "webrequest_verification", report)
            Logger:info("验证报告已保存到存储系统")
        end
    end
    
    return report
end

-- 开始完整验证流程
function TTSWebRequestVerification:runFullVerification()
    if not self:initialize() then
        Logger:error("WebRequest验证初始化失败")
        return false
    end
    
    Logger:info("开始TTS WebRequest完整验证流程")
    Logger:info("预计耗时: 30-60秒")
    
    -- 启动验证流程
    self:testBasicGetRequest()
    
    return true
end

-- 导出验证模块
return TTSWebRequestVerification 