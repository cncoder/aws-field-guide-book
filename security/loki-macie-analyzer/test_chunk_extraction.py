#!/usr/bin/env python3
"""
Loki Chunk文件解析测试工具
用于验证能否正确解析Loki chunk文件并提取文本内容
"""

import os
import subprocess
from pathlib import Path
import json
from datetime import datetime

def test_chunks_inspect_tool():
    """测试chunks-inspect工具"""
    print("🔧 测试chunks-inspect工具...")
    
    # 检查工具是否存在且可执行
    if not os.path.exists('./chunks-inspect'):
        print("❌ chunks-inspect工具不存在")
        return False
    
    if not os.access('./chunks-inspect', os.X_OK):
        print("❌ chunks-inspect工具不可执行，请运行: chmod +x chunks-inspect")
        return False
    
    # 测试工具帮助信息
    try:
        result = subprocess.run(['./chunks-inspect', '-h'], 
                              capture_output=True, text=True)
        print("✅ chunks-inspect工具可用")
        print("📋 支持的参数:")
        print("   -l: 打印日志行")
        print("   -b: 打印块详细信息")
        print("   -s: 存储块数据")
        return True
    except Exception as e:
        print(f"❌ chunks-inspect工具测试失败: {e}")
        return False

def analyze_chunk_file(chunk_file):
    """分析单个chunk文件"""
    print(f"\n📄 分析文件: {chunk_file.name}")
    
    # 获取文件基本信息
    file_size = chunk_file.stat().st_size
    print(f"   文件大小: {file_size:,} 字节")
    
    # 使用chunks-inspect提取日志内容
    try:
        cmd = ['./chunks-inspect', '-l', str(chunk_file)]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            output = result.stdout
            lines = output.split('\n')
            
            # 解析元数据
            metadata = {}
            log_lines = []
            in_log_section = False
            
            for line in lines:
                if line.startswith('UserID:'):
                    metadata['user_id'] = line.split(':', 1)[1].strip()
                elif line.startswith('From:'):
                    metadata['from_time'] = line.split(':', 1)[1].strip()
                elif line.startswith('Through:'):
                    metadata['through_time'] = line.split(':', 1)[1].strip()
                elif line.startswith('Labels:'):
                    in_log_section = False
                elif line.strip() and not line.startswith('\t') and not any(line.startswith(prefix) for prefix in ['Chunks file:', 'Metadata length:', 'Data length:', 'UserID:', 'From:', 'Through:', 'Labels:']):
                    if in_log_section or any(char.isdigit() for char in line[:20]):  # 可能是日志行
                        log_lines.append(line)
                elif 'INFO' in line or 'ERROR' in line or 'WARN' in line or 'DEBUG' in line:
                    log_lines.append(line)
            
            print(f"   ✅ 解析成功")
            print(f"   📊 输出大小: {len(output):,} 字符")
            print(f"   👤 用户ID: {metadata.get('user_id', 'N/A')}")
            print(f"   ⏰ 时间范围: {metadata.get('from_time', 'N/A')} - {metadata.get('through_time', 'N/A')}")
            print(f"   📝 日志行数: {len([l for l in log_lines if l.strip()])} 行")
            
            # 显示前几行日志样本
            sample_logs = [l for l in log_lines if l.strip()][:3]
            if sample_logs:
                print("   📋 日志样本:")
                for i, log in enumerate(sample_logs, 1):
                    print(f"      {i}. {log[:100]}{'...' if len(log) > 100 else ''}")
            
            return {
                'file_name': chunk_file.name,
                'file_size': file_size,
                'output_size': len(output),
                'metadata': metadata,
                'log_count': len([l for l in log_lines if l.strip()]),
                'success': True
            }
        else:
            print(f"   ❌ 解析失败: {result.stderr}")
            return {
                'file_name': chunk_file.name,
                'file_size': file_size,
                'success': False,
                'error': result.stderr
            }
            
    except Exception as e:
        print(f"   ❌ 解析异常: {e}")
        return {
            'file_name': chunk_file.name,
            'file_size': file_size,
            'success': False,
            'error': str(e)
        }

