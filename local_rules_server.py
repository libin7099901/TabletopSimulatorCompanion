import base64
import pathlib
from flask import Flask, request, jsonify, make_response
from flask_cors import CORS
import requests # 用于代理Ollama请求
import os
import json # 用于解析 game_context_json
import google.generativeai as genai
# from google.generativeai.types import Part # For Part.from_bytes - 改为直接构造字典
import google.generativeai.types as genai_types # For specific exception types
import mimetypes

app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False #确保jsonify返回UTF-8而不是ASCII escapes
CORS(app) # 允许所有来源的跨域请求，方便TTS Mod调用

# 全局变量（在生产环境中，您可能希望使用更持久的存储）
current_rules_type = "none" # "none", "text", "image", "pdf"
current_rules_text = ""
current_rules_bytes = None # Stores raw bytes for image or PDF files
current_rules_file_path = None # 主要用于日志记录或未来可能的其他用途
current_rules_file_mime_type = None # 通用文件MIME类型
ollama_api_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434") + "/api/generate"

DEFAULT_SYSTEM_PROMPT = """You are a helpful and knowledgeable game assistant for tabletop games.
Your goal is to answer questions about game rules, game state, or provide guidance based on the information provided.
Be concise and clear in your answers.
If rules are provided, base your answers primarily on those rules.
If game context is provided, use it to understand the current situation in the game.
If both rules and context are provided, integrate them to give the most relevant answer."""

DEFAULT_GEMINI_MODEL = 'gemini-1.5-flash-latest' # User previously changed to gemini-2.5-flash-preview-05-20, reverting to a common one first for stability

def log_message(message):
    print(f"[Server Log] {message}")

@app.route('/load_rules', methods=['POST'])
def load_rules():
    global current_rules_type, current_rules_text, current_rules_bytes, current_rules_file_path, current_rules_file_mime_type
    data = request.get_json()
    if not data:
        response = make_response(jsonify({"status": "error", "message": "无效的请求: 未提供JSON数据"}), 400)
        response.mimetype = 'application/json; charset=utf-8'
        return response

    file_path_str = data.get('file_path')
    text_rules_content = data.get('text_rules')

    # Reset relevant globals before loading new rules
    current_rules_text = ""
    current_rules_bytes = None
    # current_rules_file_path is deliberately not reset here if we want to keep last loaded path info
    # current_rules_file_mime_type will be set by new file

    if file_path_str:
        log_message(f"收到加载文件规则请求，路径: {file_path_str}")
        file_path_obj = pathlib.Path(file_path_str)
        if not file_path_obj.is_file():
            log_message(f"错误: 文件未找到于 {file_path_str}")
            response = make_response(jsonify({"status": "error", "message": f"文件未找到: {file_path_str}"}), 404)
            response.mimetype = 'application/json; charset=utf-8'
            return response
        
        ext = file_path_obj.suffix.lower()
        mime_type = None
        detected_type = "none"

        if ext == ".pdf":
            mime_type = "application/pdf"
            detected_type = "pdf"
        elif ext == ".png":
            mime_type = "image/png"
            detected_type = "image"
        elif ext in [".jpg", ".jpeg"]:
            mime_type = "image/jpeg"
            detected_type = "image"
        elif ext == ".webp":
            mime_type = "image/webp"
            detected_type = "image"
        elif ext in [".heic", ".heif"]: # Added HEIC/HEIF based on Gemini docs
             mime_type = f"image/{ext[1:]}" # e.g. image/heic
             detected_type = "image"
        else:
            log_message(f"错误: 不支持的文件类型或无法识别的扩展名: {ext}")
            response = make_response(jsonify({"status": "error", "message": f"不支持的文件类型: {ext}"}), 400)
            response.mimetype = 'application/json; charset=utf-8'
            return response

        try:
            file_bytes_content = file_path_obj.read_bytes()
            current_rules_bytes = file_bytes_content
            current_rules_file_mime_type = mime_type
            current_rules_type = detected_type
            current_rules_file_path = str(file_path_obj.resolve()) # Store absolute path for reference
            
            log_message(f"{current_rules_type.capitalize()}规则 '{file_path_obj.name}' ({mime_type}) 已作为字节加载，长度: {len(current_rules_bytes)}")
            response = make_response(jsonify({"status": "success", "message": f"文件 '{file_path_obj.name}' ({mime_type}) 已成功加载为 {current_rules_type} 类型规则", "type": current_rules_type, "mime_type": mime_type}), 200)
            response.mimetype = 'application/json; charset=utf-8'
            return response
        except Exception as e:
            log_message(f"加载文件规则 '{file_path_str}' 时出错: {e}")
            # Reset on error to ensure clean state
            current_rules_bytes = None
            current_rules_file_mime_type = None
            current_rules_type = "none"
            response = make_response(jsonify({"status": "error", "message": f"加载文件规则时出错: {str(e)}"}), 500)
            response.mimetype = 'application/json; charset=utf-8'
            return response
    elif text_rules_content:
        log_message(f"收到加载文本规则请求，长度: {len(text_rules_content)}")
        current_rules_text = text_rules_content
        current_rules_bytes = None # Clear byte-based rules
        current_rules_file_mime_type = None
        current_rules_type = "text"
        log_message("文本规则已加载。")
        response = make_response(jsonify({"status": "success", "message": "文本规则已成功加载", "type": "text"}), 200)
        response.mimetype = 'application/json; charset=utf-8'
        return response
    else:
        log_message("错误: 请求中既未提供 file_path 也未提供 text_rules。")
        response = make_response(jsonify({"status": "error", "message": "请求必须包含 'file_path' 或 'text_rules'"}), 400)
        response.mimetype = 'application/json; charset=utf-8'
        return response

