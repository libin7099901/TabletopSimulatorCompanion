-- Tabletop Companion (Tabletop Companion)
-- Version: 4.0.5 - Syntax Fix Attempt 2
-- Author: Gemini AI Assistant & User

local VERSION = "4.0.5"

local LOG_LEVEL = {
    DEBUG = "DEBUG",
    INFO = "INFO",
    WARNING = "WARNING",
    ERROR = "ERROR"
}

-- 用于比较日志级别顺序
local LOG_LEVEL_ORDER = { 
    [LOG_LEVEL.DEBUG] = 1, 
    [LOG_LEVEL.INFO] = 2, 
    [LOG_LEVEL.WARNING] = 3, 
    [LOG_LEVEL.ERROR] = 4 
}

local LOCAL_SERVER_URL = "http://localhost:5678"

local state = {
    ready = false,
    ui_minimized = false,
    llm_provider = "none",
    ollama_url = "http://localhost:11434", 
    ollama_model = "gemma:latest", 
    gemini_key = nil,
    gemini_model = "gemini-pro",
    ui_panel_offsets = {
        main = "70 -10", 
        minimized = "70 -10" 
    },
    current_game_name = "Unknown Game",
    game_context = {}, 
    rules_document_type_on_server = "none", 
    rules_document_description_on_server = "Not Loaded", 
    query_count = 0,
    success_count = 0,
    auto_context = true,
    include_objects = true,
    include_players = true,
    include_zones = true,
    include_notebook = true,
    ui_created_once = false,
    min_log_level = LOG_LEVEL.WARNING,
    perform_complex_name_detection = false, -- 新增: 全局控制复杂名称检测
    simple_default_game_name = "Game (Name Detection Simplified)" -- 新增: 复杂检测关闭时使用
}

local function log_message(msg, level)
    level = level or LOG_LEVEL.INFO

    -- 确保 level 和 state.min_log_level 都是有效的日志级别键
    local current_level_order = LOG_LEVEL_ORDER[level]
    local min_level_order = LOG_LEVEL_ORDER[state.min_log_level]

    -- 如果任一级别无效 (在 LOG_LEVEL_ORDER 中找不到对应的数字), 则采取安全措施
    if not current_level_order then
        print("[TC | UNKNOWN_LEVEL_ERROR] Invalid log level provided to log_message: " .. tostring(level) .. ". Original message: " .. tostring(msg))
        return -- 不打印此消息
    end

    if not min_level_order then
        -- 如果 state.min_log_level 无效, 默认按 WARNING 级别处理，并尝试记录这个配置错误
        print("[TC | CONFIG_ERROR] state.min_log_level is invalid: " .. tostring(state.min_log_level) .. ". Defaulting to WARNING comparison for this message.")
        min_level_order = LOG_LEVEL_ORDER[LOG_LEVEL.WARNING] -- 安全默认值
        if not min_level_order then -- 极端情况，LOG_LEVEL_ORDER 或 LOG_LEVEL.WARNING 本身出错了
            print("[TC | CRITICAL_CONFIG_ERROR] Cannot even default min_log_level. Message: " .. tostring(msg))
            return
        end
    end

    -- 根据 state.min_log_level 决定是否打印
    if current_level_order < min_level_order then
        return -- 不打印低于最低配置级别的日志
    end
    
    print("[TC | " .. level .. "] " .. tostring(msg))
end

local function safe_broadcast(msg, color_for_broadcast, player_target)
    local prefix = "[TC] " 
    local full_msg = prefix .. tostring(msg)
    
    -- message_color will be used for player.print if player_target is valid,
    -- OR for broadcastToAll if player_target is not valid.
    local message_color = color_for_broadcast -- Can be nil or a table like {r,g,b}

    if player_target and player_target.print and type(player_target.print) == 'function' then
        local text_color_for_player_print = message_color
        -- TTS player.print typically takes (message, color_table).
        -- If message_color is nil or not a table, use a default (e.g., a light/neutral color).
        if text_color_for_player_print == nil or type(text_color_for_player_print) ~= 'table' then
            text_color_for_player_print = {0.9, 0.9, 0.9} -- Default: light grey/off-white
            if message_color ~= nil then -- Log if a non-table color was provided but ignored
                 log_message(string.format("safe_broadcast: Invalid color type ('%s') provided for player_target, using default text color.", type(message_color)), LOG_LEVEL.DEBUG)
            end
        end

        local success_print, err_print = pcall(player_target.print, full_msg, text_color_for_player_print)
        if not success_print then
            log_message(string.format("safe_broadcast: Cannot send to player %s: %s", tostring(get_obj_prop(player_target, "color", false, "UnknownColor")), tostring(err_print)), LOG_LEVEL.ERROR)
            if broadcastToAll and type(broadcastToAll) == 'function' then
                 -- Use a distinct color for the fallback message if the original message_color was problematic or nil
                 local fallback_color = (type(message_color) == 'table' and message_color) or {1,0.5,0} -- Orange
                 pcall(broadcastToAll, full_msg .. " (定向消息发送失败)", fallback_color)
            end
        end
    elseif broadcastToAll and type(broadcastToAll) == 'function' then
        -- Use message_color if provided and valid, otherwise default green for broadcastToAll
        local color_for_all = (type(message_color) == 'table' and message_color) or {0.2, 0.8, 0.2} 

        local success_bc, err_bc = pcall(broadcastToAll, full_msg, color_for_all)
        if not success_bc then
            log_message(string.format("safe_broadcast: broadcastToAll failed: %s", tostring(err_bc)), LOG_LEVEL.ERROR)
        end
    else
        log_message("safe_broadcast: No broadcast method available. Msg: " .. full_msg, LOG_LEVEL.WARNING)
    end
end

local function safe_player_action(player_obj, action_func, action_name_for_log)
    local log_name = action_name_for_log or "Unknown Action"
    if not player_obj or type(player_obj) ~= 'userdata' or not player_obj.print or type(player_obj.print) ~= 'function' then
        log_message(string.format("safe_player_action: Invalid player object for '%s'.", log_name), LOG_LEVEL.WARNING)
        safe_broadcast(string.format("Error: Invalid player for action '%s'.", log_name), {1,0,0})
        return
    end
    if type(action_func) ~= 'function' then
        log_message(string.format("safe_player_action: No function for '%s'.", log_name), LOG_LEVEL.ERROR)
        safe_broadcast(string.format("Internal Error: Action '%s' misconfigured.", log_name), {1,0,0}, player_obj)
        return
    end
    local success, err = pcall(action_func, player_obj)
    if not success then
        log_message(string.format("safe_player_action: Executing '%s' failed: %s", log_name, tostring(err)), LOG_LEVEL.ERROR) 
        safe_broadcast(string.format("Error performing '%s'.", log_name), {1,0,0}, player_obj)
    end
end

local function get_obj_prop(obj, prop_name, is_method, default_val, ...)
    if not obj or (type(obj) ~= 'userdata' and type(obj) ~= 'table') then return default_val end
    local value
    local success_access, result_access = pcall(function() value = obj[prop_name] end)
    if not success_access then return default_val end
    if is_method then
        if type(value) == 'function' then
            local success_call, result_call = pcall(value, obj, ...)
            if success_call then return result_call else return default_val end
        else return default_val end
    else return value end
end

local function safe_json_encode(data)
    if not JSON or type(JSON.encode) ~= 'function' then
        log_message("JSON.encode not available.", LOG_LEVEL.ERROR) return nil, "JSON_UNAVAILABLE"
    end
    local success, result = pcall(JSON.encode, data)
    if success then return result else log_message("JSON encoding failed: " .. tostring(result), LOG_LEVEL.ERROR) return nil, tostring(result) end
end

local function safe_json_decode(text)
    if not text or text == "" then return nil, "EMPTY_INPUT" end
    if not JSON or type(JSON.decode) ~= 'function' then
        log_message("JSON.decode not available.", LOG_LEVEL.ERROR) return nil, "JSON_UNAVAILABLE"
    end
    local success, result = pcall(JSON.decode, text)
    if success then return result else log_message("JSON decoding failed: " .. tostring(result), LOG_LEVEL.ERROR) return nil, tostring(result) end
end

