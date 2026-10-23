# pypto-mirror

把 [`https://gitcode.com/cann/pypto.git`](https://gitcode.com/cann/pypto.git) 完整镜像到
`https://github.com/kaishaoshao/pypto`，由 GitHub Actions 定时自动更新。

- 镜像内容：**12 个分支 + 全部 tag**（master、9.1.0、9.2.0、v9.2.0 等），共约 **58 MB**（GitCode 会额外广播 8000+ 个临时 ref，那些占 364MB 垃圾，已排除）
- 同步频率：每 2 小时（UTC `17 */2 * * *`，即北京时间 02:17 / 04:17 / … / 00:17）
- 增量判断：先比对两边 ref，完全一致就跳过克隆，**不重复下载 58 MB**
- 严格镜像：上游删掉的分支/tag，镜像里也会被删掉

---

## 为什么需要两个仓库

GitHub 的 `schedule` 触发器**只在仓库默认分支的 workflow 文件上生效**。而镜像推送用的是
`git push --mirror`，它会强制覆盖默认分支、把 workflow 文件自己删掉 —— 下一轮定时就没了。

所以拆成两个：

| 仓库 | 作用 | 可见性 |
|---|---|---|
| `kaishaoshao/pypto` | **纯镜像**，打开就是 PyPTO 源码，默认分支 `master` | 建议 **Public** |
| `kaishaoshao/pypto-mirror` | 只放本 workflow，不放代码 | 随意 |

> 建议 Public：Public 仓库的 Actions 分钟数完全不计费；Private 仓库按分钟计费（免费额度 2000 分钟/月），
> 每次跑 2~5 分钟、一天 12 次的话会吃掉大半额度，没必要。而且 Public 别人也能直接 clone。

---

## 一次性配置（约 5 分钟）

### 第 1 步：建两个空仓库

1. 打开 <https://github.com/new>
   - Repository name: `pypto`
   - 选 **Public**
   - **不要**勾选 "Add a README file" / .gitignore / license —— 必须是完全空的仓库
2. 再打开 <https://github.com/new>
   - Repository name: `pypto-mirror`
   - 选 Private 即可（也建议 **不要**勾选 README，避免后面 push 冲突）

### 第 2 步：建一个最小权限的 PAT

打开 <https://github.com/settings/personal-access-tokens/new>

- **Token name**: `pypto-mirror-sync`
- **Expiration**: 建议 90 天（到期要换，或在到期前重新生成）
- **Repository access**: 选 `Only select repositories` → 只勾 **`kaishaoshao/pypto`**
- **Permissions**（展开 Repository permissions）：

  | 权限 | 级别 | 用途 |
  |---|---|---|
  | Contents | Read and write | 推送分支和 tag |
  | Workflows | Read and write | 上游将来若加 `.github/workflows` 也能推过去 |
  | Administration | Read and write | 自动把默认分支设成 `master`（可省，见文末） |

点 Generate token，复制那串 `github_pat_...`（**只显示一次**）。

### 第 3 步：把 token 存成 secret

在 **`pypto-mirror`** 仓库里：Settings → Secrets and variables → Actions →
New repository secret

- Name: `MIRROR_PAT`
- Secret: 粘贴上一步的 token

### 第 4 步：把本仓库推上去

本目录已经是一个 git 仓库（含首次 commit），直接：

```bash
cd ~/.dsh/ungrouped/pypto-mirror
git remote add origin git@github.com:kaishaoshao/pypto-mirror.git
git push -u origin main
```

### 第 5 步：手动跑一次验证

在 `pypto-mirror` 仓库 → Actions → 左侧 **Sync pypto from GitCode** →
右侧 **Run workflow** → 勾上 `force` → Run workflow。

第一次是完整的约 58 MB 克隆 + 推送，通常 1~3 分钟（海外链路慢时更久）。看日志确认最后出现：

```
✅ 默认分支已设为 master
```

然后打开 <https://github.com/kaishaoshao/pypto>，应该能看到 PyPTO 的 README，
分支下拉里有 12 个分支、Tags 里有 12 个 tag。

---

## 日常使用

```bash
# 只要某个版本
git clone --branch master https://github.com/kaishaoshao/pypto.git
git clone --branch v9.2.0 https://github.com/kaishaoshao/pypto.git

# 跟上游对比某天差了多少
git fetch upstream && git log --oneline HEAD..upstream/master | head
```

想改频率就编辑 `.github/workflows/sync-pypto.yml` 里的 `cron`（UTC 时间），
或直接在 GitHub 网页上改 —— 改完 push 上去即可生效。

---

## 注意事项

**许可证**：pypto 用的是 **CANN Open Software License Agreement Version 2.0**，不是 Apache/MIT 这类标准
开源协议。它的 3.3 条款允许分发，但要求「向接收方提供协议副本、保留所有声明」—— `LICENSE` 文件随镜像
一起保留，满足要求；2.1 条款把使用范围限定在华为 AI 处理器生态内。建议在 `pypto` 仓库的 About 里写清
「上游镜像，版权归华为，许可见 LICENSE」，避免别人误以为是你自己的项目。

**别用 `git clone --mirror`**：GitCode 会广播 8000+ 个 `refs/tmp/*` 临时 ref（网页端操作留下的），
`clone --mirror` 会把它们连同 364 MB 垃圾对象一起抓下来；而 `push --mirror` 到 GitHub 时，
GitHub 只接受 `refs/heads/*` 和 `refs/tags/*`，遇到 `refs/tmp/*` 会直接报错拒绝推送。
所以本仓库的做法是 `git init --bare` + 显式 refspec 只取 heads 和 tags —— 体积 58 MB、10 秒拉完。
（网上大多数「gitcode 同步 github」的教程都用 `clone --mirror`，在这个仓库上会失败，别照抄。）

**不要手动改 `pypto` 仓库**：`push --mirror` 会删掉镜像端任何上游没有的 ref，你在那建的 `main`
分 支或提交都会在下一轮被清掉。

**上游改默认分支**：如果哪天 pypto 把 master 改名，镜像会跟着变，workflow 里「设默认分支为 master」
那步会失效（只告警不影响推送），到 Settings → Branches 手动改一次即可。

**GitCode 从海外访问**：runner 在美国，拉 gitcode 可能比本机慢很多，甚至偶发超时。日志里如果
`git clone` 报 `Connection timed out` / `early EOF`，说明链路不通 —— 见下面兜底方案。

**PAT 到期**：到期后同步会以 401 失败，Actions 里会出现红色 ✗，换个新 token 更新 `MIRROR_PAT` 即可。

---

## 兜底：改在本机跑（GitHub 拉不动 GitCode 时）

本机实测克隆只要 10 秒，比 runner 快得多，而且 SSH key 已经配好了，**不需要 PAT**：

```bash
# 手动跑一次（首次会全量克隆到 ~/.cache/pypto-mirror，之后都是增量）
./scripts/sync-local.sh

# 装成每小时自动跑的 systemd timer
mkdir -p ~/.local/bin ~/.config/systemd/user
cp scripts/sync-local.sh ~/.local/bin/pypto-mirror-sync
chmod +x ~/.local/bin/pypto-mirror-sync
cp scripts/pypto-mirror.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now pypto-mirror.timer

# 看状态 / 看日志
systemctl --user list-timers pypto-mirror.timer
journalctl --user -u pypto-mirror.service -n 30 --no-pager
```

本地方案是增量 fetch，跑一次通常只要几秒（没更新时几乎 0 流量）。

两种方式可以同时开着：谁先跑完，另一边下一轮的 ref 比对就发现无差异、自动跳过。
