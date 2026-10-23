#!/usr/bin/env bash
# 把 gitcode.com/cann/pypto.git 镜像到 GitHub（本机兜底方案，走 SSH，不需要 PAT）
#
# 用法: ./sync-local.sh
# 环境变量:
#   PYPTO_UPSTREAM     上游地址，默认 https://gitcode.com/cann/pypto.git
#   PYPTO_MIRROR_REPO  目标地址，默认 git@github.com:kaishaoshao/pypto.git
#   PYPTO_MIRROR_WORK  持久缓存目录，默认 ~/.cache/pypto-mirror

set -euo pipefail

UPSTREAM="${PYPTO_UPSTREAM:-https://gitcode.com/cann/pypto.git}"
MIRROR="${PYPTO_MIRROR_REPO:-git@github.com:kaishaoshao/pypto.git}"
WORK="${PYPTO_MIRROR_WORK:-$HOME/.cache/pypto-mirror}"
BARE="$WORK/upstream.git"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

mkdir -p "$WORK"

# 防止两次运行重叠（手动跑的时候定时器也触发了）
exec 9>"$WORK/.sync.lock"
if ! flock -n 9; then
  log "上一次同步还在进行，跳过本次。"
  exit 0
fi

git config --global http.postBuffer 524288000 2>/dev/null || true
git config --global http.lowSpeedLimit 100 2>/dev/null || true
git config --global http.lowSpeedTime 300 2>/dev/null || true

if [ ! -d "$BARE" ]; then
  log "首次运行，初始化本地裸仓库…"
  git init --bare -q "$BARE"
fi

# 只跟踪 refs/heads/* 和 refs/tags/*。
# 绝不能用 clone --mirror：GitCode 会广播 8000+ 个 refs/tmp/* 临时 ref，
# 全抓下来会让仓库从 58MB 膨胀到 422MB，且 push --mirror 到 GitHub 会被拒绝。
git -C "$BARE" remote get-url origin >/dev/null 2>&1 || git -C "$BARE" remote add origin "$UPSTREAM"
git -C "$BARE" remote set-url origin "$UPSTREAM"
git -C "$BARE" config --unset-all remote.origin.fetch 2>/dev/null || true
git -C "$BARE" config remote.origin.fetch '+refs/heads/*:refs/heads/*'
git -C "$BARE" config --add remote.origin.fetch '+refs/tags/*:refs/tags/*'

# 清理历史遗留的非法 ref（比如之前用 --mirror 克隆过留下的 refs/tmp/*）
stray=$(git -C "$BARE" for-each-ref --format='%(refname)' | grep -v -E '^refs/(heads|tags)/' || true)
if [ -n "$stray" ]; then
  log "清理 $(printf '%s\n' "$stray" | wc -l) 个遗留的非 heads/tags ref…"
  printf '%s\n' "$stray" | sed 's/^/delete /' | git -C "$BARE" update-ref --stdin
fi

log "增量抓取上游 ref（--prune 会同步上游已删除的分支和 tag）…"
git -C "$BARE" fetch --prune --no-tags origin

log "推送到 $MIRROR …"
git -C "$BARE" push --mirror "$MIRROR"

log "完成。"
git -C "$BARE" for-each-ref --format='%(refname)' | sed 's#refs/##' | awk -F/ '{print "  " $1}' | sort | uniq -c
log "本地缓存体积: $(du -sh "$BARE" | cut -f1)"
