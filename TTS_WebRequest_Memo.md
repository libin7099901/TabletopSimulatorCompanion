# Tabletop Simulator Lua 网络请求备忘录

本文档旨在记录在 Tabletop Simulator (TTS) Lua 环境中使用 `WebRequest` API 时的一些关键点和常见陷阱，以避免将来重构或开发新功能时重复犯错。

## 1. `WebRequest.custom` (用于 POST, PUT, DELETE 等)

这是发送带有自定义方法、body 和 headers 的请求的主要方式。

**关键参数顺序和类型 (6个参数):**

```lua
WebRequest.custom(url_string, method_string, convert_body_to_json_boolean, body_string, headers_table, callback_function)
```

1.  `url_string` (string): 目标 URL。
2.  `method_string` (string): HTTP 方法，例如 "POST", "PUT"。
3.  `convert_body_to_json_boolean` (boolean): **极其重要！**
    *   如果你的 `body_string` **已经是 JSON 格式的字符串**，这里应该传递 `true`。
    *   如果你的 `body_string` 是普通字符串，或者你想让 TTS 尝试为你处理（通常不推荐用于复杂数据），可以设为 `false`。
    *   **我们遇到的核心错误 `cannot convert a table to a clr type System.Boolean` 就是因为最初将一个 Lua table 作为 `body_string` (第四个参数) 传递，并且第三个参数不是明确的布尔值 `true` 或 `false` (或者传递了错误的参数数量)。**
4.  `body_string` (string): 请求体。
    *   **强烈建议手动将 Lua table 编码为 JSON 字符串** (使用 `JSON.encode(lua_table)`)，然后将得到的字符串作为此参数传递。
    *   如果发送的是空 body (例如某些 POST 或 DELETE 请求)，可以传递一个空JSON对象字符串：`"{}"`。
5.  `headers_table` (table): 一个 Lua table，键值对表示 HTTP headers。
    *   例如，发送 JSON 时务必包含: `{ ["Content-Type"] = "application/json" }`。
6.  `callback_function` (function): 请求完成后调用的函数。签名通常为 `function(response_object)`。

**示例 (发送 JSON 数据):**

```lua
local payload = { key = "value", number = 123 }
local json_payload_str, encode_err = safe_json_encode(payload) -- safe_json_encode 是自定义的包装函数

if not json_payload_str then
    log_message("Error encoding JSON: " .. tostring(encode_err))
    return
end

local headers = { ["Content-Type"] = "application/json" }
local url = "http://localhost:5678/api/data"

WebRequest.custom(
    url, 
    "POST", 
    true, --因为 json_payload_str 已经是 JSON 字符串
    json_payload_str, 
    headers, 
    function(response_obj) 
        -- 在回调中处理 response_obj
    end
)
```

## 2. `WebRequest.get` (用于 GET 请求)

相对简单，通常用于获取数据，不包含请求体。

**关键参数顺序和类型 (2个参数):**

```lua
WebRequest.get(url_string, callback_function)
```

1.  `url_string` (string): 目标 URL。
2.  `callback_function` (function): 请求完成后调用的函数。签名通常为 `function(response_object)`。

## 3. 处理回调函数中的 `response_object`

回调函数接收一个 `response_object` (名称自定义，例如 `request`, `response_data`, `www` 等)。此对象的结构对于 `WebRequest.custom` 和 `WebRequest.get` 是相似的，但错误检查方式可能略有不同（尽管我们项目中已统一）。

**核心字段:**

*   `response_object.is_error` (boolean): **TTS 请求层面**是否发生错误 (例如网络连接失败、DNS解析错误、URL无效等)。这是 **首要检查点**。
    *   如果为 `true`，则 `response_object.error` (string) 和 `response_object.error_code` (number) 会包含错误详情。
*   `response_object.text` (string): 服务器返回的响应体文本。只有在 `is_error` 为 `false` 时才有意义去访问。
*   `response_object.url` (string): 请求的原始 URL。
*   `response_object.bytes_downloaded` (number): 下载的字节数。
*   `response_object.upload_progress` (number): 上传进度 (0-1)。
*   `response_object.download_progress` (number): 下载进度 (0-1)。

**推荐的回调处理逻辑:**

