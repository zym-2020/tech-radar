#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# commit-report.sh
#
# 把一份已经写入磁盘的日报/周报/月报自动 add + commit + push 到当前 git 仓库。
# 设计上作为「生成脚本的最后一步」被调用，与具体语言无关：
#   - Node:   execFileSync('scripts/commit-report.sh', ['daily', <path>])
#   - Python: subprocess.run(['scripts/commit-report.sh', 'daily', <path>])
#
# 用法：
#   scripts/commit-report.sh <daily|weekly|monthly> <file-path> [--no-push]
#
# 行为：
#   - 文件不存在      -> 报错退出
#   - 内容无变化      -> 幂等跳过（不会产生空 commit）
#   - 未配置 origin   -> 只 commit，不 push，并提示下一步命令
#   - 首次 push       -> 自动设置 upstream 到 origin/<当前分支>
# ------------------------------------------------------------------------------

set -euo pipefail

usage() {
    cat <<EOF
用法: $(basename "$0") <daily|weekly|monthly> <file-path> [--no-push]

参数:
    <type>       报告类型，仅接受 daily / weekly / monthly
    <file-path>  报告 Markdown 文件路径，相对或绝对均可
    --no-push    仅本地 commit，不推送远端

示例:
    $(basename "$0") daily  tech-radar/daily/2026-10-16.md
    $(basename "$0") weekly tech-radar/weekly/2026-W42.md --no-push
EOF
}

# ---------- 参数解析 ----------
if [[ $# -lt 2 ]]; then
    usage
    exit 1
fi

TYPE="$1"
FILE="$2"
shift 2

NO_PUSH=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-push) NO_PUSH=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "未知参数: $1" >&2; usage; exit 1 ;;
    esac
    shift
done

case "$TYPE" in
    daily|weekly|monthly) ;;
    *)
        echo "不支持的报告类型: $TYPE （只能是 daily / weekly / monthly）" >&2
        exit 1
        ;;
esac

# ---------- 定位仓库根 ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$REPO_ROOT" ]]; then
    echo "脚本所在目录不是 git 仓库，请先在仓库根执行: git init -b main" >&2
    exit 1
fi
cd "$REPO_ROOT"

if [[ ! -f "$FILE" ]]; then
    echo "文件不存在: $FILE" >&2
    exit 1
fi

# ---------- 组装 commit message ----------
# 期望格式: docs(daily): 2026-10-16 前端技术视野
BASENAME="$(basename "$FILE" .md)"

# 从首行 Markdown 标题提取「主题关键词」：
#   1) 去掉开头的 # 与空白
#   2) 用常见分隔符 ·、•、|、｜ 截断，只保留第一段
#   3) 去掉尾部空白
# 注：macOS 自带 BSD sed 对多字节字符不友好，这里用 perl -CSD 保证 UTF-8 安全。
SUBJECT="$(perl -CSD -ne '
    if ($. == 1) {
        s/^\#+\s*//;
        s/\s*[·•|｜].*//;
        s/\s+$//;
        print;
        exit;
    }
' "$FILE")"
SUBJECT="${SUBJECT:-${TYPE} 报告}"

MESSAGE="docs(${TYPE}): ${BASENAME} ${SUBJECT}"

# ---------- add + commit（幂等） ----------
git add -- "$FILE"

if git diff --cached --quiet; then
    echo "✓ 没有待提交的变更（$FILE 未发生变化），跳过。"
    exit 0
fi

git commit -m "$MESSAGE"
echo "✓ 已提交: $MESSAGE"

# ---------- push ----------
if [[ "$NO_PUSH" -eq 1 ]]; then
    echo "ℹ 根据 --no-push 参数，跳过推送。"
    exit 0
fi

if ! git remote get-url origin >/dev/null 2>&1; then
    CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
    cat <<EOF
ℹ 当前仓库尚未配置 origin 远端，已跳过 push。
    建好远端后请执行（示例）：
        git remote add origin git@github.com:<you>/<repo>.git
        git push -u origin ${CURRENT_BRANCH}
    之后再次运行本脚本时会自动推送。
EOF
    exit 0
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    # 首次推送：自动绑定上游
    git push -u origin "$CURRENT_BRANCH"
else
    git push
fi
echo "✓ 已推送到 origin/${CURRENT_BRANCH}"
