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
import shutil # Added for robust cleanup
from unittest.mock import patch, MagicMock, ANY

# 添加父目录到导入路径
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent.absolute()))

# 导入测试目标
from services.langchain_manager import LangchainManager, ChatMessageHistory
import config as cfg # Import config directly for patching

# Helper to create a dummy markdown file
def create_dummy_md_file(directory, game_name, filename, content="Test rule: Be excellent to each other."):
    game_path = os.path.join(directory, game_name)
    os.makedirs(game_path, exist_ok=True)
    file_path = os.path.join(game_path, filename)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    return file_path

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
    
    @classmethod
    def setUpClass(cls):
        """在类级别捕获真实的系统代理设置，确保在任何补丁之前获取。"""
        http_proxy = os.environ.get('HTTP_PROXY')
        https_proxy = os.environ.get('HTTPS_PROXY')

        # 如果代理是 localhost，则替换为 127.0.0.1 以避免潜在的 DNS 解析问题
        if http_proxy and '://localhost:' in http_proxy:
            cls.actual_system_http_proxy = http_proxy.replace('://localhost:', '://127.0.0.1:')
        else:
            cls.actual_system_http_proxy = http_proxy
        
        if https_proxy and '://localhost:' in https_proxy:
            cls.actual_system_https_proxy = https_proxy.replace('://localhost:', '://127.0.0.1:')
        else:
            cls.actual_system_https_proxy = https_proxy
    
    def setUp(self):
        """测试前设置"""
        self.test_base_dir = tempfile.mkdtemp(prefix="langchain_mgr_test_")
        
        self.vector_store_dir = os.path.join(self.test_base_dir, "vector_stores")
        self.editable_texts_dir = os.path.join(self.test_base_dir, "editable_texts")
        os.makedirs(self.vector_store_dir, exist_ok=True)
        os.makedirs(self.editable_texts_dir, exist_ok=True)
        
        self.original_env = os.environ.copy()

        # self.mock_faiss_module = MagicMock() # No longer mocking faiss module itself
        # self.sys_modules_patch = patch.dict(sys.modules, {'faiss': self.mock_faiss_module})
        # self.sys_modules_patch.start()
        # self.addCleanup(self.sys_modules_patch.stop)

        self.mock_cfg_patches = [
            patch.object(cfg, 'VECTOR_STORE_DIRECTORY', self.vector_store_dir),
            patch.object(cfg, 'EDITABLE_RULEBOOK_TEXT_CACHE_DIRECTORY', self.editable_texts_dir),
            patch.object(cfg, 'LLM_PROVIDER', 'gemini'),
            patch.object(cfg, 'EMBEDDING_PROVIDER', 'gemini'),
            patch.object(cfg, 'GEMINI_API_KEY', 'test_gemini_api_key'),
            patch.object(cfg, 'GEMINI_MODEL', 'gemini-pro-test'),
            patch.object(cfg, 'GEMINI_EMBEDDING_MODEL', 'models/embedding-001-test'),
            patch.object(cfg, 'EMBEDDING_MODEL', None),
            patch.object(cfg, 'OLLAMA_MODEL', 'test-ollama-model'),
            patch.object(cfg, 'OLLAMA_BASE_URL', 'http://mock-ollama:11434'),
            patch.object(cfg, 'DEBUG', False) # Keep debug off for less verbose test output
        ]
        for p in self.mock_cfg_patches:
            p.start()
            self.addCleanup(p.stop) # Ensures these are stopped automatically
        
        # Mock os.environ for proxy settings if needed, or rely on Langchain using them
        # If Langchain's Google GenAI client directly uses os.environ.get for proxies,
        # then patching os.environ is the way to go.
        self.proxy_env_patch = patch.dict(os.environ, {
            "HTTP_PROXY": "http://mockproxy:1234",
            "HTTPS_PROXY": "https://mockproxy:1234"
        })
        self.proxy_env_patch.start()
        self.addCleanup(self.proxy_env_patch.stop)
    
    def tearDown(self):
        """测试后清理"""
        shutil.rmtree(self.test_base_dir)
        os.environ.clear()
        os.environ.update(self.original_env)
    
    @patch('services.langchain_manager.LangchainManager._initialize_llm')
    @patch('services.langchain_manager.LangchainManager._initialize_embeddings')
    def test_initialization(self, mock_init_embeddings, mock_init_llm):
        """测试LangchainManager初始化"""
        mock_llm = MagicMock()
        mock_embeddings = MagicMock()
        mock_init_llm.return_value = mock_llm
        mock_init_embeddings.return_value = mock_embeddings
        
        manager = LangchainManager()
        
        self.assertEqual(manager.llm, mock_llm)
        self.assertEqual(manager.embeddings, mock_embeddings)
        mock_init_llm.assert_called_once()
        mock_init_embeddings.assert_called_once()
    
    @patch('services.langchain_manager.LangchainManager._initialize_llm')
    @patch('services.langchain_manager.LangchainManager._initialize_embeddings')
    def test_session_management(self, mock_init_embeddings, mock_init_llm):
        """测试会话管理功能"""
        mock_init_llm.return_value = MagicMock()
        mock_init_embeddings.return_value = MagicMock()
        manager = LangchainManager()
        game_name = "Test Game"
        player_id = "player1"
        memory = manager._get_or_create_memory(game_name, player_id)
        self.assertTrue(game_name in manager.game_sessions)
        self.assertTrue(player_id in manager.game_sessions[game_name])
        self.assertEqual(memory, manager.game_sessions[game_name][player_id])
        manager.reset_conversation(game_name, player_id)
        manager.clear_game_state(game_name)
        self.assertFalse(game_name in manager.game_sessions)

    @patch('langchain_google_genai.ChatGoogleGenerativeAI')
    @patch('langchain_google_genai.GoogleGenerativeAIEmbeddings')
    @patch('services.langchain_manager.FAISS')
    def test_add_rulebook_and_get_answer_with_gemini_embs(self, mock_faiss_class, mock_google_embeddings_class, mock_google_chat_llm_class):
        """测试使用Gemini Embeddings添加规则书和RAG流程，并模拟LLM调用。"""
        
        # ---- Configure Mocks ----
        # Mock for ChatGoogleGenerativeAI (LLM)
        mock_llm_instance = MagicMock() # This is the instance LangchainManager will create
        # When the chain calls the LLM, it typically uses invoke or a similar method.
        # The response should be a AIMessage if return_messages=True in the chain/memory, or string content.
        # For ConversationalRetrievalChain, the final answer is extracted from the response dictionary.
        # We will mock the chain's internal call to the LLM, so the chain itself thinks it got a response.
        # For this test, let's assume the chain will eventually call something like llm.invoke() or llm.generate().
        # Since ConversationalRetrievalChain handles the specifics, we'll mock at the chain level for directness if possible,
        # or ensure our mock_llm_instance has a method that the chain calls, returning a structured response.
        # For now, let's set up the class mock to return our instance, and we will mock the chain interaction later.
        mock_google_chat_llm_class.return_value = mock_llm_instance

        # Mock for GoogleGenerativeAIEmbeddings
        mock_embeddings_instance = MagicMock()
        def mock_embed_documents(texts: list[str]):
            return [[0.1] * 768 for _ in texts] 
        mock_embeddings_instance.embed_documents.side_effect = mock_embed_documents
        mock_embeddings_instance.embed_query.return_value = [0.1] * 768
        mock_google_embeddings_class.return_value = mock_embeddings_instance

        # Mock for FAISS (Vector Store)
        mock_vector_store_instance = MagicMock()
        mock_faiss_class.from_documents.return_value = mock_vector_store_instance
        mock_faiss_class.load_local.return_value = mock_vector_store_instance # For when get_answer tries to load
        mock_retriever_instance = MagicMock()
        mock_vector_store_instance.as_retriever.return_value = mock_retriever_instance

        # ---- Test Execution ----
        # Initialize LangchainManager
        # This will call _initialize_llm and _initialize_embeddings, using our class mocks above
        manager = LangchainManager()

        # Verify Gemini LLM and Embeddings class mocks were called
        mock_google_chat_llm_class.assert_called_once_with(
            model=cfg.GEMINI_MODEL, 
            google_api_key=cfg.GEMINI_API_KEY
        )
        mock_google_embeddings_class.assert_called_once_with(
            model=cfg.GEMINI_EMBEDDING_MODEL,
            google_api_key=cfg.GEMINI_API_KEY
        )
        self.assertEqual(manager.llm, mock_llm_instance)
        self.assertEqual(manager.embeddings, mock_embeddings_instance)

        # Prepare and add rulebook
        game_name = "GeminiRAGTestGame"
        rulebook_filename = "gemini_rules.md"
        md_file_path = create_dummy_md_file(self.editable_texts_dir, game_name, rulebook_filename, "Rule: Gemini is fun.")
        manager.add_rulebook_text(md_file_path, game_name)

        # Verify FAISS.from_documents call and save
        mock_faiss_class.from_documents.assert_called_once()
        call_args_tuple = mock_faiss_class.from_documents.call_args
        actual_kwargs = call_args_tuple[1]
        self.assertTrue(len(actual_kwargs['documents']) > 0)
        self.assertEqual(actual_kwargs['embedding'], mock_embeddings_instance)
        mock_vector_store_instance.save_local.assert_called_once_with(os.path.join(self.vector_store_dir, game_name))
        self.assertIn(game_name, manager.game_retrievers) # Retriever should be stored

        # ---- Test get_answer ----
        player_id = "gemini_tester"
        question = "What is the rule about Gemini?"
        
        # Mock the actual chain execution part
        # The ConversationalRetrievalChain instance will be created inside get_answer.
        # We need to mock its invocation. The chain itself is an object, and it's callable.
        # So, we patch the class, make it return a callable mock (MagicMock instance is callable by default).
        mock_created_chain_instance = MagicMock()
        mock_created_chain_instance.return_value = {"answer": "LLM says: Gemini is indeed fun!", "source_documents": []}

        with patch('langchain.chains.ConversationalRetrievalChain.from_llm', return_value=mock_created_chain_instance) as mock_chain_from_llm:
            answer = manager.get_answer(question, game_name, player_id)
            
            # Assert that the chain was created with the correct components
            mock_chain_from_llm.assert_called_once()
            chain_call_args_tuple = mock_chain_from_llm.call_args
            chain_actual_kwargs = chain_call_args_tuple[1]
            self.assertEqual(chain_actual_kwargs['llm'], mock_llm_instance) # manager.llm
            self.assertEqual(chain_actual_kwargs['retriever'], mock_retriever_instance) # from manager.game_retrievers
            self.assertIsNotNone(chain_actual_kwargs['memory'])
            
            # Assert that the created chain was called with the question
            mock_created_chain_instance.assert_called_once_with({"question": question})
            self.assertEqual(answer, "LLM says: Gemini is indeed fun!")

        # Verify FAISS.load_local was NOT called if retriever already existed from add_rulebook_text
        # (as add_rulebook_text stores the retriever in self.game_retrievers[game_name])
        mock_faiss_class.load_local.assert_not_called()

    @patch('langchain_community.llms.Ollama') # Mock Ollama LLM class from its source
    @patch('langchain_community.embeddings.OllamaEmbeddings') # Mock Ollama Embeddings class from its source
    @patch('services.langchain_manager.FAISS') # Keep patching FAISS class used in LangchainManager
    def test_add_rulebook_and_get_answer_with_ollama(self, mock_faiss_class, mock_ollama_embeddings_class, mock_ollama_llm_class):
        """测试使用Ollama LLM和Embeddings添加规则书和RAG流程，并模拟LLM调用。"""
        
        # ---- Configure Patches for Ollama ----
        # Temporarily override config for this test
        with patch.object(cfg, 'LLM_PROVIDER', 'ollama'), \
             patch.object(cfg, 'EMBEDDING_PROVIDER', 'ollama'), \
             patch.object(cfg, 'OLLAMA_MODEL', 'test-ollama-model'), \
             patch.object(cfg, 'OLLAMA_BASE_URL', 'http://mock-ollama:11434'):

            # ---- Configure Mocks ----
            # Mock for Ollama LLM
            mock_llm_instance = MagicMock()
            mock_ollama_llm_class.return_value = mock_llm_instance

            # Mock for Ollama Embeddings
            mock_embeddings_instance = MagicMock()
            def mock_embed_documents(texts: list[str]):
                return [[0.2] * 768 for _ in texts] # Different dummy vector for ollama
            mock_embeddings_instance.embed_documents.side_effect = mock_embed_documents
            mock_embeddings_instance.embed_query.return_value = [0.2] * 768
            mock_ollama_embeddings_class.return_value = mock_embeddings_instance

            # Mock for FAISS (Vector Store) - same as in Gemini test
            mock_vector_store_instance = MagicMock()
            mock_faiss_class.from_documents.return_value = mock_vector_store_instance
            mock_faiss_class.load_local.return_value = mock_vector_store_instance
            mock_retriever_instance = MagicMock()
            mock_vector_store_instance.as_retriever.return_value = mock_retriever_instance

            # ---- Test Execution ----
            # Initialize LangchainManager - this will use the Ollama config due to patch.object
            manager = LangchainManager()

            # Verify Ollama LLM and Embeddings class mocks were called
            mock_ollama_llm_class.assert_called_once_with(
                model=cfg.OLLAMA_MODEL, # This will be 'test-ollama-model' due to patch
                base_url=cfg.OLLAMA_BASE_URL # 'http://mock-ollama:11434'
            )
            mock_ollama_embeddings_class.assert_called_once_with(
                model=cfg.OLLAMA_MODEL, # Assumes embedding model is same as LLM model for ollama if not specified
                base_url=cfg.OLLAMA_BASE_URL
            )
            self.assertEqual(manager.llm, mock_llm_instance)
            self.assertEqual(manager.embeddings, mock_embeddings_instance)

            # Prepare and add rulebook
            game_name = "OllamaRAGTestGame"
            rulebook_filename = "ollama_rules.md"
            md_file_path = create_dummy_md_file(self.editable_texts_dir, game_name, rulebook_filename, "Rule: Ollama is versatile.")
            manager.add_rulebook_text(md_file_path, game_name)

            # Verify FAISS.from_documents call and save
            mock_faiss_class.from_documents.assert_called_once()
            call_args_tuple = mock_faiss_class.from_documents.call_args
            actual_kwargs = call_args_tuple[1]
            self.assertTrue(len(actual_kwargs['documents']) > 0)
            self.assertEqual(actual_kwargs['embedding'], mock_embeddings_instance)
            mock_vector_store_instance.save_local.assert_called_once_with(os.path.join(self.vector_store_dir, game_name))
            self.assertIn(game_name, manager.game_retrievers)

            # ---- Test get_answer ----
            player_id = "ollama_tester"
            question = "What is the rule about Ollama?"
            
            mock_created_chain_instance = MagicMock()
            # The chain's __call__ or invoke method is what ultimately gets the answer
            mock_created_chain_instance.return_value = {"answer": "LLM (Ollama) says: Ollama is indeed versatile!", "source_documents": []}

            # Patch the chain creation within the get_answer call
            with patch('langchain.chains.ConversationalRetrievalChain.from_llm', return_value=mock_created_chain_instance) as mock_chain_from_llm:
                answer = manager.get_answer(question, game_name, player_id)
                
                mock_chain_from_llm.assert_called_once()
                chain_call_args_tuple = mock_chain_from_llm.call_args
                chain_actual_kwargs = chain_call_args_tuple[1]
                self.assertEqual(chain_actual_kwargs['llm'], mock_llm_instance)
                self.assertEqual(chain_actual_kwargs['retriever'], mock_retriever_instance)
                self.assertIsNotNone(chain_actual_kwargs['memory'])
                
                mock_created_chain_instance.assert_called_once_with({"question": question})
                self.assertEqual(answer, "LLM (Ollama) says: Ollama is indeed versatile!")

            mock_faiss_class.load_local.assert_not_called()

    def test_integration_get_answer_gemini_actual_services(self):
        """Integration test for Gemini LLM and Embeddings using actual services from .env."""
        
        # 使用在 setUpClass 中捕获的真实系统代理值
        actual_http_proxy_to_use = TestLangchainManager.actual_system_http_proxy
        actual_https_proxy_to_use = TestLangchainManager.actual_system_https_proxy

        # Fetch actual .env values (or defaults if not set in .env, matching config.py logic)
        actual_gemini_api_key = os.getenv('GEMINI_API_KEY', cfg.GEMINI_API_KEY)
        actual_gemini_model = os.getenv('GEMINI_MODEL', cfg.GEMINI_MODEL)
        actual_gemini_embedding_model = os.getenv('GEMINI_EMBEDDING_MODEL', cfg.GEMINI_EMBEDDING_MODEL)
        # actual_http_proxy and actual_https_proxy are now taken from setUpClass

        with patch.object(cfg, 'LLM_PROVIDER', 'gemini'), \
             patch.object(cfg, 'EMBEDDING_PROVIDER', 'gemini'), \
             patch.object(cfg, 'GEMINI_API_KEY', actual_gemini_api_key), \
             patch.object(cfg, 'GEMINI_MODEL', actual_gemini_model), \
             patch.object(cfg, 'GEMINI_EMBEDDING_MODEL', actual_gemini_embedding_model), \
             patch.dict(os.environ, {
                 'HTTP_PROXY': actual_http_proxy_to_use or '',
                 'HTTPS_PROXY': actual_https_proxy_to_use or ''
             }, clear=True): # Ensure clean proxy env for this test, using reliably sourced actual proxies
            
            print("\n--- Starting Gemini Integration Test ---")
            print(f"Using actual GEMINI_API_KEY: {'*' * 5 if actual_gemini_api_key else 'Not Set'}")
            print(f"Using actual GEMINI_MODEL: {actual_gemini_model}")
            print(f"Using actual GEMINI_EMBEDDING_MODEL: {actual_gemini_embedding_model}")
            if actual_http_proxy_to_use or actual_https_proxy_to_use:
                print(f"Attempting to use actual system Proxy: HTTP_PROXY={actual_http_proxy_to_use or 'Not set'}, HTTPS_PROXY={actual_https_proxy_to_use or 'Not set'}")
            else:
                print("No HTTP/HTTPS proxy from actual system environment for this test.")

            # No mocks for Gemini or FAISS classes here for actual service test
            manager = LangchainManager() 

            game_name = "GeminiActualServiceGame"
            rulebook_filename = "gemini_actual_rules.md"
            rule_content = "This is a test rule for the Gemini actual service integration. The capital of France is Paris. Gemini should answer questions based on this."
            md_file_path = create_dummy_md_file(self.editable_texts_dir, game_name, rulebook_filename, rule_content)
            
            print(f"Attempting to add rulebook for {game_name} using actual Gemini embeddings...")
            try:
                manager.add_rulebook_text(md_file_path, game_name) # Real Gemini Embeddings
                print(f"Rulebook for {game_name} added. FAISS index created in {self.vector_store_dir}")
                self.assertTrue(os.path.exists(os.path.join(self.vector_store_dir, game_name, "index.faiss")))
            except Exception as e:
                print(f"ERROR during add_rulebook_text with actual Gemini embeddings: {e}")
                self.fail(f"add_rulebook_text with actual Gemini embeddings failed: {e}")

            player_id = "actual_gemini_tester"
            question = "What is the capital of France according to the rules?"
            print(f"Asking question to {game_name} (Actual Gemini LLM): {question}")
            
            answer = None
            try:
                answer = manager.get_answer(question, game_name, player_id) # Real Gemini LLM
            except Exception as e:
                print(f"ERROR during get_answer with actual Gemini LLM: {e}")
                self.fail(f"get_answer with actual Gemini LLM failed: {e}")
            
            print(f"Actual Answer from Gemini for '{game_name}': {answer}")
            self.assertIsNotNone(answer, "Answer from Gemini LLM should not be None")
            self.assertTrue(len(answer) > 0, "Answer from Gemini LLM should not be empty")
            self.assertIn("Paris", answer, "Answer from Gemini should contain 'Paris' based on the rulebook content.")
            print("--- Gemini Integration Test Ended ---")

    def test_integration_get_answer_ollama_actual_services(self):
        """Integration test for Ollama LLM and Embeddings using actual services from .env."""
        
        # 使用在 setUpClass 中捕获的真实系统代理值
        actual_http_proxy_to_use = TestLangchainManager.actual_system_http_proxy
        actual_https_proxy_to_use = TestLangchainManager.actual_system_https_proxy

        actual_ollama_base_url = os.getenv('OLLAMA_BASE_URL', cfg.OLLAMA_BASE_URL)
        actual_ollama_model = os.getenv('OLLAMA_MODEL', cfg.OLLAMA_MODEL)
        actual_ollama_embedding_model = os.getenv('EMBEDDING_MODEL') 
        if not actual_ollama_embedding_model: 
            actual_ollama_embedding_model = actual_ollama_model
            
        # actual_http_proxy and actual_https_proxy are now taken from setUpClass - BUT OLLAMA DOES NOT NEED PROXY

        with patch.object(cfg, 'LLM_PROVIDER', 'ollama'), \
             patch.object(cfg, 'EMBEDDING_PROVIDER', 'ollama'), \
             patch.object(cfg, 'OLLAMA_BASE_URL', actual_ollama_base_url), \
             patch.object(cfg, 'OLLAMA_MODEL', actual_ollama_model), \
             patch.object(cfg, 'EMBEDDING_MODEL', actual_ollama_embedding_model), \
             patch.dict(os.environ, {
                 'HTTP_PROXY': '',  # Disable proxy for Ollama test
                 'HTTPS_PROXY': ''  # Disable proxy for Ollama test
             }, clear=True): # Ensure clean proxy env for this test, using reliably sourced actual proxies
            
            print("\n--- Starting Ollama Integration Test ---")
            print(f"Using actual OLLAMA_BASE_URL: {actual_ollama_base_url}")
            print(f"Using actual OLLAMA_MODEL (for LLM): {actual_ollama_model}")
            print(f"Using actual OLLAMA_EMBEDDING_MODEL (explicitly for embeddings): {actual_ollama_embedding_model}")
            if actual_http_proxy_to_use or actual_https_proxy_to_use:
                 print(f"Attempting to use actual system Proxy: HTTP_PROXY={actual_http_proxy_to_use or 'Not set'}, HTTPS_PROXY={actual_https_proxy_to_use or 'Not set'}")
            else:
                print("No HTTP/HTTPS proxy from actual system environment for this test.")
            # The print statement above references actual_http_proxy_to_use, which might be confusing as we are disabling proxy.
            # Let's adjust the print statement to reflect that proxy is being explicitly disabled for this Ollama test.

            print("Proxy explicitly disabled for this Ollama test (HTTP_PROXY='', HTTPS_PROXY='').")

            manager = LangchainManager()

            game_name = "OllamaActualServiceGame"
            rulebook_filename = "ollama_actual_rules.md"
            rule_content = "This is a test rule for the Ollama actual service integration. The best programming language is Python. Ollama should answer questions based on this."
            md_file_path = create_dummy_md_file(self.editable_texts_dir, game_name, rulebook_filename, rule_content)
            
            print(f"Attempting to add rulebook for {game_name} using actual Ollama embeddings...")
            try:
                manager.add_rulebook_text(md_file_path, game_name) 
                print(f"Rulebook for {game_name} added. FAISS index created in {self.vector_store_dir}")
                self.assertTrue(os.path.exists(os.path.join(self.vector_store_dir, game_name, "index.faiss")))
            except Exception as e:
                print(f"ERROR during add_rulebook_text with actual Ollama embeddings: {e}")
                self.fail(f"add_rulebook_text with actual Ollama embeddings failed: {e}")

            player_id = "actual_ollama_tester"
            question = "What is the best programming language according to the rules?"
            print(f"Asking question to {game_name} (Actual Ollama LLM): {question}")
            
            answer = None
            try:
                answer = manager.get_answer(question, game_name, player_id)
            except Exception as e:
                print(f"ERROR during get_answer with actual Ollama LLM: {e}")
                self.fail(f"get_answer with actual Ollama LLM failed: {e}")

            print(f"Actual Answer from Ollama for '{game_name}': {answer}")
            self.assertIsNotNone(answer, "Answer from Ollama LLM should not be None")
            self.assertTrue(len(answer) > 0, "Answer from Ollama LLM should not be empty")
            self.assertIn("Python", answer, "Answer from Ollama should mention 'Python' based on the rulebook content.")
            print("--- Ollama Integration Test Ended ---")

if __name__ == '__main__':
    unittest.main() 