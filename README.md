# pypto-mirror

把 [`https://gitcode.com/cann/pypto.git`](https://gitcode.com/cann/pypto.git) 完整镜像到
[`Learn-Compiler/pypto`](https://github.com/Learn-Compiler/pypto)，由 GitHub Actions 定时自动更新。

- 镜像内容：**12 个分支 + 全部 tag**（master、9.1.0、9.2.0、v9.2.0 等），共约 **58 MB**
  （GitCode 会额外广播 8000+ 个临时 ref，那些是 364 MB 垃圾，已排除）
- 同步频率：每 2 小时（UTC `17 */2 * * *`，即北京时间 02:17 / 04:17 / … / 00:17）
- 增量判断：先比对两边 ref，完全一致就跳过克隆，**不重复下载 58 MB**
- 严格镜像：上游删掉的分支/tag，镜像里也会被删掉

---

## 为什么需要两个仓库

GitHub 的 `schedule` 触发器**只在仓库默认分支的 workflow 文件上生效**。而镜像推送会强制覆盖默认分支、
把 workflow 文件自己删掉 —— 下一轮定时就没了。所以拆成两个：

| 仓库 | 作用 | 可见性 |
|---|---|---|
| `Learn-Compiler/pypto` | **纯镜像**，打开就是 PyPTO 源码，默认分支 `master` | Public |
| `Learn-Compiler/pypto-mirror` | 只放本 workflow（就是当前这个目录），不放代码 | 建议 Public |

> 两个都建议 Public：Public 仓库的 Actions 分钟数完全不计费；Private 仓库按分钟计费（组织免费额度
> 2000 分钟/月），每次跑 2~5 分钟、一天 12 次的话会吃掉大半额度。配置仓库里没有任何秘密
> （PAT 存在 Secrets 里），公开没风险。

---

## 一次性配置

### 第 1 步：确认两个仓库

1. `Learn-Compiler/pypto` —— 你已经建了，**不用管它现在是空的还是有 README**
2. 建 `Learn-Compiler/pypto-mirror`：<https://github.com/organizations/Learn-Compiler/repositories/new>
   - 名字填 `pypto-mirror`，选 Public
   - **不要**勾 "Add a README file"（勾了也能用，只是多一个要删的分支）

> ⚠️ 别把 GitHub 给的 `git init` / `git remote add origin .../pypto.git` 那段命令跑在
> `~/.dsh/ungrouped/pypto-mirror` 目录里 —— 那会把配置仓库的 origin 指到镜像仓库上去。

### 第 2 步：建 PAT（组织的坑在这里）

打开 <https://github.com/settings/personal-access-tokens/new>

- **Token name**: `pypto-mirror-sync`
- **Expiration**: 90 天（到期要换）
- **Resource owner** / **Repository access**: 选 `Only select repositories` → 勾 **`Learn-Compiler/pypto`**
- **Permissions**：

  | 权限 | 级别 | 用途 |
  |---|---|---|
  | Contents | Read and write | 推送分支和 tag |
  | Workflows | Read and write | 上游将来若加 `.github/workflows` 也能推过去 |
  | Administration | Read and write | 自动把默认分支设成 `master` |

**如果选不到 `Learn-Compiler` 的仓库**，说明组织禁用了 fine-grained PAT。两条路：

- 让组织管理员去 `Learn-Compiler` → Settings → Personal access tokens 打开 fine-grained 支持
- 或者改用 **classic PAT**（<https://github.com/settings/tokens/new>，勾 `repo` + `workflow` 两个 scope）。
  classic PAT 权限粒度粗（能吃你所有仓库），但免去组织审批。

生成后复制那串 token（**只显示一次**）。

### 第 3 步：存成 secret

在 **`Learn-Compiler/pypto-mirror`** 仓库：Settings → Secrets and variables → Actions →
New repository secret

- Name: `MIRROR_PAT`
- Secret: 粘贴 token

### 第 4 步：推配置仓库

```bash
cd ~/.dsh/ungrouped/pypto-mirror
git remote add origin git@github.com:Learn-Compiler/pypto-mirror.git
git push -u origin main
```

（你的 SSH key 已认证为 `kaishaoshao`，对组织仓库有写权限就能推。）

### 第 5 步：手动跑一次

`pypto-mirror` → Actions → **Sync pypto from GitCode** → Run workflow（首次勾 `force`）。

第一次约 58 MB，通常 1~3 分钟。日志里应该依次出现：

```
✅ 分支和 tag 已推送
✅ 默认分支 = master
共清理 1 个残留 ref          ← 如果你之前推过 main，这里会看到删掉它
```

然后打开 <https://github.com/Learn-Compiler/pypto>，会看到 PyPTO 的 README，分支下拉 12 个分支、
Tags 里 12 个 tag。

---

## 你之前那段 `git init` 命令怎么处理

那段命令在镜像仓库上跑过也没关系 —— workflow 会自动收拾：

| 那段命令做的事 | 会影响镜像吗 | 处理方式 |
|---|---|---|
| 建了 `main` 分支 + 一个 README commit | 会 | workflow 推完 `master` 后**自动删掉 `main`**，不用手动清 |
| 把默认分支设成 `main` | 会 | workflow 用 API 切回 `master` |
| `git remote add origin .../pypto.git` | 看你跑在哪 | 如果跑在配置仓库目录里，执行 `git remote set-url origin git@github.com:Learn-Compiler/pypto-mirror.git` |

顺带说：**镜像仓库里不要放你自己的东西**（README、CI、脚本都行不通），
`push --mirror` 语义下它们每 2 小时就会被清掉。要写说明就写在 `pypto-mirror` 这个仓库里。

---

## 日常使用

```bash
git clone --branch master https://github.com/Learn-Compiler/pypto.git
git clone --branch v9.2.0 https://github.com/Learn-Compiler/pypto.git

# 看上游领先了多少
git clone https://github.com/Learn-Compiler/pypto.git && cd pypto
git remote add upstream https://gitcode.com/cann/pypto.git
git fetch upstream && git log --oneline HEAD..upstream/master | head
```

改频率：编辑 `.github/workflows/sync-pypto.yml` 的 `cron`（UTC 时间）后 push 即可。

---

## 注意事项

**许可证**：pypto 用的是 **CANN Open Software License Agreement Version 2.0**，不是 Apache/MIT 这类标准
开源协议。3.3 条款允许分发，但要求「向接收方提供协议副本、保留所有声明」—— `LICENSE` 随镜像保留，
满足要求；2.1 条款把使用范围限定在华为 AI 处理器生态内。建议在仓库 About 写清
「上游镜像，版权归华为，许可见 LICENSE」，避免别人误以为是你自己的项目。

**别用 `git clone --mirror`**：GitCode 会广播 8168 个 `refs/tmp/*` 临时 ref（网页端操作留下的），
`clone --mirror` 会把它们连同 364 MB 垃圾对象一起抓下来；而推回 GitHub 时，GitHub 只接受
`refs/heads/*` 和 `refs/tags/*`，遇到 `refs/tmp/*` 会直接报错拒绝推送。本仓库的做法是
`git init --bare` + 显式 refspec 只取 heads 和 tags —— 体积 58 MB、10 秒拉完。
（网上大多数「gitcode 同步 github」教程都用 `clone --mirror`，在这个仓库上会失败，别照抄。）

**别删 `master`**：它是默认分支，删了之后 `push --mirror` 会因为「不能删除当前默认分支」被 GitHub 拒绝。
workflow 已经把顺序改成「先推 ref → 再切默认分支 → 最后清理残留」，正常不会碰到。

**GitCode 从海外访问**：runner 在美国，拉 gitcode 可能比本机慢很多，甚至偶发超时。日志里如果
`git fetch` 报 `Connection timed out` / `early EOF`，说明链路不通 —— 见下面兜底方案。

**PAT 到期 / 组织权限变更**：到期后同步会以 401/403 失败，Actions 里出现红色 ✗，
换个新 token 更新 `MIRROR_PAT` 即可。

---

## 兜底：改在本机跑（GitHub 拉不动 GitCode 时）

本机实测克隆只要 10 秒，比 runner 快得多，SSH key 已配好，**不需要 PAT**：

```bash
# 手动跑一次（首次全量到 ~/.cache/pypto-mirror，之后都是增量）
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

本地方案是增量 fetch，没更新时 0.5 秒跑完、几乎零流量。
两种方式可以同时开着：谁先跑完，另一边下一轮的 ref 比对就发现无差异、自动跳过。