@app.route('/get_current_rules', methods=['GET'])
def get_current_rules_route(): # Renamed to avoid conflict with any potential global
    log_message(f"收到获取当前规则请求。当前类型: {current_rules_type}")
    if current_rules_type == "image" or current_rules_type == "pdf":
        response = make_response(jsonify({
            "status": "success", 
            "type": current_rules_type, 
            "file_byte_length": len(current_rules_bytes) if current_rules_bytes else 0,
            "mime_type": current_rules_file_mime_type,
            "file_path": current_rules_file_path,
            "message": f"{current_rules_type.capitalize()}规则当前已加载 (来自文件: {current_rules_file_path})"
        }), 200)
        response.mimetype = 'application/json; charset=utf-8'
        return response
    elif current_rules_type == "text":
        response = make_response(jsonify({
            "status": "success", 
            "type": "text", 
            "text_data_length": len(current_rules_text), # Return length instead of full text for brevity
            "message": "文本规则当前已加载"
        }), 200)
        response.mimetype = 'application/json; charset=utf-8'
        return response
    else: # none
        response = make_response(jsonify({
            "status": "success",
            "type": "none",
            "message": "当前没有规则被加载"
        }), 200)
        response.mimetype = 'application/json; charset=utf-8'
        return response

@app.route('/clear_rules', methods=['POST'])
def clear_rules_route(): # Renamed
    global current_rules_type, current_rules_text, current_rules_bytes, current_rules_file_path, current_rules_file_mime_type
    log_message("收到清除规则请求。")
    current_rules_type = "none"
    current_rules_text = ""
    current_rules_bytes = None
    current_rules_file_path = None # Also clear the path
    current_rules_file_mime_type = None
    log_message("规则已清除。")
    response = make_response(jsonify({"status": "success", "message": "所有规则已成功清除"}), 200)
    response.mimetype = 'application/json; charset=utf-8'
    return response

def generate_context_summary(game_context_data):
    if not game_context_data or not isinstance(game_context_data, dict):
        return ""

    summary_parts = ["\n--- Game Context Summary ---"]
    game_info = game_context_data.get("game_info", {})
    if game_info:
        summary_parts.append(f"Game: {game_info.get('game_name', 'Unknown')}")
        summary_parts.append(f"Players: {game_info.get('player_count', 'N/A')}")
        turn_info = game_info.get("turn_info", {})
        if turn_info:
            current_player = turn_info.get('current_player_color', 'N/A')
            round_num = turn_info.get('round', 'N/A')
            phase = turn_info.get('phase', 'N/A')
            summary_parts.append(f"Turn: Player {current_player}, Round {round_num}, Phase {phase}")

    objects_info = game_context_data.get("objects", {})
    if objects_info:
        summary_parts.append(f"Total Objects on Table: {objects_info.get('total_objects', 'N/A')}")
        # Basic summary of object types
        by_type = objects_info.get("by_type")
        if by_type and isinstance(by_type, dict) and len(by_type) > 0 :
            type_counts = ", ".join([f"{k}: {v}" for k, v in by_type.items() if v > 0])
            if type_counts:
                 summary_parts.append(f"Object Types: {type_counts}")


    players_detail = game_context_data.get("players", {})
    if players_detail and isinstance(players_detail, dict) and len(players_detail) > 0:
        player_names = [p_data.get("steam_name", p_color) for p_color, p_data in players_detail.items()]
        summary_parts.append(f"Seated Players: {', '.join(player_names) if player_names else 'N/A'}")

    if len(summary_parts) == 1: # Only the header
        return ""
    summary_parts.append("--- End Game Context Summary ---\n")
    return "\n".join(summary_parts)


