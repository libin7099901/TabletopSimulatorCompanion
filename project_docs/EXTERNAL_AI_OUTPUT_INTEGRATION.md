# **外部AI输出集成指导 (`EXTERNAL_AI_OUTPUT_INTEGRATION.md`)**

**版本**: 1.0  
**最后更新**: 2024-07-26 10:30:00  
**目标**: 指导用户如何将外部AI生成的产品需求文档集成到本项目的开发环境中。

---

## **1. 外部AI输出文档的处理流程**

### **步骤1：验证外部AI输出格式**

确保外部AI生成的文档包含以下关键部分：
- ✅ 产品概览
- ✅ 问题陈述与解决方案  
- ✅ 用户画像与使用场景
- ✅ 功能需求（核心功能和增强功能）
- ✅ 非功能性需求
- ✅ 技术考虑
- ✅ 项目规划
- ✅ 成功指标与风险
- ✅ 文档底部的状态标识："外部AI协作完成: 是"

### **步骤2：创建初步产品分析报告**

将外部AI生成的文档保存为项目文档：

1. **文件命名**：`project_docs/REQUIREMENTS/EXTERNAL_AI_PRODUCT_ANALYSIS.md`
2. **内容**：直接复制外部AI的完整输出
3. **添加元信息**：
   ```markdown
   ---
   **导入时间**: [当前时间]
   **导入者**: [用户名称]
   **外部AI来源**: [使用的AI平台，如ChatGPT、Claude等]
   **协作完成度**: 完整
   **下一步**: 准备与OrchestratorAgent进行项目初始化
   ---
   ```

### **步骤3：激活OrchestratorAgent并导入文档**

1. **确保OrchestratorAgent已激活**：
   - 检查 `PromptX/bootstrap.md` 指向 `OrchestratorAgent.role.md`
   - 发送 "Action" 指令激活AI
   
2. **向OrchestratorAgent报告外部AI协作结果**：
   ```
   🎛️ OrchestratorAgent，我已完成外部AI协作阶段，生成了一份详细的产品需求文档。
   
   文档位置：project_docs/REQUIREMENTS/EXTERNAL_AI_PRODUCT_ANALYSIS.md
   
   这份文档包含了：
   - 产品名称：[从文档中提取]
   - 核心价值：[从文档中提取] 
   - 主要功能：[简要列举3-5个核心功能]
   - 技术栈建议：[从文档中提取]
   
   请你：
   1. 阅读并理解这份外部AI生成的需求文档
   2. 将关键信息更新到PROJECT_CONTEXT.md中
   3. 根据ACTION_PLAN_MASTER.md规划下一阶段的具体任务
   4. 开始指导项目的正式开发流程
   
   我们准备好进入需求细化和架构设计阶段。
   ```

---

## **2. OrchestratorAgent的预期处理流程**

当OrchestratorAgent收到上述报告后，它应该：

### **立即任务**：
1. **读取外部AI文档**并理解产品需求
2. **更新PROJECT_CONTEXT.md**：
   - 填充项目名称、核心目标、当前阶段等信息
   - 更新技术栈概要
   - 记录关键决策
3. **更新AI_AGENT_PROGRESS.md**：
   - 将"阶段0: 项目初始化"标记为完成
   - 规划"阶段1: 需求分析与定义"的具体任务

### **战略规划**：
1. **分析外部AI文档的完整性**，识别需要进一步细化的部分
2. **推荐下一阶段的专业AI角色**（通常是ProductOwnerAI）
3. **生成具体的任务列表**，遵循TASK_LIST_TEMPLATE.md格式

---

## **3. 常见问题处理**

### **外部AI文档不完整怎么办？**

如果外部AI生成的文档缺少关键信息：

1. **回到外部AI继续完善**：
   - 将缺失的部分列出
   - 返回外部AI Chat继续对话
   - 要求补充具体的缺失信息

2. **在项目内部补充**：
   - 告知OrchestratorAgent哪些信息不完整
   - 让它推荐合适的AI角色来补充（如ProductOwnerAI）

### **外部AI建议的技术栈不合适怎么办？**

1. **记录差异**：在向OrchestratorAgent报告时明确说明
   ```
   🎛️ OrchestratorAgent，外部AI建议使用[技术栈A]，但我倾向于使用[技术栈B]，因为[原因]。
   请在技术选型阶段重新评估。
   ```

2. **让SystemArchitectAI最终决定**：技术选型应该由专业的架构师AI来决定

### **如何确保信息的连续性？**

1. **保留完整的外部AI对话记录**：如果可能，将对话过程也保存在 `bak/` 目录中
2. **在PROJECT_CONTEXT.md中记录关键决策的来源**
3. **确保OrchestratorAgent了解哪些决策来自外部AI，哪些需要重新评估**

---

## **4. 集成后的验证清单**

完成外部AI文档集成后，请确认：

- [ ] `project_docs/REQUIREMENTS/EXTERNAL_AI_PRODUCT_ANALYSIS.md` 已创建并包含完整内容
- [ ] `PROJECT_CONTEXT.md` 已更新，包含项目基本信息
- [ ] `AI_AGENT_PROGRESS.md` 已更新项目进度
- [ ] OrchestratorAgent 已理解外部AI文档内容
- [ ] 已明确下一阶段的任务和负责的AI角色
- [ ] 关键的未决定事项已被识别并列入待办

---

## **5. 示例对话模板**

**成功集成的示例OrchestratorAgent回应**：
```
🎛️ 项目总指挥AI收到外部协作成果！

我已完成以下处理：

1. ✅ 阅读了外部AI生成的产品需求文档
2. ✅ 更新了PROJECT_CONTEXT.md，项目"[产品名称]"已正式启动
3. ✅ 识别了[X]个核心功能和[Y]个技术要求
4. ✅ 更新了项目进度，当前进入"需求细化"阶段

下一步建议：
我推荐切换到ProductOwnerAI角色来细化用户故事和功能规格。
请修改bootstrap.md指向：PromptX/domain/custom/ProductOwnerAI.role.md

切换后的初始指令：
"ProductOwnerAI，请基于project_docs/REQUIREMENTS/EXTERNAL_AI_PRODUCT_ANALYSIS.md中的需求，开始编写详细的功能规格说明书（FSD.md）和用户故事（USER_STORIES.md）。"
```

---

**通过这个流程，外部AI的产品构思成果将无缝集成到我们的专业开发环境中，确保项目的连续性和高质量的执行。** 