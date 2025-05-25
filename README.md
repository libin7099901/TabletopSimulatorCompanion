# 🎲 桌游伴侣 (Tabletop Companion)

**版本**: 3.0.0  
**文件**: `TabletopCompanion.ttslua`  
**更新日期**: 2025年5月

## 📁 使用文件

**✅ 正确文件**: `TabletopCompanion.ttslua`  
**❌ 忽略**: 其他所有版本文件

## 🔧 已修复的问题

1. **UI位置**: 右移80像素避开竖直工具栏
2. **字符编码**: 完全移除Lua模式匹配，使用安全字符串函数
3. **Ollama API**: 使用2025年最新API格式
4. **命令检测**: 正确的`tc`和`@tc`命令识别
5. **瞬间启动**: 无延迟初始化

## 🚀 快速开始

1. 确保Ollama运行: `ollama serve`
2. 拉取模型: `ollama pull gemma3:12b`
3. 在TTS中加载: `TabletopCompanion.ttslua`
4. 配置: `tc config ollama http://localhost:11434 gemma3:12b`
5. 测试: `tc test`
6. 使用: `@tc 这个游戏的规则是什么？`

## 📝 命令列表

- `tc help` - 显示帮助
- `tc status` - 显示状态  
- `tc test` - 测试连接
- `tc config ollama <URL> <模型>` - 配置Ollama
- `@tc <问题>` - 向AI提问

## 🎯 特性

- ✅ 完全防崩溃设计
- ✅ UI最小化/恢复功能
- ✅ 2025年Ollama API支持
- ✅ 状态保存/恢复
- ✅ 详细调试日志 