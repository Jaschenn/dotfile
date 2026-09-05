#!/usr/bin/env python3
"""
Alfred 英语阅读助手 —— 实时抓生词 + 翻译

输入：选中的句子（Alfred 传入 argv[1]，或从 stdin 读）
输出：把句子里不在 known.txt 中的生词，连同音标和中文翻译打印到 stdout，
      供 Alfred 的 Large Type（放大显示）展示。
同时：把 {日期, 句子, 生词列表} 追加写入 review.jsonl，供以后定期复盘。
"""
import sys
import os
import re
import json
import sqlite3
import subprocess
from datetime import date

HOME       = os.path.expanduser("~/.config/english")
KNOWN_FILE = os.path.join(HOME, "known.txt")     # 已认识的词，一行一个（原形），手工维护
LOG_FILE   = os.path.join(HOME, "review.jsonl")  # 捕获日志，供复盘
DICT_DB    = os.path.join(HOME, "ecdict.db")     # ECDICT 离线词典（由 build_dict.py 生成）

MAX_TRANS_LEN = 100  # Large Type 里每个词释义的最大长度，超出截断
NOTIFICATION_TRIGGER_ID = "word-notification"


def get_input() -> str:
    """优先从命令行参数取，其次从 stdin 取。"""
    if len(sys.argv) > 1 and sys.argv[1].strip():
        return sys.argv[1].strip()
    return sys.stdin.read().strip()


def load_known() -> set:
    try:
        with open(KNOWN_FILE, encoding="utf-8") as f:
            return {
                word
                for ln in f
                if (word := ln.strip().lower()) and not word.startswith("#")
            }
    except FileNotFoundError:
        return set()


def tokens(text: str):
    """只取单词：字母，允许内部的撇号（don't、it's）。"""
    return re.findall(r"[A-Za-z]+(?:'[A-Za-z]+)?", text)


def lemma(word: str) -> str:
    """词形还原：went->go, going->go。simplemma 没装就退化为小写原样。"""
    try:
        import simplemma
        return simplemma.lemmatize(word.lower(), lang="en")
    except Exception:
        return word.lower()


def lookup(conn, word: str):
    """查词典，返回 (音标, 翻译)；查不到返回 (None, None)。"""
    cur = conn.execute(
        "SELECT phonetic, translation FROM stardict WHERE word = ? LIMIT 1",
        (word.lower(),),
    )
    row = cur.fetchone()
    return (row[0], row[1]) if row else (None, None)


def tidy(trans: str) -> str:
    """保留词典按词性分行的释义，并压缩每行多余空白。"""
    trans = trans.replace("\\n", "\n").strip()
    lines = [
        re.sub(r"\s+", " ", line).strip()
        for line in trans.splitlines()
        if line.strip()
    ]
    trans = "\n".join(lines)
    if len(trans) > MAX_TRANS_LEN:
        trans = trans[:MAX_TRANS_LEN] + "…"
    return trans


def send_notifications(lines: list[str]) -> None:
    """逐词调用当前 Alfred 工作流的通知触发器。"""
    bundle_id = os.environ.get("alfred_workflow_bundleid")
    if not bundle_id:
        # 直接在终端运行时没有 Alfred 的工作流环境，保留 stdout 供调试。
        return

    for line in lines:
        # 通过 argv 传值，避免单词或释义里的引号干扰 AppleScript。
        subprocess.run(
            [
                "osascript",
                "-e",
                'on run argv\n'
                'tell application id "com.runningwithcrayons.Alfred" '
                'to run trigger (item 2 of argv) in workflow (item 1 of argv) '
                'with argument (item 3 of argv)\n'
                'end run',
                bundle_id,
                NOTIFICATION_TRIGGER_ID,
                line,
            ],
            check=False,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def main():
    text = get_input()
    if not text:
        print("（没有捕获到文本）")
        return

    known = load_known()
    selected_words = tokens(text)
    force_lookup = len(selected_words) == 1

    # 抓生词（按 lemma 去重）
    seen, unknown = set(), []
    for w in selected_words:
        base = lemma(w)
        # 单独选词表示主动查词，即使它已在 known.txt 中也应展示。
        if (not force_lookup and base in known) or base in seen:
            continue
        seen.add(base)
        unknown.append((w, base))

    # 查词典组装输出
    conn = sqlite3.connect(DICT_DB) if os.path.exists(DICT_DB) else None
    lines, review_words = [], []
    for surface, base in unknown:
        review_words.append(base)
        phon, trans = (None, None)
        if conn is not None:
            phon, trans = lookup(conn, base)
            if trans is None and surface.lower() != base:  # 回退查原样拼写
                phon, trans = lookup(conn, surface.lower())

        head = base if surface.lower() == base else f"{surface}→{base}"
        phon = f" /{phon}/" if phon else ""
        trans = tidy(trans) if trans else "（词典无结果）"
        # 标题和释义分行：词典原本按词性分行的结构得以保留。
        lines.append(f"{head}{phon}\n{trans}")
    if conn is not None:
        conn.close()

    # 写复盘日志
    os.makedirs(HOME, exist_ok=True)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(
            {"date": date.today().isoformat(), "sentence": text, "unknown": review_words},
            ensure_ascii=False,
        ) + "\n")

    if lines:
        send_notifications(lines)
        # 保留 stdout，供现有 Large Type 输出继续使用。
        print("\n".join(lines))
    else:
        print("全部认识 ✓")


if __name__ == "__main__":
    main()
