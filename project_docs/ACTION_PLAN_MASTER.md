# **项目行动总纲 (`ACTION_PLAN_MASTER.md`)**

**版本**: 2.0
**最后更新**: 2024-07-26 10:30:00
**适用对象**: `OrchestratorAgent` 及项目全体参与者
**目的**: 定义从项目启动到交付的高级战略路线图，确保AI驱动的全自动开发过程有序、高效。

---

## **阶段0：外部AI协作预构思阶段 (0-2天)**

### **核心目标**
通过外部免费AI工具（如ChatGPT、Claude等）进行初步的产品构思和需求分析，为正式的项目开发环境提供高质量的起始输入。

### **关键产出物**
- `project_docs/REQUIREMENTS/EXTERNAL_AI_PRODUCT_ANALYSIS.md` - 外部AI生成的完整产品需求文档
- 明确的产品愿景、目标用户、核心功能列表
- 初步的技术栈建议和项目规划

### **OrchestratorAgent角色**
在此阶段，OrchestratorAgent暂不参与。用户直接与外部AI协作。

### **用户行动计划**
1. **准备外部AI协作**：
   - 复制 `project_docs/EXTERNAL_AI_COLLABORATION_GUIDE.md` 全部内容
   - 将内容粘贴给外部AI（如ChatGPT），建立协作
   
2. **完成外部AI对话**：
   - 遵循外部AI的引导，完成4个阶段的产品构思对话
   - 确保外部AI生成符合模板格式的产品需求文档
   
3. **验证输出质量**：
   - 检查外部AI输出是否包含所有必需部分
   - 确认文档底部有"外部AI协作完成: 是"标识
   
4. **准备项目集成**：
   - 将外部AI文档保存为 `project_docs/REQUIREMENTS/EXTERNAL_AI_PRODUCT_ANALYSIS.md`
   - 准备激活OrchestratorAgent进行后续处理

### **完成标准**
- ✅ 获得完整的外部AI产品需求文档
- ✅ 产品愿景和核心价值明确
- ✅ 主要功能和用户场景清晰
- ✅ 技术考虑和项目规划基本明确

### **风险与应对**
- **风险**: 外部AI输出不完整或质量不高
- **应对**: 参考 `EXTERNAL_AI_OUTPUT_INTEGRATION.md` 中的问题处理指导

---

## **阶段1：产品构思与战略定位 (1-3天)**

### **核心目标**
基于外部AI协作成果，通过OrchestratorAgent和专业AI角色，将初步需求转化为清晰、可执行的产品战略。

### **关键产出物**
- 更新的 `PROJECT_CONTEXT.md` - 包含完整项目概览
- `REQUIREMENTS/FSD.md` - 功能规格说明书
- `REQUIREMENTS/USER_STORIES.md` - 详细用户故事
- `ARCHITECTURE_AND_DESIGN/PRODUCT_VISION.md` - 精炼的产品愿景文档

### **OrchestratorAgent角色**
- **项目初始化**: 读取外部AI文档，理解产品需求
- **信息整合**: 将外部AI成果整合到项目文档体系中
- **任务规划**: 分解细化需求的具体任务
- **角色协调**: 推荐并指导切换到ProductOwnerAI进行深度需求分析

### **具体任务序列**
1. **外部AI成果集成** (`OrchestratorAgent`)：
   - 读取 `EXTERNAL_AI_PRODUCT_ANALYSIS.md`
   - 更新 `PROJECT_CONTEXT.md` 基础信息
   - 更新 `AI_AGENT_PROGRESS.md` 项目状态
   
2. **需求深化分析** (`ProductOwnerAI`)：
   - 基于外部AI文档编写详细的FSD.md
   - 创建用户故事和用户画像
   - 识别需求gap并补充
   
3. **产品战略制定** (`ProductOwnerAI` + `OrchestratorAgent`)：
   - 明确产品路线图和MVP范围
   - 定义成功指标和验收标准
   - 确认商业价值和技术可行性

