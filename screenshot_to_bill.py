#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把「校园卡交易记录查询」截图批量转成「一羽记账」可导入的 template3.csv。

用法：
    python3 screenshot_to_bill.py 截图1.jpg 截图2.jpg ...     # 传多个文件（分页截图）
    python3 screenshot_to_bill.py --dir ./截图目录              # 传整个目录(按文件名排序)
    python3 screenshot_to_bill.py --out 账单.csv 截图1.jpg     # 指定输出文件名

依赖（一次性）：
    pip install rapidocr_onnxruntime opencv-python pillow

原理：
    1. OCR 识别截图，拿到每个文字块的 (y, x, 文本)。
    2. 按 x 位置划分列：交易地点 / 交易金额 / 交易时间 / 余额。
    3. 按 y 位置聚类成行，拼成一条条交易记录。
    4. 应用下方 CONFIG 里的规则（地点分类、餐别标签、转账识别），写出 13 列模板 CSV。

规则都在 CONFIG 里，改配置即可，不用动代码。
"""

import argparse
import csv
import glob
import os
import re
import sys
from datetime import datetime

# ------------------------------------------------------------------
# 规则配置：按需修改
# ------------------------------------------------------------------
CONFIG = {
    # 交易地点 -> 账单分类
    "location_category": {
        "国铁科林BOT": "喝水",
        "紫荆园": "食堂",
        "观畴园": "食堂",
        "清芬园": "食堂",
        "桃李园": "食堂",
        "南区18号楼": "洗澡",
        # 新地点在此追加，例如  "玉树园": "食堂",
    },
    # 未匹配到上面映射的地点，落到这个默认分类
    "default_category": "食堂",

    # 只有这些分类才按时间打「早/午/晚餐」标签
    "meal_categories": ["食堂"],
    # 餐别标签规则：(标签, 起始小时[含], 结束小时[不含])
    "meal_ranges": [("早餐", 5, 10), ("午餐", 10, 15), ("晚餐", 15, 23)],

    # 这些地点识别为「转账」（如校园卡充值），不使用分类
    "transfer_locations": ["在线充值"],
    "transfer_source": "中国银行一类",   # 转账：转出账户
    "transfer_target": "校园卡",         # 转账：转入账户

    # 支出记录统一绑定的账户（需与 APP 内账户同名）
    "expense_account": "校园卡",

    # 输出文件名
    "out": "template3.csv",
}

# 一羽记账 template3.csv 表头（13 列，勿改）
HEADER = ["日期", "类型", "分类", "金额", "账户", "账户2", "备注",
          "账单图片", "标签", "手续费", "优惠", "不计预算", "不计收支"]

# 表格表头文字（用于判断跳过表头行）
_HEADER_TEXTS = {"交易地点", "交易金额", "交易时间", "余额"}

# ------------------------------------------------------------------
# OCR
# ------------------------------------------------------------------
_OCR_ENGINE = None


def get_ocr_engine():
    """惰性加载 OCR 引擎。"""
    global _OCR_ENGINE
    if _OCR_ENGINE is not None:
        return _OCR_ENGINE
    try:
        from rapidocr_onnxruntime import RapidOCR
    except ImportError:
        sys.exit("缺少 OCR 依赖，请先运行：pip install rapidocr_onnxruntime")
    _OCR_ENGINE = RapidOCR()
    return _OCR_ENGINE


def ocr_image(path):
    """返回 [(y_center, x_center, text), ...]，坐标为像素。"""
    eng = get_ocr_engine()
    result, _ = eng(path)
    blocks = []
    for box, text, score in result:
        xs = [p[0] for p in box]
        ys = [p[1] for p in box]
        blocks.append((sum(ys) / 4.0, sum(xs) / 4.0, text))
    return blocks


# ------------------------------------------------------------------
# 切分与解析
# ------------------------------------------------------------------
def col_of(x, width):
    """按 x 比例判断属于哪一列，返回列名。"""
    f = x / max(width, 1)
    if f < 0.25:
        return "location"     # 交易地点
    if f < 0.48:
        return "amount"       # 交易金额
    if f < 0.82:
        return "time"         # 交易时间
    return "balance"          # 余额


def cluster_rows(blocks, height):
    """把文字块按 y 聚成行。"""
    tol = max(15, min(60, int(height * 0.008)))
    blocks = sorted(blocks)
    rows = []
    cur = []
    prev_y = None
    for y, x, text in blocks:
        if prev_y is not None and (y - prev_y) > tol:
            rows.append(cur)
            cur = []
        cur.append((y, x, text))
        prev_y = y
    if cur:
        rows.append(cur)
    return rows


def row_to_record(row, width):
    """把一个聚类行的文字块按列归并成 dict。"""
    rec = {"location": "", "amount": "", "time": "", "balance": ""}
    for y, x, text in row:
        col = col_of(x, width)
        # 若同一列出现多个块，则拼接（防御性）
        if rec[col]:
            rec[col] += text
        else:
            rec[col] = text
    return rec


def parse_date(text):
    """解析日期时间，返回 datetime；失败返回 None。"""
    text = (text or "").replace(" /", "/")
    m = re.search(r"(\d{4})[-/](\d{1,2})[-/](\d{1,2})[\s]?(\d{1,2}):(\d{2})", text)
    if not m:
        m = re.search(r"(\d{4})[-/](\d{1,2})[-/](\d{1,2})", text)
    if not m:
        return None
    y, mo, d = int(m.group(1)), int(m.group(2)), int(m.group(3))
    if m.lastindex and m.lastindex >= 5:
        h, mi = int(m.group(4)), int(m.group(5))
    else:
        h, mi = 0, 0
    try:
        return datetime(y, mo, d, h, mi)
    except ValueError:
        return None


def format_money(text):
    """金额转字符串数字，去掉货币符号/千分位/多余空格。"""
    s = re.sub(r"[^\d.]", "", (text or "").replace(",", ""))
    if not s:
        return ""
    try:
        return f"{float(s):g}"
    except ValueError:
        return ""


def meal_tag_for(dt, category):
    """返回餐别标签；非餐点或非食堂分类返回空串。"""
    if category not in CONFIG["meal_categories"]:
        return ""
    for label, start, end in CONFIG["meal_ranges"]:
        if start <= dt.hour < end:
            return label
    return ""


# ------------------------------------------------------------------
# 生成账单记录
# ------------------------------------------------------------------
def build_record(rec):
    """把解析出的一行转成模板 CSV 的 13 列列表。"""
    loc = (rec.get("location") or "").strip()
    amount = format_money(rec.get("amount"))
    dt = parse_date(rec.get("time"))
    if not loc or not amount or dt is None:
        return None  # 缺关键字段，跳过

    if loc in CONFIG["transfer_locations"]:
        # 转账：账户=转出，账户2=转入，分类留空
        return [dt.strftime("%Y-%m-%d %H:%M"), "转账", "", amount,
                CONFIG["transfer_source"], CONFIG["transfer_target"],
                loc, "", "", "", "", "", ""]

    category = CONFIG["location_category"].get(loc, CONFIG["default_category"])
    tag = meal_tag_for(dt, category)
    return [dt.strftime("%Y-%m-%d %H:%M"), "支出", category, amount,
            CONFIG["expense_account"], "", loc, "", tag, "", "", "", ""]


def process_image(path):
    """处理单张截图，返回记录列表 + 警告。"""
    from PIL import Image
    im = Image.open(path)
    width, height = im.size
    blocks = ocr_image(path)
    warnings = []
    records = []

    for row in cluster_rows(blocks, height):
        rec = row_to_record(row, width)
        # 跳过表头行（含「交易地点」等表头文字）
        if rec["location"] in _HEADER_TEXTS or rec["time"].strip() in _HEADER_TEXTS:
            continue
        # 跳过缺少 地点/金额/时间 的杂质行（顶部导航等）
        if not (rec["location"].strip() and rec["amount"].strip() and rec["time"].strip()):
            continue
        r = build_record(rec)
        if r is None:
            warnings.append(f"  无法解析该行: {dict(rec)}")
        else:
            records.append(r)
    return records, warnings


# ------------------------------------------------------------------
# 主流程
# ------------------------------------------------------------------
def collect_images(args):
    """收集待处理图片路径。"""
    paths = []
    if args.dir:
        for ext in ("*.jpg", "*.jpeg", "*.png", "*.webp", "*.bmp"):
            paths.extend(sorted(glob.glob(os.path.join(args.dir, ext))))
    paths.extend(args.images)
    # 去重保序
    seen, uniq = set(), []
    for p in paths:
        if os.path.exists(p) and p not in seen and os.path.splitext(p)[1].lower() in (".jpg", ".jpeg", ".png", ".webp", ".bmp"):
            seen.add(p)
            uniq.append(p)
    return uniq


def main():
    ap = argparse.ArgumentParser(description="校园卡交易截图 -> 一羽记账导入 CSV")
    ap.add_argument("images", nargs="*", help="截图文件路径，可多个")
    ap.add_argument("--dir", help="截图所在目录，按文件名顺序处理")
    ap.add_argument("--out", help="输出 CSV 路径（默认取 CONFIG['out']）")
    args = ap.parse_args()

    if not args.images and not args.dir:
        ap.print_help()
        sys.exit("请传入截图文件或 --dir 目录")

    paths = collect_images(args)
    if not paths:
        sys.exit("没有找到可处理的截图文件")

    all_records, all_warnings = [], []
    for p in paths:
        print(f"处理: {p}")
        recs, warns = process_image(p)
        for r in recs:
            all_records.append(r)
        all_warnings.extend(warns)
        print(f"  本张识别 {len(recs)} 条")

    # 按时间升序、去重（分页截图可能首尾重复）
    all_records.sort(key=lambda r: (r[0], r[3], r[6]))
    dedup = []
    seen = set()
    for r in all_records:
        key = (r[0], r[3], r[6])
        if key not in seen:
            seen.add(key)
            dedup.append(r)

    out = args.out or CONFIG["out"]
    with open(out, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(HEADER)
        w.writerows(dedup)

    print(f"\n共写入 {len(dedup)} 条记录 -> {out}")
    if all_warnings:
        print("以下行无法解析（已跳过），请人工补录：")
        for w in all_warnings:
            print(w)


if __name__ == "__main__":
    main()
