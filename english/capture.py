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
from datetime import date

HOME       = os.path.expanduser("~/.config/english")
KNOWN_FILE = os.path.join(HOME, "known.txt")     # 已认识的词，一行一个（原形），手工维护
LOG_FILE   = os.path.join(HOME, "review.jsonl")  # 捕获日志，供复盘
DICT_DB    = os.path.join(HOME, "ecdict.db")     # ECDICT 离线词典（由 build_dict.py 生成）

MAX_TRANS_LEN = 100  # Large Type 里每个词释义的最大长度，超出截断


def get_input() -> str:
    """优先从命令行参数取，其次从 stdin 取。"""
    if len(sys.argv) > 1 and sys.argv[1].strip():
        return sys.argv[1].strip()
    return sys.stdin.read().strip()


def load_known() -> set:
    try:
        with open(KNOWN_FILE, encoding="utf-8") as f:
            return {ln.strip().lower() for ln in f if ln.strip()}
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
    """把多条释义压成一行，超长截断，适配 Large Type。"""
    trans = trans.replace("\\n", "; ").replace("\n", "; ").strip()
    if len(trans) > MAX_TRANS_LEN:
        trans = trans[:MAX_TRANS_LEN] + "…"
    return trans


def main():
    text = get_input()
    if not text:
        print("（没有捕获到文本）")
        return

    known = load_known()

    # 抓生词（按 lemma 去重）
    seen, unknown = set(), []
    for w in tokens(text):
        base = lemma(w)
        if base in known or base in seen:
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
        lines.append(f"{head}{phon}  {trans}")
    if conn is not None:
        conn.close()

    # 写复盘日志
    os.makedirs(HOME, exist_ok=True)
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(
            {"date": date.today().isoformat(), "sentence": text, "unknown": review_words},
            ensure_ascii=False,
        ) + "\n")

    print("\n".join(lines) if lines else "全部认识 ✓")


if __name__ == "__main__":
    main()