local function starts_with(text, prefix)
    if not text or type(text) ~= "string" or not prefix or type(prefix) ~= "string" then return false end
    return string.sub(text, 1, #prefix) == prefix
end

local function contains(text, substring)
    if not text or type(text) ~= "string" or not substring or type(substring) ~= "string" then return false end
    return string.find(text, substring, 1, true) ~= nil
end

local function trim(text)
    if not text or type(text) ~= "string" then return "" end
    local s = text
    -- 移除前导空格
    while string.sub(s, 1, 1) == " " do
        s = string.sub(s, 2)
    end
    -- 移除尾随空格
    while string.sub(s, -1, -1) == " " do
        s = string.sub(s, 1, -2)
    end
    return s
end

local function replace_all_literal(text, find_literal, replace_with)
    if not text or type(text) ~= "string" then return text end
    if not find_literal or type(find_literal) ~= "string" or find_literal == "" then return text end
    replace_with = type(replace_with) == "string" and replace_with or ""
    local result_parts = {}
    local current_pos = 1
    local find_len = #find_literal
    while true do
        local start_match, end_match = string.find(text, find_literal, current_pos, true)
        if start_match then
            table.insert(result_parts, text:sub(current_pos, start_match - 1))
            table.insert(result_parts, replace_with)
            current_pos = end_match + 1
        else table.insert(result_parts, text:sub(current_pos)); break end
    end
    return table.concat(result_parts)
end

local function parse_offset_xy(offset_str, default_x, default_y)
    default_x = default_x or 0; default_y = default_y or 0
    if not offset_str or type(offset_str) ~= "string" then return default_x, default_y end
    local x_str, y_str = offset_str:match("([%-?%d%.]+)%s+([%-?%d%.]+)")
    return tonumber(x_str) or default_x, tonumber(y_str) or default_y
end

local function ends_with(text, suffix)
    if not text or type(text) ~= "string" or not suffix or type(suffix) ~= "string" then return false end
    return #suffix == 0 or (#text >= #suffix and string.sub(text, -#suffix) == suffix)
end

local function detect_game_name_internal()
    log_message("detect_game_name_internal TEMPORARILY OVERRIDDEN to return fixed string.", LOG_LEVEL.WARNING)
    return "Fixed Game Name (Debug)"
end

local function gather_general_game_info()
    local game_info = {
        timestamp = os.time(),
        game_name = state.current_game_name,
        player_count = 0,
        seated_players_colors = {},
        turn_info = {current_player_color = "N/A", turn_order = {}, round = nil, phase = nil},
        game_mode = nil
    }
    local detected_name = detect_game_name_internal()
    if detected_name and detected_name ~= "" and detected_name ~= state.current_game_name then
        log_message(string.format("Game name updated from '%s' to '%s'", state.current_game_name, detected_name), LOG_LEVEL.INFO)
        state.current_game_name = detected_name
    end
    game_info.game_name = state.current_game_name
    if getSeatedPlayers and type(getSeatedPlayers) == 'function' then
        local success_sp, seated_colors = pcall(getSeatedPlayers)
        if success_sp and type(seated_colors) == 'table' then
            game_info.seated_players_colors = seated_colors
            game_info.player_count = #seated_colors
        else log_message("getSeatedPlayers call failed.", LOG_LEVEL.WARNING) end
    else log_message("getSeatedPlayers API not available.", LOG_LEVEL.WARNING) end
    if Turn and type(Turn) == 'table' then
        game_info.turn_info.current_player_color = get_obj_prop(Turn, "getTurnColor", true, "N/A")
        game_info.turn_info.turn_order = get_obj_prop(Turn, "getTurnOrder", true, {})
        game_info.turn_info.round = get_obj_prop(Turn, "getRound", true, nil)
        game_info.turn_info.phase = get_obj_prop(Turn, "getPhase", true, nil)
    else log_message("Turn API not available.", LOG_LEVEL.DEBUG) end
    if Info and type(Info) == 'userdata' then
        game_info.game_mode = get_obj_prop(Info, "GameMode", false, nil) 
    else log_message("Info API not available.", LOG_LEVEL.DEBUG) end
    return game_info
end

local function gather_all_objects_info()
    if not state.include_objects then return {} end
    local summary = {
        total_objects = 0, by_type = {}, cards = {}, dice = {}, tokens = {}, figures = {},
        boards = {}, decks = {}, bags = {}, custom_models = {}, custom_tokens = {},
        custom_tiles = {}, custom_cards = {}, custom_dice = {}, custom_figurines = {},
        custom_assetbundles = {}, other = {} -- 添加逗号可能会导致错误
    }
    if not getObjects or type(getObjects) ~= 'function' then log_message("getObjects API not available.", LOG_LEVEL.WARNING); return summary end
    local suc_go, all_obj = pcall(getObjects)
    if not suc_go or not all_obj or type(all_obj) ~= 'table' then log_message("getObjects call failed.", LOG_LEVEL.WARNING); return summary end
    summary.total_objects = #all_obj
    for _, obj_instance in ipairs(all_obj) do
        if obj_instance and type(obj_instance) == 'userdata' then
            local data = {
                guid = get_obj_prop(obj_instance, "getGUID", true, "GUID_N/A"),
                name = get_obj_prop(obj_instance, "getName", true, ""),
                nickname = get_obj_prop(obj_instance, "getNickname", true, ""),
                description = get_obj_prop(obj_instance, "getDescription", true, ""),
                type_str = get_obj_prop(obj_instance, "type", false, "Unknown"),
                tags = get_obj_prop(obj_instance, "getTags", true, {}),
                locked = get_obj_prop(obj_instance, "getLock", true, false),
                gm_notes = get_obj_prop(obj_instance, "getGMNotes", true, ""),
                memo = get_obj_prop(obj_instance, "getMemo", true, nil),
                script_id = get_obj_prop(obj_instance, "getVar", true, nil, "script_id"),
                position = get_obj_prop(obj_instance, "getPosition", true, {x=0,y=0,z=0})
            }
            summary.by_type[data.type_str] = (summary.by_type[data.type_str] or 0) + 1
            local cat = summary.other
            if data.type_str == "Card" then cat = summary.cards
            elseif data.type_str == "Custom_Card" then cat = summary.custom_cards
            elseif data.type_str == "Deck" then cat = summary.decks
            elseif data.type_str == "Bag" then cat = summary.bags
            elseif contains(string.lower(data.name), "token") or contains(string.lower(data.nickname), "token") then cat = summary.tokens
            end
            table.insert(cat, data)
        end
    end
    return summary
end

local function gather_all_players_info()
    if not state.include_players then return {} end
    local players_map = {}
    if not getSeatedPlayers or type(getSeatedPlayers) ~= 'function' or not Player or type(Player) ~= 'table' then
        log_message("Player APIs not available.", LOG_LEVEL.WARNING); return players_map
    end
    local suc_sp, seated_cols = pcall(getSeatedPlayers)
    if not suc_sp or not seated_cols or type(seated_cols) ~= 'table' then log_message("getSeatedPlayers call failed.", LOG_LEVEL.WARNING); return players_map end
    for _, col_str in ipairs(seated_cols) do
        if type(col_str) == 'string' and Player[col_str] and type(Player[col_str]) == 'userdata' then
            local p_inst = Player[col_str]
            players_map[col_str] = {
                color = col_str, steam_name = get_obj_prop(p_inst, "steam_name", false, "N/A"),
                team = get_obj_prop(p_inst, "team", false, "N/A"), promoted = get_obj_prop(p_inst, "promoted", false, false)
            }
        end
    end
    return players_map
end

local function gather_all_zones_info()
    if not state.include_zones then return {} end
    local zones_data = { scripting_zones = {}, layout_zones = {}, other_zones = {} }
    if not getZones or type(getZones) ~= 'function' then log_message("getZones API not available.", LOG_LEVEL.WARNING); return zones_data end
    local suc_gz, zones_list = pcall(getZones)
    if not suc_gz or not zones_list or type(zones_list) ~= 'table' then log_message("getZones call failed.", LOG_LEVEL.WARNING); return zones_data end
    for _, zone_inst in ipairs(zones_list) do
        if zone_inst and type(zone_inst) == 'userdata' then
            local z_data = {guid = get_obj_prop(zone_inst, "getGUID", true, "GUID_N/A"), type_str = get_obj_prop(zone_inst, "type", false, "Unknown")}
            if z_data.type_str == "ScriptingZone" then table.insert(zones_data.scripting_zones, z_data)
            elseif z_data.type_str == "LayoutZone" then table.insert(zones_data.layout_zones, z_data)
            else table.insert(zones_data.other_zones, z_data) end
        end
    end
    return zones_data
end

local function gather_all_notebook_info()
    if not state.include_notebook then return {} end 
    local notebook = { tabs = {} }
    if not Notes or type(Notes) ~= 'table' then log_message("Notes API not available.", LOG_LEVEL.WARNING); return notebook end
    local tab_idxs = get_obj_prop(Notes, "getTabs", true, nil)
    if not tab_idxs or type(tab_idxs) ~= 'table' then log_message("Notes.getTabs call failed.", LOG_LEVEL.WARNING); return notebook end
    for _, tab_info in ipairs(tab_idxs) do
        if tab_info and type(tab_info) == 'table' and tab_info.index and tab_info.title then
            local content_str = get_obj_prop(Notes, "getNotes", true, "", tab_info.index)
            table.insert(notebook.tabs, {index = tab_info.index, title = tab_info.title, content_length = #content_str, content_preview = string.sub(content_str, 1, 100)})
        end
    end
    return notebook
end

local function refresh_game_context()
    if not state.auto_context then log_message("Auto context collection disabled.", LOG_LEVEL.DEBUG); return end
    log_message("Collecting game context...", LOG_LEVEL.DEBUG)
    state.game_context = {
        game_info = gather_general_game_info(),
        objects = gather_all_objects_info(),
        players = gather_all_players_info(),
        zones = gather_all_zones_info(),
        notebook = gather_all_notebook_info(),
        last_updated = os.time()
    }
    log_message("Context collection complete.", LOG_LEVEL.INFO)
    if UI and UI.setXml and not state.ui_minimized and state.ui_created_once then pcall(create_ui) end
end

local function handle_llm_response(response_data, llm_provider_name, player_for_response, request_endpoint_info)
    log_message("DEBUG: ENTERING handle_llm_response", LOG_LEVEL.ERROR)
    log_message("DEBUG: handle_llm_response - response_data type: " .. type(response_data), LOG_LEVEL.ERROR)
    log_message("DEBUG: handle_llm_response - llm_provider_name: " .. tostring(llm_provider_name), LOG_LEVEL.ERROR)
    log_message("DEBUG: handle_llm_response - player_for_response type: " .. type(player_for_response), LOG_LEVEL.ERROR)
    if player_for_response and (type(player_for_response) == 'table' or type(player_for_response) == 'userdata') then
        if player_for_response.color then
            log_message("DEBUG: handle_llm_response - player_for_response.color: " .. tostring(player_for_response.color), LOG_LEVEL.ERROR)
        else
            log_message("DEBUG: handle_llm_response - player_for_response has no .color property (but is table/userdata)", LOG_LEVEL.ERROR)
        end
        if type(player_for_response.print) == 'function' then
            log_message("DEBUG: handle_llm_response - player_for_response.print is a function.", LOG_LEVEL.ERROR)
        else
            log_message("DEBUG: handle_llm_response - player_for_response.print is NOT a function. Type: " .. type(player_for_response.print), LOG_LEVEL.ERROR)
        end
    else
        log_message("DEBUG: handle_llm_response - player_for_response (raw or not table/userdata): " .. tostring(player_for_response), LOG_LEVEL.ERROR)
    end
    log_message("DEBUG: handle_llm_response - request_endpoint_info: " .. tostring(request_endpoint_info), LOG_LEVEL.ERROR)

    llm_provider_name = llm_provider_name or "UnknownLLM"
    request_endpoint_info = request_endpoint_info or "UnknownEndpoint"

    if not response_data then
        log_message(string.format("%s response_data was nil in callback from %s.", llm_provider_name, request_endpoint_info), LOG_LEVEL.ERROR)
        safe_broadcast(string.format("%s 响应无效或为空。", llm_provider_name), "Red", player_for_response)
        -- Consider if state.success_count should be decremented here, if it was incremented before the call
        return
    end

    if response_data.is_error then
        local err_code = response_data.error_code
        local err_msg = response_data.error
        log_message(string.format("%s request error (TTS Level) from %s: %s - %s", llm_provider_name, request_endpoint_info, tostring(err_code), tostring(err_msg)), LOG_LEVEL.ERROR)
        safe_broadcast(string.format("%s 请求失败 (TTS错误码: %s)。详情请查看控制台。", llm_provider_name, tostring(err_code)), "Red", player_for_response)
        -- Decrement success_count if applicable
        return
    end

    local response_body_str = response_data.text
    log_message(string.format("Raw response_body_str from %s (%s): [%s]", llm_provider_name, request_endpoint_info, tostring(response_body_str)), LOG_LEVEL.ERROR) -- 使用ERROR级别确保可见

    if not response_body_str or response_body_str == "" then
        log_message(string.format("%s response body string empty from %s (TTS reported no error).", llm_provider_name, request_endpoint_info), LOG_LEVEL.WARNING)
        safe_broadcast(string.format("%s 返回了空的回答 (但TTS请求成功)。", llm_provider_name), "Orange", player_for_response)
        return
    end

    local decoded_response, decode_err = safe_json_decode(response_body_str)
    if not decoded_response then
        log_message(string.format("%s JSON decode failed from %s: %s. Raw: %s", llm_provider_name, request_endpoint_info, tostring(decode_err), response_body_str), LOG_LEVEL.ERROR)
        safe_broadcast(string.format("无法解析来自 %s 的回答JSON。", llm_provider_name), "Red", player_for_response)
        return
    end

    if decoded_response.status and decoded_response.status == "error" then
        log_message(string.format("%s server error from %s: %s. Detail: %s", llm_provider_name, request_endpoint_info, tostring(decoded_response.message), tostring(decoded_response.detail)), LOG_LEVEL.ERROR)
        safe_broadcast(string.format("%s 处理错误: %s", llm_provider_name, tostring(decoded_response.message)), "Red", player_for_response)
        return
    end

    local llm_answer_text = nil

    -- 首先处理通过我们本地服务器代理的Ollama请求
    if llm_provider_name == "Ollama" and request_endpoint_info == "/ollama_proxy" then
        if decoded_response.status == "success" then
            if decoded_response.response and type(decoded_response.response) == 'table' then
                -- 真正的Ollama回答嵌套在 decoded_response.response.response 中
                if decoded_response.response.response and type(decoded_response.response.response) == 'string' then
                    llm_answer_text = decoded_response.response.response
                elseif decoded_response.response.message and type(decoded_response.response.message) == 'string' then -- 后备：如果Ollama的内部响应是message
                    llm_answer_text = decoded_response.response.message
                    log_message("Ollama proxy success, but extracted answer from 'response.message' instead of 'response.response'.", LOG_LEVEL.DEBUG)
                else
                    log_message(string.format("Ollama proxy success, but 'response.response' (or .message) field missing/not string in server's inner 'response' table. Inner Response: %s", safe_json_encode(decoded_response.response) or "nil"), LOG_LEVEL.WARNING)
                end
            else
                log_message(string.format("Ollama proxy success, but server's main 'response' field missing or not a table. Full Decoded: %s", safe_json_encode(decoded_response) or "nil"), LOG_LEVEL.WARNING)
            end
        elseif decoded_response.status == "error" and decoded_response.message then -- 服务器返回了 status:error 和 message
            llm_answer_text = "Error from server: " .. tostring(decoded_response.message) 
            log_message(string.format("Ollama proxy reported server-side error: %s", tostring(decoded_response.message)), LOG_LEVEL.WARNING)
        else
            log_message(string.format("Ollama proxy response status not 'success' or structure unexpected. Full Decoded: %s", safe_json_encode(decoded_response) or "nil"), LOG_LEVEL.WARNING)
        end
    -- 然后处理Gemini的特定结构 (如果直接调用Gemini API，或者我们的服务器代理Gemini时也用此结构)
    elseif llm_provider_name == "Gemini" then 
        if decoded_response.candidates and type(decoded_response.candidates) == 'table' and #decoded_response.candidates > 0 then
            local first_candidate = decoded_response.candidates[1]
            if first_candidate.content and type(first_candidate.content) == 'table' and first_candidate.content.parts and type(first_candidate.content.parts) == 'table' and #first_candidate.content.parts > 0 then
                if first_candidate.content.parts[1].text and type(first_candidate.content.parts[1].text) == 'string' then
                    llm_answer_text = first_candidate.content.parts[1].text
                end
            end
        end
        if not llm_answer_text then  -- 如果上述特定路径未找到，尝试通用错误消息
             if decoded_response.error and decoded_response.error.message then 
                llm_answer_text = "Gemini API Error: " .. tostring(decoded_response.error.message)
             end
        end
    -- 通用/备选提取逻辑 (作为最后的尝试)
    else 
        if decoded_response.response and type(decoded_response.response) == 'string' then
            llm_answer_text = decoded_response.response 
        elseif decoded_response.content and type(decoded_response.content) == 'string' then
            llm_answer_text = decoded_response.content
        elseif decoded_response.message and type(decoded_response.message) == 'string' then 
            llm_answer_text = decoded_response.message
        end
    end
    
    -- 移除之前针对Ollama的再次解码部分，因为我们的服务器（如果代理）或Ollama（如果直接）应该返回可直接使用的JSON
    
    log_message(string.format("LLM Answer (extracted, before trim) from %s (%s): [%s]", tostring(llm_provider_name), tostring(request_endpoint_info), tostring(llm_answer_text)), LOG_LEVEL.DEBUG)
    log_message(string.format("LLM Answer Type (extracted, before trim) from %s (%s): [%s]", tostring(llm_provider_name), tostring(request_endpoint_info), tostring(type(llm_answer_text))), LOG_LEVEL.DEBUG)

    if not llm_answer_text or type(llm_answer_text) ~= "string" or trim(llm_answer_text) == "" then
        if decoded_response.done == false and llm_answer_text == "" then 
             log_message(string.format("%s stream: initial empty frame from %s (not an error).", llm_provider_name, request_endpoint_info), LOG_LEVEL.DEBUG); 
             return 
        end
        log_message(string.format("%s no valid answer text in JSON from %s. Final llm_answer_text is nil or not string or empty. Raw server resp: %s", llm_provider_name, request_endpoint_info, response_body_str), LOG_LEVEL.WARNING)
        safe_broadcast(string.format("来自 %s 的回答格式不正确或为空。", llm_provider_name), "Orange", player_for_response)
        return
    end

    local final_answer = trim(llm_answer_text)
    log_message(string.format("Final LLM Answer from %s (%s) (after trim): %s", llm_provider_name, request_endpoint_info, final_answer), LOG_LEVEL.INFO)
    safe_broadcast("🤖 " .. llm_provider_name .. ": " .. final_answer, {0.6, 0.8, 1}, player_for_response)
    -- state.success_count = state.success_count + 1 -- 如果适用，通常在请求发起时乐观增加，此处仅在失败时处理
end

-- 向本地服务器的Ollama代理端点发送请求
function make_ollama_request_to_server(endpoint, payload, player_color_for_response, game_context_json)
    log_message(string.format("DEBUG: ENTERING make_ollama_request_to_server. Endpoint: %s", tostring(endpoint)), LOG_LEVEL.ERROR)
    if not state then
        log_message("CRITICAL: 'state' table is nil in make_ollama_request_to_server!", LOG_LEVEL.ERROR)
        safe_broadcast("严重错误：Mod状态丢失 (state is nil)。", "Red", player_color_for_response)
        return
    end
    log_message(string.format("DEBUG: make_ollama_request_to_server - typeof LOCAL_SERVER_URL: %s", type(LOCAL_SERVER_URL)), LOG_LEVEL.ERROR)
    log_message(string.format("DEBUG: make_ollama_request_to_server - valueof LOCAL_SERVER_URL: %s", tostring(LOCAL_SERVER_URL)), LOG_LEVEL.ERROR)

    if not WebRequest or not WebRequest.custom then
        log_message("WebRequest.custom is not available.", LOG_LEVEL.ERROR) 
        safe_broadcast("错误：WebRequest 功能不可用。", "Red", player_color_for_response)
        return
    end

    if not LOCAL_SERVER_URL then -- 检查正确的变量
        log_message("CRITICAL: 'LOCAL_SERVER_URL' is nil just before concatenation!", LOG_LEVEL.ERROR)
        safe_broadcast("严重错误：本地服务器URL为空 (LOCAL_SERVER_URL is nil)。", "Red", player_color_for_response)
        return
    end
    if not endpoint then
        log_message("CRITICAL: 'endpoint' is nil in make_ollama_request_to_server!", LOG_LEVEL.ERROR)
        safe_broadcast("严重内部错误：请求端点为空 (endpoint is nil)。", "Red", player_color_for_response)
        return
    end

    local url = LOCAL_SERVER_URL .. endpoint -- 使用正确的变量
    payload.game_context = game_context_json or "{}" 

    local json_payload, encode_err = safe_json_encode(payload)
    if not json_payload then
        log_message(string.format("Failed to encode JSON payload for Ollama request to server: %s", tostring(encode_err)), LOG_LEVEL.ERROR)
        safe_broadcast("错误：无法编码Ollama请求数据。", "Red", player_color_for_response)
        return
    end

    log_message(string.format("Sending Ollama request to server: %s with payload: %s", tostring(url), tostring(json_payload)), LOG_LEVEL.DEBUG)

    local headers = {
        ["Content-Type"] = "application/json" 
    }

    log_message("DEBUG: (Before Ollama WebRequest) typeof handle_llm_response: " .. type(handle_llm_response), LOG_LEVEL.ERROR)
    log_message("DEBUG: (Before Ollama WebRequest) typeof player_color_for_response: " .. type(player_color_for_response), LOG_LEVEL.ERROR)
    if type(player_color_for_response) == 'table' or type(player_color_for_response) == 'userdata' then
        if player_color_for_response.color then
            log_message("DEBUG: (Before Ollama WebRequest) player_color_for_response.color: " .. tostring(player_color_for_response.color), LOG_LEVEL.ERROR)
        else
            log_message("DEBUG: (Before Ollama WebRequest) player_color_for_response has no .color property", LOG_LEVEL.ERROR)
        end
    else
        log_message("DEBUG: (Before Ollama WebRequest) player_color_for_response (raw): " .. tostring(player_color_for_response), LOG_LEVEL.ERROR)
    end

    WebRequest.custom(url, "POST", true, json_payload, headers, function(response_obj)
        log_message("DEBUG: WebRequest.custom OLLAMA CALLBACK EXECUTING.", LOG_LEVEL.ERROR)
        log_message("DEBUG: (Ollama Callback) typeof handle_llm_response: " .. type(handle_llm_response), LOG_LEVEL.ERROR)
        log_message("DEBUG: (Ollama Callback) typeof player_color_for_response (captured): " .. type(player_color_for_response), LOG_LEVEL.ERROR)
        if player_color_for_response and (type(player_color_for_response) == 'table' or type(player_color_for_response) == 'userdata') and player_color_for_response.color then
             log_message("DEBUG: (Ollama Callback) player_color_for_response.color (captured): " .. tostring(player_color_for_response.color), LOG_LEVEL.ERROR)
        end

        if handle_llm_response and type(handle_llm_response) == 'function' then
            handle_llm_response(response_obj, "Ollama", player_color_for_response, endpoint)
        else
            log_message("CRITICAL: handle_llm_response is NIL or NOT A FUNCTION in Ollama callback!", LOG_LEVEL.ERROR)
            if 방송 then  -- Fallback broadcast if something is really wrong
                방송("[TC] CRITICAL: handle_llm_response is invalid in Ollama callback!", "Red")
            end
        end
    end)
end

-- 向本地服务器的Gemini代理端点发送请求
function make_gemini_request_to_server(endpoint, payload, player_color_for_response, game_context_json)
    log_message(string.format("DEBUG: ENTERING make_gemini_request_to_server. Endpoint: %s", tostring(endpoint)), LOG_LEVEL.ERROR)
    if not state then
        log_message("CRITICAL: 'state' table is nil in make_gemini_request_to_server!", LOG_LEVEL.ERROR)
        safe_broadcast("严重错误：Mod状态丢失 (state is nil)。", "Red", player_color_for_response)
        return
    end
    log_message(string.format("DEBUG: make_gemini_request_to_server - typeof LOCAL_SERVER_URL: %s", type(LOCAL_SERVER_URL)), LOG_LEVEL.ERROR)
    log_message(string.format("DEBUG: make_gemini_request_to_server - valueof LOCAL_SERVER_URL: %s", tostring(LOCAL_SERVER_URL)), LOG_LEVEL.ERROR)
    log_message(string.format("DEBUG: make_gemini_request_to_server - typeof state.gemini_key: %s", type(state.gemini_key)), LOG_LEVEL.ERROR)
    log_message(string.format("DEBUG: make_gemini_request_to_server - valueof state.gemini_key (checking if empty): %s", tostring(state.gemini_key == "")), LOG_LEVEL.ERROR)

    if not WebRequest or not WebRequest.custom then
        log_message("WebRequest.custom is not available.", LOG_LEVEL.ERROR) 
        safe_broadcast("错误：WebRequest 功能不可用。", "Red", player_color_for_response)
        return
    end

    if not LOCAL_SERVER_URL then -- 再次检查正确的变量
        log_message("CRITICAL: 'LOCAL_SERVER_URL' is nil just before concatenation in Gemini request!", LOG_LEVEL.ERROR)
        safe_broadcast("严重错误：本地服务器URL为空 (LOCAL_SERVER_URL is nil)。", "Red", player_color_for_response)
        return
    end
    if not endpoint then
        log_message("CRITICAL: 'endpoint' is nil in make_gemini_request_to_server!", LOG_LEVEL.ERROR)
        safe_broadcast("严重内部错误：请求端点为空 (endpoint is nil)。", "Red", player_color_for_response)
        return
    end

    local url = LOCAL_SERVER_URL .. endpoint -- 使用正确的变量
    
    payload.api_key = state.gemini_key
    payload.model = state.gemini_model 
    payload.game_context = game_context_json or "{}"
    -- payload.user_question 应该由调用者在 payload 中提供

    local json_payload, encode_err = safe_json_encode(payload)
    if not json_payload then
        log_message(string.format("Failed to encode JSON payload for Gemini request to server: %s", tostring(encode_err)), LOG_LEVEL.ERROR)
        safe_broadcast("错误：无法编码Gemini请求数据。", "Red", player_color_for_response)
        return
    end

    log_message(string.format("Sending Gemini request to server: %s with payload: %s", tostring(url), tostring(json_payload)), LOG_LEVEL.DEBUG)

    local headers = {
        ["Content-Type"] = "application/json"
    }

    log_message("DEBUG: (Before Gemini WebRequest) typeof handle_llm_response: " .. type(handle_llm_response), LOG_LEVEL.ERROR)
    log_message("DEBUG: (Before Gemini WebRequest) typeof player_color_for_response: " .. type(player_color_for_response), LOG_LEVEL.ERROR)
    if type(player_color_for_response) == 'table' or type(player_color_for_response) == 'userdata' then
        if player_color_for_response.color then
            log_message("DEBUG: (Before Gemini WebRequest) player_color_for_response.color: " .. tostring(player_color_for_response.color), LOG_LEVEL.ERROR)
        else
            log_message("DEBUG: (Before Gemini WebRequest) player_color_for_response has no .color property", LOG_LEVEL.ERROR)
        end
    else
        log_message("DEBUG: (Before Gemini WebRequest) player_color_for_response (raw): " .. tostring(player_color_for_response), LOG_LEVEL.ERROR)
    end

    WebRequest.custom(url, "POST", true, json_payload, headers, function(response_obj)
        log_message("DEBUG: WebRequest.custom GEMINI CALLBACK EXECUTING.", LOG_LEVEL.ERROR)
        log_message("DEBUG: (Gemini Callback) typeof handle_llm_response: " .. type(handle_llm_response), LOG_LEVEL.ERROR)
        log_message("DEBUG: (Gemini Callback) typeof player_color_for_response (captured): " .. type(player_color_for_response), LOG_LEVEL.ERROR)
        if player_color_for_response and (type(player_color_for_response) == 'table' or type(player_color_for_response) == 'userdata') and player_color_for_response.color then
             log_message("DEBUG: (Gemini Callback) player_color_for_response.color (captured): " .. tostring(player_color_for_response.color), LOG_LEVEL.ERROR)
        end
        
        if handle_llm_response and type(handle_llm_response) == 'function' then
            handle_llm_response(response_obj, "Gemini", player_color_for_response, endpoint)
        else
            log_message("CRITICAL: handle_llm_response is NIL or NOT A FUNCTION in Gemini callback!", LOG_LEVEL.ERROR)
            if 방송 then -- Fallback broadcast
                방송("[TC] CRITICAL: handle_llm_response is invalid in Gemini callback!", "Red")
            end
        end
    end)
end

function query_llm(question, target_player, is_system_query) 
    if not state.ready then safe_broadcast("System not ready for LLM query.", {1,0.5,0}, target_player); return end
    if not question or trim(question) == "" then safe_broadcast("Query question empty.", {1,0.5,0}, target_player); return end
    
    state.query_count = state.query_count + 1
    -- success_count 由 handle_llm_response 管理, 不在此处递增或递减

    log_message(string.format("LLM query. Provider: %s, Q: %s", state.llm_provider, question), LOG_LEVEL.INFO)
    safe_broadcast("正在向LLM发送查询...", {0.7, 0.7, 0.2}, target_player)

    local game_context_str = "{}"
    if state.auto_context and state.game_context and next(state.game_context) ~= nil then
        local encoded_ctx, err_encode = safe_json_encode(state.game_context)
        if encoded_ctx then 
            game_context_str = encoded_ctx
            log_message("Game context will be sent with the query.", LOG_LEVEL.DEBUG)
        else 
            log_message(string.format("Game context encoding failed for query: %s. Sending empty context.", tostring(err_encode)), LOG_LEVEL.WARNING) 
        end
    else 
        log_message("Auto context is off or game_context is empty. Sending empty context with query.", LOG_LEVEL.DEBUG)
    end

    local payload = {
        user_question = question,
        prompt = question -- 服务器端可能期望 prompt 字段
    }

    if state.llm_provider == "ollama" then 
        if not state.ollama_model or state.ollama_model == "" then 
            safe_broadcast("错误：Ollama模型未配置。", "Red", target_player)
            return 
        end
        payload.model = state.ollama_model -- Ollama 需要在 payload 中明确模型
        make_ollama_request_to_server("/ollama_proxy", payload, target_player, game_context_str)
    elseif state.llm_provider == "gemini" then
        if not state.gemini_key or state.gemini_key == "" then 
            safe_broadcast("错误：Gemini API Key 未配置。", "Red", target_player)
            return 
        end
        -- Gemini model 和 api_key 由 make_gemini_request_to_server 从 state 读取并添加到 payload
        make_gemini_request_to_server("/gemini_proxy", payload, target_player, game_context_str) 
    else
        safe_broadcast("错误：未知的LLM提供商。请使用 'tc config llm set ...' 配置。", "Red", target_player)
        log_message("query_llm: Unknown provider: " .. tostring(state.llm_provider), LOG_LEVEL.ERROR)
        state.success_count = state.success_count - 1 -- Decrement for unknown provider
    end
    if not state.ui_minimized and state.ui_created_once then pcall(create_ui) end 
end

-- 测试LLM提供商的连接
function test_llm_provider_connection(player_color_for_test)
    local provider = state.llm_provider
    log_message("Testing LLM provider connection: " .. provider, LOG_LEVEL.INFO) -- 参数顺序修正

    if provider == "ollama" then
        log_message("Preparing Ollama connection test.", LOG_LEVEL.DEBUG) -- 参数顺序修正
        safe_broadcast("正在测试 Ollama 连接...", nil, player_color_for_test) -- Color is nil for default, player_color_for_test is the target
        
        local test_payload = {
            model = state.ollama_model,
            user_question = "请用中文简单回复 \"Ollama测试成功\"", -- 修正: prompt -> user_question
            stream = false
        }
        -- 调用已修改的函数, 它内部处理 header
        make_ollama_request_to_server("/ollama_proxy", test_payload, player_color_for_test, "{}")

    elseif provider == "gemini" then
        log_message(LOG_LEVEL.DEBUG, "Preparing Gemini connection test.")
        if not state.gemini_key or state.gemini_key == "" then
            safe_broadcast("错误：Gemini API Key 未配置。", "Red", player_color_for_test)
            return
        end
        safe_broadcast("正在测试 Gemini 连接...", nil, player_color_for_test) -- Color is nil for default, player_color_for_test is the target
        
        local test_payload = {
            -- api_key and model will be added by make_gemini_request_to_server
            user_question = "请用中文简单回复 \"Gemini测试成功\"，不要使用markdown。", -- 要求中文回复，无markdown
            prompt = "请用中文简单回复 \"Gemini测试成功\"，不要使用markdown。" -- 向下兼容，确保 prompt 字段存在，因为服务器端可能期望它
        }
        -- 调用已修改的函数, 它内部处理 header
        make_gemini_request_to_server("/gemini_proxy", test_payload, player_color_for_test, "{}")

    else
        log_message(LOG_LEVEL.WARNING, "No LLM provider configured to test.")
        safe_broadcast("错误：未配置LLM提供商。", "Red", player_color_for_test)
    end
end

local function handle_server_response_for_rules(response_data, player_for_response, success_msg_prefix, failure_msg_prefix)
    success_msg_prefix = success_msg_prefix or "操作"
    failure_msg_prefix = failure_msg_prefix or "操作"

    if not response_data then 
        log_message(failure_msg_prefix .. ": Callback received nil response_data.", LOG_LEVEL.ERROR)
        safe_broadcast(failure_msg_prefix .. "失败：服务器无有效响应对象。", {1,0,0}, player_for_response)
        return false 
    end
    
    if response_data.is_error then
        log_message(string.format("%s: TTS Request Error. Code: %s, Message: %s", failure_msg_prefix, tostring(response_data.error_code), tostring(response_data.error)), LOG_LEVEL.ERROR)
        safe_broadcast(string.format("❌ %s失败 (TTS请求错误码: %s)。请检查Mod控制台和服务器日志。", failure_msg_prefix, tostring(response_data.error_code)), {1,0,0}, player_for_response)
        return false
    end

    local response_body_str = response_data.text
    if not response_body_str or response_body_str == "" then 
        log_message(failure_msg_prefix .. ": Server response body empty (TTS request was successful).", LOG_LEVEL.WARNING)
        safe_broadcast(failure_msg_prefix .. "失败：服务器响应体为空 (但TTS请求成功)。", {1,0.5,0}, player_for_response)
        return false 
    end
    
    local decoded_response, decode_err = safe_json_decode(response_body_str)
    if not decoded_response then
        log_message(string.format("%s: Server JSON decode fail: %s. Raw response: %s", failure_msg_prefix, tostring(decode_err), response_body_str), LOG_LEVEL.ERROR)
        safe_broadcast(failure_msg_prefix .. "失败：无法解析服务器响应JSON。", {1,0,0}, player_for_response)
        return false
    end

    if decoded_response.status == "success" then
        log_message(success_msg_prefix .. " OK: " .. (decoded_response.message or ""), LOG_LEVEL.INFO)
        safe_broadcast("✅ " .. success_msg_prefix .. "成功" .. (decoded_response.message and (": " .. decoded_response.message) or "!"), {0,1,0}, player_for_response)
        if _G["sync_rules_status_from_server"] and type(_G["sync_rules_status_from_server"]) == 'function' then
             pcall(_G["sync_rules_status_from_server"], nil, function() 
                if not state.ui_minimized and state.ui_created_once then 
                    if _G["create_ui"] and type(_G["create_ui"]) == 'function' then
                        pcall(_G["create_ui"])
                    else
                        log_message("create_ui is not a function inside sync_rules_status_from_server callback!", LOG_LEVEL.ERROR)
                    end
                end 
            end)
        else
            log_message("sync_rules_status_from_server is not a function or nil in handle_server_response_for_rules!", LOG_LEVEL.ERROR)
        end
        return true
    else 
        local server_error_message = decoded_response.message or "未知服务器端错误"
        log_message(string.format("%s fail (server logic): %s. Full server response: %s", failure_msg_prefix, server_error_message, response_body_str), LOG_LEVEL.ERROR)
        safe_broadcast(string.format("❌ %s失败 (服务器处理错误): %s", failure_msg_prefix, server_error_message), {1,0,0}, player_for_response)
        return false
    end
end

function sync_rules_status_from_server(target_player, success_cb)
    log_message("DEBUG: ENTERING sync_rules_status_from_server", LOG_LEVEL.ERROR)
    log_message("DEBUG: sync_rules_status_from_server - typeof LOCAL_SERVER_URL: " .. type(LOCAL_SERVER_URL), LOG_LEVEL.ERROR)
    log_message("DEBUG: sync_rules_status_from_server - valueof LOCAL_SERVER_URL: " .. tostring(LOCAL_SERVER_URL), LOG_LEVEL.ERROR)

    local request_url = LOCAL_SERVER_URL .. "/get_current_rules"
    log_message("Syncing rules status from server: " .. request_url, LOG_LEVEL.DEBUG)
    if WebRequest and WebRequest.get then
        WebRequest.get(request_url, function(response_obj)
            local request_completed_without_error = false
            local response_text_content = nil

            if response_obj then
                if not response_obj.is_error then 
                    request_completed_without_error = true
                    response_text_content = response_obj.text
                else
                    log_message(string.format("Rules sync: TTS Request Error. Code: %s, Message: %s", 
                                tostring(response_obj.error_code), tostring(response_obj.error)), LOG_LEVEL.WARNING)
                end
            else
                log_message("Rules sync: response_obj was nil in callback.", LOG_LEVEL.ERROR)
            end

            if request_completed_without_error and response_text_content then
                local decoded, err = safe_json_decode(response_text_content)
                if decoded and decoded.status == "success" then
                    state.rules_document_type_on_server = decoded.type or "none"
                    if decoded.type == "image" then state.rules_document_description_on_server = string.format("Image (Len: %s)", decoded.base64_data_length or "N/A")
                    elseif decoded.type == "text" then state.rules_document_description_on_server = string.format("Text (Len: %s)", decoded.text_data_length or "N/A")
                    else state.rules_document_description_on_server = "Not Loaded" end
                    log_message("Rules status sync OK: " .. state.rules_document_description_on_server, LOG_LEVEL.INFO)
                    if target_player then safe_broadcast("Rules status synced: " .. state.rules_document_description_on_server, nil, target_player) end -- Color nil for default
                    if success_cb and type(success_cb) == 'function' then 
                        pcall(success_cb)
                    elseif success_cb then --它存在但不是函数
                        log_message("success_cb in sync_rules_status_from_server is not a function! Type: " .. type(success_cb), LOG_LEVEL.ERROR)
                    end 
                else
                    log_message(string.format("Rules sync fail, could not parse server success response. Decode_err: %s. Raw: %s", tostring(err), response_text_content), LOG_LEVEL.WARNING)
                    if target_player then safe_broadcast("Rules sync fail (server resp format error).", {1,0.5,0}, target_player) end
                end
            else
                log_message("Rules sync: Overall failure in request or getting response text.", LOG_LEVEL.WARNING)
                if target_player then safe_broadcast("Rules sync fail (request/response issue).", {1,0.5,0}, target_player) end
            end
            if not state.ui_minimized and state.ui_created_once then 
                if _G["create_ui"] and type(_G["create_ui"]) == 'function' then
                    pcall(_G["create_ui"])
                else
                    log_message("create_ui is not a function in sync_rules_status_from_server WebRequest callback!", LOG_LEVEL.ERROR)
                end
            end
        end)
    else 
        log_message("WebRequest.get missing, cannot sync rules.", LOG_LEVEL.ERROR)
        if target_player then 
            safe_broadcast("Cannot sync rules (WebRequest missing).", {1,0,0}, target_player) 
        end 
    end
end

-- 将文本规则发送到本地服务器
function send_text_rules_to_server(rules_text, player_color_for_response)
    if not WebRequest or not WebRequest.custom then
        log_message(LOG_LEVEL.ERROR, "WebRequest.custom is not available for sending text rules.")
        safe_broadcast("错误：WebRequest 功能不可用。", "Red", player_color_for_response)
        return
    end
    if not rules_text or string.len(rules_text) == 0 then
        safe_broadcast("错误：规则文本不能为空。", "Red", player_color_for_response)
        return
    end

    local url = state.local_server_url .. "/load_rules"
    local payload = {
        type = "text",
        content = rules_text
    }
    local json_payload = JSON.encode(payload)

    if not json_payload then
        log_message(LOG_LEVEL.ERROR, "Failed to encode JSON payload for text rules.")
        safe_broadcast("错误：无法编码规则数据。", "Red", player_color_for_response)
        return
    end

    log_message(LOG_LEVEL.DEBUG, "Sending text rules to server: " .. url)
    
    local headers = {
        ["Content-Type"] = "application/json" -- 移除 charset
    }

    WebRequest.custom(url, "POST", true, json_payload, headers, function(response_obj)
        handle_server_response_for_rules(response_obj, "文本规则加载", player_color_for_response)
    end)
end

-- 将图像规则的路径发送到本地服务器
function send_image_rules_path_to_server(image_path, player_color_for_response)
    if not WebRequest or not WebRequest.custom then
        log_message(LOG_LEVEL.ERROR, "WebRequest.custom is not available for sending image rules path.")
        safe_broadcast("错误：WebRequest 功能不可用。", "Red", player_color_for_response)
        return
    end
    if not image_path or string.len(image_path) == 0 then
        safe_broadcast("错误：图像文件路径不能为空。", "Red", player_color_for_response)
        return
    end

    local url = state.local_server_url .. "/load_rules"
    local payload = {
        type = "image_path", -- 或者服务器期望的其他类型，如 "file_path"
        path = image_path,
        -- 根据服务器API，可能需要指定MIME类型，或者服务器会自行推断
        -- mime_type = "image/png" -- 例如
    }
    local json_payload = JSON.encode(payload)

    if not json_payload then
        log_message(LOG_LEVEL.ERROR, "Failed to encode JSON payload for image rules path.")
        safe_broadcast("错误：无法编码图像路径数据。", "Red", player_color_for_response)
        return
    end

    log_message(LOG_LEVEL.DEBUG, "Sending image rules path to server: " .. url .. " with path: " .. image_path)
    
    local headers = {
        ["Content-Type"] = "application/json" -- 移除 charset
    }

    WebRequest.custom(url, "POST", true, json_payload, headers, function(response_obj)
        handle_server_response_for_rules(response_obj, "图像规则加载", player_color_for_response)
    end)
end

-- 清除服务器上的所有规则
function clear_all_rules_on_server(player_color_for_response)
    if not WebRequest or not WebRequest.custom then
        log_message(LOG_LEVEL.ERROR, "WebRequest.custom is not available for clearing rules.")
        safe_broadcast("错误：WebRequest 功能不可用。", "Red", player_color_for_response)
        return
    end

    local url = state.local_server_url .. "/clear_rules"
    log_message(LOG_LEVEL.DEBUG, "Sending request to clear all rules on server: " .. url)
    
    local headers = {
        ["Content-Type"] = "application/json" -- 移除 charset
    }
    
    -- 对于 /clear_rules，通常发送一个空的JSON对象 {} 作为body，或者服务器可能不期望body。
    -- 假设服务器期望一个空的JSON对象，或者可以安全地接受它。
    local empty_json_payload = "{}"

    WebRequest.custom(url, "POST", true, empty_json_payload, headers, function(response_obj)
        handle_server_response_for_rules(response_obj, "清除规则", player_color_for_response)
    end)
end

function create_ui()
    if not UI or type(UI.setXml) ~= 'function' then log_message("UI.setXml not available", LOG_LEVEL.ERROR); return end
    state.ui_created_once = true
    local game_name_display = state.current_game_name or "未知游戏"
    if game_name_display == "" then game_name_display = "未知游戏" end
    local rules_status_display = state.rules_document_description_on_server or "未加载"
    local obj_count_display = (state.game_context and state.game_context.objects and state.game_context.objects.total_objects) or "N/A"
    local player_count_display = (state.game_context and state.game_context.game_info and state.game_context.game_info.player_count) or "N/A"
    local llm_status_ui = state.llm_provider
    if state.llm_provider == "ollama" then llm_status_ui = "Ollama (" .. state.ollama_model .. ")"
    elseif state.llm_provider == "gemini" then llm_status_ui = "Gemini (" .. state.gemini_model .. ")" end
    
    local notebook_tab_count_display = "N/A"
    if state.game_context and state.game_context.notebook and state.game_context.notebook.tabs and type(state.game_context.notebook.tabs) == 'table' then
        notebook_tab_count_display = #state.game_context.notebook.tabs
    end

    local panel_id_main = "MainPanel_TC"
    local x_main, y_main = parse_offset_xy(state.ui_panel_offsets.main, 70, -10)
    local ui_xml = 
    '<Panel rectAlignment="UpperLeft" offsetXY="' .. x_main .. ' ' .. y_main .. '" width="350" height="190" id="' .. panel_id_main .. '" allowDragging="true" returnToOriginalPositionWhenReleased="false" color="#00000000" >'
    ..'<Panel color="#2D1B69E6" width="100%" height="100%" outline="#4C3A7B" outlineSize="2">'
    ..'<Text fontSize="16" color="#FFD700" alignment="MiddleCenter" offsetXY="0 85" fontStyle="Bold">'
    ..'    🎲 桌游伴侣 v' .. (VERSION or "N/A") .. '</Text>'
    ..'<Text fontSize="10" color="#E6E6FA" alignment="MiddleCenter" offsetXY="0 70">智能游戏助手 - 上下文感知AI</Text>'
    ..'<Text fontSize="9" color="#B0C4DE" alignment="MiddleCenter" offsetXY="0 56">游戏: ' .. game_name_display .. ' | 规则: ' .. rules_status_display .. '</Text>'
    ..'<Text fontSize="8" color="#98FB98" alignment="MiddleCenter" offsetXY="0 44">对象: ' .. obj_count_display .. ' | 玩家: ' .. player_count_display .. ' | LLM: ' .. llm_status_ui .. ' | 笔记页: ' .. notebook_tab_count_display .. '</Text>'
    ..'<Panel offsetXY="0 15" width="330" height="28" color="#3E2A8A80">'
    ..'    <Button onClick="ui_show_help_handler" width="70" height="22" offsetXY="-120 0" color="#6A5ACD" highlightColor="#7B68EE" tooltip="显示帮助信息"><Text fontSize="9" color="#FFFFFF">帮助</Text></Button>'
    ..'    <Button onClick="ui_show_status_handler" width="70" height="22" offsetXY="-40 0" color="#6A5ACD" highlightColor="#7B68EE" tooltip="显示系统状态"><Text fontSize="9" color="#FFFFFF">状态</Text></Button>'
    ..'    <Button onClick="ui_refresh_context_handler" width="70" height="22" offsetXY="40 0" color="#228B22" highlightColor="#32CD32" tooltip="刷新游戏上下文"><Text fontSize="9" color="#FFFFFF">刷新上下文</Text></Button>'
    ..'    <Button onClick="ui_minimize_handler" width="70" height="22" offsetXY="120 0" color="#FF6347" highlightColor="#FF7F50" tooltip="最小化面板"><Text fontSize="9" color="#FFFFFF">最小化</Text></Button>'
    ..'</Panel>'
    ..'<Panel offsetXY="0 -15" width="330" height="28" color="#3E2A8A80">'
    ..'    <Button onClick="ui_toggle_auto_context_handler" width="100" height="22" offsetXY="-105 0" color="#4682B4" highlightColor="#5F9EA0" tooltip="切换自动上下文收集"><Text fontSize="8" color="#FFFFFF">自动上下文: ' .. (state.auto_context and "开启" or "关闭") .. '</Text></Button>'
    ..'    <Button onClick="ui_clear_rules_handler" width="100" height="22" offsetXY="0 0" color="#DC143C" highlightColor="#F08080" tooltip="清除服务器上的规则文档"><Text fontSize="8" color="#FFFFFF">清除规则</Text></Button>'
    ..'    <Button onClick="ui_test_connection_handler" width="100" height="22" offsetXY="105 0" color="#FF8C00" highlightColor="#FFA500" tooltip="测试当前LLM连接"><Text fontSize="8" color="#FFFFFF">测试连接</Text></Button>'
    ..'</Panel>'
    ..'<Panel offsetXY="0 -45" width="330" height="38" color="#3E2A8A00">'
    ..'     <InputField id="RuleInput_TC" onEndEdit="ui_rule_input_ended_handler" onValueChanged="ui_rule_input_changed_handler" width="220" height="30" offsetXY="-50 0" placeholder="粘贴文本规则或图片规则文件路径..." characterLimit="1024" tooltip="粘贴文本规则，或输入图片规则的本地绝对文件路径" color="#1A1A1AE6" textColor="#FFFFFF" fontSize="8"/>'
    ..'     <Button onClick="ui_load_rules_from_input_handler" width="90" height="30" offsetXY="115 0" color="#4CAF50" highlightColor="#66BB6A" tooltip="加载输入的规则"><Text fontSize="8" color="#FFFFFF">加载规则</Text></Button>'
    ..'</Panel>'
    ..'<Text id="RuleInputStatus_TC" fontSize="7" color="#DDDDDD" alignment="LowerCenter" offsetXY="0 -82" width="320" height="15" text=""/>'
    ..'</Panel></Panel>'
    local suc_set, err_set = pcall(UI.setXml, ui_xml)
    if not suc_set then log_message("create_ui: UI.setXml failed: " .. tostring(err_set), LOG_LEVEL.ERROR)
    else if UI.setAttributeChanged and _G["ui_panel_offset_changed_handler"] then pcall(UI.setAttributeChanged, panel_id_main, "offsetXY", "ui_panel_offset_changed_handler") end end
end

function create_minimized_ui()
    if not UI or type(UI.setXml) ~= 'function' then log_message("UI.setXml not available", LOG_LEVEL.ERROR); return end
    state.ui_created_once = true
    local panel_id_min = "MinimizedPanel_TC"
    local x_min, y_min = parse_offset_xy(state.ui_panel_offsets.minimized, 70, -10)
    local ui_xml_min =
    '<Panel rectAlignment="UpperLeft" offsetXY="' .. x_min .. ' ' .. y_min .. '" width="200" height="35" id="'..panel_id_min..'" allowDragging="true" returnToOriginalPositionWhenReleased="false" color="#00000000">'
    ..'<Panel color="#2D1B69E6" width="100%" height="100%" outline="#4C3A7B" outlineSize="2">'
    ..'<Button onClick="ui_restore_handler" width="190" height="28" color="#6A5ACD" highlightColor="#7B68EE" tooltip="恢复完整面板 (桌游伴侣 v' .. (VERSION or "N/A") ..')">'
    ..'<Text fontSize="12" color="#FFD700" alignment="MiddleCenter" fontStyle="Bold">🎲 桌游伴侣 ✨</Text>'
    ..'</Button></Panel></Panel>'
    local suc_set, err_set = pcall(UI.setXml, ui_xml_min)
    if not suc_set then log_message("create_minimized_ui: UI.setXml failed: " .. tostring(err_set), LOG_LEVEL.ERROR)
    else if UI.setAttributeChanged and _G["ui_panel_offset_changed_handler"] then pcall(UI.setAttributeChanged, panel_id_min, "offsetXY", "ui_panel_offset_changed_handler") end end
end

function ui_show_help_handler(player_clicked, _, _) show_help(player_clicked) end
function ui_show_status_handler(player_clicked, _, _) show_status(player_clicked) end
function ui_refresh_context_handler(player_clicked, _, _) pcall(refresh_game_context); safe_broadcast("✅ 游戏上下文已刷新。", nil, player_clicked) end
function ui_toggle_auto_context_handler(player_clicked, _, _)
    state.auto_context = not state.auto_context; safe_broadcast("✅ 自动上下文已切换为: " .. (state.auto_context and "开启" or "关闭"), nil, player_clicked)
    if state.auto_context then pcall(refresh_game_context) end
    if not state.ui_minimized and state.ui_created_once then pcall(create_ui) end
end
function ui_clear_rules_handler(player_clicked, _, _) clear_all_rules_on_server(player_clicked) end
function ui_test_connection_handler(player_clicked, _, _) test_llm_provider_connection(player_clicked) end
function ui_minimize_handler(_, _, _) state.ui_minimized = true; pcall(create_minimized_ui) end
function ui_restore_handler(_, _, _) state.ui_minimized = false; pcall(create_ui) end
local temp_rule_input_value = ""
function ui_rule_input_changed_handler(_, new_val, _) temp_rule_input_value = new_val or "" end
function ui_rule_input_ended_handler(_, val, _) temp_rule_input_value = val or "" end
function ui_load_rules_from_input_handler(player_clicked, _, _)
    local input = trim(temp_rule_input_value)
    if input == "" then safe_broadcast("⚠️ 规则输入为空。", {1,0.5,0}, player_clicked); return end
    
    local lower_input = string.lower(input)
    local is_file_path = false
    local supported_file_extensions = {".png", ".jpg", ".jpeg", ".webp", ".pdf", ".heic", ".heif"} -- 添加更多支持的扩展名

    if (contains(input, "/") or contains(input, "\\")) then -- 检查是否像路径
        for _, ext in ipairs(supported_file_extensions) do
            if ends_with(lower_input, ext) then
                is_file_path = true
                break
            end
        end
    end

    if is_file_path then
        log_message(string.format("Input identified as a file path: %s", input), LOG_LEVEL.DEBUG)
        send_image_rules_path_to_server(input, player_clicked) -- 函数名可考虑后续修改为 send_file_rules_path_to_server
    else
        log_message(string.format("Input identified as text rules: %s...", string.sub(input, 1, 50)), LOG_LEVEL.DEBUG)
        send_text_rules_to_server(input, player_clicked)
    end

    if UI and UI.setValue then pcall(UI.setValue, "RuleInput_TC", "") end; temp_rule_input_value = ""
end
function ui_panel_offset_changed_handler(_, panel_id, new_offset)
    if type(panel_id) ~= "string" or type(new_offset) ~= "string" then return end
    if panel_id == "MainPanel_TC" then state.ui_panel_offsets.main = new_offset
    elseif panel_id == "MinimizedPanel_TC" then state.ui_panel_offsets.minimized = new_offset end
end

local function parse_tc_command_internal(msg_str)
    local parts = {}; if type(msg_str) ~= "string" then return parts end
    for word in msg_str:gmatch("%S+") do table.insert(parts, word) end; return parts
end

function show_help(player)
    local help_msg_full = string.format([[
=== 桌游伴侣 v%s 完整帮助 ===
命令前缀: tc (例如: tc help)
查询LLM: @tc <你的问题> (例如: @tc 现在轮到谁了?)

可用 'tc' 命令:
  help                   - 显示此帮助信息
  status                 - 显示当前Mod状态和配置
  config                 - 管理Mod配置
    config llm list      - 列出可用的LLM提供商
    config llm set <ollama|gemini|none> [模型名称_或_API密钥_或_Ollama模型标签]
                         - 设置LLM提供商。
                           例 (Ollama): tc config llm set ollama llama3:latest
                           例 (Gemini): tc config llm set gemini YOUR_GEMINI_API_KEY
                           (Gemini模型可在Mod代码 state.gemini_model 或服务器端默认值更改)
                           例 (禁用):   tc config llm set none
    config ollama url <new_url> (提示: Ollama URL 当前在服务器端配置)
    config loglevel <DEBUG|INFO|WARNING|ERROR> - 设置最低日志输出级别 (当前: %s)
  context                - 管理游戏上下文收集
    context refresh      - 手动刷新游戏上下文
    context toggle auto  - 切换自动上下文收集 (当前: %s)
    context show         - 在脚本控制台显示当前游戏上下文 (JSON格式)
    context include <objects|players|zones|notebook> <true|false>
                         - 设置是否包含特定类型的上下文信息
  rules                  - 管理规则文档 (通过本地服务器)
    rules clear          - 清除本地服务器上已加载的规则
    rules status         - 从服务器获取当前规则状态
                         (使用UI输入框和'加载规则'按钮来加载文本/图片/PDF规则)
  test                   - 测试功能
    test llm             - 测试当前LLM提供商的连接

UI交互:
  - 面板可拖动。点击"最小化"以收起面板。
  - "刷新上下文"按钮: 手动更新游戏信息。
  - "自动上下文"按钮: 切换是否在游戏事件发生时自动更新 (当前: %s)。
  - "清除规则"按钮: 清除服务器上的规则。
  - "测试连接"按钮: 测试当前LLM的连接状态。
  - 输入框: 粘贴文本规则，或输入图片/PDF规则的本地绝对文件路径，然后点击"加载规则"。
]], VERSION, state.min_log_level or "N/A", (state.auto_context and "开启" or "关闭"), (state.auto_context and "开启" or "关闭"))
    
    safe_player_action(player, function(p) p.print(help_msg_full) end, "显示完整帮助信息")
    log_message("完整帮助信息已显示给玩家。\n" .. help_msg_full, LOG_LEVEL.DEBUG) 
end

function show_status(player)
    local status_msg = string.format([[
=== TC v%s 状态 ===
就绪状态: %s | LLM提供商: %s (%s) | 本地服务URL: %s
当前游戏: %s | 服务端规则: %s (%s)
自动上下文: %s (对象:%s 玩家:%s 区域:%s 笔记:%s)
查询统计: %d次 (成功:%d次) | 上下文最后更新于: %s
主面板位置: %s | 最小化面板位置: %s
最低日志级别: %s
]], 
    VERSION, tostring(state.ready),
    state.llm_provider or "未配置", 
    (state.llm_provider == "ollama" and state.ollama_model or (state.llm_provider == "gemini" and state.gemini_model or "N/A")),
    LOCAL_SERVER_URL,
    state.current_game_name or "未知",
    state.rules_document_description_on_server or "未知", state.rules_document_type_on_server or "未知",
    (state.auto_context and "开启" or "关闭"), (state.include_objects and "包含" or "排除"), 
    (state.include_players and "包含" or "排除"), (state.include_zones and "包含" or "排除"), (state.include_notebook and "包含" or "排除"),
    state.query_count, state.success_count,
    (state.game_context and state.game_context.last_updated and os.date("%%H:%%M:%%S", state.game_context.last_updated) or "从未"),
    state.ui_panel_offsets.main, state.ui_panel_offsets.minimized,
    state.min_log_level or "N/A")
    safe_player_action(player, function(p) p.print(status_msg) end, "显示状态")
end

local function process_config_command(parts, player)
    if not parts[3] then safe_broadcast("用法: tc config <llm|ollama|loglevel> ...", {1,0.5,0}, player); return end
    local category = string.lower(parts[3])
    if category == "llm" then
        if not parts[4] then safe_broadcast("用法: tc config llm <list|set> ...", {1,0.5,0}, player); return end
        local action = string.lower(parts[4])
        if action == "list" then safe_broadcast("可用的LLM提供商: ollama, gemini, none", nil, player)
        elseif action == "set" then
            if not parts[5] then safe_broadcast("用法: tc config llm set <ollama|gemini|none> [模型名称/API密钥]", {1,0.5,0}, player); return end
            local provider = string.lower(parts[5])
            if provider == "ollama" then
                state.llm_provider = "ollama"; state.ollama_model = parts[6] or "gemma:latest" 
                safe_broadcast(string.format("✅ LLM已设为: Ollama, 模型: %s", state.ollama_model), nil, player)
                log_message(string.format("LLM provider set to Ollama. Model: %s.", state.ollama_model), LOG_LEVEL.INFO)
            elseif provider == "gemini" then
                if not parts[6] or parts[6] == "" then 
                    safe_broadcast("❌ 错误: Gemini需要API密钥。", {1,0,0}, player)
                    log_message("Gemini config error: API key not provided.", LOG_LEVEL.WARNING)
                    return -- 提前返回，因为没有API Key无法继续
                end
                state.llm_provider = "gemini"; 
                state.gemini_key = parts[6]; 
                state.gemini_model = state.gemini_model or "gemini-1.5-flash-latest" -- 保留服务器端默认的逻辑，或从state.gemini_model读取
                -- 修改广播和日志，不直接打印API Key
                safe_broadcast(string.format("✅ LLM已设为: Gemini (模型: %s). API密钥已设置。", state.gemini_model), nil, player)
                log_message(string.format("LLM provider set to Gemini. Model: %s. API Key has been set (key not logged).", state.gemini_model), LOG_LEVEL.INFO)
            elseif provider == "none" then 
                state.llm_provider = "none"; 
                safe_broadcast("✅ LLM已禁用。", nil, player)
                log_message("LLM provider set to none.", LOG_LEVEL.INFO)
            else 
                safe_broadcast(string.format("❌ 错误: 未知的LLM提供商 '%s'。", provider), {1,0,0}, player)
                log_message(string.format("Unknown LLM provider in config: %s", provider), LOG_LEVEL.WARNING)
            end
        else safe_broadcast(string.format("未知的llm操作 '%s'。", action), {1,0.5,0}, player) end
    elseif category == "ollama" and parts[4] and string.lower(parts[4]) == "url" then
        safe_broadcast("提示: Ollama URL在服务器端配置，无法通过Mod设置。", {0.8, 0.8, 0.2}, player)
    elseif category == "loglevel" then
        if not parts[4] then 
            safe_broadcast("用法: tc config loglevel <DEBUG|INFO|WARNING|ERROR>。当前级别: " .. state.min_log_level, {1,0.5,0}, player)
            return 
        end
        local new_log_level_str = string.upper(parts[4])
        if LOG_LEVEL[new_log_level_str] then
            state.min_log_level = LOG_LEVEL[new_log_level_str]
            safe_broadcast("✅ 最低日志输出级别已设置为: " .. state.min_log_level, nil, player)
            log_message("最低日志级别已更改为: " .. state.min_log_level, LOG_LEVEL.WARNING) -- 用一个较高级别打印这个重要消息
        else
            safe_broadcast(string.format("❌ 错误: 无效的日志级别 '%s'。请使用 DEBUG, INFO, WARNING, 或 ERROR。", new_log_level_str), {1,0,0}, player)
        end
    else safe_broadcast(string.format("未知的配置类别 '%s'。", category), {1,0.5,0}, player) end
    
    -- 临时注释掉UI刷新，以避免在配置命令后立即触发可能导致 "pattern too complex" 的游戏名称检测
    -- if not state.ui_minimized and state.ui_created_once then pcall(create_ui) end 
    log_message("Config command processed. UI refresh skipped to avoid pattern issues.", LOG_LEVEL.DEBUG)
end

local function process_context_command(parts, player)
    if not parts[3] then safe_broadcast("用法: tc context <refresh|toggle auto|show|include ...>", {1,0.5,0}, player); return end
    local action = string.lower(parts[3])
    if action == "refresh" then pcall(refresh_game_context); safe_broadcast("✅ 上下文已刷新。", nil, player)
    elseif action == "toggle" and parts[4] and string.lower(parts[4]) == "auto" then
        state.auto_context = not state.auto_context; safe_broadcast("✅ 自动上下文已切换为: " .. (state.auto_context and "开启" or "关闭"), nil, player)
        if state.auto_context then pcall(refresh_game_context) end 
    elseif action == "show" then
        if state.game_context and next(state.game_context) ~= nil then
            local context_json, err_json = safe_json_encode(state.game_context)
            if context_json then log_message("Current context (JSON):\n" .. context_json, LOG_LEVEL.DEBUG); safe_broadcast("当前上下文信息已输出到脚本控制台。", nil, player)
            else safe_broadcast("❌ 无法编码上下文: " .. tostring(err_json), {1,0,0}, player) end
        else safe_broadcast("尚未收集上下文信息。", nil, player) end
    elseif action == "include" then
        if not parts[4] or not parts[5] then safe_broadcast("用法: tc context include <类型> <true|false>", {1,0.5,0}, player); return end
        local item = string.lower(parts[4]); local should_include = string.lower(parts[5]) == "true"; local changed = false
        if item == "objects" then state.include_objects = should_include; changed = true
        elseif item == "players" then state.include_players = should_include; changed = true
        elseif item == "zones" then state.include_zones = should_include; changed = true
        elseif item == "notebook" then state.include_notebook = should_include; changed = true
        else safe_broadcast("未知的上下文项目: " .. item, {1,0.5,0}, player); return end
        if changed then safe_broadcast(string.format("✅ 上下文项目 '%s' 已设置为 %s", item, (should_include and "包含" or "排除")), nil, player); if state.auto_context then pcall(refresh_game_context) end end
    else safe_broadcast(string.format("未知的上下文操作 '%s'。", action), {1,0.5,0}, player) end
    if not state.ui_minimized and state.ui_created_once then pcall(create_ui) end 
end

local function process_rules_command(parts, player)
    if not parts[3] then safe_broadcast("用法: tc rules <clear|status>。请使用UI加载规则。", {1,0.5,0}, player); return end
    local action = string.lower(parts[3])
    if action == "clear" then clear_all_rules_on_server(player)
    elseif action == "status" then sync_rules_status_from_server(player, function() if not state.ui_minimized and state.ui_created_once then pcall(create_ui) end end)
    else safe_broadcast(string.format("未知的规则操作 '%s'。请使用UI加载规则。", action), {1,0.5,0}, player) end
end

local function process_test_command(parts, player)
    if not parts[3] or string.lower(parts[3]) ~= "llm" then safe_broadcast("用法: tc test llm", {1,0.5,0}, player); return end
    test_llm_provider_connection(player)
end

function onLoad(saved_json)
    log_message("TC Initializing v" .. VERSION, LOG_LEVEL.INFO) -- 这个初始日志级别可以保留为INFO
    if saved_json and saved_json ~= "" then
        local loaded_state, err = safe_json_decode(saved_json)
        if loaded_state then 
            state = loaded_state; 
            log_message("State restored.", LOG_LEVEL.INFO) -- 状态恢复日志也可以保留
            state.current_game_name = state.current_game_name or "未知游戏"
            state.rules_document_description_on_server = state.rules_document_description_on_server or "未加载"
            state.rules_document_type_on_server = state.rules_document_type_on_server or "none"
            state.query_count = state.query_count or 0; state.success_count = state.success_count or 0
            state.llm_provider = state.llm_provider or "none"; state.ollama_model = state.ollama_model or "gemma:latest"; state.gemini_model = state.gemini_model or "gemini-pro"
            state.ui_panel_offsets = state.ui_panel_offsets or { main = "70 -10", minimized = "70 -10" }
            state.auto_context = (state.auto_context == nil) and true or state.auto_context 
            state.include_objects = (state.include_objects == nil) and true or state.include_objects
            state.include_players = (state.include_players == nil) and true or state.include_players
            state.include_zones = (state.include_zones == nil) and true or state.include_zones
            state.include_notebook = (state.include_notebook == nil) and true or state.include_notebook
            state.ui_created_once = state.ui_created_once or false 
            state.ui_minimized = state.ui_minimized or false
            -- state.min_log_level = state.min_log_level or LOG_LEVEL.WARNING -- 旧的恢复逻辑

            -- 新的、更健壮的 min_log_level 恢复逻辑
            if state.min_log_level and LOG_LEVEL_ORDER[state.min_log_level] then
                -- 值存在且有效，保留它
                log_message("Restored min_log_level from save: " .. state.min_log_level, LOG_LEVEL.DEBUG)
            else
                if state.min_log_level then -- 值存在但无效
                    log_message("Invalid min_log_level '،'" .. tostring(state.min_log_level) .. "'' found in save. Resetting to WARNING.", LOG_LEVEL.WARNING)
                else -- 值不存在
                    log_message("min_log_level not found in save. Setting to WARNING.", LOG_LEVEL.DEBUG)
                end
                state.min_log_level = LOG_LEVEL.WARNING -- 默认值
            end

        else 
            log_message("State restore failed: " .. tostring(err), LOG_LEVEL.WARNING) 
            -- 如果状态恢复失败，也设置一下默认日志级别
            state.min_log_level = LOG_LEVEL.WARNING
        end
    else
        -- 如果没有存档，也确保默认日志级别是 WARNING
        log_message("No saved state found. Setting min_log_level to WARNING.", LOG_LEVEL.DEBUG)
        state.min_log_level = LOG_LEVEL.WARNING
    end
    state.ready = false 
    state.current_game_name = detect_game_name_internal() 
    
    if state.auto_context then 
        pcall(refresh_game_context) 
    end

    if state.ui_minimized then
        pcall(create_minimized_ui)
    else
        pcall(create_ui)
    end
    
    sync_rules_status_from_server(nil)
    state.ready = true
    safe_broadcast("桌游伴侣 v" .. VERSION .. " 已启动。输入 'tc help' 查看帮助或 '@tc 你想问的问题' 来提问。", nil, nil) -- No specific color, no specific player (broadcast to all)
end

function onSave()
    local json_data, err = safe_json_encode(state)
    if json_data then return json_data else log_message("Save state failed: " .. tostring(err), LOG_LEVEL.ERROR); return "" end
end

function onChat(msg, player)
    if not state.ready or not msg then 
        log_message("onChat: state not ready or msg nil, returning true.", LOG_LEVEL.DEBUG)
        return true 
    end
    
    local original_msg_for_log = msg -- 保存原始msg以供日志
    local step = 0
    -- local error_occurred_at_step = -1 -- Not strictly needed with pcall like this

    local function debug_log(message)
        -- 使用ERROR级别确保能看到，或者根据需要调整为WARNING/INFO
        log_message(string.format("onChat DEBUG (Step %d): %s", step, message), LOG_LEVEL.ERROR)
    end

    local success_onchat, result_or_error = pcall(function() -- 包裹整个 onChat 逻辑
        step = 1; debug_log("Start of onChat processing for msg: " .. tostring(original_msg_for_log))

        local e_player = player
        if not player or type(player) ~= 'userdata' or not player.print or type(player.print) ~= 'function' then
            local p_color = "未知玩家"; 
            if player and type(player) == 'table' and player.player_color then p_color = tostring(player.player_color) 
            elseif player and type(player) == 'string' then p_color = player end
            e_player = { 
                print = function(m_print) log_message(string.format("[%s 通过备用聊天处理]: %s", p_color, tostring(m_print))) end, 
                color = p_color, 
                steam_name = p_color 
            }
            debug_log(string.format("Invalid player object. Color: %s. Using fallback.", p_color))
        end
        step = 2; debug_log("Player object handling complete.")

        local trimmed_msg_content = trim(msg) -- trim 内部有 string.match
        if trimmed_msg_content == "" then 
            debug_log("Trimmed message is empty, returning true from pcall inner function.")
            return true -- 这个 true 会被 pcall 捕获为 result_or_error
        end
        msg = trimmed_msg_content -- 更新 msg 为 trim后的
        step = 3; debug_log("Message trimmed: " .. msg)

        if starts_with(msg, "tc ") then
            step = 4; debug_log("Message starts with 'tc '.")
            local parts = parse_tc_command_internal(msg) -- parse_tc_command_internal 内部有 gmatch
            step = 5; debug_log("Message parsed into parts. Part count: " .. tostring(#parts))
            if #parts > 0 then debug_log("Part 1 (command prefix): " .. tostring(parts[1])) end
            if #parts > 1 then debug_log("Part 2 (main command): " .. tostring(parts[2])) end
            -- Log all parts for very detailed debugging if necessary
            -- for i, p_part in ipairs(parts) do debug_log(string.format("Part %d: %s", i, tostring(p_part))) end

            if parts[2] then
                step = 6; debug_log("parts[2] exists: " .. tostring(parts[2]))
                local cmd_group = string.lower(parts[2])
                step = 7; debug_log("cmd_group is: " .. cmd_group)

                if cmd_group == "config" then
                    step = 8; debug_log("cmd_group is 'config'. Calling process_config_command.")
                    process_config_command(parts, e_player)
                    step = 9; debug_log("process_config_command completed.")
                elseif cmd_group == "help" then show_help(e_player); step = 9.1; debug_log("show_help completed.")
                elseif cmd_group == "status" then show_status(e_player); step = 9.2; debug_log("show_status completed.")
                elseif cmd_group == "context" then process_context_command(parts, e_player); step = 9.3; debug_log("process_context_command completed.")
                elseif cmd_group == "rules" then process_rules_command(parts, e_player); step = 9.4; debug_log("process_rules_command completed.")
                elseif cmd_group == "test" then process_test_command(parts, e_player); step = 9.5; debug_log("process_test_command completed.")
                elseif cmd_group == "debug" and parts[3] and string.lower(parts[3]) == "toggle_complex_name_detection" then
                    step = 9.6; debug_log("Toggling complex name detection.")
                    state.perform_complex_name_detection = not state.perform_complex_name_detection
                    safe_broadcast("Complex name detection is now: " .. (state.perform_complex_name_detection and "ENABLED" or "DISABLED"), nil, e_player)
                    log_message("perform_complex_name_detection toggled to: " .. tostring(state.perform_complex_name_detection), LOG_LEVEL.WARNING)
                    if state.auto_context then pcall(refresh_game_context) end
                    if not state.ui_minimized and state.ui_created_once then pcall(create_ui) end
                    step = 9.7; debug_log("Complex name detection toggled and UI/context potentially refreshed.")
                else 
                    step = 10; debug_log("Unknown 'tc' command group: " .. cmd_group)
                    safe_player_action(e_player, function(p) p.print(string.format("❌ 未知 'tc' 命令组: '%s'。请尝试 'tc help'。", cmd_group)) end, "未知tc命令")
                end
            else 
                step = 11; debug_log("parts[2] does not exist. Calling show_help.")
                show_help(e_player)
            end
            step = 12; debug_log("'tc' command processing branch finished. Returning false from pcall inner function.")
            return false -- 这个 false 会被 pcall 捕获为 result_or_error
        elseif starts_with(msg, "@tc ") then
            step = 13; debug_log("Message starts with '@tc '.")
            local question = trim(string.sub(msg, #("@tc ") + 1)) 
            step = 14; debug_log("Question for LLM: " .. question)
            if question == "" then 
                step = 15; debug_log("LLM question is empty.")
                safe_player_action(e_player, function(p) p.print("⚠️ LLM问题不能为空。用法: @tc <你的问题>") end, "空LLM问题")
            else 
                step = 16; debug_log("Calling query_llm.")
                query_llm(question, e_player, false)
                step = 17; debug_log("query_llm completed.")
            end
            step = 18; debug_log("'@tc' command processing branch finished. Returning false from pcall inner function.")
            return false -- 这个 false 会被 pcall 捕获为 result_or_error
        end
        step = 19; debug_log("Message did not match 'tc ' or '@tc '. Returning true from pcall inner function.")
        return true -- 这个 true 会被 pcall 捕获为 result_or_error
    end) -- end pcall

    if not success_onchat then
        log_message(string.format("!!!!!!!! LUA ERROR in onChat !!!!!!!! Error at approx step %d. Message: %s", step, tostring(result_or_error)), LOG_LEVEL.ERROR)
        
        local error_report_msg = "[TC] Critical Lua Error in onChat. Check script logs."
        if e_player and e_player.print and type(e_player.print) == 'function' then
            pcall(e_player.print, error_report_msg, {1,0,0})
        elseif broadcastToAll and type(broadcastToAll) == 'function' then
             pcall(broadcastToAll, error_report_msg, {1,0,0})
        end
        return false
    end
    
    log_message("[DEBUG] pcall in onChat was successful. Inner func returned: " .. tostring(result_or_error) .. ". Forcing true.", LOG_LEVEL.ERROR)
    return true -- MODIFIED FOR DEBUGGING: Always return true if pcall succeeded
    -- return result_or_error 
end
    
function onObjectDrop(player_color, obj)
    if state.ready and state.auto_context then
        if Wait and Wait.time then Wait.time(function() pcall(refresh_game_context) end, 0.5) else pcall(refresh_game_context) end
    end
end

function onPlayerChangeColor(new_color)
    if state.ready and state.auto_context then
        if Wait and Wait.time then Wait.time(function() pcall(refresh_game_context) end, 1.0) else pcall(refresh_game_context) end
    end
end

function onGameLoaded()
    if state.ready then
        state.current_game_name = "未知游戏" 
        pcall(refresh_game_context)
        sync_rules_status_from_server(nil)
    end
end

log_message("TabletopCompanion.lua definitions loaded.", LOG_LEVEL.ERROR)
