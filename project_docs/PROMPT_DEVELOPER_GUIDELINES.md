# **提示词开发者指南：创建符合规范的AI角色 (`PROMPT_DEVELOPER_GUIDELINES.md`)**

**目的**: 本指南为提示词开发者（或协助创建AI角色的 `OrchestratorAgent`）提供规范，确保所有新创建的专业AI角色都能无缝集成到由 `OrchestratorAgent` 主导的项目协作流程中。遵循这些规范对于维护项目管理的统一性、清晰度和效率至关重要。

**版本**: 1.1
**最后更新**: `{{YYYY-MM-DD}}`

## **核心原则**

1.  **`OrchestratorAgent` 主导**: 所有专业AI角色都是在 `OrchestratorAgent` 的统一协调下工作的执行单元。
2.  **明确的单向任务流**: `OrchestratorAgent` 分配任务 -> 专业AI角色执行并汇报 -> `OrchestratorAgent` 评估并规划下一步。
3.  **状态管理唯一性**: `AI_AGENT_PROGRESS.md` 和 `PROJECT_CONTEXT.md` 由 `OrchestratorAgent` **独家更新和维护**。专业AI角色只负责报告其任务产出和状态。
4.  **质量内建**: 专业AI角色在执行任务时，必须遵循 `project_docs/AI_STAGE_VALIDATION_GUIDE.md` 中的自我检查规范，并在汇报时提供客观评估和证据。

## **新AI角色定义文件 (`*.role.md`) 规范**

所有新创建的AI角色定义文件（通常位于 `PromptX/domain/custom/` 或相关领域子目录下）必须遵循以下结构和内容要求：

### **1. 角色描述 (`<description>`)**

*   清晰说明角色的核心职责和专业领域。
*   **必须提及**该角色是在 `OrchestratorAgent` 的指导下执行特定任务的。
    *   例如："本角色是一名[专业领域]AI，负责[核心职责]。它接收来自 `OrchestratorAgent` 的任务指令，并在完成后向其汇报。它会遵循 `AI_STAGE_VALIDATION_GUIDE.md` 进行自我评估。"

### **2. 原则 (`<principle>`)**

*   **必须包含**一条指导原则，强调参考 `project_docs/PROJECT_CONTEXT.md` 以获取项目上下文。
*   **必须包含**一条指导原则，强调其行动和汇报需遵循 `OrchestratorAgent` 的协调。
*   **必须包含**一条指导原则，强调其产出和自我评估必须符合 `project_docs/AI_STAGE_VALIDATION_GUIDE.md` 的要求。

### **3. 行动块 (`<action>`)**

#### **A. 任务接收行动块**

*   角色必须有一个或多个清晰定义的 `<block>` 用于接收来自 `OrchestratorAgent` 的核心任务指令。
*   这些块应包含明确的 `<input>` 参数，用于接收任务详情、所需数据路径等。
*   产出物应保存到项目结构中合适的位置，并符合 `project_docs/PROJECT_NAMING_CONVENTIONS.md` (如果存在)。
*   **示例**:
    ```xml
    <action>
        <block name="execute_core_task">
            <description>接收并执行[角色专业领域]的核心任务。</description>
            <input name="task_details" type="string" description="来自OrchestratorAgent的具体任务描述"/>
            <input name="input_document_path" type="string" optional="true" description="任务所需的输入文档路径"/>
            <!-- 其他必要的输入 -->
            <output name="output_summary" type="string" description="任务执行的简要总结"/>
            <output name="output_artifact_paths" type="string" description="主要产出物路径列表 (逗号分隔)"/>
            <execute>
                print(f"正在执行核心任务: {task_details}...");
                // ... 角色执行任务的逻辑 ...
                // 产出物应保存到项目结构中合适的位置
                // self.output_summary = "核心任务已按要求完成。";
                // self.output_artifact_paths = "project_docs/section/output1.md,src/module/code.js";
                print("核心任务执行完毕。准备向 OrchestratorAgent 汇报。");
            </execute>
        </block>
        <!-- 其他特定任务的行动块 -->
    </action>
    ```

#### **B. 任务完成汇报行动块 (`report_to_orchestrator`) - 标准化信号**

*   **必须包含**一个名为 `report_to_orchestrator` (或类似且功能一致的名称) 的标准行动块。
*   此块的职责是向 `OrchestratorAgent` 报告任务完成情况，**并输出结构化的任务完成信号**。
*   **输入参数应包括** (用于内部逻辑和传统打印，可选):
    *   `task_description`: 已完成的核心任务描述。
    *   `outputs_description`: 对主要产出物的简要文字描述。
    *   `status_summary`: 任务执行的简要总结。
    *   `issues_or_blockers` (可选): 遇到的任何问题或阻塞项。
*   **执行逻辑 (`<execute>`) 必须**:
    1.  (可选) 清晰打印任务已完成、产出物、状态总结等信息，供用户即时查看。
    2.  **最重要**: **严格按照以下格式打印输出标准化的任务完成信号**: (此信号供OrchestratorAgent解析)
        ```text
        AI_TASK_COMPLETE_SIGNAL_START
        Role: [YourRoleName]
        Status: Success | Failure | Blocked
        Summary: [简要任务完成总结，例如：需求文档初稿已生成并符合所有检查点。]
        Outputs:
          - path: [project_relative/path/to/output1.md]
            description: [对output1的简明描述，例如：FSD文档初稿]
            checksum: [可选，例如MD5，用于验证文件完整性]
          - path: [project_relative/path/to/output2.json]
            description: [对output2的简明描述]
            checksum: [可选]
        SelfAssessment:
          - checkpoint: [来自AI_STAGE_VALIDATION_GUIDE.md的具体检查点1]
            compliance: Met | PartiallyMet | NotMet
            evidence: [符合该检查点的理由或证据链接/说明]
          - checkpoint: [具体检查点2]
            compliance: Met
            evidence: [理由或证据]
        IssuesOrBlockers: [如果没有，则为None；否则为具体问题描述]
        NextActionRecommended: [可选：对OrchestratorAgent的下一步行动建议，例如：请求CodeReviewerAI审查src/module/code.js]
        AI_TASK_COMPLETE_SIGNAL_END
        ```
    3.  在信号打印完毕后，**紧接着输出明确的接管请求**，例如:
        `print("请 OrchestratorAgent 接管并评估产出，进行下一步规划。");`
