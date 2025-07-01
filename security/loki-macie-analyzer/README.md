# Loki Chunk 敏感数据分析工具

## 📖 项目背景

### AWS Macie 简介
Amazon Macie 是一项完全托管的数据安全和数据隐私服务，它使用机器学习和模式匹配来发现和保护您在 AWS 中的敏感数据。Macie 可以自动发现、分类和保护敏感数据，如个人身份信息 (PII)、财务数据、健康信息和凭证等。

**Macie 核心功能：**
- 🔍 **自动数据发现**：扫描 S3 存储桶中的数据
- 🏷️ **智能分类**：使用机器学习识别敏感数据类型
- 📊 **风险评估**：评估数据暴露风险并提供安全建议
- 🚨 **实时监控**：持续监控数据访问模式和异常行为
- 📋 **合规报告**：生成详细的合规性和安全报告

### Loki 数据块格式
Grafana Loki 是一个高效的日志聚合系统，专为云原生环境设计。Loki 采用独特的数据存储格式来优化日志查询性能：

**Loki 数据块特性：**
- 📦 **压缩存储**：日志数据块在压缩后以二进制格式存储
- 🎯 **高效检索**：Loki 设计了一种简单的格式来存储时间序列日志数据
- ⚡ **部分解压**：检索日志时只解压查询所需的部分，而不是整个块
- 🏗️ **灵活存储**：数据块可存储在 Amazon S3、GCS 或本地文件系统等对象存储中
- 📈 **可扩展性**：支持大规模日志数据的高效存储和查询

**数据块结构：**
```
Loki Chunk File
├── Metadata (JSON格式)
│   ├── UserID
│   ├── From/Through 时间戳
│   ├── Labels (标签信息)
│   └── Fingerprint
└── Compressed Data (Snappy/Gzip压缩)
    └── Log Lines (实际日志内容)
```

## 🎯 项目目标

本工具旨在将 Loki 的二进制数据块转换为可读文本格式，并利用 AWS Macie 的强大功能对日志数据进行敏感信息检测和分析，帮助组织：

- 🔒 识别日志中的敏感数据泄露风险
- 📋 满足数据保护合规要求
- 🛡️ 加强日志数据安全治理
- 📊 生成详细的安全分析报告

## 🏗️ 项目架构

### 数据流程
```
Loki Binary Chunks → 文本解析 → S3上传 → Macie扫描 → 敏感数据报告
       ↓                ↓         ↓         ↓           ↓
   lokichunk/    → extracted_texts/ → 分区存储 → 智能分析 → 详细报告
```

### 核心组件
1. **loki_macie_pipeline.py** - 完整的自动化分析管道
2. **analyze_macie_results.py** - Macie结果深度分析工具
3. **run_loki_analysis.sh** - 交互式运行脚本
4. **test_chunk_extraction.py** - Loki chunk文件解析测试工具
5. **test_pipeline.py** - 环境和配置测试工具
6. **install_chunks_inspect.sh** - chunks-inspect工具安装脚本
7. **config.json** - 配置文件（需要预先配置）

#### chunks-inspect工具
来源: https://github.com/grafana/loki/tree/main/cmd/chunks-inspect

用于解析Loki chunks并打印详细信息。需要自行使用 `go build` 编译。

## ⚙️ 配置说明

### 配置文件 (config.json)

在运行管道之前，**必须**先配置 `config.json` 文件：

```json
{
  "aws": {
    "region": "ap-northeast-1",
    "profile": null
  },
  "s3": {
    "scan_bucket": "your-macie-scan-bucket",
    "results_bucket": "your-macie-results-bucket", 
    "scan_prefix": "loki-complete",
    "results_prefix": "loki-analysis"
  },
  "macie": {
    "finding_publishing_frequency": "FIFTEEN_MINUTES",
    "sampling_percentage": 100,
    "max_wait_minutes": 60
  },
  "processing": {
    "chunk_directory": "./lokichunk",
    "output_directory": "./extracted_texts",
    "temp_directory": "./temp"
  },
  "logging": {
    "level": "INFO",
    "file_pattern": "loki_analysis_{timestamp}.log"
  }
}
```

### 配置参数详解

#### AWS 配置 (`aws`)
- **`region`**: AWS区域，必须与S3存储桶所在区域一致
- **`profile`**: AWS配置文件名称，null表示使用默认配置

#### S3 存储配置 (`s3`)
- **`scan_bucket`**: 🔴 **必须修改** - 用于存储待扫描文件的S3存储桶名称
- **`results_bucket`**: 🔴 **必须修改** - 用于存储Macie分析结果的S3存储桶名称
- **`scan_prefix`**: 扫描文件在S3中的前缀路径
- **`results_prefix`**: 结果文件在S3中的前缀路径

