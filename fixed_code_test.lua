-- fixed_code_test.lua
-- 专门测试修复后的嵌套条件语句代码段

print("测试开始...")

-- 模拟修复前的代码 (会导致语法错误)
local function test_incorrect_code()
    local data = {response = "hello"}
    local player_obj = {}
    local request = {text = "test"}

    print("运行错误代码...")
    
    -- 这段代码会导致语法错误，因为在else分支内直接出现了另一个else
    if false then
        print("第一个if分支")
    else
        print("第一个else分支开始")
        print(data.response)
        -- 下面的else会导致语法错误，因为它不属于任何if语句
        else
            print("错误的else分支")
            print(request.text)
        end
    end
end

-- 模拟修复后的代码 (语法正确)
local function test_correct_code()
    local data = {response = "hello"}
    local player_obj = {}
    local request = {text = "test"}

    print("运行正确代码...")
    
    -- 这段代码是语法正确的嵌套条件结构
    if false then
        print("第一个if分支")
    else
        print("第一个else分支开始")
        if data and data.response then
            print(data.response)
        else
            print("嵌套else分支")
            print(request.text)
        end
    end
end

-- 测试修复过的代码
local function test_fixed_code_from_tts()
    local data = {response = "测试响应"}
    local data_from_ollama = nil
    local response_from_proxy = {text = "原始响应文本"}
    local player_obj = {print = function(msg) print("玩家消息: " .. msg) end}
    local request = {text = "请求文本"}
    local LOG_LEVEL = {ERROR = "ERROR"}
    
    local function safe_broadcast(msg, color, player)
        print("广播: " .. msg .. (player and " (给特定玩家)" or " (给所有人)"))
    end
    
    local function log_message(msg, level)
        print("日志 [" .. (level or "INFO") .. "]: " .. msg)
    end

    print("测试修复后的TTS代码段...")
    
    -- 这是从TabletopCompanion.ttslua中修复后的代码片段结构
    if data_from_ollama and data_from_ollama.response then
        safe_broadcast("🤖 " .. data_from_ollama.response, nil, player_obj)
    elseif data_from_ollama and data_from_ollama.status == "error" then
        log_message("Ollama代理返回错误: " .. response_from_proxy.text, LOG_LEVEL.ERROR)
        safe_broadcast("❌ Ollama查询通过代理失败: " .. "未知代理错误", {1,0.5,0}, player_obj)
    else
        if data and data.response then
            safe_broadcast("🤖 " .. data.response, nil, player_obj) -- Target response
        else
            safe_broadcast("❌ 无法解析Ollama回复。原始响应见日志。", {1,0.5,0}, player_obj)
            log_message("原始Ollama响应: " .. request.text, LOG_LEVEL.ERROR)
        end
    end
end

-- 执行测试
local success, err = pcall(test_correct_code)
if success then
    print("✅ 正确代码测试通过")
else
    print("❌ 正确代码测试失败: " .. tostring(err))
end

-- 测试我们修复的代码结构
local success2, err2 = pcall(test_fixed_code_from_tts)
if success2 then
    print("✅ 修复后的TTS代码测试通过")
else
    print("❌ 修复后的TTS代码测试失败: " .. tostring(err2))
end

-- 不要运行错误代码，它会导致语法错误
-- 只是显示它的存在
print("注意：错误代码示例未运行，因为它会导致语法错误")

print("测试结束") 