### **完成标准**
- ✅ 项目核心信息已录入 `PROJECT_CONTEXT.md`
- ✅ 功能需求文档完整且清晰
- ✅ 用户故事覆盖主要使用场景
- ✅ MVP范围明确定义
- ✅ 项目组织者（用户）确认产品方向正确

## **第二阶段：规划与设计 - 蓝图绘制**

*   **核心目标**: 将产品定位转化为详细的需求规格、清晰的系统架构和具体的技术选型方案。
*   **关键产出物**:
    *   详细的功能规格说明书 (`project_docs/REQUIREMENTS/FSD.md`)
    *   用户故事 (`project_docs/REQUIREMENTS/USER_STORIES.md`)
    *   非功能性需求文档 (`project_docs/REQUIREMENTS/NON_FUNCTIONAL_REQUIREMENTS.md`)
    *   系统架构设计文档 (`project_docs/ARCHITECTURE_AND_DESIGN/SYSTEM_ARCHITECTURE.md`)
    *   技术选型报告 (`project_docs/ARCHITECTURE_AND_DESIGN/TECHNICAL_STACK.md`)
    *   数据模型定义 (`project_docs/ARCHITECTURE_AND_DESIGN/DATA_MODEL.md`)
    *   初步的API文档 (`project_docs/ARCHITECTURE_AND_DESIGN/API_DOCUMENTATION.md`)
    *   清晰的项目目录结构规划 (记录在 `SYSTEM_ARCHITECTURE.md` 或单独文件)。
    *   详细的任务分解列表 (WBS)，遵循 `TASK_LIST_TEMPLATE.md` 格式，并按模块/阶段存放 (例如 `project_docs/PHASE_02_DESIGN/tasks.md`)。
*   **OrchestratorAgent 协调职责**:
    *   指导用户切换到"产品负责人AI"进行详细需求分析与文档化，确保需求清晰、完整、可追溯。
    *   指导用户切换到"系统架构师AI"（或协助创建此角色）进行架构设计和技术选型。强调技术选型需考虑项目目标（商业/开源、性能、成本等）。
    *   **融入问题解决 - 目录结构**: 严格要求在架构设计阶段明确项目目录结构，并在后续开发中强制执行，避免代码混乱和重复。
    *   **融入问题解决 - 文档引用**: 强调所有设计文档都应清晰引用需求来源，并由 `OrchestratorAgent` 确保 `PROJECT_CONTEXT.md` 中的文档索引正确无误。
    *   协调"项目经理AI"（或由"产品负责人AI"兼任）根据需求和架构生成详细的任务列表。

## **第三阶段：AI全自动开发与执行**

*   **核心目标**: 基于规划设计阶段的蓝图，高效、高质量地生成项目代码和相关配置。
*   **关键产出物**:
    *   各模块的源代码 (存放于 `src/`)
    *   配置文件、初始化脚本等。
    *   开发者文档（如代码注释、模块说明）。
    *   单元测试代码 (存放于 `tests/unit/`)
    *   `AI_AGENT_PROGRESS.md` 实时更新。
*   **OrchestratorAgent 协调职责**:
    *   根据 `TASK_LIST.md`，向用户建议合适的"开发者AI"角色（可能需要按技术栈或模块细分）。
    *   指导用户切换角色，并向"开发者AI"下达具体的编码任务，明确输入（需求、设计文档、API定义）和输出要求（代码、测试、文档）。
    *   **融入问题解决 - 状态检查与管理**: 指导创建的"开发者AI"角色具备检查代码编译、基本运行、处理依赖、以及报告执行状态（成功、失败、错误信息）的能力。长时间任务应有超时处理机制。
    *   **融入问题解决 - 代码质量**: 要求"开发者AI"遵循编码规范，编写可维护、可读性高的代码，并产出必要的单元测试。
    *   监督任务执行进度，及时更新 `AI_AGENT_PROGRESS.md` 和 `PROJECT_CONTEXT.md`。
    *   协调解决开发过程中出现的技术问题或资源冲突。

## **第四阶段：测试与质量保证**

