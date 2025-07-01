#!/usr/bin/env python3
"""
Loki Chunk 到 AWS Macie 完整分析管道
工作流程:
1. 将Loki chunk文件转换为文本格式
2. 按时间日期分区上传到S3存储桶 your-scan-bucket/loki-complete/
3. 启动Macie分类作业
4. 等待扫描完成并分析结果
5. 结果存储在 your-results-bucket 存储桶
"""

import os
import json
import boto3
import time
import subprocess
from datetime import datetime, timezone
from pathlib import Path
import argparse
from typing import Dict, List, Any, Optional
import logging

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('loki_macie_pipeline.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class LokiMaciePipeline:
    def __init__(self, region=None, profile=None, config_file='config.json'):
        """初始化AWS客户端"""
        
        # 加载配置文件
        self.config = self.load_config(config_file)
        
        # 检查并引导用户配置
        self.interactive_config_setup()
        
        # 使用参数或配置文件中的设置
        self.region = region or self.config['aws']['region']
        self.profile = profile or self.config['aws']['profile']
        
        # 配置AWS会话
        session = boto3.Session(profile_name=self.profile) if self.profile else boto3.Session()
        self.s3_client = session.client('s3', region_name=self.region)
        self.macie_client = session.client('macie2', region_name=self.region)
        self.sts_client = session.client('sts', region_name=self.region)
        
        # S3存储桶配置 - 从配置文件读取
        self.scan_bucket = self.config['s3']['scan_bucket']
        self.results_bucket = self.config['s3']['results_bucket']
        self.s3_prefix = self.config['s3']['scan_prefix']
        
        # 获取账户信息
        try:
            self.account_id = self.sts_client.get_caller_identity()['Account']
            logger.info(f"当前AWS账户: {self.account_id}")
        except Exception as e:
            logger.error(f"获取账户ID失败: {e}")
            raise
            
        # 时间戳用于分区
        self.timestamp = datetime.now(timezone.utc)
        self.date_partition = self.timestamp.strftime('%Y/%m/%d')
        self.job_name = f"loki-analysis-{self.timestamp.strftime('%Y%m%d-%H%M%S')}"
    
    def interactive_config_setup(self):
        """交互式配置设置 - 加强版"""
        needs_config = False
        config_issues = []
        
        # 检查所有可能的默认值和问题
        if self.config['s3']['scan_bucket'] == 'your-macie-scan-bucket':
            needs_config = True
            config_issues.append("扫描存储桶使用默认值")
        
        if self.config['s3']['results_bucket'] == 'your-macie-results-bucket':
            needs_config = True
            config_issues.append("结果存储桶使用默认值")
        
        if not self.config['aws']['region'] or self.config['aws']['region'] == 'your-region':
            needs_config = True
            config_issues.append("AWS区域未设置或使用默认值")
        
        # 检查存储桶名称是否合理（避免测试名称）
        if 'test' in self.config['s3']['scan_bucket'].lower() or 'example' in self.config['s3']['scan_bucket'].lower():
            needs_config = True
            config_issues.append("扫描存储桶名称看起来像测试值")
        
        if 'test' in self.config['s3']['results_bucket'].lower() or 'example' in self.config['s3']['results_bucket'].lower():
            needs_config = True
            config_issues.append("结果存储桶名称看起来像测试值")
        
        if needs_config:
            print("\n" + "🚨" * 20)
            print("⚠️  配置检查失败 - 需要用户输入")
            print("🚨" * 20)
            print("\n发现以下配置问题:")
            for i, issue in enumerate(config_issues, 1):
                print(f"  {i}. {issue}")
            
            print(f"\n当前配置:")
            print(f"  AWS区域: {self.config['aws']['region']}")
            print(f"  扫描存储桶: {self.config['s3']['scan_bucket']}")
            print(f"  结果存储桶: {self.config['s3']['results_bucket']}")
            
            print("\n" + "="*60)
            print("🔧 请输入正确的配置信息")
            print("="*60)
            
            # 强制用户输入，不允许跳过
            self.force_user_input()
        else:
            print("✅ 配置检查通过")
    
    def force_user_input(self):
        """强制用户输入配置，不允许跳过"""
        max_attempts = 3
        
        # AWS区域配置
        for attempt in range(max_attempts):
            region_input = input(f"\n[必填] 请输入AWS区域 (如: us-east-1, ap-northeast-1): ").strip()
            if region_input and len(region_input) > 5:  # 基本验证
                self.config['aws']['region'] = region_input
                break
            else:
                print(f"❌ AWS区域不能为空且格式要正确 (剩余尝试: {max_attempts - attempt - 1})")
                if attempt == max_attempts - 1:
                    raise ValueError("AWS区域配置失败，程序退出")
        
        # 扫描存储桶配置
        for attempt in range(max_attempts):
            scan_bucket = input(f"\n[必填] 请输入扫描存储桶名称 (用于存储待分析文件): ").strip()
            if scan_bucket and len(scan_bucket) >= 3 and scan_bucket != 'your-macie-scan-bucket':
                # 验证存储桶名称格式
                if self.validate_bucket_name(scan_bucket):
                    self.config['s3']['scan_bucket'] = scan_bucket
                    break
                else:
                    print("❌ 存储桶名称格式不正确")
            else:
                print(f"❌ 扫描存储桶名称不能为空或使用默认值 (剩余尝试: {max_attempts - attempt - 1})")
                if attempt == max_attempts - 1:
                    raise ValueError("扫描存储桶配置失败，程序退出")
        
        # 结果存储桶配置
        for attempt in range(max_attempts):
            results_bucket = input(f"\n[必填] 请输入结果存储桶名称 (用于存储分析结果): ").strip()
            if results_bucket and len(results_bucket) >= 3 and results_bucket != 'your-macie-results-bucket':
                # 验证存储桶名称格式
                if self.validate_bucket_name(results_bucket):
                    # 确保两个存储桶不同
                    if results_bucket != self.config['s3']['scan_bucket']:
                        self.config['s3']['results_bucket'] = results_bucket
                        break
                    else:
                        print("❌ 结果存储桶不能与扫描存储桶相同")
                else:
                    print("❌ 存储桶名称格式不正确")
            else:
                print(f"❌ 结果存储桶名称不能为空或使用默认值 (剩余尝试: {max_attempts - attempt - 1})")
                if attempt == max_attempts - 1:
                    raise ValueError("结果存储桶配置失败，程序退出")
        
        # 可选：最大等待时间
        wait_input = input(f"\n[可选] 最大等待时间(分钟) (当前: {self.config['macie']['max_wait_minutes']}, 回车跳过): ").strip()
        if wait_input and wait_input.isdigit() and 1 <= int(wait_input) <= 300:
            self.config['macie']['max_wait_minutes'] = int(wait_input)
        
        # 确认配置
        print("\n" + "="*60)
        print("📋 请确认您的配置:")
        print("="*60)
        print(f"AWS区域: {self.config['aws']['region']}")
        print(f"扫描存储桶: {self.config['s3']['scan_bucket']}")
        print(f"结果存储桶: {self.config['s3']['results_bucket']}")
        print(f"最大等待时间: {self.config['macie']['max_wait_minutes']} 分钟")
        
        confirm = input("\n确认以上配置正确吗? (输入 'yes' 继续): ").strip().lower()
        if confirm != 'yes':
            print("❌ 用户取消配置，程序退出")
            raise ValueError("用户取消配置")
        
        # 保存配置
        self.save_config()
        print("\n✅ 配置已确认并保存")
    
    def validate_bucket_name(self, bucket_name):
        """验证S3存储桶名称格式"""
        import re
        
        # S3存储桶命名规则
        if len(bucket_name) < 3 or len(bucket_name) > 63:
            return False
        
        # 只能包含小写字母、数字和连字符
        if not re.match(r'^[a-z0-9.-]+$', bucket_name):
            return False
        
        # 不能以连字符开头或结尾
        if bucket_name.startswith('-') or bucket_name.endswith('-'):
            return False
        
        # 不能包含连续的点
        if '..' in bucket_name:
            return False
        
        return True
    
    def save_config(self):
        """保存配置到文件"""
        try:
            with open('config.json', 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2, ensure_ascii=False)
        except Exception as e:
            logger.error(f"保存配置文件失败: {e}")
            raise
    
    def load_config(self, config_file: str) -> Dict:
        """加载配置文件"""
        try:
            with open(config_file, 'r', encoding='utf-8') as f:
                config = json.load(f)
            logger.info(f"配置文件加载成功: {config_file}")
            return config
        except FileNotFoundError:
            logger.error(f"配置文件不存在: {config_file}")
            raise
        except json.JSONDecodeError as e:
            logger.error(f"配置文件格式错误: {e}")
            raise
        
    def extract_loki_chunks_to_text(self, chunk_dir: str, output_dir: str) -> List[str]:
        """
        将Loki chunk文件转换为文本格式
        """
        logger.info(f"开始提取Loki chunk文件: {chunk_dir}")
        
        chunk_path = Path(chunk_dir)
        output_path = Path(output_dir)
        output_path.mkdir(exist_ok=True)
        
        text_files = []
        
        # 获取所有chunk文件
        chunk_files = list(chunk_path.glob('*'))
        chunk_files = [f for f in chunk_files if f.is_file() and not f.name.startswith('.')]
        
        logger.info(f"找到 {len(chunk_files)} 个chunk文件")
        
        for chunk_file in chunk_files:
            try:
                logger.info(f"处理文件: {chunk_file.name}")
                
                # 使用chunks-inspect工具提取
                output_file = output_path / f"{chunk_file.name}.txt"
                
                # 运行chunks-inspect命令
                cmd = ['./chunks-inspect', '-l', str(chunk_file)]
                result = subprocess.run(cmd, capture_output=True, text=True, cwd='.')
                
                if result.returncode == 0:
                    # 保存提取的文本
                    with open(output_file, 'w', encoding='utf-8') as f:
                        f.write(f"# Loki Chunk File: {chunk_file.name}\n")
                        f.write(f"# Extracted at: {self.timestamp.isoformat()}\n")
                        f.write(f"# File size: {chunk_file.stat().st_size} bytes\n")
                        f.write("# " + "="*50 + "\n\n")
                        f.write(result.stdout)
                    
                    text_files.append(str(output_file))
                    logger.info(f"✅ 成功提取: {output_file.name}")
                else:
                    logger.error(f"❌ 提取失败 {chunk_file.name}: {result.stderr}")
                    
            except Exception as e:
                logger.error(f"处理文件 {chunk_file.name} 时出错: {e}")
                continue
        
        logger.info(f"提取完成，生成 {len(text_files)} 个文本文件")
        return text_files
    
    def upload_to_s3_with_partition(self, text_files: List[str]) -> List[str]:
        """
        按时间分区上传文件到S3
        """
        logger.info(f"开始上传文件到S3存储桶: {self.scan_bucket}")
        
        uploaded_keys = []
        
        for text_file in text_files:
            try:
                file_path = Path(text_file)
                
                # 构建S3键名，包含时间分区
                s3_key = f"{self.s3_prefix}/{self.date_partition}/{file_path.name}"
                
                # 上传文件
                self.s3_client.upload_file(
                    str(file_path),
                    self.scan_bucket,
                    s3_key,
                    ExtraArgs={
                        'Metadata': {
                            'source': 'loki-chunk',
                            'extraction-time': self.timestamp.isoformat(),
                            'pipeline-job': self.job_name
                        }
                    }
                )
                
                uploaded_keys.append(s3_key)
                logger.info(f"✅ 上传成功: s3://{self.scan_bucket}/{s3_key}")
                
            except Exception as e:
                logger.error(f"上传文件 {text_file} 失败: {e}")
                continue
        
        logger.info(f"上传完成，共上传 {len(uploaded_keys)} 个文件")
        return uploaded_keys
    
    def ensure_macie_enabled(self):
        """
        确保Macie服务已启用
        """
        try:
            # 检查Macie状态
            response = self.macie_client.get_macie_session()
            logger.info("✅ Macie服务已启用")
            return True
        except self.macie_client.exceptions.ResourceNotFoundException:
            logger.info("Macie服务未启用，正在启用...")
            try:
                self.macie_client.enable_macie(
                    findingPublishingFrequency='FIFTEEN_MINUTES'
                )
                logger.info("✅ Macie服务启用成功")
                return True
            except Exception as e:
                logger.error(f"启用Macie服务失败: {e}")
                return False
        except Exception as e:
            logger.error(f"检查Macie状态失败: {e}")
            return False
    
    def create_macie_job(self, s3_keys: List[str]) -> str:
        """
        创建Macie分类作业
        """
        logger.info(f"创建Macie分类作业: {self.job_name}")
        
        # 构建S3作业范围
        s3_job_definition = {
            'bucketDefinitions': [
                {
                    'accountId': self.account_id,
                    'buckets': [self.scan_bucket]
                }
            ],
            'scoping': {
                'includes': {
                    'and': [
                        {
                            'simpleScopeTerm': {
                                'comparator': 'STARTS_WITH',
                                'key': 'OBJECT_KEY',
                                'values': [f"{self.s3_prefix}/{self.date_partition}/"]
                            }
                        }
                    ]
                }
            }
        }
        
        try:
            response = self.macie_client.create_classification_job(
                name=self.job_name,
                description=f"Loki chunk文件敏感数据分析 - {self.timestamp.strftime('%Y-%m-%d %H:%M:%S')}",
                jobType='ONE_TIME',
                s3JobDefinition=s3_job_definition,
                samplingPercentage=100,  # 100%采样
                tags={
                    'Source': 'loki-chunks',
                    'Pipeline': 'loki-macie-pipeline',
                    'Date': self.date_partition.replace('/', '-')
                }
            )
            
            job_id = response['jobId']
            logger.info(f"✅ Macie作业创建成功: {job_id}")
            return job_id
            
        except Exception as e:
            logger.error(f"创建Macie作业失败: {e}")
            raise
    
    def wait_for_job_completion(self, job_id: str, max_wait_minutes: int = 60) -> Dict:
        """
        等待Macie作业完成
        """
        logger.info(f"等待Macie作业完成: {job_id}")
        logger.info(f"最大等待时间: {max_wait_minutes} 分钟")
        
        start_time = time.time()
        max_wait_seconds = max_wait_minutes * 60
        
        while True:
            try:
                response = self.macie_client.describe_classification_job(jobId=job_id)
                job_status = response['jobStatus']
                
                logger.info(f"作业状态: {job_status}")
                
                if job_status == 'COMPLETE':
                    logger.info("✅ Macie作业完成")
                    return response
                elif job_status in ['CANCELLED', 'USER_PAUSED']:
                    logger.warning(f"⚠️ 作业状态异常: {job_status}")
                    return response
                elif job_status == 'RUNNING':
                    # 显示进度信息
                    if 'statistics' in response:
                        stats = response['statistics']
                        logger.info(f"进度 - 已处理对象: {stats.get('approximateNumberOfObjectsToProcess', 0)}")
                
                # 检查超时
                elapsed = time.time() - start_time
                if elapsed > max_wait_seconds:
                    logger.warning(f"⚠️ 等待超时 ({max_wait_minutes} 分钟)")
                    return response
                
                # 等待30秒后再次检查
                time.sleep(30)
                
            except Exception as e:
                logger.error(f"检查作业状态失败: {e}")
                time.sleep(30)
                continue
    
    def analyze_macie_results(self, job_id: str) -> Dict:
        """
        分析Macie扫描结果
        """
        logger.info(f"分析Macie扫描结果: {job_id}")
        
        try:
            # 获取作业统计信息
            job_response = self.macie_client.describe_classification_job(jobId=job_id)
            
            # 获取发现的敏感数据
            findings_response = self.macie_client.list_findings(
                findingCriteria={
                    'criterion': {
                        'classificationDetails.jobId': {
                            'eq': [job_id]
                        }
                    }
                },
                maxResults=50
            )
            
            # 构建分析报告
            analysis_report = {
                'job_info': {
                    'job_id': job_id,
                    'job_name': self.job_name,
                    'status': job_response.get('jobStatus'),
                    'created_at': job_response.get('createdAt'),
                    'completed_at': job_response.get('lastRunTime')
                },
                'statistics': job_response.get('statistics', {}),
                'findings_summary': {
                    'total_findings': len(findings_response.get('findingIds', [])),
                    'finding_ids': findings_response.get('findingIds', [])
                },
                'scan_scope': {
                    'bucket': self.scan_bucket,
                    'prefix': f"{self.s3_prefix}/{self.date_partition}/",
                    'date_partition': self.date_partition
                }
            }
            
            # 如果有发现，获取详细信息
            if analysis_report['findings_summary']['total_findings'] > 0:
                detailed_findings = []
                for finding_id in analysis_report['findings_summary']['finding_ids'][:10]:  # 限制前10个
                    try:
                        finding_detail = self.macie_client.get_findings(findingIds=[finding_id])
                        detailed_findings.append(finding_detail['findings'][0])
                    except Exception as e:
                        logger.warning(f"获取发现详情失败 {finding_id}: {e}")
                
                analysis_report['detailed_findings'] = detailed_findings
            
            # 保存分析报告
            report_filename = f"macie_analysis_report_{self.timestamp.strftime('%Y%m%d_%H%M%S')}.json"
            with open(report_filename, 'w', encoding='utf-8') as f:
                json.dump(analysis_report, f, indent=2, default=str, ensure_ascii=False)
            
            logger.info(f"✅ 分析报告已保存: {report_filename}")
            
            # 上传报告到结果存储桶
            try:
                results_key = f"loki-analysis/{self.date_partition}/{report_filename}"
                self.s3_client.upload_file(
                    report_filename,
                    self.results_bucket,
                    results_key
                )
                logger.info(f"✅ 报告已上传到: s3://{self.results_bucket}/{results_key}")
            except Exception as e:
                logger.warning(f"上传报告到结果存储桶失败: {e}")
            
            return analysis_report
            
        except Exception as e:
            logger.error(f"分析Macie结果失败: {e}")
            raise
    
    def run_complete_pipeline(self, chunk_dir: str = './lokichunk', output_dir: str = './extracted_texts'):
        """
        运行完整的分析管道
        """
        logger.info("🚀 开始运行Loki Macie分析管道")
        logger.info(f"Chunk目录: {chunk_dir}")
        logger.info(f"输出目录: {output_dir}")
        logger.info(f"扫描存储桶: {self.scan_bucket}")
        logger.info(f"结果存储桶: {self.results_bucket}")
        logger.info(f"时间分区: {self.date_partition}")
        
        try:
            # 步骤1: 提取Loki chunk文件为文本
            logger.info("📝 步骤1: 提取Loki chunk文件")
            text_files = self.extract_loki_chunks_to_text(chunk_dir, output_dir)
            
            if not text_files:
                logger.error("❌ 没有成功提取任何文件，终止流程")
                return None
            
            # 步骤2: 上传到S3
            logger.info("☁️ 步骤2: 上传文件到S3")
            uploaded_keys = self.upload_to_s3_with_partition(text_files)
            
            if not uploaded_keys:
                logger.error("❌ 没有成功上传任何文件，终止流程")
                return None
            
            # 步骤3: 确保Macie已启用
            logger.info("🔍 步骤3: 检查Macie服务")
            if not self.ensure_macie_enabled():
                logger.error("❌ Macie服务启用失败，终止流程")
                return None
            
            # 步骤4: 创建Macie作业
            logger.info("⚙️ 步骤4: 创建Macie分类作业")
            job_id = self.create_macie_job(uploaded_keys)
            
            # 🎯 关键变更：获得job ID后直接返回命令行，不等待完成
            logger.info("✅ Macie作业创建成功！")
            
            # 生成分析命令
            analyze_command = f"python3 analyze_macie_results.py --job-id {job_id} --region {self.region}"
            if self.profile:
                analyze_command += f" --profile {self.profile}"
            
            # 打印结果摘要
            self.print_job_created_summary(job_id, analyze_command)
            
            return {
                'job_id': job_id,
                'analyze_command': analyze_command,
                'status': 'job_created'
            }
            
        except Exception as e:
            logger.error(f"❌ 管道执行失败: {e}")
            raise
    
    def print_job_created_summary(self, job_id: str, analyze_command: str):
        """
        打印作业创建成功的摘要
        """
        print("\n" + "="*60)
        print("🎉 MACIE 分析作业已创建成功！")
        print("="*60)
        
        print(f"📋 作业信息:")
        print(f"   作业ID: {job_id}")
        print(f"   作业名称: {self.job_name}")
        print(f"   创建时间: {self.timestamp.isoformat()}")
        
        print(f"\n📁 数据位置:")
        print(f"   扫描数据: s3://{self.scan_bucket}/{self.s3_prefix}/{self.date_partition}/")
        print(f"   结果存储: s3://{self.results_bucket}/loki-analysis/{self.date_partition}/")
        
        print(f"\n⏳ 作业状态:")
        print(f"   Macie正在后台分析数据...")
        print(f"   预计完成时间: {self.config['macie']['max_wait_minutes']} 分钟内")
        
        print(f"\n🔍 查看结果:")
        print(f"   等待几分钟后运行以下命令查看分析结果:")
        print(f"   {analyze_command}")
        
        print(f"\n📊 监控作业:")
        print(f"   AWS控制台: https://{self.region}.console.aws.amazon.com/macie/home?region={self.region}#/jobs")
        
        print("="*60)
    
    def print_pipeline_summary(self, analysis_report: Dict):
        """
        打印管道执行摘要
        """
        print("\n" + "="*60)
        print("🎯 LOKI MACIE 分析管道执行摘要")
        print("="*60)
        
        job_info = analysis_report.get('job_info', {})
        stats = analysis_report.get('statistics', {})
        findings = analysis_report.get('findings_summary', {})
        
        print(f"📋 作业信息:")
        print(f"   作业ID: {job_info.get('job_id')}")
        print(f"   作业名称: {job_info.get('job_name')}")
        print(f"   状态: {job_info.get('status')}")
        print(f"   创建时间: {job_info.get('created_at')}")
        
        print(f"\n📊 扫描统计:")
        print(f"   处理对象数: {stats.get('approximateNumberOfObjectsToProcess', 0)}")
        print(f"   已处理对象: {stats.get('approximateNumberOfObjectsProcessed', 0)}")
        
        print(f"\n🔍 发现摘要:")
        print(f"   敏感数据发现数: {findings.get('total_findings', 0)}")
        
        print(f"\n📁 存储位置:")
        print(f"   扫描数据: s3://{self.scan_bucket}/{self.s3_prefix}/{self.date_partition}/")
        print(f"   分析结果: s3://{self.results_bucket}/loki-analysis/{self.date_partition}/")
        
        print("="*60)

def main():
    parser = argparse.ArgumentParser(description='Loki Chunk到AWS Macie完整分析管道')
    parser.add_argument('--chunk-dir', help='Loki chunk文件目录 (默认从配置文件读取)')
    parser.add_argument('--output-dir', help='提取文本输出目录 (默认从配置文件读取)')
    parser.add_argument('--region', help='AWS区域 (默认从配置文件读取)')
    parser.add_argument('--profile', help='AWS配置文件名称 (默认从配置文件读取)')
    parser.add_argument('--max-wait', type=int, help='最大等待时间(分钟) (默认从配置文件读取)')
    parser.add_argument('--config', default='config.json', help='配置文件路径 (默认: config.json)')
    
    args = parser.parse_args()
    
    try:
        # 创建管道实例
        pipeline = LokiMaciePipeline(
            region=args.region, 
            profile=args.profile,
            config_file=args.config
        )
        
        # 从配置文件或参数获取设置
        chunk_dir = args.chunk_dir or pipeline.config['processing']['chunk_directory']
        output_dir = args.output_dir or pipeline.config['processing']['output_directory']
        
        # 运行完整管道
        result = pipeline.run_complete_pipeline(
            chunk_dir=chunk_dir,
            output_dir=output_dir
        )
        
        if result:
            print("\n✅ 管道执行成功完成！")
            return 0
        else:
            print("\n❌ 管道执行失败！")
            return 1
            
    except Exception as e:
        logger.error(f"管道执行异常: {e}")
        return 1

if __name__ == '__main__':
    exit(main())
