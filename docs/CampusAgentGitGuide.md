# campus-agent Git 协作命令手册

> 适用项目：https://github.com/LEC544/campus-agent
> 终端：Windows Git Bash
> 整理日期：2026-10-19
> 本文依据此前提供的仓库规则与工程结构编写，不代表对当前远端状态的实时审计。

## 1. 项目约定

- `main`：用于接收已经审查并合并的代码，不直接在上面开发或推送。
- `client/`：ArkUI-X 客户端；`server/`：建议的后端目录，实际名称以仓库为准。
- 一个功能或修复使用一个分支，通过 Pull Request（PR）合并。
- 此前仓库规则要求 PR，并至少需要一名有写入权限的其他协作者批准；以后以 PR 页面的实际规则为准。
- 提交信息与 PR 标题采用 Conventional Commits。
- 下文的功能分支名是示例，按实际任务替换；不要把所有章节的命令一次执行。
- `git status` 显示工作区干净后，再进行切换分支、拉取或合并等操作。

日常流程：同步 main → 创建功能分支 → 修改与测试 → 提交 → 推送 → PR 审查 → 合并 → 同步 main。

## 2. 先分清这几个概念

| 名称 | 含义 |
|---|---|
| 工作区 | 你正在编辑的本地文件 |
| 暂存区（index） | 下一次 commit 准备包含的内容 |
| commit | 保存到本地 Git 历史中的一次提交 |
| push | 把本地提交上传到远端分支 |
| PR | 请求把一个分支的修改合并到另一个分支 |
| 本地 main | 你电脑上的主分支 |
| origin/main | 最近一次 fetch 得到的远端主分支位置，不是实时联网视图 |

`git add` 不上传代码，`git commit` 也不上传；只有 push 才向远端发送提交。

## 3. 第一次在一台电脑上配置

### 3.1 已有仓库：进入目录

```bash
cd /d/arkUI-X_agent/campus-agent
git status
git remote -v
```

### 3.2 新电脑：克隆一次

仅在目标位置还没有该仓库时执行，路径按自己的电脑调整。

```bash
mkdir -p /d/arkUI-X_agent
cd /d/arkUI-X_agent
git clone git@github.com:LEC544/campus-agent.git
cd campus-agent
```

使用 HTTPS 推送时按 Git Credential Manager 的提示登录；GitHub 账号密码不是 Git HTTPS 推送密码，不要把令牌写进仓库 URL。

### 3.3 设置本仓库的提交身份

将示例姓名和邮箱替换成自己的信息；可使用 GitHub 邮箱设置中提供的 noreply 邮箱。

```bash
git config user.name "你的名字"
git config user.email "你的提交邮箱"
git config --get user.name
git config --get user.email
```

这里没有加 `--global`，因此只影响当前仓库；提交身份不等于 GitHub 登录授权。

每台电脑各自配置 SDK、JDK 和 `local.properties`；不通过 Git 同步真实 `.env`、SDK 安装路径和密钥。

## 4. 每天开始：按当前任务选择

### 4.1 开始一个新功能

先执行 `git status`，如有未提交修改，先按第 9 节保存；以下操作以工作区干净为前提。

```bash
git switch main
git pull --ff-only origin main
git switch -c feat/task-list
```

`--ff-only` 只允许快进更新，不会自动制造合并提交；如果失败，停在这里，按第 11 节检查，不要继续从旧 main 创建新分支。

### 4.2 继续昨天未合并的功能

```bash
git switch feat/task-list
git pull --ff-only
```

前提是该分支已通过 `git push -u` 建立上游关系；这会同步同名功能分支，不会自动带入 main 的修改。

如果只是本机开发、远端没有新提交，拉取会提示已经是最新；同一个功能不需要每天创建新分支。

### 4.3 接手他人已推送的功能分支

在本地尚无该分支时执行：

```bash
git fetch origin
git switch -c feat/task-list --track origin/feat/task-list
```

