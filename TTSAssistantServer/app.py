#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TabletopSimulatorCompanion (TTS Companion) - 服务端入口
"""

from flask import Flask, request, jsonify
import os
import json
from services.workshop_manager import WorkshopManager
from services.langchain_manager import LangchainManager
import config as cfg

app = Flask(__name__)
workshop_manager = WorkshopManager()
langchain_manager = LangchainManager()

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
    
    answer = langchain_manager.get_answer(question, game_name, player_id)
    return jsonify({"answer": answer, "player_id": player_id})

@app.route('/rulebook', methods=['GET'])
def get_rulebooks():
    """获取当前游戏的规则书列表"""
    game_name = request.args.get('game_name')
    if not game_name:
        return jsonify({"error": "缺少游戏名称"}), 400
    
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
    
    # 检查是否有可自动加载的规则书
    rulebook_info = workshop_manager.check_auto_load_rulebook(game_name)
    auto_rag_loaded = False
    
    if rulebook_info and os.path.exists(rulebook_info['editable_text_path']):
        # 检查文件是否非空
        file_size = os.path.getsize(rulebook_info['editable_text_path'])
        if file_size > 0:  # 如果文件非空，加载RAG索引
            langchain_manager.add_rulebook_text(rulebook_info['editable_text_path'], game_name)
            workshop_manager.update_rulebook_status(game_name, rulebook_info['pdf_identifier_key'], "processed_into_rag")
            auto_rag_loaded = True
    
    # 如果之前未发现该游戏的规则书引用，创建默认条目
    if not workshop_manager.has_game(game_name):
        workshop_manager.create_default_rulebook_entry(game_name)
    
    return jsonify({
        "status": "success", 
        "message": f"游戏 {game_name} 已加载", 
        "auto_rag_loaded": auto_rag_loaded
    })

@app.route('/api/rulebook/refresh_rag_from_cache', methods=['POST'])
def refresh_rag_from_cache():
    """从用户填充的缓存文件更新RAG索引"""
    data = request.json
    game_name = data.get('game_name')
    identifier = data.get('identifier')  # 编号或部分文件名
    
    if not all([game_name, identifier]):
        return jsonify({"error": "缺少必要参数"}), 400
    
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