*   **核心目标**: 全面测试已开发的功能模块和整个系统，确保其满足需求规格和质量标准。
*   **关键产出物**:
    *   测试计划 (`project_docs/tests/TEST_PLAN.md`)
    *   集成测试用例和脚本 (存放于 `tests/integration/`)
    *   端到端测试用例和脚本 (存放于 `tests/e2e/`)
    *   性能测试脚本和报告 (如适用)
    *   安全测试报告 (如适用)
    *   详细的测试报告，记录测试结果和缺陷 (存放于 `project_docs/tests/TEST_REPORTS/`)
    *   缺陷跟踪列表 (可结合 `AI_AGENT_PROGRESS.md` 或专用工具)
*   **OrchestratorAgent 协调职责**:
    *   指导用户切换到"测试工程师AI"或"QA分析师AI"。
    *   协调测试角色的工作，确保测试计划的制定、测试用例的设计与执行覆盖所有关键功能和非功能需求。
    *   **融入问题解决 - 前端测试工具**: 主动建议并指导测试角色集成和使用合适的前端测试工具 (如Jest, Cypress, Playwright)。
    *   **融入问题解决 - 任务执行状态检查深度**: 强调测试不仅是功能通过，还包括性能、安全、用户体验等方面的评估。
    *   跟踪缺陷修复过程，协调开发者AI和测试者AI的协作。

## **第五阶段：部署与交付**

*   **核心目标**: 将经过测试验证的系统成功部署到目标环境，并准备好交付给用户。
*   **关键产出物**:
    *   部署脚本 (`project_docs/deployment/DEPLOYMENT_SCRIPTS/`)
    *   部署指南 (`project_docs/deployment/DEPLOYMENT_GUIDE.md`)
    *   生产环境配置文档。
    *   用户手册/操作指南 (如适用)。
    *   版本发布说明。
*   **OrchestratorAgent 协调职责**:
    *   指导用户切换到"DevOps工程师AI"或"部署工程师AI"。
    *   协调完成部署环境的准备、部署脚本的编写与测试、以及最终的上线过程。
    *   **融入问题解决 - 应用开发过程文件维护**: 确保所有部署相关的文档都得到妥善创建和管理，并记录在 `PROJECT_CONTEXT.md` 中。
    *   协助用户进行用户验收测试 (UAT) 并收集反馈。

## **第六阶段：持续维护与优化**

*   **核心目标**: 对已上线的系统进行监控、维护、问题修复，并根据用户反馈和业务发展进行持续迭代优化。
*   **关键产出物**: (持续更新)
    *   系统监控报告。
    *   错误修复补丁和版本更新。
    *   性能优化报告和实施方案。
    *   根据新需求进行的迭代开发。
    *   更新的文档。
*   **OrchestratorAgent 协调职责**:
    *   作为长期维护和优化的主要协调者。
    *   根据用户反馈或监控数据，委派任务给合适的AI角色（如开发者AI进行bug修复，性能工程师AI进行优化，产品负责人AI分析新需求）。
    *   确保所有变更都经过适当的测试和文档更新。
    *   **融入问题解决 - 文档重命名与引用更新**: 在长期维护中，文档结构可能变化，`OrchestratorAgent` 需持续关注并维护 `PROJECT_CONTEXT.md` 中文档链接的有效性。

## **关键成功因素与AI协作原则**

*   **用户清晰的顶层指令与反馈**: `OrchestratorAgent` 的高效运作依赖于用户提供清晰的目标和及时的反馈。
*   **`OrchestratorAgent` 的强大协调与规划能力**: 其自身的 `<personality>`, `<principle>`, `<experience>` 定义至关重要。
*   **高质量和丰富的PromptX角色库**: 预置角色和自定义角色的能力是项目成功的基石。
*   **迭代优化整个协作流程**: 本总纲及所有协作模式都应根据实践不断回顾和优化。
*   **透明化与可追溯性**: 所有关键决策、任务分配和产出都应有记录，主要通过 `PROJECT_CONTEXT.md` 和 `AI_AGENT_PROGRESS.md` 实现。

---
**OrchestratorAgent，请以此总纲为基准，领导我们共同完成这个激动人心的项目！** 