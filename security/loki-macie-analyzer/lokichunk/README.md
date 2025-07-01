# 大规模 Loki 文件处理指南

## 📦 场景说明

当您的环境中每日产生大量的 Loki 文件存储在 S3 中时，手动管理这些文件变得不现实。本指南介绍如何通过 S3 清单功能自动获取每日新增的 Loki 文件列表，实现大规模自动化处理。

## 🗂️ S3 清单配置

Amazon S3 清单功能可以定期生成存储桶中对象的报告，非常适合跟踪每日新增的 Loki 文件。

### 配置步骤

**⚠️ 注意**: Amazon S3 交付第一份清单报告可能需要长达 48 小时。

1. **登录 AWS 控制台**
   - 访问 [Amazon S3 控制台](https://console.aws.amazon.com/s3/)

2. **选择源存储桶**
   - 在左侧导航窗格中，选择"通用存储桶"
   - 在存储桶列表中，选择包含 Loki 文件的存储桶

3. **创建清单配置**
   - 选择"管理"选项卡
   - 在"Inventory configurations (清单配置)"下，选择"Create inventory configuration (创建清单配置)"

4. **配置参数**
   ```
   清单配置名称: loki-daily-inventory
   
   清单范围:
   - 前缀: loki/chunks/ (可选，用于过滤 Loki 文件)
   - 对象版本: 仅当前版本
   
   报告详细信息:
   - 报告保存位置: 此账户
   - 目标存储桶: your-inventory-bucket
   - 目标前缀: inventory-reports/loki/
   
   频率: 每日
   
   输出格式:
   - 格式: CSV
   - 压缩: Gzip (推荐)
   ```

### 清单报告结构

生成的清单报告将包含以下信息：
```csv
Bucket,Key,Size,LastModifiedDate,ETag,StorageClass
your-loki-bucket,loki/chunks/2024/01/15/chunk-001.gz,1024,2024-01-15T10:30:00.000Z,abc123,STANDARD
your-loki-bucket,loki/chunks/2024/01/15/chunk-002.gz,2048,2024-01-15T11:45:00.000Z,def456,STANDARD
```

## 🔄 使用 S3 清单获取文件列表

### 清单处理脚本

创建 `process_daily_inventory.sh` 脚本来处理 S3 清单报告：

```bash
#!/bin/bash
# 获取最新清单报告并生成当日新增的 Loki 文件列表

INVENTORY_BUCKET="your-inventory-bucket"
INVENTORY_PREFIX="inventory-reports/loki"

# 获取最新的清单报告
aws s3 ls s3://${INVENTORY_BUCKET}/${INVENTORY_PREFIX}/ --recursive | \
    grep "manifest.json" | sort -k1,2 | tail -1 | awk '{print $4}' > latest_manifest.txt

# 下载并解析清单
MANIFEST_KEY=$(cat latest_manifest.txt)
aws s3 cp s3://${INVENTORY_BUCKET}/${MANIFEST_KEY} manifest.json
INVENTORY_FILE=$(jq -r '.files[0].key' manifest.json)

# 下载清单数据文件
aws s3 cp s3://${INVENTORY_BUCKET}/${INVENTORY_FILE} inventory.csv.gz
gunzip inventory.csv.gz

# 过滤今日新增的文件
TODAY=$(date +%Y-%m-%d)
grep "$TODAY" inventory.csv | cut -d',' -f2 > today_loki_files.txt

echo "今日新增 Loki 文件数量: $(wc -l < today_loki_files.txt)"
```

生成的 `today_loki_files.txt` 文件可以直接输入到 Loki Macie 分析管道中进行批量处理。

## 📊 处理建议

### Macie 大规模处理能力
AWS Macie 本身就具备处理大量文件的能力，可以：
- 自动扫描整个 S3 存储桶或指定前缀
- 并行处理数千个文件
- 智能采样以控制成本
- 生成统一的分析报告

### 最佳实践
- **直接扫描** - 让 Macie 直接扫描 S3 中的 Loki 文件，无需预先下载
- **合理采样** - 根据数据量设置适当的采样百分比
- **分区存储** - 按日期组织 S3 中的文件结构，便于增量处理

## 💰 成本优化

### Macie 成本控制
- 合理设置采样百分比（建议 5-20%）
- 使用 S3 前缀过滤，只扫描相关文件
- 避免重复扫描已处理的文件

### S3 存储优化
- 配置生命周期策略，自动转换存储类别
- 30天后转为 Standard-IA，90天后转为 Glacier

## 📈 监控建议

### CloudWatch 指标
- 监控 Macie 作业状态和完成情况
- 跟踪发现的敏感数据数量和类型

### 成本控制
- 合理设置 Macie 采样百分比
- 配置 S3 生命周期策略优化存储成本

## 🔗 相关文档

- [S3 清单配置官方文档](https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/userguide/configure-inventory.html)
- [AWS Macie 定价](https://aws.amazon.com/macie/pricing/)
- [S3 生命周期管理](https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
