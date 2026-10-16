# scripts/

本目录放置和「报告生命周期」相关的工具脚本。

## commit-report.sh

把一份已经写入磁盘的日报/周报/月报自动 `git add` + `commit` + `push` 到当前仓库。
作为**生成脚本的最后一步**调用，与具体语言无关。

### 直接命令行调用

```bash
# 日报
scripts/commit-report.sh daily  tech-radar/daily/2026-10-16.md

# 周报（第 42 周）
scripts/commit-report.sh weekly tech-radar/weekly/2026-W42.md

# 月报
scripts/commit-report.sh monthly tech-radar/monthly/2026-10.md

# 只本地 commit，不 push
scripts/commit-report.sh daily tech-radar/daily/2026-10-16.md --no-push
```

### Commit Message 规则

格式：`docs(<type>): <basename> <主题>`

- `<type>` 取自第一个参数：`daily` / `weekly` / `monthly`
- `<basename>` 取自文件名（去掉 `.md` 后缀）
- `<主题>` 取自 Markdown 首行标题（`# ...`），用常见分隔符 `·`、`•`、`|`、`｜` 截断后保留第一段

例：首行是 `# 前端技术视野·每日简报 · 2026-10-16`，文件名是 `2026-10-16.md`，
最终 message 为：

```
docs(daily): 2026-10-16 前端技术视野
```

### 关键行为

| 场景 | 行为 |
| --- | --- |
| 文件不存在 | 报错退出，exit 1 |
| 文件内容和上一次 commit 完全一致 | 幂等跳过，不会产生空 commit |
| 当前仓库未配置 `origin` 远端 | 只 commit，不 push，并打印下一步要执行的命令 |
| 当前分支首次推送 | 自动 `push -u origin <branch>` |
| 已有 upstream | 普通 `git push` |

### 远端 URL 后补的流程

目前仓库只有本地 `main` 分支。等你在 GitHub/GitLab 建好空仓库后：

```bash
cd /Users/code/tech
git remote add origin git@github.com:<you>/<repo>.git
git push -u origin main
```

从此之后，所有通过 `commit-report.sh` 产生的 commit 都会自动 push。

### 在生成脚本里集成

#### Node.js

```js
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const repoRoot = /* 你的仓库根路径，例如 */ '/Users/code/tech';

// ... 在这里完成报告生成并写入 filePath ...
const filePath = 'tech-radar/daily/2026-10-16.md';

execFileSync(
    join(repoRoot, 'scripts/commit-report.sh'),
    ['daily', filePath],
    { stdio: 'inherit', cwd: repoRoot },
);
```

#### Python

```python
import subprocess
from pathlib import Path

repo_root = Path('/Users/code/tech')

# ... 在这里完成报告生成并写入 file_path ...
file_path = 'tech-radar/daily/2026-10-16.md'

subprocess.run(
    [str(repo_root / 'scripts/commit-report.sh'), 'daily', file_path],
    cwd=repo_root,
    check=True,
)
```

#### Shell（兜底）

```bash
# 任意生成命令写入文件后，最后一行：
./scripts/commit-report.sh daily tech-radar/daily/"$(date +%F)".md
```

### 常见坑

1. **author 配置**：commit 会用全局 `git config --global user.name/user.email`。
     本机当前已配置为 `zym-2020 <1161384816@qq.com>`，如需按仓库覆盖可执行
     `git config user.email "your-work@email"`。
2. **SSH key**：`push` 时若远端是 `git@github.com:...`，确保 `ssh -T git@github.com` 能通。
     否则改用 HTTPS + Personal Access Token。
3. **冲突**：若远端被别处推进过，`git push` 会失败。脚本不做 `--force`。
     手动 `git pull --rebase` 后再调用一次脚本即可（内容无变化会被幂等跳过，不会重复 commit）。