#### Macie 配置 (`macie`)
- **`finding_publishing_frequency`**: 发现结果发布频率
  - 可选值: `FIFTEEN_MINUTES`, `ONE_HOUR`, `SIX_HOURS`
- **`sampling_percentage`**: 采样百分比 (1-100)
- **`max_wait_minutes`**: 等待Macie作业完成的最大时间(分钟)

#### 处理配置 (`processing`)
- **`chunk_directory`**: Loki chunk文件目录
- **`output_directory`**: 文本提取输出目录
- **`temp_directory`**: 临时文件目录

#### 日志配置 (`logging`)
- **`level`**: 日志级别 (`DEBUG`, `INFO`, `WARNING`, `ERROR`)
- **`file_pattern`**: 日志文件命名模式

## 📦 大规模文件处理

当您的环境中每日产生大量的 Loki 文件时，可以使用 S3 清单功能自动获取文件列表并批量处理。

详细说明请参考：[大规模 Loki 文件处理指南](./lokichunk/README.md)

主要特性：
- 🗂️ **S3 清单集成** - 自动获取每日新增文件列表
- ⚡ **批量处理** - 支持并行处理大量文件
- 💰 **成本优化** - 智能采样和存储类别管理
- 📊 **监控告警** - CloudWatch 指标和 SNS 通知

## 🚀 快速开始

### 一键运行 (推荐)

使用交互式脚本，自动完成所有设置：

```bash
./run_loki_analysis.sh
```

脚本将自动引导您完成：
- ✅ 环境依赖检查 (Python, AWS CLI, boto3)
- ✅ chunks-inspect工具自动编译
- ✅ Loki chunk文件验证
- ✅ 交互式配置设置
- ✅ S3存储桶创建和验证
- ✅ AWS Macie服务检查
- ✅ 完整分析管道执行

### 手动安装 (高级用户)

#### 1. 环境准备

```bash
# 安装Python依赖
pip install boto3

# 配置AWS凭证
aws configure
```

### 2. 获取chunks-inspect工具

`chunks-inspect` 是Grafana Loki官方提供的数据块检查工具，用于解析Loki chunks并打印详细信息。

**工具地址**: https://github.com/grafana/loki/tree/main/cmd/chunks-inspect

**编译安装**:
```bash
# 方法1: 使用安装脚本 (推荐)
./install_chunks_inspect.sh

# 方法2: 手动编译
git clone https://github.com/grafana/loki.git
cd loki/cmd/chunks-inspect
go build
cp chunks-inspect /path/to/your/project/
chmod +x chunks-inspect

# 验证安装
./chunks-inspect -h
```

### 3. 配置文件设置

**🔴 重要：在运行之前必须修改配置文件**

```bash
# 复制并编辑配置文件
cp config.json config.json.backup
nano config.json

# 至少需要修改以下参数：
# - aws.region (设置为你的AWS区域)
# - s3.scan_bucket (设置为你的扫描存储桶)
# - s3.results_bucket (设置为你的结果存储桶)
```

### 3. 测试环境

```bash
# 运行环境测试
python3 test_pipeline.py
```

### 手动运行管道 (高级用户)

如果您希望手动控制每个步骤：

#### 步骤1: 测试文本提取
```bash
# 测试chunk文件解析
python3 test_chunk_extraction.py
```

#### 步骤2: 配置设置
```bash
# 编辑配置文件
nano config.json

# 必须修改的参数：
# - aws.region (设置为你的AWS区域)
# - s3.scan_bucket (设置为你的扫描存储桶)
# - s3.results_bucket (设置为你的结果存储桶)
```

#### 步骤3: 运行管道
```bash
# 使用配置文件运行
python3 loki_macie_pipeline.py --config config.json
```

#### 步骤4: 分析结果
```bash
# 分析特定作业结果
python3 analyze_macie_results.py \
    --job-id your-job-id \
    --region your-region \
    --output detailed_analysis.json
```

## 📋 详细使用说明

### Loki Chunk 文件解析

工具支持多种Loki数据块格式：

```bash
# 查看chunk文件基本信息
./chunks-inspect -l lokichunk/chunk-file

# 查看详细块信息
./chunks-inspect -b lokichunk/chunk-file

# 提取并保存块数据
./chunks-inspect -s lokichunk/chunk-file
```

### 文本提取验证

在运行完整管道前，建议先测试文本提取：

```bash
# 创建测试目录
mkdir -p test_extraction

# 手动测试提取
for file in lokichunk/*; do
    echo "处理文件: $(basename $file)"
    ./chunks-inspect -l "$file" > "test_extraction/$(basename $file).txt"
    echo "输出大小: $(wc -c < "test_extraction/$(basename $file).txt") 字节"
done
```

### S3存储结构

管道会按以下结构组织S3中的数据：