多人一起开发时优先各自使用功能分支；若共用一个分支，应协调修改，并在开始前拉取它。

## 5. 修改后：检查、暂存、提交、推送

以下以客户端页面修改为例；先运行项目实际需要的测试或构建，再提交。

```bash
# 查看文件状态
git status

# 查看尚未暂存的已跟踪文件修改
git diff

# 暂存指定文件；换成你实际修改的路径
git add -- client/entry/src/main/ets/pages/Index.ets

# 检查下一次 commit 的具体内容
git diff --cached

# 提交到本地
git commit -m "feat(client): 实现任务列表"

# 首次推送此功能分支，并设置上游
git push -u origin feat/task-list
```

`git diff` 不显示未跟踪文件的内容；新文件应在编辑器中检查，暂存后再用 `git diff --cached` 复核。

以后在这个功能分支上增加提交，可直接运行 `git push`；现有未合并 PR 会自动包含新提交，无需再开一个 PR。

如果同一文件暂存后又被修改，需要重新 `git add` 才能把最新修改放入暂存区。

## 6. Conventional Commits 格式

```text
type(scope): 简短描述
```

| 类型 | 用途 | 示例 |
|---|---|---|
| feat | 新功能 | `feat(client): 新增课表页面` |
| fix | 修复问题 | `fix(server): 修正截止时间解析` |
| docs | 文档 | `docs: 补充本地启动步骤` |
| refactor | 不改变功能的重构 | `refactor(server): 拆分模型调用模块` |
| test | 测试 | `test(server): 添加任务提取测试` |
| chore | 日常维护 | `chore: 更新忽略规则` |
| build | 依赖与构建 | `build(client): 更新构建依赖` |
| ci | 自动检查流程 | `ci: 添加后端测试工作流` |

`scope` 可省略；本项目常用 `client`、`server`。存在不兼容变更时，用 `!` 或 `BREAKING CHANGE:` 正文说明影响。

分支名可使用 `feat/task-list`、`fix/deadline-parser`、`docs/setup-guide`；分支名不等于提交信息。

格式参考：[Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/)。

## 7. 在 GitHub 创建并合并 PR

1. 推送功能分支后，打开仓库并点击 **Compare & pull request**。
2. 确认 `base: main`，`compare: 你的功能分支`。
3. 标题使用 Conventional Commits；描述说明改了什么、为什么改、如何验证。
4. 在 Reviewers 中选择协作者；对方查看 Files changed，使用 Review changes → Approve 批准。
5. 按 PR 页提示满足检查和审查要求，再执行合并；作者不能批准自己的 PR。
6. 如果选择 Squash and merge，最终提交标题也使用 Conventional Commits。

`Open` 表示尚未合并，`Approved` 只是审查通过，紫色 `Merged` 才代表已经合并。

