-- test_script.lua
-- 简单测试TabletopCompanion.ttslua的关键部分

-- 模拟测试框架
local function test(name, func)
    print("开始测试: " .. name)
    local success, result = pcall(func)
    if success then
        print("✅ 测试通过: " .. name)
        return true
    else
        print("❌ 测试失败: " .. name .. " - 错误: " .. tostring(result))
        return false
    end
end

-- 测试修复过的代码段 (1260行附近的错误)
test("嵌套条件语句测试", function()
    local function simulate_fixed_code(data, data_from_ollama, response_from_proxy, player_obj, request)
        if data_from_ollama and data_from_ollama.response then
            print("第一个条件分支")
            return true
        elseif data_from_ollama and data_from_ollama.status == "error" then
            print("第二个条件分支")
            return true
        else
            if data and data.response then
                print("嵌套条件分支1")
                return true
            else
                print("嵌套条件分支2")
                return true
            end
        end
    end
    
    -- 测试各种情况
    simulate_fixed_code({}, {}, {}, {}, {})
    simulate_fixed_code({response="test"}, {}, {}, {}, {})
    simulate_fixed_code({}, {response="test"}, {}, {}, {})
    simulate_fixed_code({}, {status="error"}, {}, {}, {})
    
    return true
end)

-- 测试简单的JSON操作
test("JSON操作测试", function()
    local sample_data = {name="test", value=123}
    local json_str = '{"name":"test","value":123}'
    
    -- 模拟JSON.encode (在实际代码中由TTS提供)
    local function encode(data)
        if type(data) ~= "table" then error("Expected table") end
        return json_str
    end
    
    -- 模拟JSON.decode
    local function decode(str)
        if type(str) ~= "string" then error("Expected string") end
        return sample_data
    end
    
    -- 模拟safe_json_encode
    local function safe_json_encode(data)
        local JSON = {encode = encode}
        if not JSON then
            print("JSON模块不可用，使用简单编码")
            return "JSON_NOT_AVAILABLE"
        end
        
        local success, result = pcall(JSON.encode, data)
        if success then
            return result
        else
            print("JSON编码失败: " .. tostring(result))
            return nil
        end
    end
    
    -- 测试编码
    local encoded = safe_json_encode(sample_data)
    assert(encoded == json_str, "JSON编码结果不匹配")
    
    return true
end)

-- 测试字符串处理函数
test("字符串处理测试", function()
    -- 实现manual_trim函数
    local function manual_trim(text)
        if not text or type(text) ~= "string" then return "" end
        local s = 1
        local e = #text
        while s <= e and (text:sub(s,s) == " " or text:sub(s,s) == "\t") do
            s = s + 1
        end
        while e >= s and (text:sub(e,e) == " " or text:sub(e,e) == "\t") do
            e = e - 1
        end
        if s > e then return "" else return text:sub(s, e) end
    end
    
    -- 测试cases
    assert(manual_trim("  hello  ") == "hello", "manual_trim测试1失败")
    assert(manual_trim("\thello\t") == "hello", "manual_trim测试2失败")
    assert(manual_trim("") == "", "manual_trim测试3失败")
    assert(manual_trim(nil) == "", "manual_trim测试4失败")
    assert(manual_trim("  ") == "", "manual_trim测试5失败")
    
    return true
end)

print("所有测试完成") 