# TabletopSimulatorCompanion (TTS Companion)

**版本**: 0.3.4

## 项目简介

TabletopSimulatorCompanion (TTS Companion) 是一个为桌游模拟器 (Tabletop Simulator, TTS) 设计的辅助工具，通过集成大型语言模型(LLM)，为玩家提供即时的游戏规则解释和问答服务，显著提升游戏体验。

## 核心功能

- 通过TTS聊天窗口进行交互，使用`@tc`命令提问
- 使用RAG技术提供准确的游戏规则解释
- 支持多玩家会话管理，每个玩家有独立的对话历史
- 用户可自行编辑规则书内容，系统自动构建检索索引
- 轻量级设计，分离Mod前端与Python后端

## 项目结构

```
TTSCompanion/
├── README.md                                 # 项目说明文档
├── PROJECT_DESIGN_AND_IMPLEMENTATION.md      # 项目设计与实现文档
│
├── TTSAssistantServer/                       # Python服务端
│   ├── app.py                                # Flask API入口
│   ├── config.py                             # 配置加载模块
│   ├── requirements.txt                      # 依赖包列表
│   ├── .env.example                          # 环境变量示例
│   │
│   ├── services/                             # 核心服务模块
│   │   ├── __init__.py                       # 包初始化
│   │   ├── langchain_manager.py              # RAG和LLM管理
│   │   ├── rulebook_manager.py               # 规则书文件管理
│   │   └── workshop_manager.py               # TTS数据扫描和元数据管理
│   │
│   ├── tests/                                # 单元测试
│   │   ├── __init__.py                       # 测试包初始化
│   │   ├── test_config.py                    # 配置模块测试
│   │   └── test_langchain_manager.py         # Langchain管理器测试
│   │
│   └── data/                                 # 数据目录
│       ├── cache/                            # 缓存数据
│       │   ├── editable_rulebook_texts/      # 用户编辑的规则书文本
│       │   └── vector_stores/                # FAISS索引存储
│       │
│       └── processed_mods.json               # 规则书元数据
│
└── tc_mod/                                   # TTS Mod (Lua)
    ├── tc_mod.lua                            # Mod核心脚本
    └── tc_mod.json                           # Mod定义文件
```

## 技术架构

### TTS Mod (`tc_mod`)
- **语言**: Lua
- **职责**: 
  - 处理用户聊天命令
  - 与Python服务端通信
  - 将回答显示给对应玩家

### Python服务端 (`TTSAssistantServer`)
- **框架**: Flask
- **核心组件**:
  - `WorkshopManager`: 扫描TTS数据，管理规则书元数据
  - `RulebookManager`: 管理规则书缓存文件
  - `LangchainManager`: 处理RAG和LLM交互，管理玩家会话

### 关键技术
- **LLM框架**: Langchain
- **向量存储**: FAISS
- **支持的LLM**: Gemini, Ollama, OpenAI, 其他Langchain支持的模型
- **Embedding模型**: 
  - Sentence Transformers (all-MiniLM-L6-v2)
  - Ollama内置Embedding
  - Gemini/OpenAI Embedding

## 安装指南

### 服务端设置
1. 安装Python 3.9+
2. 安装依赖包:
   ```
   cd TTSAssistantServer
   pip install -r requirements.txt
   ```
3. 复制`.env.example`为`.env`并配置:
   ```
   cp .env.example .env
   ```
4. 编辑`.env`文件:
   - 设置`TTS_DATA_DIRECTORY`指向TTS数据目录
   - 配置LLM相关参数(API密钥、URL等)
   - 配置Embedding提供商和模型
   - 可选：配置`HTTP_PROXY`和`HTTPS_PROXY`

### 启动服务
```
cd TTSAssistantServer
python app.py
```

### TTS Mod安装
1. 通过Steam Workshop订阅Mod或手动安装:
   - 将`tc_mod`文件夹复制到TTS的Mod目录
2. 在游戏中加载Mod

**当前可用的部署方法：**
- 在TTS游戏中创建一个对象（如记分板、芯片等），然后将`tc_mod/tc_mod.lua`文件的全部内容复制粘贴到该对象的脚本编辑器中。
- 保存并锁定该对象，即可在游戏中使用TTS Companion的功能。
- （目前尚未验证完整的Mod文件夹整体部署，推荐使用上述粘贴脚本的方式进行集成和测试。）

## 使用方法

### 基本命令
- **提问**: `@tc 你的问题`
- **查看规则书列表**: `tc rulebook list`
- **更新规则书缓存**: `tc rulebook refresh_cache <游戏名> <编号或部分文件名>`
- **设置服务器地址**: `tc set_server <地址>`
- **重置会话**: `tc reset_session [player_id|all]`

### 规则书管理流程
1. 启动服务端，自动扫描TTS数据并创建规则书缓存文件
2. 在游戏中使用`tc rulebook list`查看可用规则书
3. 找到对应的`.md`文件，使用文本编辑器填充规则内容
   - 规则书的`.md`文件位于 `TTSAssistantServer/data/cache/editable_rulebook_texts/` 目录下，以游戏名（经过处理）为子目录。例如，若游戏名为 `Gizmos`，则规则书文件路径类似于：
     
     `data/cache/editable_rulebook_texts/gizmos/rulebook_xxx.md`
   - 可通过 `tc rulebook list` 命令获取规则书的编号和文件名，便于定位。
4. 使用`tc rulebook refresh_cache`命令更新RAG索引
5. 使用`@tc`命令提问规则相关问题

#### 如何在TTS中查找规则书的URL
- 在TTS中加载目标游戏后，**右键点击桌面上的PDF规则手册对象，选择"自定义"弹出的窗口中可以直接看到该PDF文档的URL**。
- 你也可以在TTS的Mod文件（如Workshop的json文件）中查找`Custom_PDF`对象，其`PDFUrl`、`FileURL`或`URL`字段即为规则书的链接。
- 通过这些URL可以确认规则书的来源，或用于手动下载和整理规则内容。

## API接口

主要API接口:
- `POST /ask`: 处理问题并返回回答
- `GET /rulebook`: 获取规则书列表
- `POST /api/game/loaded`: 通知服务端游戏已加载
- `POST /api/rulebook/refresh_rag_from_cache`: 从缓存文件更新RAG索引
- `POST /session/reset`: 重置会话

## 单元测试

运行单元测试:
```
cd TTSAssistantServer
python -m unittest discover tests
```

单元测试覆盖:
- 配置模块测试
- Langchain管理器测试
- 更多测试将基于项目功能开发进度添加

## 许可证

本项目采用 MIT 许可证，允许任何人免费使用、修改、分发和商用，无需署名。

详细内容请参见 [LICENSE](./LICENSE) 文件。 