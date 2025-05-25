# TTS API技术可行性研究报告

> **项目**: 桌游伴侣 (Tabletop Companion)  
> **调研负责**: TechnicalResearchAI  
> **完成时间**: 2025-01-27  
> **文档版本**: 1.0

## 📋 执行摘要

本报告基于TTS官方API文档和知识库的深度调研，对PRD第10节中标识的5个关键TBD技术点进行了系统性验证。通过分析`external_repos/Tabletop-Simulator-API-master/docs/`中的官方文档，我们为桌游伴侣项目的技术实现提供了明确的可行性评估和实现建议。

### 关键发现总结

| TBD编号 | 技术点 | 可行性评级 | 风险等级 | 推荐方案 |
|---------|--------|------------|----------|----------|
| TBD-001 | 文件系统访问权限 | 🟡 有限可行 | 中 | script_state + 用户输入 |
| TBD-002 | 游戏对象文本修改 | 🟢 可行 | 低 | setName/setDescription + UI覆盖 |
| TBD-003 | 网络请求限制 | 🟢 可行 | 低 | WebRequest API |
| TBD-004 | OCR实现路径 | 🔴 不可行 | 高 | 多模态LLM + 用户输入 |
| TBD-005 | 自定义UI系统 | 🟢 可行 | 低 | XML-based UI + 动态更新 |

## 🔍 详细技术验证

### TBD-001: TTS API文件系统访问权限

#### 🎯 调研目标
- 验证Lua `io`库在TTS沙箱中的可用性和限制
- 研究`persistence.*` API的存在性和功能
- 分析`Global.script_state`的大小限制和性能特征
- 评估大型数据存储的可行方案

#### 📊 调研结果

**❌ io库访问**: 
- 在TTS官方API文档中**未发现**任何关于Lua标准`io`库可用性的说明
- 搜索结果显示TTS环境中不提供直接的文件系统访问

**❌ persistence.* API**:
- 官方API文档中**不存在**`persistence.*`相关API
- 此API仅在项目需求文档中被假设性提及

**✅ script_state机制**:
- **Global.script_state**: 全局脚本状态存储 (官方文档: `events.md#onSave`)
- **Object.script_state**: 对象级脚本状态存储 (官方文档: `object.md#script_state`)
- **保存机制**: 通过`onSave()`事件返回JSON字符串，`onLoad(script_state)`事件接收
- **支持格式**: JSON编码的字符串，支持嵌套表、字符串、数字和对象GUID

#### 🔧 技术实现方案

**主方案**: script_state存储机制
```lua
-- 存储数据 (在onSave事件中)
function onSave()
    local data = {
        llm_config = {
            api_key = user_provided_key,  -- 用户每次输入
            api_url = "https://api.example.com"
        },
        translation_cache = translation_data,
        user_preferences = user_settings
    }
    return JSON.encode(data)
end

-- 加载数据 (在onLoad事件中)
function onLoad(script_state)
    if script_state != "" then
        local data = JSON.decode(script_state)
        -- 恢复配置和缓存
    end
end
```

**备选方案**: 用户输入 + 临时存储
- 敏感数据(API Key)每次启动时用户输入
- 大型缓存数据分块存储或简化处理
- 利用TTS对象作为数据载体

#### ⚠️ 限制与约束

1. **大小限制**: script_state的确切大小限制未在文档中明确，需要实际测试
2. **安全性**: JSON存储为明文，API密钥等敏感信息需要用户每次输入
3. **性能**: 频繁的JSON编码/解码可能影响性能
4. **持久性**: 数据随存档保存，但不能跨游戏保持

#### 🎯 可行性评级: 🟡 有限可行

**理由**: script_state提供了基本的持久化能力，但受限于大小和安全性约束

---

### TBD-002: 游戏对象文本动态修改能力

#### 🎯 调研目标
- 验证`object.setName()`和`object.setDescription()`对非本Mod对象的有效性
- 研究3D UI Text元素覆盖的可行性和性能
- 分析动态贴图生成和`object.setCustomImage()`的可用性
- 评估翻译文本显示的各种技术方案

#### 📊 调研结果

**✅ 基础文本修改API**:
- `object.setName(name)`: 设置对象名称，显示在工具提示中 (官方文档: `object.md#setName`)
- `object.setDescription(description)`: 设置对象描述，延迟显示在工具提示中 (官方文档: `object.md#setDescription`)
- `object.setGMNotes(notes)`: 设置GM专用笔记
- **返回值**: 布尔值，表示操作成功/失败

