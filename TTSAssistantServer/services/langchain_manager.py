#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TabletopSimulatorCompanion (TTS Companion) - Langchain管理器
负责处理RAG和LLM交互，管理对话记忆
"""

import os
import sys
from typing import Dict, Any, Optional
import config as cfg

from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferWindowMemory
from langchain.schema import BaseChatMessageHistory
from langchain.schema.messages import HumanMessage, AIMessage, BaseMessage
from langchain_community.document_loaders import TextLoader

# 对话历史管理类
class ChatMessageHistory(BaseChatMessageHistory):
    """管理对话历史的简单实现"""
    
    def __init__(self):
        self.messages: list[BaseMessage] = []
    
    def add_user_message(self, message: str) -> None:
        """添加用户消息"""
        self.messages.append(HumanMessage(content=message))
    
    def add_ai_message(self, message: str) -> None:
        """添加AI消息"""
        self.messages.append(AIMessage(content=message))

    def add_message(self, message: BaseMessage) -> None:
        """添加单个消息对象 (兼容Langchain)"""
        self.messages.append(message)

    def add_messages(self, messages: list[BaseMessage]) -> None:
        """添加多个消息对象列表 (兼容Langchain)"""
        self.messages.extend(messages)
    
    def clear(self) -> None:
        """清空对话历史"""
        self.messages = []
        
    def get_messages(self) -> list[BaseMessage]:
        """获取所有消息"""
        return self.messages

class LangchainManager:
    """管理Langchain组件、RAG和LLM交互"""
    
    def __init__(self):
        """初始化Langchain管理器"""
        # 游戏会话字典 {game_name: {player_id: memory_object}}
        self.game_sessions = {}
        
        # 游戏RAG索引 {game_name: retriever_object}
        self.game_retrievers = {}
        
        # 配置LLM和Embedding模型
        self.llm = self._initialize_llm()
        self.embeddings = self._initialize_embeddings()
        
        # 确保向量存储目录存在
        os.makedirs(cfg.VECTOR_STORE_DIRECTORY, exist_ok=True)
    
    def _initialize_llm(self):
        """初始化LLM模型"""
        if cfg.LLM_PROVIDER == "gemini":
            try:
                from langchain_google_genai import ChatGoogleGenerativeAI
                llm = ChatGoogleGenerativeAI(
                    model=cfg.GEMINI_MODEL,
                    google_api_key=cfg.GEMINI_API_KEY,
                )
                return llm
            except ImportError:
                print("未安装langchain_google_genai库，请使用pip install langchain-google-genai安装")
                sys.exit(1)
        elif cfg.LLM_PROVIDER == "ollama":
            try:
                from langchain_community.llms import Ollama
                base_url = cfg.OLLAMA_BASE_URL
                if base_url == "http://localhost:11434":
                    base_url = "http://127.0.0.1:11434"
                    print(f"Ollama LLM: Changed base_url to {base_url} to avoid localhost resolution issues.")
                llm = Ollama(
                    model=cfg.OLLAMA_MODEL,
                    base_url=base_url,
                )
                return llm
            except ImportError:
                print("未安装langchain_community库，请使用pip install langchain-community安装")
                sys.exit(1)
        elif cfg.LLM_PROVIDER == "openai":
            try:
                from langchain_openai import ChatOpenAI
                llm = ChatOpenAI(
                    model=cfg.OPENAI_MODEL,
                    api_key=cfg.OPENAI_API_KEY,
                )
                return llm
            except ImportError:
                print("未安装langchain_openai库，请使用pip install langchain-openai安装")
                sys.exit(1)
        else:
            raise ValueError(f"不支持的LLM提供商: {cfg.LLM_PROVIDER}")
    
    def _initialize_embeddings(self):
        """初始化Embedding模型"""
        embedding_provider = cfg.EMBEDDING_PROVIDER
        if embedding_provider == "default":
            embedding_provider = cfg.LLM_PROVIDER
        
        if embedding_provider == "gemini":
            try:
                from langchain_google_genai import GoogleGenerativeAIEmbeddings
                # 优先使用 cfg.EMBEDDING_MODEL (来自.env或全局配置)
                # 否则回退到 cfg.GEMINI_EMBEDDING_MODEL (通常是测试或代码内定义的默认值)
                model_name_to_use = cfg.EMBEDDING_MODEL if cfg.EMBEDDING_MODEL else cfg.GEMINI_EMBEDDING_MODEL

                # 确保 Gemini embedding 模型名称格式正确 (e.g., "models/embedding-001")
                # 已知的 Gemini embedding 模型短名称列表 (可以根据需要扩展)
                known_gemini_short_models = ["embedding-001", "text-embedding-004"] 
                
                # 移除任何已有的 "models/" 前缀，以避免重复添加
                if model_name_to_use.startswith("models/"):
                    model_name_to_use = model_name_to_use.split("models/", 1)[-1]

                if model_name_to_use in known_gemini_short_models:
                    final_model_name = f"models/{model_name_to_use}"
                elif ":" in model_name_to_use: # 如果包含冒号，认为是Ollama风格或其他特殊格式，不修改
                    final_model_name = model_name_to_use
                    print(f"Warning: Gemini embedding model '{model_name_to_use}' contains ':', using as-is. This might be an Ollama model name mistakenly used for Gemini.")
                else: # 如果不是已知短名称，也不是特殊格式，并且没有 models/ 前缀，则添加
                    if not model_name_to_use.startswith("models/"):
                         final_model_name = f"models/{model_name_to_use}" # 尝试添加，但可能仍不正确如果不是Gemini模型
                         print(f"Warning: Gemini embedding model '{model_name_to_use}' was not a known short name and did not start with 'models/'. Prepended 'models/'. Ensure this is a valid Gemini model name.")
                    else:
                        final_model_name = model_name_to_use # 已经有 models/ 前缀
                
                print(f"Gemini Embeddings: Using model name: {final_model_name}")
                embeddings = GoogleGenerativeAIEmbeddings(
                    model=final_model_name,
                    google_api_key=cfg.GEMINI_API_KEY,
                )
                return embeddings
            except ImportError:
                print("未安装langchain_google_genai库，请使用pip install langchain-google-genai安装")
                sys.exit(1)
        elif embedding_provider == "ollama":
            try:
                from langchain_community.embeddings import OllamaEmbeddings
                model = cfg.EMBEDDING_MODEL if cfg.EMBEDDING_MODEL else cfg.OLLAMA_MODEL
                base_url = cfg.OLLAMA_BASE_URL
                if base_url == "http://localhost:11434":
                    base_url = "http://127.0.0.1:11434"
                    print(f"Ollama Embeddings: Changed base_url to {base_url} to avoid localhost resolution issues.")
                embeddings = OllamaEmbeddings(
                    model=model,
                    base_url=base_url,
                )
                return embeddings
            except ImportError:
                print("未安装langchain_community库，请使用pip install langchain-community安装")
                sys.exit(1)
        elif embedding_provider == "openai":
            try:
                from langchain_openai import OpenAIEmbeddings
                embeddings = OpenAIEmbeddings(
                    model="text-embedding-ada-002",
                    api_key=cfg.OPENAI_API_KEY,
                )
                return embeddings
            except ImportError:
                print("未安装langchain_openai库，请使用pip install langchain-openai安装")
                sys.exit(1)
        elif embedding_provider == "sentence_transformers":
            try:
                from langchain_community.embeddings import HuggingFaceEmbeddings
                embeddings = HuggingFaceEmbeddings(
                    model_name=cfg.SENTENCE_TRANSFORMER_MODEL,
                    model_kwargs={'device': 'cpu'},
                    encode_kwargs={'normalize_embeddings': True}
                )
                return embeddings
            except ImportError:
                print("未安装sentence-transformers库，请使用pip install sentence-transformers安装")
                sys.exit(1)
        else:
            raise ValueError(f"不支持的Embedding提供商: {embedding_provider}")
    
    def add_rulebook_text(self, file_path: str, game_name: str):
        """从文件加载规则书文本并构建RAG索引"""
        # 加载文本
        loader = TextLoader(file_path, encoding='utf-8')
        documents = loader.load()
        
        # 文本分割
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=1000,
            chunk_overlap=200,
            length_function=len,
        )
        splits = text_splitter.split_documents(documents)
        
        # 创建向量存储
        vector_store_path = os.path.join(cfg.VECTOR_STORE_DIRECTORY, f"{game_name}")
        os.makedirs(vector_store_path, exist_ok=True)
        
        # 创建或更新FAISS索引
        vector_store = FAISS.from_documents(
            documents=splits,
            embedding=self.embeddings,
        )
        
        # 保存到磁盘
        vector_store.save_local(vector_store_path)
        
        # 更新游戏检索器
        self.game_retrievers[game_name] = vector_store.as_retriever(
            search_type="similarity",
            search_kwargs={"k": 5}
        )
        
        print(f"已为游戏 '{game_name}' 创建/更新RAG索引")
    
    def _get_or_create_memory(self, game_name: str, player_id: str) -> ConversationBufferWindowMemory:
        """获取或创建玩家的对话记忆"""
        # 如果游戏会话不存在，创建一个
        if game_name not in self.game_sessions:
            self.game_sessions[game_name] = {}
        
        # 如果玩家会话不存在，创建一个
        if player_id not in self.game_sessions[game_name]:
            message_history = ChatMessageHistory()
            # 使用新版本的API创建记忆对象
            memory = ConversationBufferWindowMemory(
                chat_memory=message_history,
                return_messages=True,
                memory_key="chat_history",
                k=5  # 保留最近5轮对话
            )
            self.game_sessions[game_name][player_id] = memory
        
        return self.game_sessions[game_name][player_id]
    
    def get_answer(self, question: str, game_name: str, player_id: str) -> str:
        """处理用户问题并返回回答"""
        # 如果游戏没有RAG索引，尝试加载
        if game_name not in self.game_retrievers:
            vector_store_path = os.path.join(cfg.VECTOR_STORE_DIRECTORY, f"{game_name}")
            if os.path.exists(vector_store_path):
                try:
                    vector_store = FAISS.load_local(vector_store_path, self.embeddings)
                    self.game_retrievers[game_name] = vector_store.as_retriever(
                        search_type="similarity",
                        search_kwargs={"k": 5}
                    )
                except Exception as e:
                    return f"无法加载游戏 '{game_name}' 的RAG索引: {str(e)}。请先使用 'tc rulebook refresh_cache' 构建规则索引。"
            else:
                return f"游戏 '{game_name}' 没有可用的RAG索引。请先使用 'tc rulebook refresh_cache' 构建规则索引。"
        
        # 获取玩家的对话记忆
        memory = self._get_or_create_memory(game_name, player_id)
        
        try:
            # 创建问答链
            qa_chain = ConversationalRetrievalChain.from_llm(
                llm=self.llm,
                retriever=self.game_retrievers[game_name],
                memory=memory,
                verbose=cfg.DEBUG,
                return_source_documents=False,
            )
            
            # 处理问题
            response = qa_chain({"question": question})
            answer = response.get("answer", "无法生成回答")
            
            return answer
        except Exception as e:
            print(f"处理问题时出错: {str(e)}")
            return f"处理问题时出错: {str(e)}"
    
    def reset_conversation(self, game_name: str, player_id: str):
        """重置指定玩家的对话记忆"""
        if game_name in self.game_sessions and player_id in self.game_sessions[game_name]:
            self.game_sessions[game_name][player_id].clear()
            print(f"已重置玩家 '{player_id}' 在 '{game_name}' 中的对话记忆")
    
    def clear_game_state(self, game_name: str):
        """清除游戏的所有状态（对话记忆和RAG索引）"""
        # 清除对话记忆
        if game_name in self.game_sessions:
            del self.game_sessions[game_name]
        
        # 清除RAG检索器
        if game_name in self.game_retrievers:
            del self.game_retrievers[game_name]
        
        print(f"已清除游戏 '{game_name}' 的所有状态") 