# 项目自定义验证规则

**创建时间**: [填入创建时间]  
**项目名称**: [填入项目名称]  
**维护者**: [填入维护者]  
**说明**: 本文件定义了项目特定的质量门控和验证要求，OrchestratorAgent会自动读取并执行这些规则。

---

## 阶段门控规则

### 需求分析阶段 (REQUIREMENTS_ANALYSIS)
**任务生成后必须满足**:
- [ ] 必须包含用户验收测试计划
- [ ] 每个功能必须有对应的用户故事
- [ ] 必须定义明确的成功指标和KPI
- [ ] 需要包含非功能性需求分析

**阶段完成前必须验证**:
- [ ] 所有用户故事都经过利益相关者确认
- [ ] 需求优先级已明确定义
- [ ] 验收标准清晰可测试

### 设计阶段 (DESIGN)
**任务生成后必须满足**:
- [ ] API设计必须包含完整的错误处理规范
- [ ] 数据库设计必须考虑性能优化和扩展性
- [ ] UI设计必须符合无障碍访问标准(WCAG 2.1)
- [ ] 必须包含系统架构的安全性设计

**阶段完成前必须验证**:
- [ ] 架构设计与需求文档的完全对应关系
- [ ] 技术选型的合理性评估完成
- [ ] 性能目标和监控指标已定义

### 开发阶段 (DEVELOPMENT)
**任务生成后必须满足**:
- [ ] 所有公共API必须有完整的文档注释
- [ ] 代码覆盖率目标不得低于80%
- [ ] 必须包含完整的集成测试计划
- [ ] 错误处理和日志记录规范明确

**阶段完成前必须验证**:
- [ ] 代码审查已完成且问题已解决
- [ ] 单元测试和集成测试全部通过
- [ ] 代码符合团队编码规范
- [ ] 安全漏洞扫描已完成

### 测试阶段 (TESTING)
**任务生成后必须满足**:
- [ ] 测试用例必须覆盖所有用户故事
- [ ] 必须包含性能测试和压力测试
- [ ] 必须包含安全测试和渗透测试
- [ ] 用户验收测试计划已准备

**阶段完成前必须验证**:
- [ ] 所有测试用例执行完成
- [ ] 缺陷修复率达到要求标准
- [ ] 性能指标满足需求文档要求
- [ ] 用户验收测试通过

### 部署阶段 (DEPLOYMENT)
**任务生成后必须满足**:
- [ ] 部署脚本必须包含回滚机制
- [ ] 必须有完整的监控和告警配置
- [ ] 数据迁移脚本经过充分测试
- [ ] 备份和恢复方案已验证

**阶段完成前必须验证**:
- [ ] 生产环境部署成功
- [ ] 监控系统正常运行
- [ ] 用户手册和运维文档完整
- [ ] 灾难恢复方案已测试

---

## 文档参考强制要求

### ProductOwnerAI必须参考：
- `project_docs/REQUIREMENTS/EXTERNAL_AI_PRODUCT_ANALYSIS.md` (如存在)
- `project_docs/PROJECT_CONTEXT.md`
- `project_docs/ACTION_PLAN_MASTER.md`

### SystemArchitectAI必须参考：
- `project_docs/REQUIREMENTS/FSD.md`
- `project_docs/REQUIREMENTS/NON_FUNCTIONAL_REQUIREMENTS.md`
- `project_docs/PROJECT_CONTEXT.md`

### DeveloperAI必须参考：
- `project_docs/REQUIREMENTS/FSD.md`
- `project_docs/ARCHITECTURE_AND_DESIGN/SYSTEM_ARCHITECTURE.md`
- `project_docs/ARCHITECTURE_AND_DESIGN/API_DOCUMENTATION.md`
- `project_docs/ARCHITECTURE_AND_DESIGN/DATA_MODEL.md`

### TesterAI必须参考：
- `project_docs/REQUIREMENTS/USER_STORIES.md`
- `project_docs/REQUIREMENTS/NON_FUNCTIONAL_REQUIREMENTS.md`
- `project_docs/ARCHITECTURE_AND_DESIGN/API_DOCUMENTATION.md`

### DevOpsAI必须参考：
- `project_docs/ARCHITECTURE_AND_DESIGN/SYSTEM_ARCHITECTURE.md`
- `project_docs/deployment/DEPLOYMENT_GUIDE.md`
- `project_docs/PROJECT_CONTEXT.md`

---

## 质量检查清单

### 代码质量标准
- [ ] 遵循项目编码规范 (命名、注释、结构)
- [ ] 没有硬编码的配置信息或敏感数据
- [ ] 有适当的错误处理和异常管理
- [ ] 日志记录完整且级别合理
- [ ] 代码复用性良好，避免重复代码
- [ ] 性能考虑：无明显的性能瓶颈

### 文档质量标准
- [ ] 所有公共API有使用示例和错误码说明
- [ ] 部署文档包含详细的回滚步骤
- [ ] 用户手册经过非技术人员验证和确认
- [ ] 技术文档的版本与代码版本保持同步
- [ ] 文档中的链接和引用全部有效
- [ ] 关键决策有记录和追溯能力

### 安全性要求
- [ ] 输入验证和输出编码已实现
- [ ] 身份认证和授权机制正确
- [ ] 敏感数据加密存储和传输
- [ ] SQL注入、XSS等常见漏洞已防护
- [ ] 日志中不包含敏感信息
- [ ] 第三方依赖安全漏洞已检查

### 性能要求
- [ ] 关键接口响应时间满足需求 (如 < 500ms)
- [ ] 数据库查询优化，避免N+1查询
- [ ] 缓存策略合理有效
- [ ] 资源使用优化 (内存、CPU、网络)
- [ ] 并发处理能力满足预期负载
- [ ] 错误重试和熔断机制完善

---

## 项目特定规则

### [根据项目特点添加特定规则]
**示例 - 电商项目特定规则**:
- [ ] 所有价格计算必须使用高精度数值类型
- [ ] 订单状态变更必须有完整的审计日志
- [ ] 支付相关接口必须有双重验证
- [ ] 库存操作必须支持事务回滚

### [根据团队要求添加协作规则]
**示例 - 团队协作规则**:
- [ ] 代码提交必须包含详细的commit message
- [ ] 功能分支命名遵循约定格式
- [ ] 重要决策必须在团队会议中讨论确认
- [ ] 技术债务必须记录在专门的跟踪文档中

---

## 使用说明

1.  **`OrchestratorAgent` 会在项目早期（如需求深化阶段）主动询问您是否需要配置此类规则，并会在其整个生命周期中自动检测、读取并强制应用本文件 (`project_docs/custom_validation_rules.md`) 中的规则。**
2.  **其他专业AI角色在执行任务和进行自我评估时，也会被引导参考本文件中的相关规则。**
3.  请根据您的项目具体需求定制这些规则：可以复制本模板到 `project_docs/custom_validation_rules.md`，然后删除不适用的示例，添加项目特定的要求。
4.  建议定期审查和更新这些规则，确保它们与项目的进展和目标保持一致。
5.  确保团队成员（包括您自己作为与AI协作的用户）都了解这些规则，以便形成统一的质量标准和期望。

---

**注意**: 这些规则是对标准开发流程和 [`project_docs/AI_STAGE_VALIDATION_GUIDE.md`](../project_docs/AI_STAGE_VALIDATION_GUIDE.md) 中定义的AI验证规范的补充和具体化，不会取代基本的软件工程最佳实践。 