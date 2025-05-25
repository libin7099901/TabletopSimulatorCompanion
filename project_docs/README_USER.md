# **欢迎来到AI驱动的全自动产品开发项目!**

本文档是您的项目导航地图，旨在帮助您理解如何与我们的人工智能助手（尤其是核心协调者 `OrchestratorAgent`）高效协作，以实现从产品概念到最终交付的全流程自动化。

## **1. 项目愿景与AI的核心角色**

本项目的核心愿景是借助先进的AI工具（如Cursor）和强大的提示词工程框架（PromptX），最大限度地自动化软件开发的各个环节，从而提高效率、降低成本、并释放人类创造力。

在这个愿景中，AI不仅仅是代码生成器，更是您的智能合作伙伴。我们将通过一个名为 **`OrchestratorAgent`** (项目总指挥AI) 的核心AI角色来协调整个开发流程。您可以将其视为项目的AI项目经理和首席架构师，它将：

*   理解您的顶层需求和目标。
*   分析任务并将其分解给专门的AI角色（例如，产品负责人AI、开发者AI、测试工程师AI等），这些角色会通过标准化的信号向其汇报进度和产出。
*   指导您在必要时切换AI角色，或协助创建新的专业AI角色（遵循 `PROMPT_DEVELOPER_GUIDELINES.md`）。
*   **自动、动态地维护项目核心上下文信息** (`PROJECT_CONTEXT.md`)，确保所有AI角色都能基于一致的理解工作。
*   **自动追踪并记录项目进度** (`AI_AGENT_PROGRESS.md`)，并向您汇报。
*   引导您配置项目特定的自定义验证规则 (`custom_validation_rules.md`)，以确保AI产出符合您的特定要求。

您的主要交互对象将是 `OrchestratorAgent`。

## **2. 本文档体系导览**

为了支持这种新型的AI协作模式，我们构建了一套专门的文档体系，主要存放在 `project_docs/` 目录下。理解这套体系对您至关重要：

*   **用户指导与总览 (面向您)**：
    *   `README.md` (位于项目根目录)：**首要的快速安装、项目初始化和启动指南。请务必先阅读此文件完成项目设置。**
    *   `README_USER.md` (本文档)：在您完成项目初始化后，本文档将帮助您理解协作理念和基本模式。
    *   `PROMPTX_USAGE_GUIDE.md`：详细说明如何配置和使用PromptX框架及 `OrchestratorAgent`。
    *   `AI_COLLABORATION_BEST_PRACTICES.md`：与AI高效协作的最佳实践和技巧。
    *   `COMPREHENSIVE_PROJECT_GUIDE.md`：更详细的项目操作流程和AI能力说明。

*   **AI指令与项目上下文 (主要面向AI，您可查阅)**：
    *   `PROJECT_CONTEXT.md`：项目的核心动态上下文，包含项目状态、关键决策、文档索引等。**由 `OrchestratorAgent` 自动维护，是项目的单一事实来源，请经常关注**。
    *   `OrchestratorAgent_Directives.md`：赋予 `OrchestratorAgent` 的"使命宣言"和核心行动准则。
    *   `AI_STAGE_VALIDATION_GUIDE.md`：AI各阶段任务验证与质量保证的详细规范，所有AI角色均需遵守。
    *   `custom_validation_rules.md` (用户按需创建)：您定义的、本项目特有的、AI必须遵守的规则。`OrchestratorAgent` 会引导您配置并自动应用。
    *   `AI_AGENT_PROGRESS.md`：**由 `OrchestratorAgent` 自动记录和更新的**项目进度跟踪板。
    *   `PROMPT_DEVELOPER_GUIDELINES.md`：创建新AI角色或理解现有角色行为的规范。
    *   `ACTION_PLAN_MASTER.md`：项目从启动到交付的高级战略路线图，指导 `OrchestratorAgent` 的宏观调控。

*   **项目执行产出 (主要由AI生成和维护，您负责审查)**：
    *   `REQUIREMENTS/`：包含需求文档。
    *   `ARCHITECTURE_AND_DESIGN/`：包含架构设计、接口定义等。
    *   `src/`：项目源代码。
    *   `tests/`：测试相关文档和代码。
    *   以及其他在项目过程中生成的必要文档。

**请优先阅读根目录的 `README.md` 完成项目设置，然后阅读本文档和 `PROMPTX_USAGE_GUIDE.md`。关注 `PROJECT_CONTEXT.md` 以了解项目最新动态。**

## **3. 与 OrchestratorAgent 协作的核心模式**

1.  **项目初始化 (首次使用模板时)**：
    *   根据根目录 `README.md` 中的"快速开始"指引，完成依赖安装和AI环境配置。
    *   **最重要的第一步是向 `OrchestratorAgent` 发出"初始化本项目"的指令。** 这将使模板自动适配您的具体项目。`OrchestratorAgent` 会引导您完成此过程，包括预填充项目信息等。

2.  **启动与激活 `OrchestratorAgent`** (初始化完成后或后续日常使用)：
    *   确保您的Cursor环境已正确配置 `PromptX`，并且 `bootstrap.md` 文件指向 `PromptX/domain/custom/OrchestratorAgent.role.md`。
    *   向Cursor发送初始的 "Action" 指令以激活 `OrchestratorAgent`。

3.  **下达指令**：
    *   您主要通过向 `OrchestratorAgent` 发送自然语言指令来驱动项目。
    *   **示例指令**："🎛️ OrchestratorAgent，请分析位于 `project_docs/REQUIREMENTS/my_prd.md` 的需求文档，并开始需求深化阶段。" 或 "🎛️ OrchestratorAgent，根据项目计划，请指派 `DeveloperAI` 开始开发用户认证模块。"
    *   指令应清晰、明确，并提供必要的上下文（例如，引用相关文档）。

4.  **接收反馈与指导**：
    *   `OrchestratorAgent` 会分析您的请求，可能会向您提问以澄清需求，或者指导您切换到更专业的AI角色（并告知您如何操作及切换后的指令）。
    *   它会自动更新核心项目文档如 `PROJECT_CONTEXT.md` 和 `AI_AGENT_PROGRESS.md`。
    *   它还会引导您在合适的时机（如需求深化阶段）配置 `custom_validation_rules.md`。

5.  **审查产出**：
    *   AI生成的代码、文档等产出物需要您的审查和确认。`OrchestratorAgent` 会在关键节点提议进行阶段性评审。

## **4. 如何开始 (在阅读完根目录 `README.md` 并完成初始化之后)**

1.  请先完整阅读本文档 (`README_USER.md`)。
2.  接着，请仔细阅读 `project_docs/PROMPTX_USAGE_GUIDE.md`，了解 `OrchestratorAgent` 的配置和详细使用方法。
3.  然后，您可以查阅 `project_docs/AI_COLLABORATION_BEST_PRACTICES.md` 获取更多协作技巧。
4.  当您准备好后，就可以激活 `OrchestratorAgent` 并开始您的第一个具体项目任务了！

## **5. 遇到问题怎么办？**

*   **首先尝试向 `OrchestratorAgent` 提问**。它被设计为能够理解和协助解决许多常见问题，并能访问最新的项目文档。
*   如果问题依然存在，请检查您的PromptX配置和指令是否清晰。
*   查阅本文档体系中的相关指导文档，特别是 `COMPREHENSIVE_PROJECT_GUIDE.md`。

我们致力于打造一个顺畅、高效的AI协作体验。祝您项目顺利！ 