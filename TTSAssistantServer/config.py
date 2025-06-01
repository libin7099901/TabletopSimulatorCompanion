#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
TabletopSimulatorCompanion (TTS Companion) - 配置管理模块
"""

import os
from dotenv import load_dotenv
import pathlib

# 加载 .env 文件中的环境变量
load_dotenv()

# 服务器配置
HOST = os.getenv('HOST', '0.0.0.0')
PORT = int(os.getenv('PORT', '5678'))

# TTS数据目录
# Windows默认："C:/Users/<username>/Documents/My Games/Tabletop Simulator/"
# Linux默认："/home/<username>/.local/share/Tabletop Simulator/"
# MacOS默认："/Users/<username>/Library/Tabletop Simulator/"
TTS_DATA_DIRECTORY = os.getenv('TTS_DATA_DIRECTORY')

# 当前目录作为基础路径
BASE_DIR = pathlib.Path(__file__).parent.absolute()

# 缓存目录
EDITABLE_RULEBOOK_TEXT_CACHE_DIRECTORY = os.getenv(
    'EDITABLE_RULEBOOK_TEXT_CACHE_DIRECTORY', 
    str(BASE_DIR / "data" / "cache" / "editable_rulebook_texts")
)

# 向量存储目录
VECTOR_STORE_DIRECTORY = os.getenv(
    'VECTOR_STORE_DIRECTORY', 
    str(BASE_DIR / "data" / "cache" / "vector_stores")
)

# 元数据文件路径
PROCESSED_MODS_FILE = os.getenv(
    'PROCESSED_MODS_FILE', 
    str(BASE_DIR / "data" / "processed_mods.json")
)

# LLM 配置
LLM_PROVIDER = os.getenv('LLM_PROVIDER', 'gemini')  # 可选: gemini, ollama, openai等

# Gemini配置
GEMINI_API_KEY = os.getenv('GEMINI_API_KEY', '')
GEMINI_MODEL = os.getenv('GEMINI_MODEL', 'gemini-pro')
GEMINI_EMBEDDING_MODEL = os.getenv('GEMINI_EMBEDDING_MODEL', 'models/embedding-001')

# Ollama配置
OLLAMA_BASE_URL = os.getenv('OLLAMA_BASE_URL', 'http://localhost:11434')
OLLAMA_MODEL = os.getenv('OLLAMA_MODEL', 'llama3')

# OpenAI配置
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY', '')
OPENAI_MODEL = os.getenv('OPENAI_MODEL', 'gpt-3.5-turbo')

# Embedding模型配置
EMBEDDING_PROVIDER = os.getenv('EMBEDDING_PROVIDER', 'default')  # default使用与LLM相同的提供商
EMBEDDING_MODEL = os.getenv('EMBEDDING_MODEL', '')  # 自定义Embedding模型名称

# Sentence Transformers配置
SENTENCE_TRANSFORMER_MODEL = os.getenv('SENTENCE_TRANSFORMER_MODEL', 'all-MiniLM-L6-v2')

# HTTP代理
HTTP_PROXY = os.getenv('HTTP_PROXY', '')
HTTPS_PROXY = os.getenv('HTTPS_PROXY', '')

# 调试模式
DEBUG = os.getenv('DEBUG', 'False').lower() == 'true'

# 自定义提示词模板 (可选)
# 如果未设置，将使用Langchain的默认提示词
# {chat_history} 和 {question} 是 condense_question_prompt 的可用变量
CUSTOM_CONDENSE_QUESTION_PROMPT_TEMPLATE = os.getenv('CUSTOM_CONDENSE_QUESTION_PROMPT_TEMPLATE', None)

# {context} 和 {question} 是 qa_prompt (combine_docs_chain) 的可用变量
CUSTOM_QA_PROMPT_TEMPLATE = os.getenv('CUSTOM_QA_PROMPT_TEMPLATE', None) 