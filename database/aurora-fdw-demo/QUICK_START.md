# 🚀 Aurora PostgreSQL FDW Demo 快速操作指南

## 📋 前置条件检查

✅ Aurora集群已部署（通过Terraform）  
✅ EC2跳板机已创建  
✅ PostgreSQL 14客户端已安装  

## 🔧 快速执行步骤

### 1️⃣ 获取连接信息

在terraform目录下执行：

```bash
# 获取EC2连接命令
terraform output ssm_connect_command

# 获取数据库连接信息
terraform output connection_info

# 获取环境变量设置命令（包含密码）
terraform output -json environment_setup_commands
```

### 2️⃣ 连接到跳板机

使用上一步获取的命令：

```bash
aws ssm start-session --target <your-instance-id> --region <your-region>
```

### 3️⃣ 设置环境变量

使用terraform输出的环境变量命令，或手动设置：

```bash
export PGPASSWORD='<your-database-password>'
export USERS_WRITER='<your-users-writer-endpoint>'
export USERS_READER='<your-users-reader-endpoint>'
export ORDERS_WRITER='<your-orders-writer-endpoint>'
```

### 4️⃣ 初始化用户数据库

```bash
# 连接到用户数据库写实例
psql -h $USERS_WRITER -U postgres -d usersdb
```

```sql
INSERT INTO users (username, email, first_name, last_name) VALUES ('john_doe', 'john.doe@example.com', 'John', 'Doe');
INSERT INTO users (username, email, first_name, last_name) VALUES ('jane_smith', 'jane.smith@example.com', 'Jane', 'Smith');
INSERT INTO users (username, email, first_name, last_name) VALUES ('bob_wilson', 'bob.wilson@example.com', 'Bob', 'Wilson');
INSERT INTO users (username, email, first_name, last_name) VALUES ('alice_brown', 'alice.brown@example.com', 'Alice', 'Brown');
INSERT INTO users (username, email, first_name, last_name) VALUES ('charlie_davis', 'charlie.davis@example.com', 'Charlie', 'Davis');
SELECT COUNT(*) FROM users;
\q
```

### 5️⃣ 初始化订单数据库

```bash
# 连接到订单数据库写实例
psql -h $ORDERS_WRITER -U postgres -d ordersdb
```

```sql
INSERT INTO orders (user_id, product_name, quantity, unit_price, total_amount, order_status) VALUES (1, 'Laptop Computer', 1, 999.99, 999.99, 'completed');
INSERT INTO orders (user_id, product_name, quantity, unit_price, total_amount, order_status) VALUES (1, 'Wireless Mouse', 2, 29.99, 59.98, 'completed');
INSERT INTO orders (user_id, product_name, quantity, unit_price, total_amount, order_status) VALUES (2, 'Smartphone', 1, 699.99, 699.99, 'pending');
INSERT INTO orders (user_id, product_name, quantity, unit_price, total_amount, order_status) VALUES (3, 'Tablet', 1, 399.99, 399.99, 'completed');
INSERT INTO orders (user_id, product_name, quantity, unit_price, total_amount, order_status) VALUES (4, 'Monitor', 2, 299.99, 599.98, 'completed');
INSERT INTO orders (user_id, product_name, quantity, unit_price, total_amount, order_status) VALUES (5, 'Headphones', 1, 149.99, 149.99, 'pending');
SELECT COUNT(*) FROM orders;
\q
```

### 6️⃣ 配置FDW（⚠️ 在写实例上）

```bash
# 连接到用户数据库写实例
psql -h $USERS_WRITER -U postgres -d usersdb
```

```sql
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE SERVER IF NOT EXISTS orders_server FOREIGN DATA WRAPPER postgres_fdw OPTIONS (host '$ORDERS_WRITER', port '5432', dbname 'ordersdb');
CREATE USER MAPPING IF NOT EXISTS FOR postgres SERVER orders_server OPTIONS (user 'postgres', password '$PGPASSWORD');
CREATE FOREIGN TABLE IF NOT EXISTS remote_orders (order_id INTEGER, user_id INTEGER, product_name VARCHAR(100), quantity INTEGER, unit_price DECIMAL(10,2), total_amount DECIMAL(10,2), order_status VARCHAR(20), order_date TIMESTAMP) SERVER orders_server OPTIONS (schema_name 'public', table_name 'orders');
SELECT 'FDW配置成功', COUNT(*) FROM remote_orders;
\q
```

**注意**: 在实际执行时，需要将上述SQL中的变量替换为实际值：
- 将 `$ORDERS_WRITER` 替换为实际的订单数据库端点
- 将 `$PGPASSWORD` 替换为实际的数据库密码

### 7️⃣ 测试跨库查询（在只读实例上）

```bash
# 连接到用户数据库只读实例
psql -h $USERS_READER -U postgres -d usersdb
```

#### 🔍 基本联表查询
```sql
SELECT u.username, u.first_name || ' ' || u.last_name as full_name, ro.product_name, ro.total_amount, ro.order_status FROM users u LEFT JOIN remote_orders ro ON u.user_id = ro.user_id ORDER BY u.user_id;
```

