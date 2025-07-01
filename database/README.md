# Database Solutions

Field-tested database architecture patterns and solutions for AWS environments.

## 📚 Available Solutions

### 🔗 [Aurora PostgreSQL 跨数据库联表查询](./aurora-fdw-demo/)

**技术栈**: Aurora PostgreSQL + postgres_fdw + VPC + EC2  
**场景**: 微服务架构中的跨数据库实时查询和数据聚合  
**特性**: 
- 读写分离架构
- 实时跨数据库联表查询
- VPC内网优化
- 企业级安全配置

**适用场景**:
- 微服务数据聚合报表
- 跨业务域的实时数据分析
- 数据仓库ETL场景
- 混合云数据访问

---

## 🎯 解决方案特点

所有解决方案都经过实际验证，包含：
- ✅ **完整的基础设施代码** (Terraform)
- ✅ **详细的部署文档** 
- ✅ **实际测试验证**
- ✅ **性能分析报告**
- ✅ **最佳实践建议**
- ✅ **故障排除指南**

## 🚀 快速开始

每个解决方案都包含：
1. **README.md** - 完整的项目说明和架构介绍
2. **QUICK_START.md** - 快速操作指南
3. **terraform/** - 基础设施即代码
4. **scripts/** - 自动化脚本
5. **sql/** - 数据库脚本（如适用）

## 🤝 贡献

欢迎贡献新的数据库解决方案！请参考各项目的贡献指南。

---

*Solutions will be added as they are documented and validated.*
