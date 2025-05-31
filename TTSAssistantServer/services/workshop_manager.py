#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TabletopSimulatorCompanion (TTS Companion) - Workshop管理器
负责扫描TTS数据目录，管理规则书元数据
"""

import os
import json
import re
import glob
import pathlib
from typing import Dict, List, Optional, Any
import config as cfg
from services.rulebook_manager import RulebookManager

class WorkshopManager:
    """管理TTS Workshop数据和规则书元数据"""
    
    def __init__(self):
        """初始化Workshop管理器"""
        self.rulebook_manager = RulebookManager()
        self.processed_mods_file = cfg.PROCESSED_MODS_FILE
        self.processed_mods = self._load_processed_mods()
        
    def _load_processed_mods(self) -> Dict:
        """从JSON文件加载已处理的Mod数据"""
        if os.path.exists(self.processed_mods_file):
            try:
                with open(self.processed_mods_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except json.JSONDecodeError:
                print(f"警告: {self.processed_mods_file} 解析失败，将创建新文件")
        return {}
    
    def _save_processed_mods(self):
        """保存已处理的Mod数据到JSON文件"""
        # 确保目录存在
        os.makedirs(os.path.dirname(self.processed_mods_file), exist_ok=True)
        
        with open(self.processed_mods_file, 'w', encoding='utf-8') as f:
            json.dump(self.processed_mods, f, ensure_ascii=False, indent=2)
    
    def slugify(self, text: str) -> str:
        """将文本转换为URL友好的格式"""
        # 移除非字母数字字符
        text = re.sub(r'[^\w\s-]', '', text.lower())
        # 将空格替换为下划线
        text = re.sub(r'[\s]+', '_', text)
        return text
    
    def scan_all_tts_data(self):
        """扫描整个TTS数据目录，查找所有游戏和规则书引用"""
        if not cfg.TTS_DATA_DIRECTORY or not os.path.exists(cfg.TTS_DATA_DIRECTORY):
            print(f"错误: TTS数据目录不存在: {cfg.TTS_DATA_DIRECTORY}")
            return
        
        # 扫描Mods目录
        mods_dir = os.path.join(cfg.TTS_DATA_DIRECTORY, "Mods")
        if os.path.exists(mods_dir):
            self._scan_directory(mods_dir)
        
        # 扫描Saves目录
        saves_dir = os.path.join(cfg.TTS_DATA_DIRECTORY, "Saves")
        if os.path.exists(saves_dir):
            self._scan_directory(saves_dir)
        
        # 保存处理结果
        self._save_processed_mods()
        
        print(f"扫描完成，已处理 {len(self.processed_mods)} 个游戏")
    
    def _scan_directory(self, directory: str):
        """扫描指定目录中的JSON文件，查找游戏和规则书引用"""
        json_files = glob.glob(os.path.join(directory, "**", "*.json"), recursive=True)
        
        for json_file in json_files:
            try:
                with open(json_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                
                # 获取游戏名称
                game_name = data.get('SaveName') or data.get('Name')
                if not game_name:
                    continue
                
                # 查找规则书引用
                rulebook_refs = self._find_rulebook_refs(data)
                if rulebook_refs:
                    self._process_rulebook_refs(game_name, rulebook_refs)
                
            except (json.JSONDecodeError, UnicodeDecodeError):
                continue
    
    def _find_rulebook_refs(self, data: Dict) -> List[str]:
        """在游戏数据中查找规则书引用"""
        rulebook_refs = []
        
        # 检查常见的规则书引用位置
        # 这里是简化的示例，实际上应该更全面地检查各种可能的引用方式
        if isinstance(data, dict):
            # 检查NotebookTab中的PDF引用
            notebook = data.get('Notebook', [])
            if isinstance(notebook, list):
                for tab in notebook:
                    if isinstance(tab, dict):
                        content = tab.get('Content', '')
                        if isinstance(content, str) and '.pdf' in content.lower():
                            pdf_refs = re.findall(r'https?://[^\s<>"]+?\.pdf|[^\s<>"]+?\.pdf', content)
                            rulebook_refs.extend(pdf_refs)
        
        return rulebook_refs
    
    def _process_rulebook_refs(self, game_name: str, rulebook_refs: List[str]):
        """处理游戏中的规则书引用"""
        if game_name not in self.processed_mods:
            self.processed_mods[game_name] = {
                "_game_display_name": game_name,
                "rulebooks": {}
            }
        
        for i, ref in enumerate(rulebook_refs):
            # 规范化引用标识符
            pdf_identifier_key = ref
            
            # 如果规则书已经处理过，跳过
            if pdf_identifier_key in self.processed_mods[game_name].get("rulebooks", {}):
                continue
            
            # 从引用中提取文件名
            filename = os.path.basename(ref)
            normalized_filename = f"rulebook_{self.slugify(os.path.splitext(filename)[0])}.md"
            
            # 创建规则书缓存文件
            editable_text_path = self.rulebook_manager.create_rulebook_file(game_name, normalized_filename)
            
            # 添加规则书元数据
            self.processed_mods[game_name]["rulebooks"][pdf_identifier_key] = {
                "original_source": ref,
                "normalized_filename": normalized_filename,
                "editable_text_path": editable_text_path,
                "status": "awaiting_user_content",
                "display_id": str(len(self.processed_mods[game_name]["rulebooks"]) + 1)
            }
    
    def create_default_rulebook_entry(self, game_name: str):
        """为游戏创建默认的规则书条目"""
        if game_name not in self.processed_mods:
            self.processed_mods[game_name] = {
                "_game_display_name": game_name,
                "rulebooks": {}
            }
        
        # 默认规则书标识符
        default_key = f"default_for_{game_name}"
        
        # 如果默认规则书已经存在，跳过
        if default_key in self.processed_mods[game_name].get("rulebooks", {}):
            return
        
        # 创建默认规则书文件名
        normalized_filename = f"rulebook_default_for_{self.slugify(game_name)}.md"
        
        # 创建规则书缓存文件
        editable_text_path = self.rulebook_manager.create_rulebook_file(game_name, normalized_filename)
        
        # 添加规则书元数据
        self.processed_mods[game_name]["rulebooks"][default_key] = {
            "original_source": default_key,
            "normalized_filename": normalized_filename,
            "editable_text_path": editable_text_path,
            "status": "awaiting_user_content",
            "display_id": str(len(self.processed_mods[game_name]["rulebooks"]) + 1)
        }
        
        # 保存更新
        self._save_processed_mods()
    
    def get_game_rulebook_info(self, game_name: str) -> List[Dict]:
        """获取游戏的规则书信息列表"""
        rulebooks = []
        
        if game_name in self.processed_mods:
            for pdf_key, rulebook_info in self.processed_mods[game_name].get("rulebooks", {}).items():
                rulebooks.append({
                    "id": rulebook_info.get("display_id", ""),
                    "name": rulebook_info.get("normalized_filename", ""),
                    "status": rulebook_info.get("status", ""),
                    "path": rulebook_info.get("editable_text_path", "")
                })
        
        return rulebooks
    
    def has_game(self, game_name: str) -> bool:
        """检查是否存在指定游戏的元数据"""
        return game_name in self.processed_mods
    
    def check_auto_load_rulebook(self, game_name: str) -> Optional[Dict]:
        """检查是否有可自动加载的规则书"""
        if game_name in self.processed_mods:
            rulebooks = self.processed_mods[game_name].get("rulebooks", {})
            
            # 如果只有一个规则书，返回它的信息
            if len(rulebooks) == 1:
                pdf_identifier_key = next(iter(rulebooks))
                return {
                    "pdf_identifier_key": pdf_identifier_key,
                    **rulebooks[pdf_identifier_key]
                }
        
        return None
    
    def update_rulebook_status(self, game_name: str, pdf_identifier_key: str, status: str):
        """更新规则书状态"""
        if (game_name in self.processed_mods and 
            pdf_identifier_key in self.processed_mods[game_name].get("rulebooks", {})):
            self.processed_mods[game_name]["rulebooks"][pdf_identifier_key]["status"] = status
            self._save_processed_mods()
    
    def resolve_rulebook_path(self, game_name: str, identifier: str) -> Optional[str]:
        """根据编号或部分文件名解析规则书路径"""
        if game_name not in self.processed_mods:
            return None
        
        rulebooks = self.processed_mods[game_name].get("rulebooks", {})
        
        # 尝试按编号查找
        for pdf_key, info in rulebooks.items():
            if info.get("display_id") == identifier:
                return info.get("editable_text_path")
        
        # 尝试按部分文件名查找
        for pdf_key, info in rulebooks.items():
            filename = info.get("normalized_filename", "")
            if identifier.lower() in filename.lower():
                return info.get("editable_text_path")
        
        return None
    
    def get_identifier_key_by_path(self, game_name: str, path: str) -> Optional[str]:
        """根据文件路径获取pdf_identifier_key"""
        if game_name not in self.processed_mods:
            return None
        
        rulebooks = self.processed_mods[game_name].get("rulebooks", {})
        
        for pdf_key, info in rulebooks.items():
            if info.get("editable_text_path") == path:
                return pdf_key
        
        return None 