def test_batch_extraction():
    """测试批量提取"""
    print("\n📦 测试批量提取...")
    
    chunk_dir = Path('./lokichunk')
    if not chunk_dir.exists():
        print("❌ lokichunk目录不存在")
        return []
    
    # 获取所有chunk文件
    chunk_files = [f for f in chunk_dir.iterdir() if f.is_file() and not f.name.startswith('.')]
    
    if not chunk_files:
        print("❌ lokichunk目录中没有找到文件")
        return []
    
    print(f"📁 找到 {len(chunk_files)} 个chunk文件")
    
    results = []
    for chunk_file in chunk_files:
        result = analyze_chunk_file(chunk_file)
        results.append(result)
    
    return results

def save_extraction_test(results):
    """保存提取测试结果"""
    if not results:
        return
    
    # 创建测试输出目录
    output_dir = Path('./test_extraction')
    output_dir.mkdir(exist_ok=True)
    
    # 保存测试报告
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    report_file = output_dir / f'extraction_test_report_{timestamp}.json'
    
    test_report = {
        'test_time': datetime.now().isoformat(),
        'total_files': len(results),
        'successful_extractions': len([r for r in results if r['success']]),
        'failed_extractions': len([r for r in results if not r['success']]),
        'results': results
    }
    
    with open(report_file, 'w', encoding='utf-8') as f:
        json.dump(test_report, f, indent=2, ensure_ascii=False)
    
    print(f"\n📄 测试报告已保存: {report_file}")
    
    # 实际提取一个文件作为样本
    successful_results = [r for r in results if r['success']]
    if successful_results:
        sample_file = successful_results[0]['file_name']
        sample_path = Path('./lokichunk') / sample_file
        
        try:
            cmd = ['./chunks-inspect', '-l', str(sample_path)]
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                sample_output = output_dir / f'{sample_file}_sample.txt'
                with open(sample_output, 'w', encoding='utf-8') as f:
                    f.write(f"# Loki Chunk文件提取样本\n")
                    f.write(f"# 文件: {sample_file}\n")
                    f.write(f"# 提取时间: {datetime.now().isoformat()}\n")
                    f.write("# " + "="*50 + "\n\n")
                    f.write(result.stdout)
                
                print(f"📝 样本文件已保存: {sample_output}")
        except Exception as e:
            print(f"⚠️ 保存样本文件失败: {e}")

def print_summary(results):
    """打印测试摘要"""
    if not results:
        return
    
    successful = [r for r in results if r['success']]
    failed = [r for r in results if not r['success']]
    
    print("\n" + "="*60)
    print("📊 Loki Chunk文件解析测试摘要")
    print("="*60)
    
    print(f"📁 总文件数: {len(results)}")
    print(f"✅ 成功解析: {len(successful)}")
    print(f"❌ 解析失败: {len(failed)}")
    
    if successful:
        total_size = sum(r['file_size'] for r in successful)
        total_output = sum(r['output_size'] for r in successful)
        total_logs = sum(r.get('log_count', 0) for r in successful)
        
        print(f"\n📊 成功解析统计:")
        print(f"   原始数据大小: {total_size:,} 字节")
        print(f"   提取文本大小: {total_output:,} 字符")
        print(f"   总日志行数: {total_logs:,} 行")
        print(f"   平均压缩比: {total_size/total_output:.1f}:1" if total_output > 0 else "   压缩比: N/A")
    
    if failed:
        print(f"\n❌ 失败文件:")
        for r in failed:
            print(f"   {r['file_name']}: {r.get('error', 'Unknown error')}")
    
    print("="*60)

def main():
    """主测试函数"""
    print("🧪 Loki Chunk文件解析测试")
    print("="*40)
    
    # 测试chunks-inspect工具
    if not test_chunks_inspect_tool():
        print("\n❌ chunks-inspect工具测试失败，无法继续")
        return 1
    
    # 测试批量提取
    results = test_batch_extraction()
    
    if not results:
        print("\n❌ 没有找到可测试的文件")
        return 1
    
    # 保存测试结果
    save_extraction_test(results)
    
    # 打印摘要
    print_summary(results)
    
    # 检查是否所有文件都成功解析
    successful_count = len([r for r in results if r['success']])
    if successful_count == len(results):
        print("\n🎉 所有文件解析成功！可以继续运行完整管道。")
        print("💡 下一步: 修改config.json后运行完整管道")
        return 0
    else:
        print(f"\n⚠️ {len(results) - successful_count} 个文件解析失败")
        print("💡 建议: 检查失败原因后再运行完整管道")
        return 1

if __name__ == '__main__':
    exit(main())
