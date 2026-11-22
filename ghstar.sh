#!/bin/sh
# ghstar.sh —— 查看 GitHub 仓库 Star 数
# 兼容 ZeroTermux / Termux / Ubuntu（POSIX sh，dash 也能跑）
# SPDX-License-Identifier: MIT
# License: MIT · https://github.com/deekoz2/Ghstar/blob/main/LICENSE
#
# 依赖: curl
#   Termux/ZeroTermux:  pkg install curl
#   Ubuntu/Debian:      apt install curl
#
# 用法:
#   sh ghstar.sh torvalds/linux                     查一个仓库
#   sh ghstar.sh torvalds/linux rust-lang/rust      批量查
#   sh ghstar.sh https://github.com/torvalds/linux  贴完整链接也行
#   sh ghstar.sh torvalds                           汇总某用户全部公开仓库
#
# 可选: export GITHUB_TOKEN=ghp_xxx
#   匿名接口限额 60 次/小时，设 token 后 5000 次/小时
# 可选: export GHSTAR_API=镜像地址
#   连不上 api.github.com 时换成代理/镜像

API="${GHSTAR_API:-https://api.github.com}"
UA="ghstar-sh/1.0"
TMP=""
http_code=""

cleanup() { [ -n "$TMP" ] && rm -f "$TMP"; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM

# 发请求: $1=URL；响应体写入 $TMP，状态码存 http_code
gh_get() {
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    http_code=$(curl -sSL --user-agent "$UA" \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -o "$TMP" -w '%{http_code}' "$1")
  else
    http_code=$(curl -sSL --user-agent "$UA" \
      -H "Accept: application/vnd.github+json" \
      -o "$TMP" -w '%{http_code}' "$1")
  fi
}

# 从 JSON 取字符串字段: $1=文件 $2=字段名
jstr() {
  sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -n 1
}

# 从 JSON 取某数字字段的所有出现: $1=文件 $2=字段名，每行一个
jnum_all() {
  tr ',{}' '\n\n\n' < "$1" |
    sed -n 's/.*"'"$2"'"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p'
}

# 1234567 -> 1,234,567
thou() {
  n=$1
  case $n in ''|*[!0-9]*) printf '%s' "$n"; return ;; esac
  out=""
  while [ "${#n}" -gt 3 ]; do
    out=",$(printf '%s' "$n" | tail -c 3)$out"
    n=${n%???}
  done
  printf '%s%s' "$n" "$out"
}

die_http() { # $1=名字 $2=HTTP 状态码
  case $2 in
    404) printf '✗ %s：不存在（名字错了或是私有仓库）\n' "$1" ;;
    403) printf '✗ %s：接口限额用完（403），可 export GITHUB_TOKEN=xxx 后重试\n' "$1" ;;
    401) printf '✗ %s：token 无效（401）\n' "$1" ;;
    000) printf '✗ %s：连不上 GitHub，检查网络，或 export GHSTAR_API=镜像地址\n' "$1" ;;
    *)   printf '✗ %s：请求失败（HTTP %s）\n' "$1" "$2" ;;
  esac
  return 1
}