@app.route('/ollama_proxy', methods=['POST'])
def ollama_proxy():
    log_message("收到Ollama代理请求 (新版)。")
    data_from_mod = request.get_json()

    if not data_from_mod:
        log_message("错误: Ollama代理请求缺少JSON数据。")
        response = make_response(jsonify({"status": "error", "message": "代理请求缺少JSON数据"}), 400)
        response.mimetype = 'application/json; charset=utf-8'
        return response

    user_question = data_from_mod.get('user_question')
    model_name = data_from_mod.get('model')
    game_context_json_str = data_from_mod.get('game_context_json') # This is a JSON string
    system_prompt_override = data_from_mod.get('system_prompt_override')
    stream_response = data_from_mod.get('stream', False)

    if not user_question or not model_name:
        log_message("错误: Ollama代理请求缺少 'user_question' 或 'model'。")
        response = make_response(jsonify({"status": "error", "message": "代理请求缺少 'user_question' 或 'model'"}), 400)
        response.mimetype = 'application/json; charset=utf-8'
        return response

    # 1. Determine System Prompt
    final_system_prompt = system_prompt_override if system_prompt_override else DEFAULT_SYSTEM_PROMPT
    
    # 2. Process Game Context
    game_context_summary = ""
    if game_context_json_str:
        try:
            game_context_data = json.loads(game_context_json_str) # Decode the JSON string
            game_context_summary = generate_context_summary(game_context_data)
            log_message("游戏上下文已解析并生成摘要。")
        except json.JSONDecodeError as e:
            log_message(f"错误: 解析 game_context_json 失败: {e}")
            # Optionally, inform the user or proceed without context
            game_context_summary = "\n[Context Error: Could not parse game context data provided by the mod.]\n"


    # 3. Assemble the final prompt for LLM
    prompt_parts = [final_system_prompt]
    if game_context_summary:
        prompt_parts.append(game_context_summary)

    # 4. Add Text Rules if available
    if current_rules_type == "text" and current_rules_text:
        prompt_parts.append("\n--- Game Rules (Text) ---")
        prompt_parts.append(current_rules_text)
        prompt_parts.append("--- End Game Rules (Text) ---\n")
        log_message("文本规则已附加到提示。")
    
    prompt_parts.append("\n--- User Question ---")
    prompt_parts.append(user_question)
    prompt_parts.append("--- End User Question ---\n")

    final_llm_prompt = "\n".join(prompt_parts)
    
    # Log parts of the prompt for debugging, not the whole thing if it's huge
    log_message(f"构建的最终提示开头: {final_llm_prompt[:300]}...")
    if len(final_llm_prompt) > 300:
        log_message(f"...最终提示结尾: {final_llm_prompt[-200:]}")

    # MODIFIED: Add instruction for Chinese response
    prompt_for_llm = f"请用中文回答以下问题，除非另有说明：{final_llm_prompt}"

    ollama_payload = {
        "model": model_name,
        "prompt": prompt_for_llm,
        "stream": stream_response,
        "system": final_system_prompt # Some Ollama versions might use this for system prompt explicitly
    }

    # 5. Add Image Rules if available (converting from bytes to base64 for Ollama)
    if current_rules_type == "image" and current_rules_bytes:
        try:
            img_base64_for_ollama = base64.b64encode(current_rules_bytes).decode('utf-8')
            ollama_payload["images"] = [img_base64_for_ollama]
            log_message(f"Ollama请求中附加了图片规则 (来自bytes, Base64编码后长度: {len(img_base64_for_ollama)})")
        except Exception as e:
            log_message(f"错误: 为Ollama Base64编码图片规则时失败: {e}")
    # Note: Ollama does not typically support PDFs directly in the same way as images in 'images' field.
    # If PDF text content is desired for Ollama, it should be extracted and put into the text prompt.
    
    log_message(f"向Ollama ({ollama_api_url}) 发送请求: 模型 {ollama_payload['model']}")

    try:
        response_from_ollama = requests.post(ollama_api_url, json=ollama_payload, timeout=180) # Increased timeout
        response_from_ollama.raise_for_status()
        
        log_message(f"Ollama响应状态码: {response_from_ollama.status_code}")
        response_content = response_from_ollama.json()
        
        # Ensure inner 'response' field is UTF-8 string if it's bytes (shouldn't be common for JSON)
        if 'response' in response_content and isinstance(response_content.get('response'), bytes):
            response_content['response'] = response_content['response'].decode('utf-8', errors='replace')

        response = make_response(jsonify({"status": "success", "response": response_content}), 200)
        response.mimetype = 'application/json'
        return response
    except requests.exceptions.Timeout:
        log_message(f"错误: 请求Ollama超时 ({ollama_api_url})")
        response = make_response(jsonify({"status": "error", "message": "请求Ollama超时"}), 504)
        response.mimetype = 'application/json; charset=utf-8'
        return response
    except requests.exceptions.RequestException as e:
        log_message(f"错误: 代理Ollama请求失败: {e}")
        error_detail = str(e)
        if hasattr(e, 'response') and e.response is not None:
            try:
                error_detail = e.response.json()
            except ValueError:
                error_detail = e.response.text 
        response = make_response(jsonify({"status": "error", "message": f"代理Ollama请求失败", "detail": error_detail}), 502)
        response.mimetype = 'application/json; charset=utf-8'
        return response

