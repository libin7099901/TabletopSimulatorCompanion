--[[ TabletopSimulatorCompanion (TTS Companion) - Mod Script
Version: 0.3.4
--]]

-- 保存服务器地址和调试模式
local tc_server_address = "http://localhost:5678"
local debug_mode = false

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
        local question = string.sub(message, 4):match("^%s*(.-)%s*$") -- 去除首尾空格
        if question ~= "" then
            handle_question(question, player)
            return false -- 不在聊天中显示命令
        end
    end

    -- 处理管理命令: tc <命令>
    if string.sub(message, 1, 3) == "tc " then
        local cmd = string.sub(message, 4)
        handle_command(cmd, player)
        return false -- 不在聊天中显示命令
    end

    return true -- 允许其他聊天消息正常显示
end

-- 处理问题
function handle_question(question, player)
    -- 获取游戏名
    local game_name = Info.name or ""

    if game_name == "" then
        player_broadcast(player.color, "无法确定当前游戏名称。")
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

    player_broadcast(player.color, "正在思考中...")

    -- 发送请求到服务器
    local headers = { ["Content-Type"] = "application/json" }
    WebRequest.custom(tc_server_address .. "/ask","POST", true,  JSON.encode(request), headers, function(response)
        if response.is_error then
            player_broadcast(player.color, "服务器错误: " .. response.error)
            return
        end

        if response.text then
            local data = JSON.decode(response.text)
            if data.error then
                player_broadcast(player.color, "错误: " .. data.error)
            else
                -- 确保响应与请求的玩家ID匹配
                local response_player_id = data.player_id
                if response_player_id == player_id then
                    player_broadcast(player.color, data.answer)
                end
            end
        else
            player_broadcast(player.color, "无法获取回答")
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
        player_broadcast(player.color, "未知命令 '" .. command .. "'. 输入 'tc help' 获取帮助。")
    end
end

-- 设置服务器地址命令
function handle_set_server_command(args, player)
    if #args < 2 then
        player_broadcast(player.color, "用法: tc set_server <地址>")
        return
    end

    tc_server_address = args[2]
    self.script_state = JSON.encode({
        tc_server_address = tc_server_address,
        debug_mode = debug_mode
    })

    player_broadcast(player.color, "服务器地址已设置为: " .. tc_server_address)
    log_debug("服务器地址已更新: " .. tc_server_address)
end

-- 调试模式命令
function handle_debug_mode_command(args, player)
    if #args < 2 then
        player_broadcast(player.color, "用法: tc debug_mode <true|false>")
        return
    end

    if args[2] == "true" then
        debug_mode = true
    elseif args[2] == "false" then
        debug_mode = false
    else
        player_broadcast(player.color, "用法: tc debug_mode <true|false>")
        return
    end

    self.script_state = JSON.encode({
        tc_server_address = tc_server_address,
        debug_mode = debug_mode
    })

    player_broadcast(player.color, "调试模式已" .. (debug_mode and "开启" or "关闭"))
end

-- 重置会话命令
function handle_reset_session_command(args, player)
    -- 获取游戏名
    local game_name = Info.name or ""

    if game_name == "" then
        player_broadcast(player.color, "无法确定当前游戏名称。")
        return
    end

    local request = {
        game_name = game_name,
        player_info = {}
    }

    if #args > 1 then
        if args[2] ~= "all" then
            request.player_info.player_id = args[2]
        end
    else
        request.player_info.player_id = player.color
    end
    local headers = { ["Content-Type"] = "application/json" }
    WebRequest.custom(tc_server_address .. "/session/reset","POST", true,  JSON.encode(request), headers, function(response)
        if response.is_error then
            player_broadcast(player.color, "服务器错误: " .. response.error)
            return
        end

        if response.text then
            local data = JSON.decode(response.text)
            if data.error then
                player_broadcast(player.color, "错误: " .. data.error)
            else
                player_broadcast(player.color, data.message)
            end
        end
    end, headers)
end

-- 规则书命令
function handle_rulebook_command(args, player)
    if #args < 2 then
        player_broadcast(player.color, "用法: tc rulebook <list|refresh_cache> [参数]")
        return
    end

    -- 获取游戏名
    local game_name = Info.name or ""

    if game_name == "" then
        player_broadcast(player.color, "无法确定当前游戏名称。")
        return
    end

    local subcommand = args[2]

    if subcommand == "list" then
        WebRequest.get(tc_server_address .. "/rulebook?game_name=" .. url_encode(game_name), function(response)
            if response.is_error then
                player_broadcast(player.color, "服务器错误: " .. response.error)
                return
            end

            if response.text then
                local data = JSON.decode(response.text)
                if data.error then
                    player_broadcast(player.color, "错误: " .. data.error)
                elseif #data.rulebooks == 0 then
                    player_broadcast(player.color, "当前游戏没有规则书。")
                else
                    player_broadcast(player.color, "可用的规则书:")
                    for _, rulebook in ipairs(data.rulebooks) do
                        local status_str = ""
                        if rulebook.status == "awaiting_user_content" then
                            status_str = "[待填充]"
                        elseif rulebook.status == "processed_into_rag" then
                            status_str = "[已索引]"
                        end
                        player_broadcast(player.color, rulebook.id .. ": " .. rulebook.name .. " " .. status_str)
                        player_broadcast(player.color, "    路径: " .. rulebook.path)
                    end
                end
            end
        end)
    elseif subcommand == "refresh_cache" then
        if #args < 3 then
            player_broadcast(player.color, "用法: tc rulebook refresh_cache <编号或部分文件名>")
            return
        end

        local identifier = args[3]
        local request = {
            game_name = game_name,
            identifier = identifier
        }

        player_broadcast(player.color, "正在刷新RAG索引...")

        local headers = { ["Content-Type"] = "application/json" }
        WebRequest.custom(tc_server_address .. "/api/rulebook/refresh_rag_from_cache","POST", true,  JSON.encode(request), headers, function(response)
            if response.is_error then
                player_broadcast(player.color, "服务器错误: " .. response.error)
                return
            end

            if response.text then
                local data = JSON.decode(response.text)
                if data.error then
                    player_broadcast(player.color, "错误: " .. data.error)
                else
                    player_broadcast(player.color, data.message)
                end
            end
        end, headers)
    else
        player_broadcast(player.color, "未知子命令 '" .. subcommand .. "'. 可用: list, refresh_cache")
    end
end

-- 帮助命令
function handle_help_command(player)
    player_broadcast(player.color, "TTS Companion 命令:")
    player_broadcast(player.color, "- @tc <问题> - 询问有关游戏规则的问题")
    player_broadcast(player.color, "- tc rulebook list - 列出当前游戏可用的规则书")
    player_broadcast(player.color, "- tc rulebook refresh_cache <编号或部分文件名> - 从编辑的规则书文件更新RAG索引")
    player_broadcast(player.color, "- tc set_server <地址> - 设置服务器地址")
    player_broadcast(player.color, "- tc reset_session [玩家ID|all] - 重置会话记忆")
    player_broadcast(player.color, "- tc debug_mode <true|false> - 设置调试模式")
    player_broadcast(player.color, "- tc help - 显示此帮助信息")
end

-- 通知服务器游戏已加载
function notify_game_loaded(game_name)
    local request = {
        game_name = game_name
    }

    local headers = { ["Content-Type"] = "application/json" }
    WebRequest.custom(tc_server_address .. "/api/game/loaded","POST", true,  JSON.encode(request), headers, function(response)
        if response.is_error then
            log_debug("通知游戏加载失败: " .. response.error)
            return
        end

        if response.text then
            local data = JSON.decode(response.text)
            if data.auto_rag_loaded then
                log_debug("游戏 '" .. game_name .. "' RAG索引已自动加载")
            end
        end
    end, headers)
end

-- URL编码函数
function url_encode(str)
    if str then
        str = string.gsub(str, "\n", "\r\n")
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

-- 给特定玩家广播消息
function player_broadcast(player_color, message)
    printToColor(message, player_color)
end
