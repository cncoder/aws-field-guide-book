#!/usr/bin/env python3
"""
Loki Macie管道测试脚本
用于验证管道的各个组件是否正常工作
"""

import os
import sys
import subprocess
import json
from pathlib import Path

def test_environment():
    """测试环境依赖"""
    print("🔍 测试环境依赖...")
    
    tests = []
    
    # 测试Python模块
    try:
        import boto3
        tests.append(("✅", "boto3模块"))
    except ImportError:
        tests.append(("❌", "boto3模块 - 请运行: pip install boto3"))
    
    # 测试AWS配置
    try:
        result = subprocess.run(['aws', 'sts', 'get-caller-identity'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            tests.append(("✅", "AWS凭证配置"))
        else:
            tests.append(("❌", "AWS凭证配置 - 请运行: aws configure"))
    except FileNotFoundError:
        tests.append(("❌", "AWS CLI - 请安装AWS CLI"))
    
    # 测试chunks-inspect工具
    if os.path.exists('./chunks-inspect') and os.access('./chunks-inspect', os.X_OK):
        tests.append(("✅", "chunks-inspect工具"))
    else:
        tests.append(("❌", "chunks-inspect工具 - 请运行: chmod +x chunks-inspect"))
    
    # 测试lokichunk目录
    if os.path.exists('./lokichunk') and os.path.isdir('./lokichunk'):
        chunk_files = list(Path('./lokichunk').glob('*'))
        chunk_files = [f for f in chunk_files if f.is_file()]
        if chunk_files:
            tests.append(("✅", f"lokichunk目录 ({len(chunk_files)} 个文件)"))
        else:
            tests.append(("❌", "lokichunk目录为空"))
    else:
        tests.append(("❌", "lokichunk目录不存在"))
    
    # 显示测试结果
    for status, message in tests:
        print(f"  {status} {message}")
    
    # 返回是否所有测试都通过
    return all(status == "✅" for status, _ in tests)

def test_chunk_extraction():
    """测试chunk文件提取"""
    print("\n📝 测试chunk文件提取...")
    
    try:
        # 创建测试输出目录
        test_output = Path('./test_extraction')
        test_output.mkdir(exist_ok=True)
        
        # 获取第一个chunk文件进行测试
        chunk_files = list(Path('./lokichunk').glob('*'))
        chunk_files = [f for f in chunk_files if f.is_file()]
        
        if not chunk_files:
            print("  ❌ 没有找到chunk文件")
            return False
        
        test_file = chunk_files[0]
        print(f"  📄 测试文件: {test_file.name}")
        
        # 运行chunks-inspect
        cmd = ['./chunks-inspect', '-l', str(test_file)]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            # 保存测试结果
            output_file = test_output / f"{test_file.name}_test.txt"
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(result.stdout)
            
            print(f"  ✅ 提取成功，输出: {output_file}")
            print(f"  📊 输出大小: {len(result.stdout)} 字符")
            return True
        else:
            print(f"  ❌ 提取失败: {result.stderr}")
            return False
            
    except Exception as e:
        print(f"  ❌ 测试异常: {e}")
        return False

def test_s3_connectivity():
    """测试S3连接"""
    print("\n☁️ 测试S3连接...")
    
    try:
        import boto3
        s3_client = boto3.client('s3')
        
        # 测试扫描存储桶
        scan_bucket = 'your-macie-scan-bucket'
        try:
            s3_client.head_bucket(Bucket=scan_bucket)
            print(f"  ✅ 扫描存储桶可访问: {scan_bucket}")
        except Exception as e:
            print(f"  ❌ 扫描存储桶不可访问: {scan_bucket} - {e}")
            return False
        
        # 测试结果存储桶
        results_bucket = 'your-macie-results-bucket'
        try:
            s3_client.head_bucket(Bucket=results_bucket)
            print(f"  ✅ 结果存储桶可访问: {results_bucket}")
        except Exception as e:
            print(f"  ❌ 结果存储桶不可访问: {results_bucket} - {e}")
            return False
        
        return True
        
    except Exception as e:
        print(f"  ❌ S3连接测试失败: {e}")
        return False

def test_macie_service():
    """测试Macie服务"""
    print("\n🔍 测试Macie服务...")
    
    try:
        import boto3
        macie_client = boto3.client('macie2', region_name='us-east-1')
        
        # 检查Macie状态
        try:
            response = macie_client.get_macie_session()
            print("  ✅ Macie服务已启用")
            print(f"  📊 服务状态: {response.get('status', 'UNKNOWN')}")
            return True
        except macie_client.exceptions.ResourceNotFoundException:
            print("  ⚠️ Macie服务未启用，管道将自动启用")
            return True
        except Exception as e:
            print(f"  ❌ Macie服务检查失败: {e}")
            return False
            
    except Exception as e:
        print(f"  ❌ Macie连接测试失败: {e}")
        return False

def test_pipeline_dry_run():
    """测试管道干运行"""
    print("\n🧪 测试管道组件...")
    
    try:
        # 测试管道脚本语法
        result = subprocess.run([sys.executable, '-m', 'py_compile', 'loki_macie_pipeline.py'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("  ✅ 主管道脚本语法正确")
        else:
            print(f"  ❌ 主管道脚本语法错误: {result.stderr}")
            return False
        
        # 测试分析脚本语法
        result = subprocess.run([sys.executable, '-m', 'py_compile', 'analyze_macie_results.py'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("  ✅ 结果分析脚本语法正确")
        else:
            print(f"  ❌ 结果分析脚本语法错误: {result.stderr}")
            return False
        
        # 测试配置文件
        try:
            with open('config.json', 'r') as f:
                config = json.load(f)
            print("  ✅ 配置文件格式正确")
        except Exception as e:
            print(f"  ❌ 配置文件错误: {e}")
            return False
        
        return True
        
    except Exception as e:
        print(f"  ❌ 管道测试失败: {e}")
        return False

def main():
    """主测试函数"""
    print("🚀 Loki Macie管道测试")
    print("=" * 40)
    
    tests = [
        ("环境依赖", test_environment),
        ("文件提取", test_chunk_extraction),
        ("S3连接", test_s3_connectivity),
        ("Macie服务", test_macie_service),
        ("管道组件", test_pipeline_dry_run)
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"  ❌ {test_name}测试异常: {e}")
            results.append((test_name, False))
    
    # 显示测试摘要
    print("\n" + "=" * 40)
    print("📊 测试摘要")
    print("=" * 40)
    
    passed = 0
    for test_name, result in results:
        status = "✅ 通过" if result else "❌ 失败"
        print(f"  {test_name}: {status}")
        if result:
            passed += 1
    
    print(f"\n总计: {passed}/{len(results)} 个测试通过")
    
    if passed == len(results):
        print("\n🎉 所有测试通过！管道已准备就绪。")
        print("💡 运行命令: ./run_loki_analysis.sh")
        return 0
    else:
        print(f"\n⚠️ {len(results) - passed} 个测试失败，请检查上述错误。")
        return 1

if __name__ == '__main__':
    exit(main())
