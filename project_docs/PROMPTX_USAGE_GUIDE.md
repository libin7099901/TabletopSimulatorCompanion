# **PromptX 集成与使用指南 (本项目特定)**

本文档旨在为您提供在本项目中有效集成和使用 `PromptX` 框架，特别是与核心AI协调者 **`OrchestratorAgent`** 进行交互的详细步骤和最佳实践。

## **1. PromptX 框架简介**

`PromptX` 是一个工程化的AI提示词管理框架，它通过结构化、模块化的方式帮助我们构建和管理AI的提示词，从而增强AI的思维、行为和记忆能力。在本项目中，我们主要通过 `PromptX` 来定义和管理人AI角色（如 `OrchestratorAgent`、产品负责人AI、开发者AI等）。

*   **核心组件**：角色 (`.role.md`)、思维 (`.think.md`)、行为 (`.action.md`)、记忆 (`.memory.md`)。
*   **角色定义**：每个AI角色通过一个 `.role.md` 文件定义，其中包含了该角色的性格、原则、经验、以及可执行的动作等。
*   **启动机制**：通过 `PromptX/bootstrap.md` 文件加载和初始化指定的AI角色。

有关 `PromptX` 的更完整信息，请参考 `PromptX/README.md`。

## **2. 配置Cursor与 OrchestratorAgent 协同**

`OrchestratorAgent` 是本项目的"总指挥AI"。为了让它正确地引导项目流程，您需要进行以下关键配置：

**步骤1：确认 `OrchestratorAgent.role.md` 文件**

*   确保 `PromptX/domain/custom/OrchestratorAgent.role.md` 文件存在并且内容是我们之前共同设计好的。如果 `custom` 文件夹不存在，请在 `PromptX/domain/` 下创建它。

**步骤2：修改 `bootstrap.md` 以指定 `OrchestratorAgent` 为默认角色**

*   打开 `PromptX/bootstrap.md` 文件。
*   找到引用角色文件的行（通常以 `@file://` 开头）。
*   将其修改为明确指向 `OrchestratorAgent` 的角色文件：
    ```markdown
    @file://PromptX/domain/custom/OrchestratorAgent.role.md
    ```
*   **重要**：在项目初期，我们将主要通过 `OrchestratorAgent` 进行协调。当它指导您切换到其他专业角色时，您需要再次修改此文件，指向相应的专业角色 `.role.md` 文件路径。

**步骤3：设置Cursor的系统提示词 (System Prompt)**

*   将**修改后的 `PromptX/bootstrap.md` 文件的全部内容**复制。
*   粘贴到Cursor的系统提示词设置区域。具体位置可能因Cursor版本而异，请查阅Cursor的官方文档或设置界面。
*   **或者**，如果您不想设置为全局系统提示词，也可以在每次与AI开始新的会话时，首先将 `bootstrap.md` 的内容作为第一条消息发送给AI。
*   **这是激活 `PromptX` 框架并指定当前主导AI角色的关键步骤。**

**步骤4：发送 "Action" 指令以激活角色**

*   在正确设置了系统提示词（或发送了 `bootstrap.md` 内容）之后，向AI发送一个简单的指令：
    ```
    Action
    ```
*   此时，`bootstrap.md` 中指定的AI角色（初始为 `OrchestratorAgent`）将被激活，并准备好接收您的具体任务指令。
*   您应该会看到AI以其所扮演角色的身份回应您。

## **3. 与 OrchestratorAgent 交互**

一旦 `OrchestratorAgent` 被激活，您就可以开始通过自然语言向它下达指令了。

*   **清晰的指令**：指令应尽可能清晰、明确，并包含必要的上下文。例如，如果您希望它处理某个文档，请提供文档的完整路径。
*   **参考 `project_docs/README_USER.md`** 中关于与 `OrchestratorAgent` 协作模式的说明。
*   **参考 `project_docs/OrchestratorAgent_Directives.md`** 了解它的核心职责和被期望的行为模式。

## **4. AI角色切换机制**

`OrchestratorAgent` 的核心职责之一是根据任务需求，向您推荐合适的专业AI角色，并指导您进行切换。

*   **切换时机**：当 `OrchestratorAgent` 判断当前任务需要特定领域的专业知识时（例如，详细的需求分析需要"产品负责人AI"，底层代码编写需要"资深开发者AI"），它会明确告知您。
*   **切换指令**：`OrchestratorAgent` 会告诉您需要切换到哪个角色的 `.role.md` 文件（例如，`@file://PromptX/domain/scrum/role/product-owner.role.md`）。
*   **您的操作**：
    1.  打开 `PromptX/bootstrap.md` 文件。
    2.  将其中的角色引用行修改为 `OrchestratorAgent` 指定的新角色文件路径。
    3.  保存 `bootstrap.md` 文件。
    4.  如果您的系统提示词是直接复制 `bootstrap.md` 内容的，请相应更新系统提示词。
    5.  **重新向AI发送 "Action" 指令**。这将激活新的AI角色。
    6.  之后，`OrchestratorAgent` (或您自己) 会给新的AI角色下达具体的任务指令。