**✅ UI覆盖系统**:
- **全局UI**: `UI.setXml(xml)` 创建屏幕UI元素
- **对象UI**: `object.UI.setXml(xml)` 在特定对象上创建UI
- **动态更新**: `UI.setValue(id, value)` 实时更新UI内容
- **3D世界UI**: 支持在3D空间中放置UI元素

**✅ 动态内容更新**:
- **属性修改**: `UI.setAttribute(id, attribute, value)` 修改UI属性
- **可视性控制**: `UI.show(id)` / `UI.hide(id)` 显示/隐藏元素
- **事件响应**: UI元素可以响应玩家交互并触发Lua函数

#### 🔧 技术实现方案

**主方案**: setName/setDescription + UI覆盖
```lua
-- 方案1: 直接修改对象属性 (适用于简单文本)
function translateObjectText(object, translatedName, translatedDescription)
    local success1 = object.setName(translatedName)
    local success2 = object.setDescription(translatedDescription)
    return success1 and success2
end

-- 方案2: UI覆盖显示 (适用于复杂内容)
function createTranslationOverlay(object, translatedText)
    local xml = [[
        <Panel position="0 2 0" width="200" height="100">
            <Text fontSize="14" color="white" alignment="MiddleCenter">
                ]] .. translatedText .. [[
            </Text>
        </Panel>
    ]]
    object.UI.setXml(xml)
end
```

**备选方案**: 全局翻译面板
```lua
-- 创建独立的翻译显示面板
function createGlobalTranslationPanel()
    local xml = [[
        <Panel id="translationPanel" position="10 10" width="300" height="400">
            <Text id="translationContent" fontSize="12" color="white"/>
        </Panel>
    ]]
    UI.setXml(xml)
end

-- 更新翻译显示
function updateTranslation(objectName, translation)
    local content = objectName .. ": " .. translation
    UI.setValue("translationContent", content)
end
```

#### ⚠️ 限制与约束

1. **对象权限**: 需要验证是否能修改非本Mod创建的对象
2. **UI性能**: 大量UI元素可能影响游戏性能
3. **同步问题**: UI更新需要在所有客户端同步
4. **视觉效果**: UI覆盖可能遮挡游戏元素

#### 🎯 可行性评级: 🟢 可行

**理由**: TTS提供了多种文本修改和显示方案，API功能完整且文档齐全

---

### TBD-003: 网络请求(WebRequest)详细限制

#### 🎯 调研目标
- 分析主机/客户端请求权限差异
- 研究请求频率、并发数限制
- 验证HTTPS支持和证书处理机制
- 评估LLM API集成的可行性

#### 📊 调研结果

**✅ WebRequest API能力**:
- **HTTP方法支持**: GET, POST, PUT, DELETE, HEAD, CUSTOM (官方文档: `webrequest/manager.md`)
- **HTTPS支持**: 完全支持HTTPS请求
- **自定义头部**: 支持设置请求头部，包括Authorization
- **请求体**: 支持JSON、表单数据、二进制数据
- **异步处理**: 基于回调函数的异步请求处理

**✅ 权限模型**:
- **限制说明**: 仅游戏主机可发起请求 (官方文档明确说明: "from the game host's computer only")
- **客户端行为**: 客户端脚本可以调用WebRequest，但实际请求由主机执行
- **数据同步**: 主机需要将响应结果广播给所有客户端

**✅ LLM集成支持**:
- **JSON支持**: 内置JSON编码/解码功能
- **错误处理**: 完整的错误检测和处理机制
- **响应解析**: 支持响应头部、状态码、响应体解析

#### 🔧 技术实现方案

**LLM API集成示例**:
```lua
-- LLM查询函数
function queryLLM(prompt, context, callback)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. llm_api_key
    }
    
    local data = {
        model = "gpt-3.5-turbo",
        messages = {
            {role = "system", content = "You are a helpful assistant."},
            {role = "user", content = prompt}
        },
        max_tokens = 150
    }
    
    local body = JSON.encode(data)
    
    WebRequest.custom(
        "https://api.openai.com/v1/chat/completions",
        "POST",
        true,  -- download response
        body,
        headers,
        function(request)
            if request.is_error then
                print("LLM Request failed: " .. request.error)
                return
            end
            
            local response = JSON.decode(request.text)
            local answer = response.choices[1].message.content
            callback(answer)
        end
    )
end

-- 翻译功能
function translateText(text, targetLanguage, callback)
    local prompt = "Translate the following text to " .. targetLanguage .. ": " .. text
    queryLLM(prompt, "", callback)
end
```

