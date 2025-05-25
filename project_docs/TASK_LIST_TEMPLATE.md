# **任务列表模板 (`TASK_LIST_TEMPLATE.md`)**

**目的**: 本模板为 `OrchestratorAgent` 或其他AI角色在分解和生成具体任务列表时提供一个标准化的结构。AI应参考此模板格式，将实际的任务列表存储在按阶段或模块组织的具体文件中（例如 `project_docs/PHASE_01_PLANNING/tasks.md` 或 `project_docs/MODULE_X_DEV/tasks.md`）。

---

## **任务列表：[阶段名称/模块名称]**

**最后更新**: {{YYYY-MM-DD HH:MM:SS}}
**负责人**: {{AI Role or OrchestratorAgent}}

| 任务ID   | 任务描述                                     | 优先级 | 状态        | 负责人 (AI角色) | 前置依赖 (任务ID或文档) | 预计产出物/交付成果                      | 估算工时 | 开始日期   | 截止日期   | 实际完成日期 | 备注/问题                                |
| -------- | -------------------------------------------- | ------ | ----------- | --------------- | ------------------------- | ---------------------------------------- | -------- | ---------- | ---------- | ------------ | ---------------------------------------- |
| `{{P01-T001}}` | `{{例如：确认项目范围与核心目标}}`                 | 高     | `{{To Do}}` | `OrchestratorAgent` | -                         | `PROJECT_CONTEXT.md` 中项目概览更新      | `{{2h}}` | `YYYY-MM-DD` | `YYYY-MM-DD` |              | `{{需要与用户进行一次会议讨论}}`             |
| `{{P01-T002}}` | `{{例如：收集用户对[某功能]的详细需求}}`           | 高     | `{{To Do}}` | `ProductOwnerAI`  | `P01-T001`                | `需求访谈记录.md`, `FSD.md` 初稿相关章节 | `{{8h}}` | `YYYY-MM-DD` | `YYYY-MM-DD` |              |                                          |
| `{{P02-D001}}` | `{{例如：设计[某模块]的数据库表结构}}`           | 中     | `{{To Do}}` | `DeveloperAI`     | `FSD.md Sec 3.2`          | `DATA_MODEL.md` 中相关ER图和表定义     | `{{4h}}` | `YYYY-MM-DD` | `YYYY-MM-DD` |              |                                          |
| `{{P02-C001}}` | `{{例如：编写[某API接口]的后端代码实现}}`         | 高     | `{{To Do}}` | `DeveloperAI`     | `API_DOC.md Sec 2.1`, `P02-D001` | `[service_name].py`, `[controller_name].py` | `{{16h}}`| `YYYY-MM-DD` | `YYYY-MM-DD` |              | `{{单元测试覆盖率需达到80%}}`                |
| `{{P03-T001}}` | `{{例如：为[某模块]编写单元测试用例}}`           | 中     | `{{To Do}}` | `TesterAI`        | `P02-C001`                | `tests/unit/test_[module].py`            | `{{8h}}` | `YYYY-MM-DD` | `YYYY-MM-DD` |              |                                          |
|          |                                              |        |             |                 |                           |                                          |          |            |            |              |                                          |

**状态说明**: 
*   **To Do**: 待处理
*   **In Progress**: 进行中
*   **Blocked**: 受阻
*   **In Review**: 审查中 (例如代码审查或用户确认)
*   **Done**: 已完成
*   **Cancelled**: 已取消

**优先级说明**:
*   **高**: 关键任务，需优先处理
*   **中**: 重要任务，按计划处理
*   **低**: 次要任务，可在资源允许时处理

**任务ID命名建议**: `{{PhasePrefix}}-{{TaskType}}-{{SequentialNumber}}`
*   `PhasePrefix`: 例如 P01 (阶段1), P02 (阶段2)
*   `TaskType`: 例如 T (通用任务), R (需求), D (设计), C (编码), TS (测试), DP (部署)
*   `SequentialNumber`: 例如 001, 002

---
**OrchestratorAgent 指示**: 请在分解任务时，参考并遵循此模板的结构和字段定义。将具体的任务列表保存在相应的阶段或模块目录下的 `tasks.md` 文件中。 