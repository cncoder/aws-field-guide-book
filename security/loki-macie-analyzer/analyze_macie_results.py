#!/usr/bin/env python3
"""
AWS Macie结果分析工具
用于深度分析Macie扫描结果并生成详细报告
"""

import json
import boto3
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class MacieResultsAnalyzer:
    def __init__(self, region='us-east-1', profile=None):
        """初始化AWS客户端"""
        session = boto3.Session(profile_name=profile) if profile else boto3.Session()
        self.macie_client = session.client('macie2', region_name=region)
        self.s3_client = session.client('s3', region_name=region)
        self.region = region
        
    def get_job_findings(self, job_id: str) -> List[Dict]:
        """获取指定作业的所有发现"""
        logger.info(f"获取作业发现: {job_id}")
        
        findings = []
        paginator = self.macie_client.get_paginator('list_findings')
        
        try:
            page_iterator = paginator.paginate(
                findingCriteria={
                    'criterion': {
                        'classificationDetails.jobId': {
                            'eq': [job_id]
                        }
                    }
                }
            )
            
            for page in page_iterator:
                finding_ids = page.get('findingIds', [])
                
                if finding_ids:
                    # 批量获取发现详情
                    findings_response = self.macie_client.get_findings(findingIds=finding_ids)
                    findings.extend(findings_response.get('findings', []))
            
            logger.info(f"获取到 {len(findings)} 个发现")
            return findings
            
        except Exception as e:
            logger.error(f"获取发现失败: {e}")
            return []
    
    def analyze_sensitive_data_types(self, findings: List[Dict]) -> Dict:
        """分析敏感数据类型分布"""
        data_types = {}
        severity_counts = {'HIGH': 0, 'MEDIUM': 0, 'LOW': 0}
        
        for finding in findings:
            # 分析严重程度
            severity = finding.get('severity', {}).get('description', 'UNKNOWN')
            if severity in severity_counts:
                severity_counts[severity] += 1
            
            # 分析敏感数据类型
            classification_details = finding.get('classificationDetails', {})
            result = classification_details.get('result', {})
            
            if 'sensitiveData' in result:
                for sensitive_data in result['sensitiveData']:
                    category = sensitive_data.get('category', 'UNKNOWN')
                    detections = sensitive_data.get('detections', [])
                    
                    if category not in data_types:
                        data_types[category] = {
                            'count': 0,
                            'types': {},
                            'total_occurrences': 0
                        }
                    
                    data_types[category]['count'] += 1
                    
                    for detection in detections:
                        detection_type = detection.get('type', 'UNKNOWN')
                        occurrences = detection.get('count', 1)
                        
                        if detection_type not in data_types[category]['types']:
                            data_types[category]['types'][detection_type] = 0
                        
                        data_types[category]['types'][detection_type] += occurrences
                        data_types[category]['total_occurrences'] += occurrences
        
        return {
            'data_types': data_types,
            'severity_distribution': severity_counts,
            'total_findings': len(findings)
        }
    
    def analyze_file_distribution(self, findings: List[Dict]) -> Dict:
        """分析文件分布情况"""
        file_stats = {}
        
        for finding in findings:
            resources = finding.get('resources', [])
            
            for resource in resources:
                if resource.get('resourcesAffected', {}).get('s3Object'):
                    s3_obj = resource['resourcesAffected']['s3Object']
                    bucket_name = s3_obj.get('bucketName', 'UNKNOWN')
                    key = s3_obj.get('key', 'UNKNOWN')
                    
                    if bucket_name not in file_stats:
                        file_stats[bucket_name] = {}
                    
                    if key not in file_stats[bucket_name]:
                        file_stats[bucket_name][key] = {
                            'findings_count': 0,
                            'size': s3_obj.get('size', 0),
                            'last_modified': s3_obj.get('lastModified'),
                            'storage_class': s3_obj.get('storageClass', 'UNKNOWN')
                        }
                    
                    file_stats[bucket_name][key]['findings_count'] += 1
        
        return file_stats
    
    def generate_detailed_report(self, job_id: str, output_file: str = None) -> Dict:
        """生成详细的分析报告"""
        logger.info(f"生成详细报告: {job_id}")
        
        # 获取作业信息
        try:
            job_info = self.macie_client.describe_classification_job(jobId=job_id)
        except Exception as e:
            logger.error(f"获取作业信息失败: {e}")
            return {}
        
        # 获取发现
        findings = self.get_job_findings(job_id)
        
        # 分析数据
        sensitive_analysis = self.analyze_sensitive_data_types(findings)
        file_analysis = self.analyze_file_distribution(findings)
        
        # 构建报告
        report = {
            'report_metadata': {
                'generated_at': datetime.now().isoformat(),
                'job_id': job_id,
                'analyzer_version': '1.0.0'
            },
            'job_summary': {
                'name': job_info.get('name'),
                'status': job_info.get('jobStatus'),
                'created_at': str(job_info.get('createdAt')),
                'completed_at': str(job_info.get('lastRunTime')),
                'statistics': job_info.get('statistics', {})
            },
            'findings_analysis': sensitive_analysis,
            'file_distribution': file_analysis,
            'detailed_findings': findings[:20] if len(findings) > 20 else findings,  # 限制详细发现数量
            'recommendations': self.generate_recommendations(sensitive_analysis, file_analysis)
        }
        
        # 保存报告
        if not output_file:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            output_file = f"detailed_macie_analysis_{timestamp}.json"
        
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, default=str, ensure_ascii=False)
        
        logger.info(f"详细报告已保存: {output_file}")
        
        # 生成人类可读的摘要
        self.generate_human_readable_summary(report, output_file.replace('.json', '_summary.txt'))
        
        return report
    
    def generate_recommendations(self, sensitive_analysis: Dict, file_analysis: Dict) -> List[str]:
        """生成安全建议"""
        recommendations = []
        
        data_types = sensitive_analysis.get('data_types', {})
        severity_dist = sensitive_analysis.get('severity_distribution', {})
        
        # 基于发现的敏感数据类型给出建议
        if 'PII' in data_types:
            recommendations.append("发现个人身份信息(PII)，建议实施数据脱敏或加密存储")
        
        if 'FINANCIAL_INFORMATION' in data_types:
            recommendations.append("发现财务信息，建议加强访问控制和审计日志")
        
        if 'CREDENTIALS' in data_types:
            recommendations.append("发现凭证信息，建议立即轮换相关密钥并加强密钥管理")
        
        # 基于严重程度给出建议
        if severity_dist.get('HIGH', 0) > 0:
            recommendations.append(f"发现 {severity_dist['HIGH']} 个高风险项，建议优先处理")
        
        if severity_dist.get('MEDIUM', 0) > 10:
            recommendations.append("中等风险项较多，建议制定批量处理计划")
        
        # 基于文件分布给出建议
        total_files = sum(len(files) for files in file_analysis.values())
        if total_files > 50:
            recommendations.append("涉及文件较多，建议实施自动化数据分类和保护策略")
        
        if not recommendations:
            recommendations.append("未发现明显的敏感数据，建议定期重新扫描以确保持续合规")
        
        return recommendations
    
    def generate_human_readable_summary(self, report: Dict, output_file: str):
        """生成人类可读的摘要报告"""
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write("LOKI CHUNK 敏感数据分析报告\n")
            f.write("=" * 50 + "\n\n")
            
            # 作业摘要
            job_summary = report['job_summary']
            f.write(f"作业名称: {job_summary.get('name')}\n")
            f.write(f"作业状态: {job_summary.get('status')}\n")
            f.write(f"创建时间: {job_summary.get('created_at')}\n")
            f.write(f"完成时间: {job_summary.get('completed_at')}\n\n")
            
            # 统计信息
            stats = job_summary.get('statistics', {})
            f.write("扫描统计:\n")
            f.write(f"  处理对象数: {stats.get('approximateNumberOfObjectsToProcess', 0)}\n")
            f.write(f"  已处理对象: {stats.get('approximateNumberOfObjectsProcessed', 0)}\n\n")
            
            # 发现摘要
            findings_analysis = report['findings_analysis']
            f.write(f"发现摘要:\n")
            f.write(f"  总发现数: {findings_analysis.get('total_findings', 0)}\n")
            
            severity_dist = findings_analysis.get('severity_distribution', {})
            f.write(f"  高风险: {severity_dist.get('HIGH', 0)}\n")
            f.write(f"  中风险: {severity_dist.get('MEDIUM', 0)}\n")
            f.write(f"  低风险: {severity_dist.get('LOW', 0)}\n\n")
            
            # 敏感数据类型
            data_types = findings_analysis.get('data_types', {})
            if data_types:
                f.write("发现的敏感数据类型:\n")
                for category, info in data_types.items():
                    f.write(f"  {category}: {info['count']} 个发现, {info['total_occurrences']} 次出现\n")
                    for data_type, count in info['types'].items():
                        f.write(f"    - {data_type}: {count} 次\n")
                f.write("\n")
            
            # 建议
            recommendations = report.get('recommendations', [])
            if recommendations:
                f.write("安全建议:\n")
                for i, rec in enumerate(recommendations, 1):
                    f.write(f"  {i}. {rec}\n")
        
        logger.info(f"摘要报告已保存: {output_file}")

def main():
    parser = argparse.ArgumentParser(description='AWS Macie结果分析工具')
    parser.add_argument('--job-id', required=True, help='Macie作业ID')
    parser.add_argument('--output', help='输出文件名')
    parser.add_argument('--region', default='us-east-1', help='AWS区域')
    parser.add_argument('--profile', help='AWS配置文件名称')
    
    args = parser.parse_args()
    
    try:
        analyzer = MacieResultsAnalyzer(region=args.region, profile=args.profile)
        report = analyzer.generate_detailed_report(args.job_id, args.output)
        
        if report:
            print("✅ 分析完成！")
            print(f"📊 总发现数: {report['findings_analysis']['total_findings']}")
            print(f"📄 详细报告: {args.output or 'detailed_macie_analysis_*.json'}")
            return 0
        else:
            print("❌ 分析失败！")
            return 1
            
    except Exception as e:
        logger.error(f"分析异常: {e}")
        return 1

if __name__ == '__main__':
    exit(main())
