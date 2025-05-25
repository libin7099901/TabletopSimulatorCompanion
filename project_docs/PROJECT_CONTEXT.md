# **项目核心上下文 (`PROJECT_CONTEXT.md`)**

**最后更新时间**: `2025-01-27 09:15:00 UTC+8`
**最后更新者**: `OrchestratorAgent`

**注意**: 本文档是您当前项目的"单一事实来源"，由 `OrchestratorAgent` 全权负责动态维护。请勿手动修改此文件的核心追踪信息部分，除非得到AI明确指导。

## **1. 项目概览**

*   **项目名称**: 桌游伴侣 (Tabletop Companion)
*   **项目目标**: 作为Tabletop Simulator的辅助Mod，通过深度集成TTS内部机制，提供高度可定制的智能规则查询、自动化计分和游戏流程引导，大幅提升线上桌游体验
*   **当前阶段**: 项目初始化与需求分析
*   **项目状态**: 项目启动中 - PRD文档已完成，正在进行项目框架初始化

## **2. 关键决策与里程碑 (本项目)**

*由 `OrchestratorAgent` 在关键决策或里程碑达成时记录。*

| 日期       | 决策/里程碑描述                                  | 决策者/负责人        | 相关文档/链接                 |
| ---------- | ------------------------------------------------ | -------------------- | ------------------------------------------------ |
| 2025-01-27 | 项目启动，产品需求文档完成，激活项目总指挥        | 用户 & OrchestratorAgent | 产品需求文档 - 桌游伴侣 (Tabletop Companion).md |
|            |                                                  |                      |                                                  |

## **3. 核心项目文档索引 (本项目)**

*由 `OrchestratorAgent` 动态维护。所有AI角色在执行任务前，必须参考此列表以获取最新、最准确的文档信息。*

### **A. AI行为与项目管理规范**
*   **全局AI助手行为准则**: `../.cursor/rules.md` (位于工作区根目录，所有AI交互的基础准则)
*   **OrchestratorAgent核心指令**: `project_docs/OrchestratorAgent_Directives.md` (本项目总指挥的核心行动指南)
*   **AI阶段任务验证指南**: `project_docs/AI_STAGE_VALIDATION_GUIDE.md` (项目各阶段质量保证和验证规范)
*   **自定义项目验证规则**: `project_docs/custom_validation_rules.md` 
    *   **用途**: 用户定义的、本项目特有的、AI必须遵守的硬性规则、约束或质量检查清单。例如：特定的技术栈禁止事项、必须实现的安全标准、特定的代码风格、性能指标等。
    *   **创建与使用**: 
        *   此文件**默认可能不存在**。`OrchestratorAgent` 会在项目早期（如需求深化阶段）**主动询问**用户是否需要创建并配置此文件。
        *   用户可以随时手动创建或更新此文件。模板位于 `templates/custom_validation_rules_template.md`。
        *   `OrchestratorAgent` 和其他AI角色在执行任务和进行阶段验证时，会**优先检查并严格遵守**此文件中的规则。
*   **项目命名规范** (建议创建): `project_docs/PROJECT_NAMING_CONVENTIONS.md` (确保项目内命名一致性)
*   **提示词开发者指南**: `project_docs/PROMPT_DEVELOPER_GUIDELINES.md` (创建和优化AI角色的规范)

### **B. 项目执行与追踪**
*   **项目进度跟踪**: `project_docs/AI_AGENT_PROGRESS.md` (详细任务状态与进展)
*   **高级战略规划**: `project_docs/ACTION_PLAN_MASTER.md` (初始战略蓝图与长期目标)
*   **本项目上下文**: `project_docs/PROJECT_CONTEXT.md` (本文档 - 项目的单一事实来源)
*   **项目会话状态 (大型项目/断点续行)** (如使用): `project_docs/PROJECT_SESSION_STATE.md` (用于保存和恢复项目状态)

### **C. 需求、设计与架构 (具体项目文档)**
*   **需求文档**:
    *   **产品需求文档**: `产品需求文档 - 桌游伴侣 (Tabletop Companion).md` (外部AI协作完成的完整PRD)
    *   `project_docs/REQUIREMENTS/FUNCTIONAL_SPECIFICATION.md` (待创建 - 功能规格说明书)
    *   `project_docs/REQUIREMENTS/USER_STORIES.md` (待创建 - 用户故事)
    *   `project_docs/REQUIREMENTS/TECHNICAL_REQUIREMENTS.md` (待创建 - 技术需求详细分析)
