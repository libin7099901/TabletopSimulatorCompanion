--[[ TabletopSimulatorCompanion (TTS Companion) - Mod Script
Version: 0.3.4
--]]

-- 保存服务器地址和调试模式
local tc_server_address = "http://localhost:5678"
local debug_mode = false

-- TC 消息颜色定义 (r, g, b format, 0-1 range)
local TC_COLORS = {
    INFO = {0.6, 0.8, 1.0},   -- Light Blue
    ANSWER = {0.7, 1.0, 0.7}, -- Light Green
    ERROR = {1.0, 0.6, 0.6},  -- Light Red
    USAGE = {0.9, 0.9, 0.6},  -- Light Yellow
    HELP = {0.8, 0.7, 0.9}    -- Light Purple
}

-- 初始化
function onLoad()
    -- 加载保存的配置
    if self.script_state ~= "" then
        local saved_data = JSON.decode(self.script_state)
        if saved_data.tc_server_address then
            tc_server_address = saved_data.tc_server_address
        end
        if saved_data.debug_mode ~= nil then
            debug_mode = saved_data.debug_mode
        end
    end

    log_debug("TTS Companion Mod 已加载")
    log_debug("服务器地址: " .. tc_server_address)

    -- 获取游戏名
    local game_name = Info.name or ""

    -- 通知服务器游戏已加载
    if game_name ~= "" then
        log_debug("当前游戏: " .. game_name)
        notify_game_loaded(game_name)
    end
end

-- 保存配置
function onSave()
    local saved_data = {
        tc_server_address = tc_server_address,
        debug_mode = debug_mode
    }
    return JSON.encode(saved_data)
end

-- 游戏更新时检查游戏名变化
function onUpdate()
    -- 获取游戏名
    local game_name = Info.name or ""

    -- 检查游戏名是否变化
    local current_game = self.getVar("current_game") or ""
    if game_name ~= "" and game_name ~= current_game then
        self.setVar("current_game", game_name)
        log_debug("游戏已变更: " .. game_name)
        notify_game_loaded(game_name)
    end
end

-- 聊天监听
function onChat(message, player)
    -- 处理提问命令: @tc <问题>
    if string.sub(message, 1, 3) == "@tc" then
        if Player[player.color] then Player[player.color].print(player.steam_name .. ": " .. message) end -- 任务3: 回显输入
        local question_raw = string.sub(message, 4)
        local question = question_raw:gsub("^%s+", ""):gsub("%s+$", "") -- 去除首尾空格
        if question ~= "" then
            handle_question(question, player)
            return false -- 不在聊天中显示命令
        end
    end

    -- 处理管理命令: tc <命令>
    if string.sub(message, 1, 3) == "tc " then
        if Player[player.color] then Player[player.color].print(player.steam_name .. ": " .. message) end -- 任务3: 回显输入
        local cmd = string.sub(message, 4)
        handle_command(cmd, player)
        return false -- 不在聊天中显示命令
    end

    return true -- 允许其他聊天消息正常显示
end

-- 将格式化的TC消息发送给特定玩家
function tc_message_to_player(player_steam_color, message_content, message_type_key)
    local color_rgb_table = TC_COLORS[message_type_key] or TC_COLORS.INFO -- Fallback to INFO color
    local display_prefix = ""
    if message_type_key == "ANSWER" then display_prefix = "[TC-回答] "
    elseif message_type_key == "INFO" then display_prefix = "[TC-信息] "
    elseif message_type_key == "ERROR" then display_prefix = "[TC-错误] "
    elseif message_type_key == "USAGE" then display_prefix = "[TC-用法] "
    elseif message_type_key == "HELP" then display_prefix = "[TC-帮助] "
    else display_prefix = "[TC] " end -- Fallback prefix

    if Player[player_steam_color] then
        Player[player_steam_color].print(display_prefix .. message_content, color_rgb_table)
    else
        -- 如果找不到玩家对象，记录到服务器控制台 (避免游戏内刷屏)
        log_debug("Player " .. player_steam_color .. " not found for private message: " .. display_prefix .. message_content)
        -- 也可以考虑用 printToColor 公开显示一个通用错误，但可能会打扰其他玩家
        -- printToColor("[TC-系统错误] 无法向特定玩家发送消息。", TC_COLORS.ERROR)
    end
