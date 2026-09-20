#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""
一键准备脚本 —— 跑一次就好： uv run build_dict.py

自动完成两件事，不需要你手动下载或配置：
  1. 从 GitHub 下载 ECDICT 英汉词典（约 63 MB，明文 csv，无需解压）
  2. 构建成 capture.py 查询用的本地 sqlite 词典

如果所在网络访问 GitHub 困难，可以自己下载 csv 放到 ~/.config/english/ecdict.csv，
再跑本脚本，它会跳过下载直接建库。
"""
import os
import sys
import csv
import sqlite3
import urllib.request

HOME     = os.path.expanduser("~/.config/english")
GITHUB_CSV_URL = "https://raw.githubusercontent.com/skywind3000/ECDICT/master/ecdict.csv"
GH_MIRROR = os.environ.get("GH_MIRROR", "").rstrip("/")
CSV_URL  = f"{GH_MIRROR}/{GITHUB_CSV_URL}" if GH_MIRROR else GITHUB_CSV_URL
CSV_PATH = os.path.join(HOME, "ecdict.csv")
DB_PATH  = os.path.join(HOME, "ecdict.db")


def download(url, path):
    def hook(count, block_size, total):
        done = count * block_size
        if total > 0:
            pct = min(done * 100 / total, 100)
            sys.stdout.write(
                f"\r  下载中 {pct:5.1f}%  ({done/1048576:.1f}/{total/1048576:.1f} MB)"
            )
            sys.stdout.flush()
    urllib.request.urlretrieve(url, path, reporthook=hook)
    print()


def ensure_csv():
    if os.path.exists(CSV_PATH):
        print(f"已有词典 csv：{CSV_PATH}")
        return True
    print("正在从 GitHub 下载 ECDICT 词典（约 63 MB）…")
    try:
        download(CSV_URL, CSV_PATH)
        return True
    except Exception as e:
        if os.path.exists(CSV_PATH):
            os.remove(CSV_PATH)  # 清掉下了一半的文件
        print(f"\n下载失败：{e}")
        print("多半是当前网络访问 GitHub 受限。可以手动下载：")
        print(f"  {CSV_URL}")
        print(f"下载后把 ecdict.csv 放到： {CSV_PATH}")
        print("然后重新运行本脚本即可。")
        return False


def build_db():
    print("正在构建 sqlite 词典（第一次约需十几秒）…")
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        "CREATE TABLE IF NOT EXISTS stardict ("
        "  word TEXT PRIMARY KEY, phonetic TEXT, translation TEXT)"
    )
    with open(CSV_PATH, encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = (
            (r["word"].lower(), r.get("phonetic", ""), r.get("translation", ""))
            for r in reader if r.get("word")
        )
        conn.executemany("INSERT OR REPLACE INTO stardict VALUES (?, ?, ?)", rows)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_word ON stardict(word)")
    conn.commit()
    n = conn.execute("SELECT COUNT(*) FROM stardict").fetchone()[0]
    conn.close()
    print(f"完成，共 {n} 个词条 -> {DB_PATH}")


def main():
    os.makedirs(HOME, exist_ok=True)

    if os.path.exists(DB_PATH):
        print(f"词典库已存在：{DB_PATH}（如需重建，删掉它再跑一次）")
    else:
        if not ensure_csv():
            sys.exit(1)
        build_db()
        print(f"提示：csv 已保留在 {CSV_PATH}，想省空间可以手动删除，不影响使用。")

    print("\n全部就绪，可以开始用 Alfred 捕获句子了。")


if __name__ == "__main__":
    main()
