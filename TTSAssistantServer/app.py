#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TabletopSimulatorCompanion (TTS Companion) - 服务端入口
"""

from flask import Flask, request, jsonify, Response
import os
import json
from services.workshop_manager import WorkshopManager
from services.langchain_manager import LangchainManager
import config as cfg

app = Flask(__name__)
workshop_manager = WorkshopManager()
langchain_manager = LangchainManager()
app.json.ensure_ascii = False

@app.route('/ask', methods=['POST'])
def ask():
    """处理来自TTS Mod的问题请求"""
    data = request.json
    question = data.get('question')
    game_name = data.get('game_name')
    player_info = data.get('player_info', {})
    player_id = player_info.get('player_id')
    
    if not all([question, game_name, player_id]):
        return jsonify({"error": "缺少必要参数"}), 400
    
    # 清理 game_name
    if isinstance(game_name, str):
        game_name = game_name.strip()

    answer = langchain_manager.get_answer(question, game_name, player_id)
    # import json as std_json
    # manual_json_string = std_json.dumps(answer, ensure_ascii=False)
    # print(f"9. Manual JSON string with std_json.dumps(ensure_ascii=False) (repr): {repr(manual_json_string)}")
    # return Response(manual_json_string, mimetype='application/json; charset=utf-8')
    return jsonify({"answer": answer, "player_id": player_id})

@app.route('/rulebook', methods=['GET'])
def get_rulebooks():
    """获取当前游戏的规则书列表"""
    game_name = request.args.get('game_name')
    if not game_name:
        return jsonify({"error": "缺少游戏名称"}), 400
    
    # 清理 game_name
    if isinstance(game_name, str):
        game_name = game_name.strip()

    rulebooks = workshop_manager.get_game_rulebook_info(game_name)
    return jsonify({"rulebooks": rulebooks})

@app.route('/session/reset', methods=['POST'])
def reset_session():
    """重置会话记忆"""
    data = request.json
    game_name = data.get('game_name')
    player_info = data.get('player_info', {})
    player_id = player_info.get('player_id')
    
    if not game_name:
        return jsonify({"error": "缺少游戏名称"}), 400
    
    # 清理 game_name
    if isinstance(game_name, str):
        game_name = game_name.strip()

    if player_id:
        langchain_manager.reset_conversation(game_name, player_id)
        return jsonify({"status": "success", "message": f"已重置玩家 {player_id} 在 {game_name} 的会话"})
    else:
        langchain_manager.clear_game_state(game_name)
        return jsonify({"status": "success", "message": f"已重置 {game_name} 的所有会话和RAG状态"})

@app.route('/api/game/loaded', methods=['POST'])
def game_loaded():
    """处理游戏加载通知"""
    data = request.json
    game_name = data.get('game_name')
    
    if not game_name:
        return jsonify({"error": "缺少游戏名称"}), 400

    # 清理 game_name
    cleaned_game_name = game_name.strip() if isinstance(game_name, str) else game_name
    
    auto_rag_processed_from_md = False
    
    # 1. 检查是否有单个规则书 .md 文件可以自动处理成RAG索引
    rulebook_info_for_md_processing = workshop_manager.check_auto_load_rulebook(cleaned_game_name)
    
    if rulebook_info_for_md_processing and os.path.exists(rulebook_info_for_md_processing['editable_text_path']):
        file_size = os.path.getsize(rulebook_info_for_md_processing['editable_text_path'])
        # 假设模板内容小于100字节 (或者可以检查是否与预定义模板完全相同)
        if file_size > 100: 
            try:
                print(f"Game loaded: Found rulebook .md for '{cleaned_game_name}', attempting to process into RAG.")
                langchain_manager.add_rulebook_text(
                    rulebook_info_for_md_processing['editable_text_path'], 
                    cleaned_game_name
                )
                # 更新 WorkshopManager 中的状态
                pdf_key = rulebook_info_for_md_processing.get('pdf_identifier_key') or \
                          workshop_manager.get_identifier_key_by_path(
                              cleaned_game_name, 
                              rulebook_info_for_md_processing['editable_text_path']
                          )
                if pdf_key:
                     workshop_manager.update_rulebook_status(
                         cleaned_game_name, 
                         pdf_key, 
                         "processed_into_rag"
                     )
                auto_rag_processed_from_md = True
                print(f"Game loaded: Successfully processed .md into RAG for '{cleaned_game_name}'.")
            except Exception as e:
                print(f"Game loaded: Error processing .md into RAG for '{cleaned_game_name}': {e}")
        else:
            print(f"Game loaded: Rulebook .md for '{cleaned_game_name}' found but is empty or only template, skipping RAG processing.")
    
    # 2. 无论 .md 文件是否被处理，都尝试从磁盘加载已存在的RAG索引
    retriever_loaded = langchain_manager.load_or_get_retriever(cleaned_game_name)
    
    final_auto_rag_loaded_status = auto_rag_processed_from_md or (retriever_loaded is not None)

    # 3. 如果游戏首次加载且 WorkshopManager 中没有记录，创建默认条目
    if not workshop_manager.has_game(cleaned_game_name):
        print(f"Game loaded: First time loading '{cleaned_game_name}', creating default rulebook entry.")
        workshop_manager.create_default_rulebook_entry(cleaned_game_name)
    
    return jsonify({
        "status": "success", 
        "message": f"游戏 {cleaned_game_name} 已加载", 
        "auto_rag_loaded": final_auto_rag_loaded_status
    })

@app.route('/api/rulebook/refresh_rag_from_cache', methods=['POST'])
def refresh_rag_from_cache():
    """从用户填充的缓存文件更新RAG索引"""
    data = request.json
    game_name = data.get('game_name')
    identifier = data.get('identifier')  # 编号或部分文件名
    
    if not all([game_name, identifier]):
        return jsonify({"error": "缺少必要参数"}), 400
    
    # 清理 game_name
    if isinstance(game_name, str):
        game_name = game_name.strip()

    rulebook_path = workshop_manager.resolve_rulebook_path(game_name, identifier)
    if not rulebook_path:
        return jsonify({"error": f"找不到匹配的规则书: {identifier}"}), 404
    
    if not os.path.exists(rulebook_path):
        return jsonify({"error": f"规则书文件不存在: {rulebook_path}"}), 404
    
    try:
        langchain_manager.add_rulebook_text(rulebook_path, game_name)
        pdf_identifier_key = workshop_manager.get_identifier_key_by_path(game_name, rulebook_path)
        if pdf_identifier_key:
            workshop_manager.update_rulebook_status(game_name, pdf_identifier_key, "processed_into_rag")
        return jsonify({"status": "success", "message": f"成功从 {os.path.basename(rulebook_path)} 更新RAG索引"})
    except Exception as e:
        return jsonify({"error": f"更新RAG索引失败: {str(e)}"}), 500

if __name__ == '__main__':
    # 启动时扫描TTS数据目录
    workshop_manager.scan_all_tts_data()
    
    # 启动Flask应用
    app.run(host=cfg.HOST, port=cfg.PORT) 