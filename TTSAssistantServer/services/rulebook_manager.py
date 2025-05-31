#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TabletopSimulatorCompanion (TTS Companion) - 规则书管理器
负责创建和管理规则书的缓存文件
"""

import os
import re
from pathlib import Path
import config as cfg

class RulebookManager:
    """管理规则书的缓存文件"""
    
    def __init__(self):
        """初始化规则书管理器"""
        self.cache_dir = cfg.EDITABLE_RULEBOOK_TEXT_CACHE_DIRECTORY
        os.makedirs(self.cache_dir, exist_ok=True)
    
    def slugify(self, text: str) -> str:
        """将文本转换为URL友好的格式"""
        # 移除非字母数字字符
        text = re.sub(r'[^\w\s-]', '', text.lower())
        # 将空格替换为下划线
        text = re.sub(r'[\s]+', '_', text)
        return text
    
    def create_rulebook_file(self, game_name: str, filename: str) -> str:
        """
        为规则书创建空的缓存文件
        
        Args:
            game_name: 游戏名称
            filename: 规则书文件名（已标准化）
            
        Returns:
            str: 创建的缓存文件的绝对路径
        """
        # 为游戏创建子目录
        game_dir = os.path.join(self.cache_dir, self.slugify(game_name))
        os.makedirs(game_dir, exist_ok=True)
        
        # 构建文件路径
        file_path = os.path.join(game_dir, filename)
        
        # 仅在文件不存在时创建空文件（避免覆盖用户已填充的内容）
        if not os.path.exists(file_path):
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(self._generate_template_content(game_name, filename))
        
        return file_path
    
    def _generate_template_content(self, game_name: str, filename: str) -> str:
        """生成规则书模板内容"""
        return f"""# {game_name} 规则书

## 使用说明

这是一个用于填充游戏规则的模板文件。请将游戏规则文本粘贴到此处，然后使用 `tc rulebook refresh_cache {game_name} {Path(filename).stem}` 命令更新RAG索引。

## 规则内容

[在此处粘贴游戏规则...]

""" 