# 查单个仓库
repo_stars() {
  r=$(printf '%s' "$1" | tr -d ' \t\r\n' | sed -E \
    -e 's#^[Hh][Tt][Tt][Pp][Ss]?://##' \
    -e 's#^git@github\.com:##' \
    -e 's#^www\.##' \
    -e 's#^github\.com/##' \
    -e 's#\.git$##' \
    -e 's#/*$##')
  case $r in
    */*) ;;
    *) printf '✗ %s：格式应为 owner/repo\n' "$1"; return 1 ;;
  esac
  owner=${r%%/*}
  name=${r#*/}
  case $name in */*) name=${name%%/*} ;; esac
  [ -n "$owner" ] && [ -n "$name" ] || {
    printf '✗ %s：格式应为 owner/repo\n' "$1"; return 1
  }

  gh_get "$API/repos/$owner/$name" || { die_http "$owner/$name" "${http_code:-000}"; return 1; }
  [ "$http_code" = 200 ] || { die_http "$owner/$name" "$http_code"; return 1; }

  stars=$(jnum_all "$TMP" stargazers_count | head -n 1)
  forks=$(jnum_all "$TMP" forks_count | head -n 1)
  watch=$(jnum_all "$TMP" subscribers_count | head -n 1)
  issues=$(jnum_all "$TMP" open_issues_count | head -n 1)
  desc=$(jstr "$TMP" description)
  : ${stars:=0} ${forks:=0} ${watch:=0} ${issues:=0}

  printf '★ %s/%s\n' "$owner" "$name"
  printf '  Star %s · Fork %s · Watch %s · Issue %s\n' \
    "$(thou "$stars")" "$(thou "$forks")" "$(thou "$watch")" "$(thou "$issues")"
  [ -n "$desc" ] && printf '  %s\n' "$desc"
}

# 汇总某用户全部公开仓库的 star
user_stars() {
  u=$(printf '%s' "$1" | tr -d ' \t\r\n' | sed -E \
    -e 's#^[Hh][Tt][Tt][Pp][Ss]?://##' \
    -e 's#^www\.##' \
    -e 's#^github\.com/##' \
    -e 's#^@##' \
    -e 's#\.git$##' -e 's#/*$##')
  case $u in */*) u=${u%%/*} ;; esac
  [ -n "$u" ] || { printf '✗ %s：请给用户名\n' "$1"; return 1; }

  total=0; repos=0; page=1
  while [ "$page" -le 10 ]; do
    gh_get "$API/users/$u/repos?per_page=100&page=$page" || {
      die_http "$u" "${http_code:-000}"; return 1
    }
    [ "$http_code" = 200 ] || { die_http "$u" "$http_code"; return 1; }
    n=$(tr ',{}' '\n\n\n' < "$TMP" | grep -c '"full_name"')
    [ "$n" -eq 0 ] && break
    for s in $(jnum_all "$TMP" stargazers_count); do
      total=$((total + s))
    done
    repos=$((repos + n))
    [ "$n" -lt 100 ] && break
    page=$((page + 1))
  done
  printf '👤 %s：公开仓库 %d 个 · Star 总计 %s\n' "$u" "$repos" "$(thou "$total")"
}

usage() {
  cat <<'EOF'
ghstar.sh —— 查看 GitHub 仓库 Star

用法: sh ghstar.sh <仓库|用户名> [更多...]
  sh ghstar.sh torvalds/linux                     # 一个仓库
  sh ghstar.sh torvalds/linux rust-lang/rust      # 批量
  sh ghstar.sh https://github.com/torvalds/linux  # 完整链接
  sh ghstar.sh torvalds                           # 某用户全部公开仓库合计

可选:
  export GITHUB_TOKEN=ghp_xxx   # 限额 60次/时 -> 5000次/时
  export GHSTAR_API=镜像地址    # 连不上时换镜像
依赖: curl（Termux/ZeroTermux: pkg install curl）
EOF
}

main() {
  command -v curl >/dev/null 2>&1 || {
    echo "缺少 curl，请先安装:"
    echo "  Termux/ZeroTermux:  pkg install curl"
    echo "  Ubuntu/Debian:      apt install curl"
    exit 1
  }
  [ $# -ge 1 ] || { usage; exit 1; }

  TMP=$(mktemp 2>/dev/null) || TMP="${TMPDIR:-$HOME}/ghstar.$$"
  : > "$TMP" 2>/dev/null || { echo "无法创建临时文件"; exit 1; }

  rc=0; sep=""
  for a in "$@"; do
    case $a in
      -h|--help|help) usage ;;
      */*) [ -n "$sep" ] && printf '\n'; sep=1; repo_stars "$a" || rc=1 ;;
      *)   [ -n "$sep" ] && printf '\n'; sep=1; user_stars "$a" || rc=1 ;;
    esac
  done
  exit $rc
}
main "$@"