GEMINI_API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

@app.route('/gemini_proxy', methods=['POST'])
def gemini_proxy():
    log_message("收到Gemini代理请求 (SDK版本)。")
    data_from_mod = request.get_json()

    if not data_from_mod:
        log_message("错误: Gemini代理请求缺少JSON数据。")
        response = make_response(jsonify({"status": "error", "message": "代理请求缺少JSON数据"}), 400)
        response.mimetype = 'application/json; charset=utf-8'
        return response

    api_key = data_from_mod.get('api_key')
    model_name_from_mod = data_from_mod.get('model', DEFAULT_GEMINI_MODEL)
    user_question = data_from_mod.get('user_question')

    if not api_key or not user_question:
        missing_fields = []
        if not api_key: missing_fields.append("api_key")
        if not user_question: missing_fields.append("user_question")
        log_message(f"错误: Gemini代理请求缺少必要字段: {', '.join(missing_fields)}。")
        response = make_response(jsonify({"status": "error", "message": f"代理请求缺少必要字段: {', '.join(missing_fields)}"}), 400)
        response.mimetype = 'application/json; charset=utf-8'
        return response

    try:
        genai.configure(api_key=api_key)
    except Exception as e:
        log_message(f"错误: 配置Google GenAI SDK失败: {e}")
        response = make_response(jsonify({"status": "error", "message": "配置Google GenAI SDK失败", "detail": str(e)}), 500)
        response.mimetype = 'application/json; charset=utf-8'
        return response

    model = genai.GenerativeModel(model_name_from_mod)
    
    # --- 构建发送给SDK的 contents 列表 --- 
    sdk_contents = []
    
    # 1. 系统提示 (始终作为第一个文本部分，如果适用)
    # 对于Gemini 1.5 Pro，系统指令可以通过 `system_instruction` 参数传递给 `GenerativeModel` 构造函数
    # model = genai.GenerativeModel(model_name_from_mod, system_instruction=DEFAULT_SYSTEM_PROMPT)
    # 或者，如果模型不支持，则作为第一个 `Part`。
    # 为了更广泛的兼容性，我们将其作为第一个文本部分添加到 contents 中。
    # 但请注意，对于Gemini 1.5+，使用 `system_instruction` 是推荐的做法。
    # 为了简单起见，这里我们先将系统提示作为用户消息的一部分。
    full_prompt_text_parts = [DEFAULT_SYSTEM_PROMPT]

    # 2. 附加文本规则 (如果存在)
    if current_rules_type == "text" and current_rules_text:
        full_prompt_text_parts.append("\n--- Game Rules (Text) ---")
        full_prompt_text_parts.append(current_rules_text)
        full_prompt_text_parts.append("--- End Game Rules (Text) ---")
        log_message("文本规则已附加到Gemini提示。")

    # 3. 附加用户问题
    full_prompt_text_parts.append(f"\n\n--- User Question ---")
    full_prompt_text_parts.append(user_question)
    full_prompt_text_parts.append("--- End User Question ---")

    final_text_prompt_for_sdk = "\n".join(full_prompt_text_parts)
    # sdk_contents.append(final_text_prompt_for_sdk) # 将所有文本合并为一个部分

    # 4. 附加文件规则 (PDF或图片)
    if (current_rules_type == "image" or current_rules_type == "pdf") and current_rules_bytes and current_rules_file_mime_type:
        log_message(f"准备将 {current_rules_type} ({current_rules_file_mime_type}) 作为 inline_data 附加。原始字节长度: {len(current_rules_bytes)}")
        try:
            # 对于 inline_data，数据需要是Base64编码的字符串
            base64_encoded_data = base64.b64encode(current_rules_bytes).decode('utf-8')
            file_part_dict = {
                "inline_data": {
                    "mime_type": current_rules_file_mime_type,
                    "data": base64_encoded_data 
                }
            }
            sdk_contents.append(file_part_dict) 
            log_message(f"{current_rules_type.capitalize()}规则已作为字典 Part (Base64编码后) 附加。编码后数据预览 (首100字符): {base64_encoded_data[:100]}...")
        except Exception as e:
            log_message(f"错误: Base64编码或创建文件部分失败 for {current_rules_type}: {e}")
            # 根据情况决定是否要中止请求
    
    # 将文本提示作为另一个独立的 Content dict 添加
    if final_text_prompt_for_sdk: #确保有文本内容才添加
        sdk_contents.append({"parts": [{"text": final_text_prompt_for_sdk}]})
    # 旧的追加方式：sdk_contents.append(final_text_prompt_for_sdk)

    log_message(f"向Gemini SDK ({model_name_from_mod}) 发送请求。Contents包含 {len(sdk_contents)} 部分。")
    if sdk_contents:
        log_message(f"SDK Contents 预览: {str(sdk_contents)[:500]}...") # 打印部分内容以供调试

    try:
        # 确保 generation_config 合理，例如，避免过长的响应或过高的温度
        # generation_config = genai.types.GenerationConfig(
        #     candidate_count=1,
        #     max_output_tokens=2048,
        #     temperature=0.7,
        # )
        response_from_gemini = model.generate_content(
            sdk_contents, 
            # generation_config=generation_config,
            request_options={"timeout": 180} # 设置超时
            )
        
        # 检查是否有 .parts 并且 .parts[0] 是否有 .text
        if response_from_gemini.candidates and response_from_gemini.candidates[0].content and response_from_gemini.candidates[0].content.parts and response_from_gemini.candidates[0].content.parts[0].text:
            text_answer = response_from_gemini.text # .text 快捷访问
            log_message(f"Gemini SDK 成功提取答案: {text_answer[:200]}...")
            response = make_response(jsonify({"status": "success", "response": text_answer, "raw_gemini_response_summary": str(response_from_gemini)}), 200)
            response.mimetype = 'application/json; charset=utf-8'
            return response
        else:
            log_message(f"错误: 从Gemini SDK响应中提取文本答案失败或结构不符。响应: {response_from_gemini}")
            block_reason = response_from_gemini.prompt_feedback.block_reason if response_from_gemini.prompt_feedback else "Unknown"
            response = make_response(jsonify({"status": "error", "message": f"从Gemini SDK响应中提取文本答案失败 (Block reason: {block_reason})", "detail": str(response_from_gemini)}), 500)
            response.mimetype = 'application/json; charset=utf-8'
            return response

    except Exception as e:
        log_message(f"错误: 调用Gemini SDK时出错: {e}")
        # 尝试获取更详细的错误信息，例如Google API错误
        error_detail = str(e)
        if hasattr(e, 'response') and e.response is not None: # For requests-like errors if SDK wraps them
            try: error_detail = e.response.json()
            except: error_detail = e.response.text
        elif isinstance(e, genai.types.BlockedPromptException):
             error_detail = f"BlockedPromptException: {e}"
        elif isinstance(e, genai.types.StopCandidateException):
             error_detail = f"StopCandidateException: {e}"
        # Add more specific Google API error types if needed
        response = make_response(jsonify({"status": "error", "message": f"调用Gemini SDK时出错", "detail": error_detail}), 502)
        response.mimetype = 'application/json; charset=utf-8'
        return response

if __name__ == '__main__':
    log_message("启动本地规则和Ollama/Gemini代理服务器...")
    # 监听所有网络接口，方便同一网络下的TTS（如果不在本机运行）访问
    # 对于TTS在本机运行，'localhost' 或 '127.0.0.1' 也可以
    # 生产环境中应谨慎使用 '0.0.0.0'
    app.run(host='0.0.0.0', port=5678, debug=False) # 使用 debug=False 