end

-- 处理问题
function handle_question(question, player)
    -- 获取游戏名
    local game_name = Info.name or ""

    if game_name == "" then
        tc_message_to_player(player.color, "无法确定当前游戏名称。", "ERROR")
        return
    end

    -- 获取玩家ID (使用颜色)
    local player_id = player.color

    -- 准备请求
    local request = {
        question = question,
        game_name = game_name,
        player_info = {
            player_id = player_id
        }
    }

    tc_message_to_player(player.color, "正在思考中...", "INFO")

    -- 发送请求到服务器
    local headers = { ["Content-Type"] = "application/json" }
    WebRequest.custom(tc_server_address .. "/ask","POST", true,  JSON.encode(request), headers, function(response)
        if response.is_error then
            tc_message_to_player(player.color, "服务器连接错误: " .. response.error, "ERROR")
            return
        end

        if response.text then
            local success, data = pcall(JSON.decode, response.text)
            if not success or type(data) ~= "table" then
                tc_message_to_player(player.color, "无法解析服务器响应。", "ERROR")
                log_debug("Failed to decode JSON response: " .. response.text)
                return
            end

            if data.error then
                tc_message_to_player(player.color, "错误: " .. data.error, "ERROR")
            else
                -- 确保响应与请求的玩家ID匹配
                local response_player_id = data.player_id
                if response_player_id == player_id then
                    tc_message_to_player(player_id, data.answer or "收到空的回答。", "ANSWER")
                else
                    log_debug("Player ID mismatch. Expected: " .. player_id .. ", Got: " .. (response_player_id or "nil"))
                    -- Potentially inform the original player about the mismatch if it's a critical error path
                end
            end
        else
            tc_message_to_player(player.color, "无法获取回答，服务器未返回任何文本。", "ERROR")
        end
    end, headers)
end

-- 处理命令
function handle_command(cmd, player)
    -- 分割命令和参数
    local args = {}
    for arg in string.gmatch(cmd, "%S+") do
        table.insert(args, arg)
    end

    local command = args[1]

    if command == "set_server" then
        handle_set_server_command(args, player)
    elseif command == "debug_mode" then
        handle_debug_mode_command(args, player)
    elseif command == "reset_session" then
        handle_reset_session_command(args, player)
    elseif command == "rulebook" then
        handle_rulebook_command(args, player)
    elseif command == "help" then
        handle_help_command(player)
    else
        tc_message_to_player(player.color, "未知命令 '" .. command .. "'. 输入 'tc help' 获取帮助。", "ERROR")
    end
end

-- 设置服务器地址命令
function handle_set_server_command(args, player)
    if #args < 2 then
        tc_message_to_player(player.color, "用法: tc set_server <地址>", "USAGE")
        return
    end

    tc_server_address = args[2]
    self.script_state = JSON.encode({
        tc_server_address = tc_server_address,
        debug_mode = debug_mode
    })

    tc_message_to_player(player.color, "服务器地址已设置为: " .. tc_server_address, "INFO")
    log_debug("服务器地址已更新: " .. tc_server_address)
end

-- 调试模式命令
function handle_debug_mode_command(args, player)
    if #args < 2 then
        tc_message_to_player(player.color, "用法: tc debug_mode <true|false>", "USAGE")
        return
    end

    if args[2] == "true" then
        debug_mode = true
    elseif args[2] == "false" then
        debug_mode = false
    else
        tc_message_to_player(player.color, "用法: tc debug_mode <true|false>", "USAGE")
        return
    end

    self.script_state = JSON.encode({
        tc_server_address = tc_server_address,
        debug_mode = debug_mode
    })

    tc_message_to_player(player.color, "调试模式已" .. (debug_mode and "开启" or "关闭"), "INFO")