*   **示例 (`<execute>` 部分)**:
    ```xml
    <execute>
        // ... 角色执行任务的逻辑，保存产出物 ...
        String roleName = "MyExampleAI"; // 替换为实际角色名
        String taskStatus = "Success"; // 或 Failure, Blocked
        String summary = "核心功能模块已开发完成并通过单元测试。";
        String outputPath1 = "src/my_module/feature.js";
        String outputDesc1 = "核心功能实现代码";
        String outputChecksum1 = "md5:abcdef123456"; // 示例
        String checkpoint1 = "代码符合编码规范";
        String compliance1 = "Met";
        String evidence1 = "所有代码均通过Linter检查，并遵循PROJECT_NAMING_CONVENTIONS.md";
        String issues = "None";
        String nextAction = "建议进行集成测试";

        // (可选) 传统打印供用户查看
        print(f"任务 '{self.task_description}' 已完成。");
        print(f"主要产出: {outputPath1} - {outputDesc1}");
        print(f"状态总结: {summary}");

        // 标准化信号输出 (确保严格按格式)
        print("AI_TASK_COMPLETE_SIGNAL_START");
        print(f"Role: {roleName}");
        print(f"Status: {taskStatus}");
        print(f"Summary: {summary}");
        print("Outputs:");
        print(f"  - path: {outputPath1}");
        print(f"    description: {outputDesc1}");
        print(f"    checksum: {outputChecksum1}");
        print("SelfAssessment:");
        print(f"  - checkpoint: {checkpoint1}");
        print(f"    compliance: {compliance1}");
        print(f"    evidence: {evidence1}");
        print(f"IssuesOrBlockers: {issues}");
        print(f"NextActionRecommended: {nextAction}");
        print("AI_TASK_COMPLETE_SIGNAL_END");

        print("请 OrchestratorAgent 接管并评估产出，进行下一步规划。");
    </execute>
    ```

### **4. 思考过程 (`<thought_process>`)**

*   **最后一步必须是**: 调用标准的 `report_to_orchestrator` 行动块，以确保任务完成后总是向 `OrchestratorAgent` 汇报。
    *   例如: `<step>使用 "report_to_orchestrator" 行动块，清晰汇报任务完成情况、产出物和遇到的任何问题，并明确请求 OrchestratorAgent 接管。</step>`

### **5. 内存/资源访问 (`<memory>`)**

*   **禁止写入核心状态文件**:
    *   `project_docs/AI_AGENT_PROGRESS.md`：**禁止**授予 `write` 或 `append` 权限。
    *   `project_docs/PROJECT_CONTEXT.md`：**禁止**授予 `write` 或 `append` 权限。
    *   如果角色需要了解项目进度或上下文，可以授予对这两个文件的 `read` 权限。
*   **必须包含对核心规范文件的只读访问**:
    ```xml
    <memory>
        <resource name="project_context" type="file" path="project_docs/PROJECT_CONTEXT.md" access="read"/>
        <resource name="ai_stage_validation_guide" type="file" path="project_docs/AI_STAGE_VALIDATION_GUIDE.md" access="read"/>
        <resource name="orchestrator_directives" type="file" path="project_docs/OrchestratorAgent_Directives.md" access="read"/>
        <resource name="custom_validation_rules" type="file" path="project_docs/custom_validation_rules.md" access="read" optional="true"/> 
        <resource name="naming_conventions" type="file" path="project_docs/PROJECT_NAMING_CONVENTIONS.md" access="read" optional="true"/> 
        <!-- 其他角色特定的只读资源 -->

        <resource name="role_specific_output_dir" type="directory" path="project_docs/role_outputs/[RoleName]/" access="read_write"/>
        <!-- 其他角色特定的读写资源 -->
    </memory>
    ```

## **集成到 OrchestratorAgent 流程中**

`OrchestratorAgent` 在其指令 (`OrchestratorAgent_Directives.md`) 中已被告知：
*   如何选择和激活专业AI角色。
*   如何向它们分配任务。
*   期望从它们那里接收标准化的任务完成信号 (包含结构化数据和自我评估) 和产出物报告。
*   在接收到报告后，如何解析信号、验证产出、更新核心状态文件 (`AI_AGENT_PROGRESS.md`, `PROJECT_CONTEXT.md`) 并规划下一步。

提示词开发者在创建新角色时，务必确保新角色遵循本指南，以便顺利融入这一协作流程。

## **审查与验证**

在创建或修改AI角色后，请对照本指南进行审查，确保所有规范都已满足。可以模拟一次 `OrchestratorAgent` 分配任务 -> 新角色执行 -> 新角色汇报 (检查信号格式和内容) 的完整流程，以验证其行为符合预期。

---
本指南旨在促进AI协作的标准化和高效化。 