```lua
function handle_my_callback(response_obj, player_for_response, operation_description)
    operation_description = operation_description or "网络操作"

    -- 1. 检查回调对象本身是否为 nil (不太可能发生，但以防万一)
    if not response_obj then
        log_message(operation_description .. ": 回调收到的 response_obj 为 nil。", LOG_LEVEL.ERROR)
        safe_broadcast(operation_description .. "失败：内部错误，回调对象为空。", {1,0,0}, player_for_response)
        return 
    end

    -- 2. 检查 TTS WebRequest 请求本身的错误
    -- 对于 WebRequest.custom 和 WebRequest.get，可以直接访问 .is_error
    if response_obj.is_error then
        log_message(string.format("%s: TTS 请求错误。代码: %s, 消息: %s", 
            operation_description, tostring(response_obj.error_code), tostring(response_obj.error)), LOG_LEVEL.ERROR)
        safe_broadcast(string.format("❌ %s失败 (TTS错误码: %s)。详情请查看Mod控制台。", 
            operation_description, tostring(response_obj.error_code)), {1,0,0}, player_for_response)
        return
    end

    -- 3. 获取响应文本 (此时 is_error 为 false，TTS层面请求成功)
    local response_body_str = response_obj.text
    if not response_body_str or response_body_str == "" then
        log_message(operation_description .. ": 服务器响应体为空 (但TTS请求成功)。", LOG_LEVEL.WARNING)
        safe_broadcast(operation_description .. "警告：服务器返回了空内容。", {1,0.5,0}, player_for_response)
        -- 根据业务逻辑，空响应也可能是一种有效情况，不一定总是错误
        -- return -- 可能需要根据情况决定是否在此处返回
    end

    -- 4. 尝试将响应文本解码为 JSON (如果期望的是JSON)
    local decoded_data, decode_error_msg = safe_json_decode(response_body_str) -- 自定义安全解码函数
    if not decoded_data then
        log_message(string.format("%s: 无法解码服务器响应JSON。错误: %s. 原始响应: %s", 
            operation_description, tostring(decode_error_msg), response_body_str), LOG_LEVEL.ERROR)
        safe_broadcast(string.format("❌ %s失败：无法解析服务器响应数据。", operation_description), {1,0,0}, player_for_response)
        return
    end

    -- 5. 处理解码后的数据 (服务器应用层面的逻辑)
    if decoded_data.status and decoded_data.status == "success" then
        log_message(operation_description .. " 成功完成。消息: " .. (decoded_data.message or ""), LOG_LEVEL.INFO)
        safe_broadcast(string.format("✅ %s成功！%s", operation_description, (decoded_data.message or "")), {0,1,0}, player_for_response)
        -- ... 执行成功后的操作 ...
    elseif decoded_data.status and decoded_data.status == "error" then
        log_message(string.format("%s: 服务器返回错误。消息: %s. 详情: %s", 
            operation_description, tostring(decoded_data.message), tostring(decoded_data.detail or "N/A")), LOG_LEVEL.ERROR)
        safe_broadcast(string.format("❌ %s失败 (服务器错误): %s", 
            operation_description, tostring(decoded_data.message or "未知错误")), {1,0,0}, player_for_response)
    else
        log_message(operation_description .. ": 服务器响应格式未知或缺少状态字段。原始响应: " .. response_body_str, LOG_LEVEL.WARNING)
        safe_broadcast(string.format("⚠️ %s：服务器响应格式意外。", operation_description), {1,0.5,0}, player_for_response)
    end
end
```

## 4. `pcall` 的使用

*   在调用 TTS API 功能（如 `JSON.encode`, `JSON.decode`, `obj:isError()` 等）时，如果这些功能可能因无效输入或意外状态而抛出 Lua 错误，建议使用 `pcall` 来安全地调用它们，以防止整个脚本中断。
*   例如，`response_obj:isError()` 曾导致问题，改为 `local success, result = pcall(response_obj.isError, response_obj)` 或 `local success, result = pcall(function() return response_obj:isError() end)` 更安全。
    *   在我们项目中，对于 `WebRequest.custom` 和 `WebRequest.get` 返回的 `response_obj`，我们已经统一为直接访问 `response_obj.is_error` 字段，这似乎是 TTS API 推荐的且更直接的方式。

## 5. 避免的常见错误总结

*   **`WebRequest.custom` 参数数量/类型错误**: 确保传递所有6个参数，特别是第三个布尔参数和第四个作为字符串的body。
*   **未手动编码 Body 为 JSON 字符串**: 对于POST/PUT JSON数据，总是先用 `JSON.encode` 转换 Lua table，再传递该字符串。
*   **未设置 `Content-Type` header**: 发送JSON时，务必在 `headers_table` 中设置 `["Content-Type"] = "application/json"`。
*   **回调中错误处理不当**: 没有正确检查 `response_object.is_error`，或者在 `is_error` 为 `true` 时仍然尝试访问 `response_object.text`。
*   **JSON 解码失败未处理**: 服务器返回的 `response_object.text` 可能不是有效的JSON，或者与预期结构不符。使用 `safe_json_decode` 并检查其返回值。
*   **混淆 TTS 请求错误和服务端应用错误**: `is_error` 反映的是 HTTP 请求本身是否成功。即使 `is_error` 是 `false`，服务器应用也可能在其 JSON 响应中返回一个业务逻辑错误 (例如 `{status: "error", message: "Invalid input"}` )。

通过遵循这些指南，可以显著减少与TTS网络请求相关的错误。 