end

-- 重置会话命令
function handle_reset_session_command(args, player)
    -- 获取游戏名
    local game_name = Info.name or ""

    if game_name == "" then
        tc_message_to_player(player.color, "无法确定当前游戏名称。", "ERROR")
        return
    end

    local request_body = {
        game_name = game_name,
        player_info = {} -- Default to all players for this game if not specified
    }

    if #args > 1 then -- Player ID or "all" is provided
        if args[2] ~= "all" then
            request_body.player_info.player_id = args[2] -- Specific player ID
        else
            -- If "all", we send an empty player_info, or explicitly signal 'all' if API supports
            -- Current API design: if no player_id, it clears all for game_name
            -- So, if args[2] == "all", player_info remains empty as intended
        end
    else -- No argument, reset for current player
        request_body.player_info.player_id = player.color
    end

    local headers = { ["Content-Type"] = "application/json" }
    WebRequest.custom(tc_server_address .. "/session/reset","POST", true,  JSON.encode(request_body), headers, function(response)
        if response.is_error then
            tc_message_to_player(player.color, "服务器连接错误: " .. response.error, "ERROR")
            return
        end

        if response.text then
            local success, data = pcall(JSON.decode, response.text)
            if not success or type(data) ~= "table" then
                tc_message_to_player(player.color, "无法解析服务器响应。", "ERROR")
                log_debug("Failed to decode JSON for session reset: " .. response.text)
                return
            end

            if data.error then
                tc_message_to_player(player.color, "错误: " .. data.error, "ERROR")
            else
                tc_message_to_player(player.color, data.message or "会话重置操作已发送。", "INFO")
            end
        else
            tc_message_to_player(player.color, "服务器未返回会话重置确认信息。", "ERROR")
        end
    end, headers)
end

-- 规则书命令
function handle_rulebook_command(args, player)
    if #args < 2 then
        tc_message_to_player(player.color, "用法: tc rulebook <list|refresh_cache> [参数]", "USAGE")
        return
    end

    -- 获取游戏名
    local game_name = Info.name or ""

    if game_name == "" then
        tc_message_to_player(player.color, "无法确定当前游戏名称。", "ERROR")
        return
    end

    local subcommand = args[2]

    if subcommand == "list" then
        WebRequest.get(tc_server_address .. "/rulebook?game_name=" .. url_encode(game_name), function(response)
            if response.is_error then
                tc_message_to_player(player.color, "服务器连接错误: " .. response.error, "ERROR")
                return
            end

            if response.text then
                local success, data = pcall(JSON.decode, response.text)
                if not success or type(data) ~= "table" then
                     tc_message_to_player(player.color, "无法解析规则书列表响应。", "ERROR")
                     log_debug("Failed to decode JSON for rulebook list: " .. response.text)
                     return
                end

                if data.error then
                    tc_message_to_player(player.color, "获取规则书列表错误: " .. data.error, "ERROR")
                elseif type(data.rulebooks) ~= "table" or #data.rulebooks == 0 then
                    tc_message_to_player(player.color, "当前游戏没有可用的规则书。", "INFO")
                else
                    tc_message_to_player(player.color, "可用的规则书:", "INFO")
                    for _, rulebook in ipairs(data.rulebooks) do
                        local status_str = ""
                        if rulebook.status == "awaiting_user_content" then
                            status_str = "[待填充]"
                        elseif rulebook.status == "processed_into_rag" then
                            status_str = "[已索引]"
                        end
                        local name_str = rulebook.name or "未知规则书"
                        local id_str = rulebook.id or "?"
                        local path_str = rulebook.path or "无路径"
                        tc_message_to_player(player.color, id_str .. ": " .. name_str .. " " .. status_str, "INFO")
                        tc_message_to_player(player.color, "    路径: " .. path_str, "INFO")
                    end
                end
            else
                 tc_message_to_player(player.color, "服务器未返回规则书列表。", "ERROR")
            end
        end)
    elseif subcommand == "refresh_cache" then
        if #args < 3 then
            tc_message_to_player(player.color, "用法: tc rulebook refresh_cache <编号或部分文件名>", "USAGE")
            return
        end

        local identifier = table.concat(args, " ", 3) -- Allow identifiers with spaces
        local request_body = {
            game_name = game_name,
            identifier = identifier
        }

        tc_message_to_player(player.color, "正在刷新RAG索引 (" .. identifier ..")...", "INFO")

        local headers = { ["Content-Type"] = "application/json" }
        WebRequest.custom(tc_server_address .. "/api/rulebook/refresh_rag_from_cache","POST", true,  JSON.encode(request_body), headers, function(response)
            if response.is_error then
                tc_message_to_player(player.color, "服务器连接错误: " .. response.error, "ERROR")
                return
            end

            if response.text then
                local success, data = pcall(JSON.decode, response.text)
                if not success or type(data) ~= "table" then
                    tc_message_to_player(player.color, "无法解析刷新索引响应。", "ERROR")
                    log_debug("Failed to decode JSON for refresh_rag: " .. response.text)
                    return
                end

                if data.error then
                    tc_message_to_player(player.color, "刷新索引错误: " .. data.error, "ERROR")
                else
                    tc_message_to_player(player.color, data.message or "RAG索引刷新请求已发送。", "INFO")
                end
            else
                tc_message_to_player(player.color, "服务器未返回刷新索引确认信息。", "ERROR")
            end
        end, headers)
    else
        tc_message_to_player(player.color, "未知规则书子命令 '" .. subcommand .. "'. 可用: list, refresh_cache", "ERROR")
    end