**主机-客户端同步机制**:
```lua
-- 主机端: 处理LLM请求
function handleLLMRequest(player, request_data)
    if player.host then  -- 仅主机处理
        queryLLM(request_data.prompt, request_data.context, function(response)
            -- 广播结果给所有客户端
            broadcastToAll("LLM Response: " .. response, "White")
        end)
    end
end
```

#### ⚠️ 限制与约束

1. **主机限制**: 仅主机可发起实际网络请求
2. **频率限制**: 文档未明确说明请求频率限制，需要实际测试
3. **并发限制**: 并发请求数量限制未明确
4. **网络依赖**: 功能完全依赖主机的网络连接
5. **API成本**: LLM API调用产生费用

#### 🎯 可行性评级: 🟢 可行

**理由**: WebRequest API功能完整，完全支持LLM API集成所需的所有功能

---

### TBD-004: OCR实现路径

#### 🎯 调研目标
- 评估在TTS Lua环境中集成OCR的可能性
- 研究多模态LLM图像处理的成本和效果
- 设计用户友好的OCR工作流程

#### 📊 调研结果

**❌ 本地OCR集成**:
- TTS Lua环境为**沙箱环境**，无法加载外部Lua库
- 无法直接调用系统OCR工具或库
- WebRequest API不支持上传图片到外部OCR服务

**🟡 多模态LLM方案**:
- **图像上传限制**: TTS WebRequest API主要支持文本数据，图像上传能力有限
- **Base64编码**: 理论上可以将图像转换为Base64字符串通过JSON发送
- **成本考虑**: 多模态LLM API调用成本较高
- **效果不确定**: 对游戏特定内容的识别效果需要验证

**✅ 用户辅助方案**:
- 用户使用外部OCR工具处理图像
- 通过UI输入框将OCR结果粘贴到Mod中
- Mod提供文本编辑和校正功能

#### 🔧 技术实现方案

**主方案**: 用户辅助 + 文本编辑
```lua
-- 创建OCR文本输入界面
function createOCRInputUI()
    local xml = [[
        <Panel position="center" width="400" height="300">
            <Text>Please paste OCR result below:</Text>
            <InputField id="ocrInput" height="200" multiline="true" 
                       placeholder="Paste OCR text here..."/>
            <Button onClick="processOCRText">Process Text</Button>
        </Panel>
    ]]
    UI.setXml(xml)
end

-- 处理OCR文本
function processOCRText(player, value, id)
    local ocrText = UI.getValue("ocrInput")
    if ocrText != "" then
        -- 进行文本清理和处理
        local cleanedText = cleanOCRText(ocrText)
        -- 发送给LLM进行翻译或处理
        translateText(cleanedText, "Chinese", function(result)
            displayTranslation(result)
        end)
    end
end
```

**备选方案**: 多模态LLM (实验性)
```lua
-- 图像转Base64 (需要外部预处理)
function processImageWithLLM(base64Image, callback)
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. llm_api_key
    }
    
    local data = {
        model = "gpt-4-vision-preview",
        messages = {
            {
                role = "user",
                content = {
                    {type = "text", text = "Please extract and translate all text from this image to Chinese:"},
                    {type = "image_url", image_url = {url = "data:image/jpeg;base64," .. base64Image}}
                }
            }
        }
    }
    
    -- 发送请求...
end
```

#### ⚠️ 限制与约束

1. **技术限制**: TTS环境无法直接集成OCR库
2. **工作流复杂**: 需要用户使用外部工具
3. **成本问题**: 多模态LLM API成本较高
4. **效果限制**: OCR准确性依赖图像质量
5. **用户体验**: 非一体化的工作流程

#### 🎯 可行性评级: 🔴 不可行

**理由**: TTS环境限制导致无法实现自动化OCR，只能依赖用户手动处理

---

### TBD-005: TTS自定义UI系统限制

#### 🎯 调研目标
- 分析复杂UI布局的实现可行性
- 研究UI与Lua脚本交互的最佳实践
- 评估跨平台UI一致性