#### 📊 聚合统计查询
```sql
SELECT u.username, COUNT(ro.order_id) as total_orders, COALESCE(SUM(ro.total_amount), 0) as total_spent FROM users u LEFT JOIN remote_orders ro ON u.user_id = ro.user_id GROUP BY u.user_id, u.username ORDER BY total_spent DESC;
```

#### 🏆 客户分级查询
```sql
WITH customer_stats AS (SELECT u.user_id, u.username, u.email, COUNT(ro.order_id) as order_count, COALESCE(SUM(ro.total_amount), 0) as total_spent FROM users u LEFT JOIN remote_orders ro ON u.user_id = ro.user_id GROUP BY u.user_id, u.username, u.email) SELECT username, email, order_count, total_spent, CASE WHEN total_spent > 1000 THEN 'VIP' WHEN total_spent > 500 THEN 'Premium' WHEN total_spent > 100 THEN 'Regular' ELSE 'New' END as customer_tier FROM customer_stats ORDER BY total_spent DESC;
```

### 8️⃣ 🔥 实时数据验证实验

**目的**: 验证外部表能否实时获取源数据库的最新变化

#### 步骤A: 记录当前状态
在只读实例上查看john_doe的当前订单：
```sql
SELECT u.username, ro.product_name, ro.total_amount, ro.order_status FROM users u LEFT JOIN remote_orders ro ON u.user_id = ro.user_id WHERE u.username = 'john_doe';
```

#### 步骤B: 在源数据库添加新订单
**开启新终端窗口**，连接到订单数据库：
```bash
# 新终端窗口 - 设置环境变量
export PGPASSWORD='<your-database-password>'
export ORDERS_WRITER='<your-orders-writer-endpoint>'
psql -h $ORDERS_WRITER -U postgres -d ordersdb
```

插入新订单：
```sql
INSERT INTO orders (user_id, product_name, quantity, unit_price, total_amount, order_status) VALUES (1, 'Gaming Keyboard', 1, 129.99, 129.99, 'processing');
INSERT INTO orders (user_id, product_name, quantity, unit_price, total_amount, order_status) VALUES (1, 'Webcam HD', 1, 89.99, 89.99, 'shipped');
SELECT 'New orders added' as status;
\q
```

#### 步骤C: 立即验证实时性
**回到只读实例终端**，立即重新查询：
```sql
-- 应该能看到新增的订单
SELECT u.username, ro.product_name, ro.total_amount, ro.order_status FROM users u LEFT JOIN remote_orders ro ON u.user_id = ro.user_id WHERE u.username = 'john_doe' ORDER BY ro.order_date DESC;

-- 验证聚合数据也实时更新
SELECT u.username, COUNT(ro.order_id) as total_orders, SUM(ro.total_amount) as total_spent FROM users u LEFT JOIN remote_orders ro ON u.user_id = ro.user_id WHERE u.username = 'john_doe' GROUP BY u.username;
```

#### 步骤D: 测试数据修改
在订单数据库修改订单状态：
```bash
# 在订单数据库终端
psql -h $ORDERS_WRITER -U postgres -d ordersdb
```
```sql
UPDATE orders SET order_status = 'delivered' WHERE user_id = 1 AND product_name = 'Gaming Keyboard';
SELECT 'Order status updated' as status;
\q
```

立即在只读实例验证：
```sql
-- 应该看到状态已更新为 'delivered'
SELECT ro.product_name, ro.order_status FROM remote_orders ro WHERE ro.user_id = 1 AND ro.product_name = 'Gaming Keyboard';
```

### 9️⃣ ⚡ 性能压力测试

#### 测试A: 查看查询执行计划
```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) 
SELECT u.username, COUNT(ro.order_id) as order_count, SUM(ro.total_amount) as total_amount 
FROM users u LEFT JOIN remote_orders ro ON u.user_id = ro.user_id 
GROUP BY u.username;
```

#### 测试B: 并发查询测试
```sql
-- 执行多次相同查询，观察性能
\timing on
SELECT COUNT(*) FROM (SELECT u.username, ro.product_name FROM users u LEFT JOIN remote_orders ro ON u.user_id = ro.user_id) t;
SELECT COUNT(*) FROM (SELECT u.username, ro.product_name FROM users u LEFT JOIN remote_orders ro ON u.user_id = ro.user_id) t;
SELECT COUNT(*) FROM (SELECT u.username, ro.product_name FROM users u LEFT JOIN remote_orders ro ON u.user_id = ro.user_id) t;
\timing off
```

#### 测试C: 大数据量模拟
在订单数据库批量插入数据：
```bash
psql -h $ORDERS_WRITER -U postgres -d ordersdb
```
```sql
-- 批量插入测试数据
INSERT INTO orders (user_id, product_name, quantity, unit_price, total_amount, order_status) 
SELECT 
    (random() * 4 + 1)::int as user_id,
    'Test Product ' || generate_series as product_name,
    1 as quantity,
    (random() * 100 + 10)::decimal(10,2) as unit_price,
    (random() * 100 + 10)::decimal(10,2) as total_amount,
    CASE (random() * 3)::int WHEN 0 THEN 'pending' WHEN 1 THEN 'completed' ELSE 'shipped' END as order_status
FROM generate_series(1, 100);

SELECT 'Bulk test data inserted', COUNT(*) as total_orders FROM orders;
\q
```