end

-- 帮助命令
function handle_help_command(player)
    tc_message_to_player(player.color, "TTS Companion 命令:", "HELP")
    tc_message_to_player(player.color, "- @tc <问题> - 询问有关游戏规则的问题", "HELP")
    tc_message_to_player(player.color, "- tc rulebook list - 列出当前游戏可用的规则书", "HELP")
    tc_message_to_player(player.color, "- tc rulebook refresh_cache <编号或部分文件名> - 从编辑的规则书文件更新RAG索引", "HELP")
    tc_message_to_player(player.color, "- tc set_server <地址> - 设置服务器地址 (例如: http://localhost:5678)", "HELP")
    tc_message_to_player(player.color, "- tc reset_session [玩家ID|all] - 重置会话记忆 (默认当前玩家, 'all'为游戏中所有玩家)", "HELP")
    tc_message_to_player(player.color, "- tc debug_mode <true|false> - 开启或关闭调试日志", "HELP")
    tc_message_to_player(player.color, "- tc help - 显示此帮助信息", "HELP")
end

-- 通知服务器游戏已加载
function notify_game_loaded(game_name)
    local request_body = {
        game_name = game_name
    }

    local headers = { ["Content-Type"] = "application/json" }
    WebRequest.custom(tc_server_address .. "/api/game/loaded","POST", true,  JSON.encode(request_body), headers, function(response)
        if response.is_error then
            log_debug("通知游戏加载失败: " .. response.error)
            return
        end

        if response.text then
            local success, data = pcall(JSON.decode, response.text)
            if success and type(data) == "table" and data.message then
                 log_debug("游戏加载通知响应: " .. data.message)
                 if data.auto_rag_loaded then
                    log_debug("游戏 '" .. game_name .. "' RAG索引已自动加载")
                 end
            else
                log_debug("无法解析游戏加载响应或无消息: " .. response.text)
            end
        end
    end, headers)
end

-- URL编码函数
function url_encode(str)
    if str then
        str = string.gsub(str, "\\n", "\\r\\n")
        str = string.gsub(str, "([^%w %-%_%.%~])",
            function(c) return string.format("%%%02X", string.byte(c)) end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

-- 调试日志
function log_debug(message)
    if debug_mode then
        print("[TC-DEBUG] " .. message)
    end
end