```
your-scan-bucket/
└── loki-complete/
    └── YYYY/MM/DD/
        ├── chunk-file-1.txt
        ├── chunk-file-2.txt
        └── ...

your-results-bucket/
└── loki-analysis/
    └── YYYY/MM/DD/
        ├── macie_analysis_report_*.json
        ├── detailed_analysis_*.json
        └── ...
```

## 🔧 故障排除

### 常见问题

1. **配置文件未修改**
   ```
   错误: 使用了默认的存储桶名称
   解决: 修改config.json中的scan_bucket和results_bucket
   ```

2. **区域不匹配**
   ```
   错误: bucket is in a different region
   解决: 确保config.json中的region与S3存储桶区域一致
   ```

3. **chunks-inspect工具问题**
   ```
   错误: chunks-inspect: command not found
   解决: 从 https://github.com/grafana/loki/tree/main/cmd/chunks-inspect 获取源码并编译
   
   错误: permission denied
   解决: chmod +x chunks-inspect
   ```

4. **AWS权限不足**
   ```
   错误: Access Denied
   解决: 确保AWS用户有Macie和S3的必要权限
   ```

### 调试模式

```bash
# 启用详细日志
export PYTHONPATH=.
python3 -c "
import logging
logging.basicConfig(level=logging.DEBUG)
from loki_macie_pipeline import LokiMaciePipeline
pipeline = LokiMaciePipeline()
pipeline.run_complete_pipeline()
"
```

## 🛡️ 安全最佳实践

### AWS权限配置

创建专用的IAM策略：

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "macie2:*",
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket",
                "s3:GetBucketLocation"
            ],
            "Resource": [
                "arn:aws:s3:::your-scan-bucket",
                "arn:aws:s3:::your-scan-bucket/*",
                "arn:aws:s3:::your-results-bucket", 
                "arn:aws:s3:::your-results-bucket/*"
            ]
        }
    ]
}
```

### 数据保护建议

1. **加密传输**: 所有S3操作使用HTTPS
2. **访问控制**: 限制S3存储桶访问权限
3. **审计日志**: 启用CloudTrail记录所有操作
4. **数据保留**: 设置合理的数据保留策略
5. **网络隔离**: 在VPC环境中运行分析

## 📊 输出文件说明

### 管道输出
- `loki_macie_pipeline.log` - 管道执行日志
- `extracted_texts/` - 提取的文本文件目录
- `macie_analysis_report_*.json` - 基础分析报告

### 详细分析输出
- `detailed_macie_analysis_*.json` - 详细JSON报告
- `detailed_macie_analysis_*_summary.txt` - 人类可读摘要
- S3中的完整结果文件

## 🌟 开源贡献

本项目采用开源方式分享，欢迎社区贡献：

### 依赖工具
- **chunks-inspect**: https://github.com/grafana/loki/tree/main/cmd/chunks-inspect

### 贡献指南
1. Fork 项目仓库
2. 创建功能分支
3. 提交代码更改
4. 创建 Pull Request

### 开发环境设置
```bash
# 克隆项目
git clone <repository-url>
cd loki-macie-analyzer

# 编译chunks-inspect工具
git clone https://github.com/grafana/loki.git
cd loki/cmd/chunks-inspect
go build
cp chunks-inspect ../../../
cd ../../../
chmod +x chunks-inspect

# 安装开发依赖
pip install boto3

# 运行测试
python3 test_chunk_extraction.py
```

## 📞 支持与反馈

### 项目结构
```
loki-macie-analyzer/
├── lokichunk/                    # Loki chunk文件目录 (用户放置文件)
├── loki_macie_pipeline.py       # 主管道脚本
├── analyze_macie_results.py     # 结果分析工具
├── run_loki_analysis.sh         # 交互式运行脚本
├── test_chunk_extraction.py     # 文件解析测试工具
├── test_pipeline.py             # 环境测试脚本
├── install_chunks_inspect.sh    # chunks-inspect安装脚本
├── config.json                  # 配置文件 (需要修改)
├── chunks-inspect               # Loki工具 (需要下载编译)
└── README.md                    # 本文档
```

**注意**: 
- `chunks-inspect` 需要从 https://github.com/grafana/loki/tree/main/cmd/chunks-inspect 获取源码并编译
- `lokichunk/` 目录需要用户放置自己的 Loki chunk 文件

### 版本信息
- **项目版本**: 1.0.0
- **支持的Loki版本**: 2.x
- **AWS Macie版本**: Macie2
- **Python版本**: 3.6+

---

🎯 **使命**: 为Loki日志数据提供企业级的敏感数据检测和分析解决方案  
🔒 **安全**: 遵循AWS安全最佳实践，保护敏感数据  
🌍 **开源**: 促进社区协作，共同改进数据安全工具