#### 📊 调研结果

**✅ UI系统能力**:
- **XML-based**: 基于XML的声明式UI系统 (官方文档: `ui/introUI.md`)
- **布局组件**: 支持复杂布局，包括HorizontalLayout, VerticalLayout, GridLayout等
- **基础元素**: Text, Button, InputField, Image, Panel等完整组件
- **样式系统**: 支持颜色、字体、大小、位置等样式设置
- **动态更新**: 运行时动态修改UI属性和内容

**✅ 交互机制**:
- **事件系统**: UI元素可以触发Lua函数 (传递player, value, id参数)
- **双向通信**: Lua可以读取和设置UI元素的值
- **实时更新**: 支持实时更新UI内容和样式
- **多层级**: 支持嵌套的UI元素结构

**✅ 部署方式**:
- **全局UI**: 显示在屏幕上，所有玩家可见
- **对象UI**: 附加到特定游戏对象上
- **个人UI**: 可以为特定玩家显示不同内容

#### 🔧 技术实现方案

**主UI框架设计**:
```lua
-- 创建主要的Mod UI
function createMainUI()
    local xml = [[
        <Panel id="mainPanel" position="100 100" width="800" height="600" 
               color="rgba(0,0,0,0.8)">
            <!-- 标题栏 -->
            <Panel height="50" color="rgba(50,50,50,1)">
                <Text fontSize="20" color="white" alignment="MiddleCenter">
                    桌游伴侣 - Tabletop Companion
                </Text>
                <Button id="closeBtn" onClick="closeMainUI" 
                        position="750 10" width="40" height="30">×</Button>
            </Panel>
            
            <!-- 主内容区 -->
            <HorizontalLayout spacing="10" padding="10">
                <!-- 左侧功能菜单 -->
                <VerticalLayout width="200" spacing="5">
                    <Button onClick="showRulesQuery">规则查询</Button>
                    <Button onClick="showTranslation">翻译助手</Button>
                    <Button onClick="showScoreKeeper">计分辅助</Button>
                    <Button onClick="showSettings">设置</Button>
                </VerticalLayout>
                
                <!-- 右侧内容区域 -->
                <Panel id="contentArea" width="570" height="500">
                    <!-- 动态内容区域 -->
                </Panel>
            </HorizontalLayout>
        </Panel>
    ]]
    UI.setXml(xml)
end

-- 规则查询UI
function createRulesQueryUI()
    local xml = [[
        <VerticalLayout spacing="10" padding="10">
            <Text fontSize="16" color="white">智能规则查询</Text>
            <InputField id="ruleQuery" height="100" multiline="true" 
                       placeholder="请输入您的规则问题..."/>
            <Button onClick="submitRuleQuery">查询规则</Button>
            <Panel id="ruleResponse" height="300" color="rgba(30,30,30,1)">
                <Text id="responseText" fontSize="12" color="white" 
                      wordWrap="true" padding="10"/>
            </Panel>
        </VerticalLayout>
    ]]
    UI.setValue("contentArea", xml)
end

-- 翻译助手UI
function createTranslationUI()
    local xml = [[
        <VerticalLayout spacing="10" padding="10">
            <Text fontSize="16" color="white">游戏内容翻译</Text>
            <HorizontalLayout spacing="10">
                <Button onClick="autoTranslate">自动翻译可见对象</Button>
                <Button onClick="manualTranslate">手动翻译</Button>
            </HorizontalLayout>
            <Panel id="translationResult" height="400" color="rgba(30,30,30,1)">
                <!-- 翻译结果显示区域 -->
            </Panel>
        </VerticalLayout>
    ]]
    UI.setValue("contentArea", xml)
end
```

**交互处理机制**:
```lua
-- UI事件处理函数
function submitRuleQuery(player, value, id)
    local query = UI.getValue("ruleQuery")
    if query != "" then
        UI.setValue("responseText", "正在查询规则...")
        
        -- 调用LLM API查询规则
        queryLLM(query, getCurrentGameContext(), function(response)
            UI.setValue("responseText", response)
        end)
    end
end

-- 自动翻译功能
function autoTranslate(player, value, id)
    local objects = getAllObjects()
    local translationResults = ""
    
    for _, obj in ipairs(objects) do
        local name = obj.getName()
        local description = obj.getDescription()
        
        if name != "" then
            translateText(name, "Chinese", function(translatedName)
                translationResults = translationResults .. 
                    "原文: " .. name .. "\n翻译: " .. translatedName .. "\n\n"
                UI.setValue("translationResult", translationResults)
            end)
        end
    end
end
```

