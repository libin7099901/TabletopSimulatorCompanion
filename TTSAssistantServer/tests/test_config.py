#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TabletopSimulatorCompanion (TTS Companion) - 配置模块单元测试
"""

import os
import unittest
import sys
import pathlib

# 添加父目录到导入路径
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent.absolute()))

# 导入配置模块
import config as cfg

class TestConfig(unittest.TestCase):
    """配置模块测试类"""

    def test_base_config(self):
        """测试基本配置是否正确加载"""
        # 测试默认配置值
        self.assertEqual(cfg.HOST, '0.0.0.0')
        self.assertEqual(cfg.PORT, 5678)
        
        # 测试路径配置
        self.assertTrue(hasattr(cfg, 'BASE_DIR'))
        self.assertTrue(hasattr(cfg, 'EDITABLE_RULEBOOK_TEXT_CACHE_DIRECTORY'))
        self.assertTrue(hasattr(cfg, 'VECTOR_STORE_DIRECTORY'))
        self.assertTrue(hasattr(cfg, 'PROCESSED_MODS_FILE'))
        
        # 验证目录结构
        base_dir = pathlib.Path(cfg.BASE_DIR)
        self.assertTrue(base_dir.exists())
    
    def test_llm_config(self):
        """测试LLM配置是否正确"""
        # 测试LLM提供商配置
        self.assertTrue(hasattr(cfg, 'LLM_PROVIDER'))
        
        # 测试各个LLM相关配置
        self.assertTrue(hasattr(cfg, 'GEMINI_API_KEY'))
        self.assertTrue(hasattr(cfg, 'GEMINI_MODEL'))
        self.assertTrue(hasattr(cfg, 'OLLAMA_BASE_URL'))
        self.assertTrue(hasattr(cfg, 'OLLAMA_MODEL'))
        self.assertTrue(hasattr(cfg, 'OPENAI_API_KEY'))
        self.assertTrue(hasattr(cfg, 'OPENAI_MODEL'))
    
    def test_embedding_config(self):
        """测试Embedding配置是否正确"""
        # 测试Embedding提供商配置
        self.assertTrue(hasattr(cfg, 'EMBEDDING_PROVIDER'))
        self.assertTrue(hasattr(cfg, 'EMBEDDING_MODEL'))
        
        # 测试Sentence Transformer配置
        self.assertTrue(hasattr(cfg, 'SENTENCE_TRANSFORMER_MODEL'))
        self.assertEqual(cfg.SENTENCE_TRANSFORMER_MODEL, 'all-MiniLM-L6-v2')

if __name__ == '__main__':
    unittest.main() 