参考：[GitHub flow](https://docs.github.com/en/get-started/using-github/github-flow)及[仓库规则](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets)。

## 8. PR 合并后

工作区干净，且本地 main 没有独有提交时：

```bash
git switch main
git pull --ff-only origin main
```

如果同步失败，先看第 11 节，不要强推或直接硬重置。

之后从更新成功的 main 创建下一个功能分支：

```bash
git switch -c feat/course-import
```

### 可选：清理旧功能分支

确认 PR 已合并、分支没有后续未合并工作，并且其他协作者不再依赖它后，可在 GitHub PR 页面点击 **Delete branch** 删除远端分支。

切到 main 后可以尝试删除本地旧分支：

```bash
git switch main
git branch -d feat/task-list
git fetch --prune origin
```

`fetch --prune` 清理已被远端删除的分支跟踪引用，不会删除你的本地功能分支。

Squash 合并会产生新的提交编号，`git branch -d` 有时仍提示分支未合并；可以先保留，不必为清理而使用强制删除。PR 是否合并以 GitHub 状态和代码检查为准。

## 9. 工作没写完，需要临时切换

以下用 stash 保存已跟踪的修改和未跟踪文件，但不包含被忽略的 `.env` 等文件。

```bash
git stash push -u -m "临时保存任务列表开发"
git stash list
git status
```

确认工作区干净后再切换；回来时先切回原功能分支，再恢复指定记录：

```bash
git switch feat/task-list
git stash apply 'stash@{0}'
git status
```

`apply` 保留 stash 作为备份；确认文件完整、测试正常且已经安全保存后，先用 `git stash list` 核对，再删除对应记录：

```bash
git stash drop 'stash@{0}'
```

如果期间产生了更多 stash，序号可能改变。恢复冲突时先处理冲突，不要删除备份。stash 只在本机，不会随着 push 上传，也不是跨电脑备份。

## 10. 让功能分支跟上 main

PR 未合并、功能还在开发时，可以把最新 main 合并进当前功能分支；工作区应当干净。

```bash
git switch feat/task-list
git fetch origin
git merge origin/main -m "chore(client): 同步 main 最新修改"
```

如有冲突：运行 `git status` 找到冲突文件，编辑并移除冲突标记，保留双方需要的内容，测试后将实际解决的文件暂存。

```bash
# 示例路径应替换成实际冲突文件
git add -- client/entry/src/main/ets/pages/Index.ets
git commit -m "chore(client): 合并 main 并解决冲突"
git push
```

没有冲突时，merge 可能已完成提交或快进，无需再执行上面的解决冲突 commit，只需测试并 push。

若放弃本次合并，在合并仍未完成时执行：

```bash
git merge --abort
```

这会放弃此次合并中进行的冲突解决；合并前保持干净工作区更容易恢复。不要对已经成功结束的合并执行此命令。

## 11. 本项目遇到过的报错

### 11.1 GH013：Changes must be made through a pull request

原因：直接推送 main 被规则拒绝，本地提交仍然存在。

如果当前就在包含这些提交的 main，创建一个尚不存在的新分支并推送：

```bash
git switch -c feat/client-init
git push -u origin feat/client-init
```

然后在 GitHub 创建 PR。创建分支不会生成新 commit，也不用再 commit 一次。

### 11.2 main 无法快进：尤其是 Squash 合并之后

先检查，以下命令不覆盖工作区：

```bash
git status
git fetch origin
git log --oneline --graph --decorate --all -20
git log --oneline origin/main..main
git diff --stat main origin/main
```

`origin/main..main` 列出本地 main 独有的提交；Squash 后可能只是提交编号不同，不能单凭这些编号判断代码未合并。

如果已经确认 PR 合并成功，而且希望以远端 main 为基准，可保留旧 main 为备份，再重建本地 main。

执行条件：工作区干净、没有正在进行的合并或变基、`origin/main` 已更新，并且备份名称还不存在。

```bash
git switch main
git branch -m backup/main-before-sync
git switch -c main --track origin/main
```

旧提交保留在 `backup/main-before-sync`；如果它还有远端没有的工作，应另开功能分支处理，不能以为备份操作已经把代码合并到了远端。

### 11.3 功能分支 push 被拒绝：non-fast-forward

通常是别人或另一台电脑已经更新了同一远端分支；先保证本地修改已保存，再检查并合并远端修改。

```bash
git fetch origin
git log --oneline --graph --decorate --all -15
git merge origin/feat/task-list -m "chore(client): 同步远端功能分支"
```

分支名换成当前功能分支；有冲突按第 10 节处理，确认测试通过后再 `git push`。不要用强推覆盖别人的提交。

## 12. .gitignore、local.properties 与误暂存

### 12.1 根目录通用规则

```gitignore
.env
.env.*
!.env.example
local.properties
.idea/
.hvigor/
oh_modules/
node_modules/
build/
*.log
```

根目录的无路径规则会匹配各层同名文件或目录；子目录的 `.gitignore` 可以保留，但应检查是否有反向规则覆盖它。后端专用缓存等按语言补充。

`client/hvigor/` 是工程配置，应保留；`client/.hvigor/` 是构建缓存，应忽略。不要忽略整个 `.arkui-x/`，其平台源码需要协作同步。

### 12.2 检查规则和跟踪状态

```bash
git check-ignore -v --no-index client/.arkui-x/android/local.properties
git ls-files -- client/.arkui-x/android/local.properties
```

前者即使文件已被跟踪，也会检查规则匹配；后者有输出说明文件仍在索引中。最终确认要结合两条结果，不能只看规则命中。

### 12.3 文件是本次新增，误放进暂存区，还没 commit

```bash
git restore --staged -- client/.arkui-x/android/local.properties
git add -- .gitignore
git status
```

`restore --staged` 只调整暂存区，本地文件保留。先确保忽略规则生效，否则下次 add 还可能加入它。

### 12.4 文件早已提交，需要停止跟踪

确认忽略规则已补齐，在功能分支执行：

```bash
git rm --cached -- client/.arkui-x/android/local.properties
git add -- .gitignore
git diff --cached
git commit -m "chore(client): 停止跟踪本机 SDK 配置"
```

`--cached` 保留执行者的本地文件，但会提交一次仓库删除；协作者拉取该删除时，干净的已跟踪副本也可能被删除，应提前备份自己的本机配置。

忽略规则和停止跟踪都不会清除历史中的秘密；如果真实 Key 已提交或泄露，应先撤销或轮换，再按需协调清理历史。

参考：[Git ignore](https://git-scm.com/docs/gitignore)、[Git restore](https://git-scm.com/docs/git-restore)、[GitHub 敏感信息处置](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository)。

## 13. 常用检查命令速查

| 命令 | 用途 |
|---|---|
| `git status` | 查看分支、暂存和未暂存状态 |
| `git diff` | 查看已跟踪文件的未暂存修改 |
| `git diff --cached` | 查看下一次 commit 的内容 |
| `git diff --cached --stat` | 查看暂存修改的文件统计 |
| `git diff --cached --check` | 检查暂存差异中的空白问题及部分冲突标记，不代替测试 |
| `git branch --show-current` | 查看当前分支名 |
| `git branch -vv` | 查看本地分支及其上游关系 |
| `git branch -r` | 查看已获取的远端分支引用 |
| `git remote -v` | 查看远端地址 |
| `git fetch origin` | 更新远端信息，不把修改合并进工作区 |
| `git log --oneline --graph --decorate --all -15` | 查看提交关系 |
| `git show --stat HEAD` | 查看最近一次提交的文件统计 |
| `git restore --staged -- README.md` | 取消 README 暂存，保留文件修改 |

日志或 diff 进入分页显示时，按 `q` 退出。

## 14. 两台电脑或多人协作

- 每台电脑各自 clone 一份仓库，分别安装依赖和配置开发环境。
- `.env`、`local.properties` 各自维护；忽略文件不会随 clone 或 pull 传递。
- 同一功能换电脑继续：原电脑 commit 并 push，新电脑 fetch 后切换并同步对应功能分支。
- 不同功能各开分支，通过 PR 汇合；若多人改同一文件，提前协调。
- 拉取前保存工作，合并后测试；仅仅 push 成功不代表功能已经进入 main。

## 15. 使用这份手册

可将本文保存到仓库的 `docs/git-workflow.md`；若准备提交，应从最新 main 创建文档分支，并检查暂存内容。

```bash
git switch -c docs/git-workflow
git add -- docs/git-workflow.md
git diff --cached
git commit -m "docs: 添加项目 Git 协作手册"
git push -u origin docs/git-workflow
```

执行前请先手动将文档放入该路径；不要在已有未完成工作或尚未同步的分支上直接照抄。

补充参考：[Git pull](https://git-scm.com/docs/git-pull)、[Git stash](https://git-scm.com/docs/git-stash)、[Git merge](https://git-scm.com/docs/git-merge)。