在只读实例测试大数据量查询性能：
```sql
\timing on
SELECT u.username, COUNT(ro.order_id) as total_orders, AVG(ro.total_amount)::decimal(10,2) as avg_amount FROM users u LEFT JOIN remote_orders ro ON u.user_id = ro.user_id GROUP BY u.username ORDER BY total_orders DESC;
\timing off
```

## ✅ 验证成功标志

### 基础功能验证：
1. **用户数据**: 5个用户记录
2. **订单数据**: 初始6个订单记录  
3. **FDW连接**: 显示"FDW配置成功"和订单数量
4. **跨库查询**: 能看到用户和订单的联表结果

### 实时性验证：
5. **实时新增**: 新插入的订单立即在跨库查询中可见
6. **实时更新**: 订单状态修改立即反映在外部表查询中
7. **聚合实时**: 统计数据（订单数量、总金额）实时更新

### 性能验证：
8. **查询延迟**: 跨库查询响应时间 < 10ms（VPC内网优化）
9. **并发性能**: 多次查询性能稳定
10. **大数据量**: 100+订单的聚合查询性能良好

## 📊 性能压力分析

### 🔍 对数据库A（用户数据库）的影响：

#### 写实例压力：
- **FDW配置**: 一次性操作，无持续压力
- **元数据存储**: 外部表定义占用极少存储空间
- **连接管理**: postgres_fdw自动管理连接池，影响微乎其微

#### 只读实例压力：
- **查询负载**: ✅ **设计目标** - 所有跨库查询在只读实例执行
- **CPU使用**: 联表查询会增加CPU使用，但不影响写实例
- **内存消耗**: 查询缓存和连接缓存，正常范围内
- **网络带宽**: VPC内网传输，延迟低，带宽充足

### 🔍 对数据库B（订单数据库）的影响：

#### 写实例压力：
- **额外连接**: postgres_fdw会建立连接到订单数据库
- **查询负载**: 每次跨库查询都会在订单数据库执行SELECT
- **锁竞争**: 只读查询使用MVCC，不会阻塞写操作
- **资源消耗**: 增加少量CPU和内存使用

#### 网络影响：
- **连接数**: 每个FDW查询会占用1个数据库连接
- **数据传输**: 查询结果通过VPC内网传输，影响很小
- **连接复用**: postgres_fdw会复用连接，减少连接开销

### 📈 性能优化建议：

#### 1. 查询优化：
```sql
-- ✅ 好的做法：使用WHERE条件减少数据传输
SELECT u.username, ro.product_name FROM users u 
LEFT JOIN remote_orders ro ON u.user_id = ro.user_id 
WHERE u.user_id <= 10;

-- ❌ 避免：无条件的大表JOIN
SELECT * FROM users u LEFT JOIN remote_orders ro ON u.user_id = ro.user_id;
```

#### 2. 索引优化：
```sql
-- 在订单数据库创建索引优化跨库查询
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status_date ON orders(order_status, order_date);
```

#### 3. 连接池配置：
- 设置合理的`max_connections`
- 配置连接超时参数
- 监控连接使用情况

### ⚠️ 注意事项：

1. **高并发场景**: 大量并发跨库查询可能对订单数据库造成压力
2. **大数据量**: 避免无条件查询大表，使用分页和过滤条件
3. **网络延迟**: 虽然是VPC内网，但仍有1-2ms延迟，避免频繁小查询
4. **事务一致性**: 跨库查询不支持分布式事务，注意数据一致性

### 🎯 最佳实践：

1. **读写分离**: ✅ 聚合查询在只读实例执行
2. **索引优化**: ✅ 在关联字段创建索引
3. **查询优化**: ✅ 使用WHERE条件限制数据量
4. **监控告警**: ✅ 监控跨库查询性能和连接数
5. **缓存策略**: 考虑在应用层缓存频繁查询的结果

## 🧹 完成后清理
```bash
cd terraform && terraform destroy
```

## 🆘 常见问题

**Q: 如何获取数据库连接信息？**  
A: 使用 `terraform output connection_info` 获取所有连接端点

**Q: 忘记数据库密码？**  
A: 使用 `terraform output database_password` 查看（敏感输出）

**Q: 只读实例无法创建FDW？**  
A: FDW配置必须在写实例上执行，然后在只读实例上查询

**Q: 实时数据不更新？**  
A: postgres_fdw是实时的，检查网络连接和权限配置

**Q: 查询性能慢？**  
A: 检查索引、网络延迟，避免大表无条件JOIN

**Q: 对生产环境影响？**  
A: 合理使用，配置连接池，监控资源使用情况

---
🎯 **目标**: 演示Aurora PostgreSQL跨数据库实时联表查询能力  
⏱️ **预计时间**: 15-20分钟（含实时验证实验）  
🏗️ **架构**: 读写分离 + postgres_fdw + VPC内网优化 + 实时数据同步  
📊 **验证**: 功能性 + 实时性 + 性能压力测试
