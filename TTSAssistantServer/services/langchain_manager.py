#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TabletopSimulatorCompanion (TTS Companion) - Langchain管理器
负责处理RAG和LLM交互，管理对话记忆
"""

import os
import sys
import re
from typing import Dict, Any, Optional
import config as cfg
import shutil

from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferWindowMemory
from langchain.schema import BaseChatMessageHistory
from langchain.schema.messages import HumanMessage, AIMessage, BaseMessage
from langchain_community.document_loaders import TextLoader
from langchain.prompts import PromptTemplate

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
    
    def load_or_get_retriever(self, game_name: str) -> Optional[Any]:
        """
        获取内存中的RAG检索器，如果不存在则尝试从磁盘加载。
        Args:
            game_name: 游戏名称 (可能需要内部清理)。
        Returns:
            Langchain Retriever 对象或 None (如果无法加载)。
        """
        cleaned_game_name = game_name.strip() if isinstance(game_name, str) else game_name

        if cleaned_game_name in self.game_retrievers:
            print(f"Retriever for '{cleaned_game_name}' found in memory.")
            return self.game_retrievers[cleaned_game_name]
        
        vector_store_path = os.path.join(cfg.VECTOR_STORE_DIRECTORY, f"{cleaned_game_name}")
        if os.path.exists(vector_store_path):
            try:
                print(f"Attempting to load retriever for '{cleaned_game_name}' from disk: {vector_store_path}")
                vector_store = FAISS.load_local(
                    vector_store_path, 
                    self.embeddings, 
                    allow_dangerous_deserialization=True
                )
                retriever = vector_store.as_retriever(
                    search_type="similarity",
                    search_kwargs={"k": 5}
                )
                self.game_retrievers[cleaned_game_name] = retriever
                print(f"Successfully loaded retriever for '{cleaned_game_name}' from disk.")
                return retriever
            except Exception as e:
                print(f"警告: 为游戏 '{cleaned_game_name}' 从磁盘加载RAG索引失败: {e}")
                return None
        else:
            print(f"No pre-built RAG index found on disk for game '{cleaned_game_name}' at {vector_store_path}")
            return None

    def add_rulebook_text(self, file_path: str, game_name: str):
        """从文件加载规则书文本并构建RAG索引"""
        
        # 确保 game_name 用于路径时是干净的
        cleaned_game_name = game_name.strip() if isinstance(game_name, str) else game_name

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
        vector_store_path = os.path.join(cfg.VECTOR_STORE_DIRECTORY, f"{cleaned_game_name}")
        os.makedirs(vector_store_path, exist_ok=True)
        
        # 创建或更新FAISS索引
        vector_store = FAISS.from_documents(
            documents=splits,
            embedding=self.embeddings,
        )
        
        # 保存到磁盘
        vector_store.save_local(vector_store_path)
        
        # 更新游戏检索器
        self.game_retrievers[cleaned_game_name] = vector_store.as_retriever(
            search_type="similarity",
            search_kwargs={"k": 5}
        )
        
        print(f"已为游戏 '{cleaned_game_name}' 创建/更新RAG索引")
    
    def _get_or_create_memory(self, game_name: str, player_id: str) -> ConversationBufferWindowMemory:
        """获取或创建玩家的对话记忆"""
        cleaned_game_name = game_name.strip() if isinstance(game_name, str) else game_name
        # 如果游戏会话不存在，创建一个
        if cleaned_game_name not in self.game_sessions:
            self.game_sessions[cleaned_game_name] = {}
        
        # 如果玩家会话不存在，创建一个
        if player_id not in self.game_sessions[cleaned_game_name]:
            message_history = ChatMessageHistory()
            # 使用新版本的API创建记忆对象
            memory = ConversationBufferWindowMemory(
                chat_memory=message_history,
                return_messages=True,
                memory_key="chat_history",
                k=5  # 保留最近5轮对话
            )
            self.game_sessions[cleaned_game_name][player_id] = memory
        
        return self.game_sessions[cleaned_game_name][player_id]
    
    def get_answer(self, question: str, game_name: str, player_id: str) -> str:
        """获取LLM的回答"""
        cleaned_game_name = game_name.strip() if isinstance(game_name, str) else game_name
        
        memory = self._get_or_create_memory(cleaned_game_name, player_id)
        retriever = self.load_or_get_retriever(cleaned_game_name)

        raw_answer = "" 

        if retriever:
            try:
                # 准备 condense_question_prompt (如果自定义了)
                condense_question_prompt_obj = None 
                if cfg.CUSTOM_CONDENSE_QUESTION_PROMPT_TEMPLATE:
                    condense_question_prompt_obj = PromptTemplate.from_template(
                        cfg.CUSTOM_CONDENSE_QUESTION_PROMPT_TEMPLATE
                    )
                    print("Using custom condense_question_prompt.")

                # 准备 QA prompt (如果自定义了)
                current_combine_docs_chain_kwargs = {} 
                if cfg.CUSTOM_QA_PROMPT_TEMPLATE:
                    qa_prompt = PromptTemplate.from_template(cfg.CUSTOM_QA_PROMPT_TEMPLATE)
                    current_combine_docs_chain_kwargs["prompt"] = qa_prompt
                    print("Using custom qa_prompt for combine_docs_chain.")

                chain_args = {
                    "llm": self.llm,
                    "retriever": retriever,
                    "memory": memory,
                    "verbose": cfg.DEBUG,
                    "return_source_documents": False,
                }
                if condense_question_prompt_obj: 
                    chain_args["condense_question_prompt"] = condense_question_prompt_obj
                
                if current_combine_docs_chain_kwargs: 
                    chain_args["combine_docs_chain_kwargs"] = current_combine_docs_chain_kwargs

                qa_chain = ConversationalRetrievalChain.from_llm(**chain_args)
                
                response = qa_chain.invoke({"question": question})
                raw_answer = response.get("answer", "无法生成回答")
            except Exception as e:
                print(f"处理问题时出错: {str(e)}")
                raw_answer = f"抱歉，处理您的问题时发生了内部错误: {str(e)}"
        else:
            print(f"游戏 '{cleaned_game_name}' 没有可用的RAG检索器。")
            raw_answer = "抱歉，当前游戏没有可用的规则书RAG索引，无法回答关于规则的问题。您可以尝试使用 `tc rulebook refresh_cache` 来加载规则书。"

        # 清理回答中的 <think>...</think> 标签
        if isinstance(raw_answer, str):
            cleaned_answer = re.sub(r"<think>.*?</think>\n?", "", raw_answer, flags=re.DOTALL).strip()
        else:
            cleaned_answer = str(raw_answer).strip() if raw_answer is not None else ""

        return cleaned_answer if cleaned_answer else "抱歉，我无法生成回答。"
    
    def reset_conversation(self, game_name: str, player_id: str):
        """重置特定玩家的对话记忆"""
        cleaned_game_name = game_name.strip() if isinstance(game_name, str) else game_name
        if cleaned_game_name in self.game_sessions and player_id in self.game_sessions[cleaned_game_name]:
            self.game_sessions[cleaned_game_name][player_id].clear()
            print(f"已重置玩家 {player_id} 在游戏 '{cleaned_game_name}' 的对话记忆")
    
    def clear_game_state(self, game_name: str):
        """清除特定游戏的所有会话记忆和RAG索引"""
        cleaned_game_name = game_name.strip() if isinstance(game_name, str) else game_name
        if cleaned_game_name in self.game_sessions:
            del self.game_sessions[cleaned_game_name]
            print(f"已清除游戏 '{cleaned_game_name}' 的所有会话记忆")
        
        if cleaned_game_name in self.game_retrievers:
            del self.game_retrievers[cleaned_game_name]
            # 物理删除磁盘上的向量存储
            vector_store_path = os.path.join(cfg.VECTOR_STORE_DIRECTORY, f"{cleaned_game_name}")
            if os.path.exists(vector_store_path):
                try:
                    shutil.rmtree(vector_store_path) # 使用 shutil.rmtree 删除目录
                    print(f"已删除磁盘上的向量存储: {vector_store_path}")
                except Exception as e:
                    print(f"删除向量存储 {vector_store_path} 失败: {e}")
            print(f"已清除游戏 '{cleaned_game_name}' 的RAG索引") 