*   **专业AI角色完成任务后的处理**：
    *   当专业AI角色（如 `DeveloperAI`）完成其特定任务后，它们被设计为遵循 `project_docs/PROMPT_DEVELOPER_GUIDELINES.md` 中的规范，通过**标准化的结构化信号向 `OrchestratorAgent` 报告**其任务状态、产出物和自我评估结果。
    *   `OrchestratorAgent` 在接收到此信号后，会自动进行验证、更新核心项目文档（如 `PROJECT_CONTEXT.md`, `AI_AGENT_PROGRESS.md`），然后向您汇报该专业AI角色的完成情况，并与您一起规划下一步。
    *   在某些情况下，`OrchestratorAgent` 可能会建议或自动切换回其自身进行后续的宏观调控。如果需要手动切回 `OrchestratorAgent`，操作方法与切换到专业角色类似：将 `bootstrap.md` 中的角色路径改回 `PromptX/domain/custom/OrchestratorAgent.role.md`，更新系统提示词（如果使用），并重发 "Action"。

## **5. 新角色创建的协作 (遵循规范)**

如果项目需要一个当前 `PromptX` 角色库中不存在的全新角色，`OrchestratorAgent` 会：

1.  向您解释为什么需要新角色以及该角色的核心职责、技能应该是什么。
2.  指导您使用 `PromptX/domain/template/prompt-developer.role.md` (提示词开发者角色) 或其自身的能力来协助您创建这个新的 `.role.md` 文件。
3.  **强调新角色定义必须遵循 [`project_docs/PROMPT_DEVELOPER_GUIDELINES.md`](./PROMPT_DEVELOPER_GUIDELINES.md) 中的规范**，特别是关于任务完成信号的输出格式，以确保新角色能无缝集成到 `OrchestratorAgent` 的管理流程中。
4.  新的自定义角色通常应存放在 `PromptX/domain/custom/` 目录下。
5.  创建完成后，您就可以通过修改 `bootstrap.md` 来激活并使用这个新角色了。

## **6. 集成手动或外部创建的AI角色 (确保兼容性)**

除了通过 `OrchestratorAgent` 引导并使用 `prompt-developer` 角色创建新角色外，您也可能通过其他方式创建（例如，手动编写 `.role.md` 文件，或使用PromptX相关的beta开发工具生成）。

在这种情况下，为了让 `OrchestratorAgent` 能够识别、理解并向您推荐使用这个新创建的角色，您必须执行以下关键步骤：

1.  **确保角色文件有效且符合规范**：确保您的 `.role.md` 文件符合PromptX的语法规范，并且**其行为（尤其是汇报机制）遵循 [`project_docs/PROMPT_DEVELOPER_GUIDELINES.md`](./PROMPT_DEVELOPER_GUIDELINES.md)**。文件应放置在 `PromptX/domain/` 目录下（通常是 `PromptX/domain/custom/` 子目录中）。
2.  **主动告知 `OrchestratorAgent`**：
    *   您需要与已激活的 `OrchestratorAgent` 进行交互。
    *   明确告知它新角色的**完整文件路径**（例如：`PromptX/domain/custom/MyNewBetaRole.role.md`）。
    *   简要描述这个新角色的**核心职责、主要功能和特长**。
    *   **示例指令**："🎛️ OrchestratorAgent，我创建了一个新的AI角色，文件路径是 `PromptX/domain/custom/MyNewBetaRole.role.md`。这个角色专门用于执行高级数据分析和生成可视化报告。请你记录一下，并在合适的任务中向我推荐它。"
3.  **`OrchestratorAgent` 的处理**：
    *   根据其设计 (`OrchestratorAgent.role.md` 中的原则)，`OrchestratorAgent` 在收到此类信息后，会尝试记录这个新角色及其元信息。
    *   之后，在分析未来任务时，如果该新角色的能力与任务需求匹配，`OrchestratorAgent` 就能够向您推荐它。
4.  **激活和使用**：
    *   一旦 `OrchestratorAgent` 推荐使用这个（您手动集成的）新角色，后续的激活步骤与常规角色切换一致：修改 `PromptX/bootstrap.md` 指向新角色，更新系统提示词，并重发 "Action" 指令。

**重要提示**：仅仅将 `.role.md` 文件放入文件夹中并不会让 `OrchestratorAgent` 自动发现它。您必须通过明确的沟通来完成集成过程。

## **7. 常见问题 (FAQ)**

*   **Q: 我修改了 `bootstrap.md`，但AI的行为没有改变。**
    *   **A:** 请确保您在修改 `bootstrap.md` 后，**重新发送了 "Action" 指令**。同时，如果您是将 `bootstrap.md` 内容复制到系统提示词的，请确保系统提示词也已更新为最新内容。

*   **Q: `OrchestratorAgent` 让我切换角色，我切换后应该给新角色什么指令？**
    *   **A:** `OrchestratorAgent` 在指导您切换角色时，通常会一并告知您切换成功后应该给新角色的初始任务指令。仔细阅读它的回复。

*   **Q: 我可以直接和专业AI角色对话，跳过 `OrchestratorAgent` 吗？**
    *   **A:** 技术上可以（通过修改 `bootstrap.md` 直接激活专业角色），但在本项目中，为了确保项目整体的协调性和上下文一致性，**强烈建议您始终通过 `OrchestratorAgent` 作为主要的交互入口**，由它来指导何时以及如何使用专业角色。重要的项目信息和决策应由 `OrchestratorAgent` 记录在 `PROJECT_CONTEXT.md` 中。

---

请仔细阅读并遵循本指南，以便更顺畅地与AI协作。如有疑问，可首先向 `OrchestratorAgent` 寻求澄清。 