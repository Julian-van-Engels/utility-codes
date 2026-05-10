#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
递归并行比较两个文件夹，生成差异报告。
用法: python compare_folders.py <path_a> <path_b>
"""

import os
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from collections import defaultdict
import time

# 用于存储线程安全的差异结果
results_lock = threading.Lock()
results = {
    'only_in_a': set(),
    'only_in_b': set(),
    'common': set(),
    'total_files_a': 0,
    'total_files_b': 0
}

def normalize_path(path_str):
    """
    规范化路径：统一使用正斜杠，并转换为小写（可选，用于Windows大小写不敏感）
    """
    # 统一使用正斜杠
    normalized = path_str.replace('\\', '/')
    # Windows系统下，可以考虑忽略大小写（取消注释下一行）
    # if sys.platform == 'win32':
    #     normalized = normalized.lower()
    return normalized

def get_relative_paths(root_dir):
    """
    递归获取目录下所有文件的相对路径（相对于root_dir）。
    返回一个生成器，产生 (relative_path, full_path) 元组。
    路径会被规范化（统一使用正斜杠）。
    """
    root = Path(root_dir).resolve()  # 使用绝对路径并解析
    if not root.is_dir():
        raise NotADirectoryError(f"路径不存在或不是目录: {root_dir}")
    
    for entry in root.rglob('*'):
        if entry.is_file():
            # 计算相对路径并规范化
            rel_path = str(entry.relative_to(root))
            rel_path = normalize_path(rel_path)
            yield rel_path, str(entry.resolve())  # 返回绝对路径以便调试

def worker(root_dir, side):
    """
    单个线程的工作函数：收集指定目录的所有文件相对路径。
    side: 'a' 或 'b'，用于标记结果。
    """
    local_set = set()
    file_count = 0
    try:
        for rel_path, full_path in get_relative_paths(root_dir):
            local_set.add(rel_path)
            file_count += 1
    except Exception as e:
        print(f"处理目录 {root_dir} 时出错: {e}", file=sys.stderr)
        return side, local_set, file_count
    
    return side, local_set, file_count

def compare_folders(path_a, path_b, max_workers=None):
    """
    并行比较两个文件夹，返回差异字典。
    """
    if max_workers is None:
        max_workers = min(32, (os.cpu_count() or 1) * 2)
    
    # 规范化输入路径
    path_a = str(Path(path_a).resolve())
    path_b = str(Path(path_b).resolve())
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # 提交两个任务
        future_a = executor.submit(worker, path_a, 'a')
        future_b = executor.submit(worker, path_b, 'b')
        
        # 收集结果
        results_dict = {}
        for future in as_completed([future_a, future_b]):
            side, file_set, count = future.result()
            results_dict[side] = (file_set, count)
    
    set_a, count_a = results_dict['a']
    set_b, count_b = results_dict['b']
    
    only_in_a = set_a - set_b
    only_in_b = set_b - set_a
    common = set_a & set_b
    
    return {
        'total_files_a': count_a,
        'total_files_b': count_b,
        'only_in_a': only_in_a,
        'only_in_b': only_in_b,
        'common': common,
        'all_paths_a': set_a,  # 保存所有路径用于调试
        'all_paths_b': set_b
    }

def generate_markdown_report(result, path_a, path_b, output_file="folder_comparison_report.md"):
    """
    生成Markdown格式的报告。
    """
    lines = []
    lines.append("# 文件夹比较报告\n")
    lines.append(f"**生成时间**: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
    lines.append("## 比较路径\n")
    lines.append(f"- 文件夹 A: `{path_a}`")
    lines.append(f"- 文件夹 B: `{path_b}`\n")
    
    lines.append("## 统计摘要\n")
    lines.append(f"- **A 中文件总数**: {result['total_files_a']}")
    lines.append(f"- **B 中文件总数**: {result['total_files_b']}")
    lines.append(f"- **共同文件数**: {len(result['common'])}")
    lines.append(f"- **仅存在于 A 的文件数**: {len(result['only_in_a'])}")
    lines.append(f"- **仅存在于 B 的文件数**: {len(result['only_in_b'])}\n")
    
    lines.append("## 差异详情\n")
    
    lines.append("### 仅存在于 A 的文件\n")
    if result['only_in_a']:
        # 限制显示数量，避免报告过长
        only_a_sorted = sorted(result['only_in_a'])
        for f in only_a_sorted[:100]:
            lines.append(f"- `{f}`")
        if len(only_a_sorted) > 100:
            lines.append(f"- ... 还有 {len(only_a_sorted) - 100} 个文件")
    else:
        lines.append("*无*")
    lines.append("")
    
    lines.append("### 仅存在于 B 的文件\n")
    if result['only_in_b']:
        only_b_sorted = sorted(result['only_in_b'])
        for f in only_b_sorted[:100]:
            lines.append(f"- `{f}`")
        if len(only_b_sorted) > 100:
            lines.append(f"- ... 还有 {len(only_b_sorted) - 100} 个文件")
    else:
        lines.append("*无*")
    lines.append("")
    
    lines.append("### 共同文件示例 (前20项)\n")
    common_sorted = sorted(result['common'])
    if common_sorted:
        for f in common_sorted[:20]:
            lines.append(f"- `{f}`")
        if len(common_sorted) > 20:
            lines.append(f"- ... 共 {len(common_sorted)} 个文件")
    else:
        lines.append("*无共同文件*")
    
    # 写入文件
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))
    
    return output_file

def debug_compare_files(result, path_a, path_b):
    """
    调试函数：找出两个文件夹中路径相似但不完全相同的文件
    """
    print("\n===== 调试信息 =====")
    
    # 找出A和B中可能匹配的文件（路径部分相同）
    set_a = result['all_paths_a']
    set_b = result['all_paths_b']
    
    # 找出A中但B中没有的，检查是否有路径相似的文件
    only_a = sorted(result['only_in_a'])
    only_b = sorted(result['only_in_b'])
    
    if only_a and only_b:
        print("\n可能存在的路径格式差异：")
        print("A中第一个独有文件:", only_a[0] if only_a else "无")
        print("B中第一个独有文件:", only_b[0] if only_b else "无")
        
        # 检查是否只是大小写或分隔符差异
        if only_a and only_b:
            normalized_a = only_a[0].replace('\\', '/').lower()
            normalized_b = only_b[0].replace('\\', '/').lower()
            if normalized_a == normalized_b:
                print("\n⚠️ 发现路径格式不一致！")
                print(f"    A中的路径: {only_a[0]}")
                print(f"    B中的路径: {only_b[0]}")
                print("    建议：文件实际上相同，但路径字符串格式不同导致未匹配")

def main(path_a, path_b):
    
    # 验证路径
    if not os.path.isdir(path_a):
        print(f"错误: 路径 '{path_a}' 不是一个有效的目录。", file=sys.stderr)
        sys.exit(1)
    if not os.path.isdir(path_b):
        print(f"错误: 路径 '{path_b}' 不是一个有效的目录。", file=sys.stderr)
        sys.exit(1)
    
    print(f"开始比较文件夹: {path_a} 和 {path_b}")
    start_time = time.time()
    
    # 执行比较
    result = compare_folders(path_a, path_b)
    
    elapsed = time.time() - start_time
    print(f"比较完成，耗时 {elapsed:.2f} 秒")
    
    # 生成报告
    report_file = generate_markdown_report(result, path_a, path_b)
    print(f"报告已生成: {os.path.abspath(report_file)}")
    
    # 控制台输出简要信息
    print("\n===== 简要结果 =====")
    print(f"A 文件总数: {result['total_files_a']}")
    print(f"B 文件总数: {result['total_files_b']}")
    print(f"共同文件数: {len(result['common'])}")
    print(f"仅 A 有: {len(result['only_in_a'])}")
    print(f"仅 B 有: {len(result['only_in_b'])}")
    
    # 调试信息：检查路径格式差异
    debug_compare_files(result, path_a, path_b)

if __name__ == "__main__":
    json_file = 'config/compare_2folder.json'
    def import_path_from_json(json_file):
        import json
        with open(json_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return data.get('path_a'), data.get('path_b')
    path_a, path_b = import_path_from_json('config/compare_2folder.json')
    main(path_a, path_b)