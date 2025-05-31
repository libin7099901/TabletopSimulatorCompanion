#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TabletopSimulatorCompanion (TTS Companion) - Langchain管理器单元测试
"""

import os
import unittest
import sys
import pathlib
import tempfile
from unittest.mock import patch, MagicMock

# 添加父目录到导入路径
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent.absolute()))

# 导入测试目标
from services.langchain_manager import LangchainManager, ChatMessageHistory

class TestChatMessageHistory(unittest.TestCase):
    """测试对话历史记录类"""
    
    def test_chat_history(self):
        """测试对话历史基本功能"""
        history = ChatMessageHistory()
        
        # 测试初始状态
        self.assertEqual(len(history.messages), 0)
        
        # 测试添加用户消息
        history.add_user_message("Hello")
        self.assertEqual(len(history.messages), 1)
        self.assertEqual(history.messages[0].content, "Hello")
        
        # 测试添加AI消息
        history.add_ai_message("Hi there!")
        self.assertEqual(len(history.messages), 2)
        self.assertEqual(history.messages[1].content, "Hi there!")
        
        # 测试清空功能
        history.clear()
        self.assertEqual(len(history.messages), 0)

class TestLangchainManager(unittest.TestCase):
    """测试Langchain管理器类"""
    
    def setUp(self):
        """测试前设置"""
        # 创建临时目录用于测试
        self.temp_dir = tempfile.TemporaryDirectory()
        self.vector_store_dir = os.path.join(self.temp_dir.name, "vector_stores")
        os.makedirs(self.vector_store_dir, exist_ok=True)
        
        # 设置测试环境变量
        self.original_vector_store_dir = os.getenv('VECTOR_STORE_DIRECTORY')
        os.environ['VECTOR_STORE_DIRECTORY'] = self.vector_store_dir
        
        # 模拟配置
        self.mock_config = {
            'LLM_PROVIDER': 'gemini',
            'EMBEDDING_PROVIDER': 'sentence_transformers',
            'VECTOR_STORE_DIRECTORY': self.vector_store_dir
        }
    
    def tearDown(self):
        """测试后清理"""
        # 恢复环境变量
        if self.original_vector_store_dir:
            os.environ['VECTOR_STORE_DIRECTORY'] = self.original_vector_store_dir
        else:
            os.environ.pop('VECTOR_STORE_DIRECTORY', None)
        
        # 清理临时目录
        self.temp_dir.cleanup()
    
    @patch('services.langchain_manager.LangchainManager._initialize_llm')
    @patch('services.langchain_manager.LangchainManager._initialize_embeddings')
    def test_initialization(self, mock_init_embeddings, mock_init_llm):
        """测试LangchainManager初始化"""
        # 设置模拟对象的返回值
        mock_llm = MagicMock()
        mock_embeddings = MagicMock()
        mock_init_llm.return_value = mock_llm
        mock_init_embeddings.return_value = mock_embeddings
        
        # 初始化管理器
        manager = LangchainManager()
        
        # 验证初始化
        self.assertEqual(manager.llm, mock_llm)
        self.assertEqual(manager.embeddings, mock_embeddings)
        self.assertEqual(manager.game_sessions, {})
        self.assertEqual(manager.game_retrievers, {})
        
        # 验证调用
        mock_init_llm.assert_called_once()
        mock_init_embeddings.assert_called_once()
    
    @patch('services.langchain_manager.LangchainManager._initialize_llm')
    @patch('services.langchain_manager.LangchainManager._initialize_embeddings')
    def test_session_management(self, mock_init_embeddings, mock_init_llm):
        """测试会话管理功能"""
        # 设置模拟对象
        mock_init_llm.return_value = MagicMock()
        mock_init_embeddings.return_value = MagicMock()
        
        # 初始化管理器
        manager = LangchainManager()
        
        # 测试获取新的记忆对象
        game_name = "Test Game"
        player_id = "player1"
        memory = manager._get_or_create_memory(game_name, player_id)
        
        # 验证记忆对象被正确创建和存储
        self.assertTrue(game_name in manager.game_sessions)
        self.assertTrue(player_id in manager.game_sessions[game_name])
        self.assertEqual(memory, manager.game_sessions[game_name][player_id])
        
        # 测试重置对话
        manager.reset_conversation(game_name, player_id)
        
        # 测试清除游戏状态
        manager.clear_game_state(game_name)
        self.assertFalse(game_name in manager.game_sessions)

if __name__ == '__main__':
    unittest.main() 