*   **架构与设计文档**:
    *   `project_docs/ARCHITECTURE_AND_DESIGN/SYSTEM_ARCHITECTURE.md` (待创建 - 系统架构总览)
    *   `project_docs/ARCHITECTURE_AND_DESIGN/MODULE_INTERFACES.md` (待创建 - 模块间接口定义)
    *   `project_docs/ARCHITECTURE_AND_DESIGN/TTS_API_RESEARCH.md` (待创建 - TTS API调研报告)
    *   `project_docs/ARCHITECTURE_AND_DESIGN/TEMPLATE_STRUCTURE_DESIGN.md` (待创建 - 游戏模板结构设计)
    *   `project_docs/ARCHITECTURE_AND_DESIGN/TECHNICAL_STACK.md` (待创建 - 技术栈详情)

### **D. 测试文档 (具体项目文档)**
*   `project_docs/tests/TEST_PLAN.md` (待创建 - 测试计划)
*   `project_docs/tests/TTS_MODDING_VALIDATION.md` (待创建 - TTS Modding API验证测试)

### **E. 源代码与构建 (具体项目文档)**
*   **源代码根目录**: `src/` (此目录及其内容将在项目开发过程中由AI根据需求动态创建和填充。初始阶段可能不存在。)
*   **测试代码根目录**: `tests/` (此目录及其内容将在项目开发过程中由AI根据需求动态创建和填充。初始阶段可能不存在。)
*   **构建配置**: 待TTS Mod开发环境确定后添加

### **F. 外部参考资料与依赖 (重要)**
*   **TTS官方API文档**: `external_repos/Tabletop-Simulator-API-master/` (完整的TTS Modding API参考)
    *   核心API文档: `external_repos/Tabletop-Simulator-API-master/docs/`
    *   关键模块: `object.md` (113KB - 游戏对象API), `events.md` (65KB - 事件系统), `ui.md` (UI系统), `webrequest/` (网络请求)
*   **TTS官方知识库**: `external_repos/Tabletop-Simulator-Knowledge-Base-master/` (TTS使用和开发指南)
*   **关键TBD验证点**: 根据PRD文档第10节，需要重点验证：
    *   文件系统访问权限 (`io`库可用性, `persistence.*` API)
    *   游戏对象文本修改能力 (`object.setName()`, `object.setDescription()`)
    *   网络请求限制 (`WebRequest` API详细调研)
    *   UI系统灵活性和3D文本覆盖能力

## **4. 技术栈概要 (本项目)**

*基于PRD文档的技术考虑部分确定，将由 `SystemArchitectAI` 进一步详化。*

*   **前端**: Tabletop Simulator 自定义UI (基于XML/Lua)
*   **后端**: 无独立后端，逻辑在TTS Lua脚本中
*   **外部集成**: LLM服务HTTP API调用 (用户配置)
*   **数据存储**: TTS存档机制 (`script_state`) 或Mod本地文件
*   **主要框架/库**: Tabletop Simulator Modding API (Lua)
*   **开发语言**: Lua (TTS脚本), JSON/XML (模板配置)
*   **构建工具**: 待研究TTS Mod发布流程
*   **版本控制**: Git
*   **参考文档**: TTS官方API文档和知识库 (见外部参考资料)

## **5. OrchestratorAgent 当前关注点**

*由 `OrchestratorAgent` 更新，反映其当前正在处理或监控的核心事项。*

*   **当前主要任务**: 项目初始化 - 需求分析准备与技术可行性验证
*   **等待用户输入**: 需要确认自定义验证规则配置需求
*   **下一步计划**: 激活ProductOwnerAI进行详细需求分析，优先处理TTS API技术验证
*   **关键风险点**: TTS Modding API限制验证，LLM集成方案确认

---
*本文档由 `OrchestratorAgent` 在项目生命周期中持续更新，以确保所有参与者和AI角色拥有统一的项目视图。* 