#### ⚠️ 限制与约束

1. **性能限制**: 复杂UI可能影响游戏性能
2. **平台差异**: 不同平台(Windows/Mac/Linux)的UI渲染可能有细微差异
3. **分辨率适配**: 需要考虑不同屏幕分辨率的适配
4. **事件限制**: UI事件处理需要合理设计避免阻塞

#### 🎯 可行性评级: 🟢 可行

**理由**: TTS提供了功能完整的UI系统，完全满足项目需求

---

## 🔄 架构设计建议

基于技术验证结果，为桌游伴侣项目提供以下架构建议：

### 核心架构模式

```
┌─────────────────────────────────────────────────────────────┐
│                     TTS UI Layer                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │    主UI     │ │   对象UI    │ │    翻译显示UI       │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                  Lua Logic Layer                            │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │ 规则查询模块 │ │  翻译模块   │ │    状态管理模块     │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│                 Data Persistence Layer                      │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │script_state │ │ 对象属性存储 │ │    用户输入缓存     │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│               External Services Layer                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────┐   │
│  │  LLM API    │ │  翻译API    │ │    规则知识库       │   │
│  └─────────────┘ └─────────────┘ └─────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### 关键设计决策

1. **数据存储策略**: 使用script_state作为主要持久化机制，敏感数据由用户每次输入
2. **翻译方案**: 优先使用setName/setDescription直接修改，复杂内容使用UI覆盖
3. **网络通信**: 所有外部API调用由主机处理，结果广播给客户端
4. **OCR处理**: 采用用户辅助方案，提供文本输入界面和编辑功能
5. **UI架构**: 基于XML的模块化UI设计，支持动态内容更新

## ⚠️ 风险评估与缓解

### 高风险项

| 风险项 | 影响程度 | 可能性 | 缓解措施 |
|--------|----------|--------|----------|
| script_state大小限制 | 高 | 中 | 分块存储、数据压缩、简化缓存 |
| LLM API成本控制 | 中 | 高 | 缓存机制、请求优化、用户设置 |
| OCR功能用户体验 | 中 | 高 | 详细使用指南、流程优化 |

### 中风险项

| 风险项 | 影响程度 | 可能性 | 缓解措施 |
|--------|----------|--------|----------|
| 网络连接稳定性 | 中 | 中 | 错误处理、重试机制、离线模式 |
| UI性能影响 | 低 | 中 | 懒加载、优化渲染、简化UI |
| 跨平台兼容性 | 低 | 低 | 多平台测试、UI适配 |

## 📋 实现路线图

### MVP阶段 (优先实现)

1. **✅ 基础UI框架**: 主界面和核心模块框架
2. **✅ script_state存储**: 基本的配置和缓存管理
3. **✅ WebRequest集成**: LLM API基础集成
4. **✅ 文本修改功能**: setName/setDescription实现
5. **✅ 基础翻译功能**: 简单文本翻译

### 完整版阶段

1. **🔄 高级UI功能**: 复杂布局和交互
2. **🔄 智能规则查询**: 上下文感知的规则问答
3. **🔄 批量翻译**: 自动化游戏内容翻译
4. **🔄 用户偏好系统**: 个性化设置和缓存
5. **🔄 OCR辅助工具**: 用户友好的OCR工作流

## 📝 技术约束清单

为后续架构设计和开发提供的核心约束：

### 存储约束
- 仅可使用script_state进行持久化存储
- 敏感数据需要用户每次输入
- 大型数据需要分块或简化处理

### 网络约束
- 仅主机可发起网络请求
- 需要设计主机-客户端同步机制
- 必须处理网络错误和重试

### UI约束
- 基于XML的声明式UI系统
- 需要考虑性能和跨平台兼容性
- 动态内容更新需要合理设计

### 功能约束
- OCR功能需要用户手动操作
- 文本修改能力有限于API提供的方法
- 所有外部服务调用需要错误处理

---

**报告完成时间**: 2025-01-27 09:35:00 UTC+8  
**下一步行动**: 将此报告提交给OrchestratorAgent进行架构设计阶段规划

**任务[TTS API技术可行性验证]已完成，控制权交还OrchestratorAgent。** 