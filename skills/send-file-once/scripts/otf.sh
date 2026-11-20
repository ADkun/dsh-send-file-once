#!/usr/bin/env bash
# otf.sh — 阅后即焚文件/文本快传黑盒脚本（封装 1time 端到端加密 CLI）
# 用法见 --help；AI 只需读 --help，不必通读实现。
set -uo pipefail

DEFAULT_MAX_MB=250
EXIT_CODE=2

usage() {
  cat <<'EOF'
otf.sh — 阅后即焚文件/文本快传（封装 1time 端到端加密 CLI）

用法:
  bash otf.sh send --file <路径> [--expires 2d] [--views 3] [--passphrase <口令>] [--host <origin>] [--json] [--max-mb 250]
  bash otf.sh send --text <一段机密文本> [--expires 2d] [--views 3] [--host <origin>] [--json]
  bash otf.sh read <一次性链接> [--out <保存路径>] [--passphrase <口令>] [--host <origin>] [--json]
  bash otf.sh doctor
  bash otf.sh --help

send   --file 与 --text 二选一。成功即在 stdout 打印 "链接: <url>"（加 --json 则输出单行 JSON）。
       文本发送不支持口令（1time 文本接口无口令参数）；文件支持口令。
read   下载并解密一次性链接（文件用 --out 指定保存路径，不给则存当前目录原文件名）。
       自动按链接区分文件(/f/#)与文本(/v/#)站点。
doctor 自检 node 版本与 1time CLI 是否可用。

参数默认与范围:
  --expires  默认 1d，范围 1h–30d，写法 2d / 23h / 2d23h
  --views    默认 1，范围 1–10（文件=可下载次数，文本=可查看次数）
  --max-mb   默认 250，单文件软上限（MiB），超出直接报错不发

退出码: 0 成功 | 2 用法/校验错误 | 3 上传或下载失败 | 4 依赖缺失
EOF
}

die(){ echo "otf: $*" >&2; exit "$EXIT_CODE"; }
to_win(){ if command -v cygpath >/dev/null 2>&1; then cygpath -w -- "$1"; else printf '%s' "$1"; fi; }
to_posix(){ if command -v cygpath >/dev/null 2>&1; then cygpath -u -- "$1"; else printf '%s' "$1"; fi; }

ONETIME=""
find_1time(){
  if [ -n "$ONETIME" ]; then return 0; fi
  if command -v 1time >/dev/null 2>&1; then ONETIME="1time"; return 0; fi
  local pfx cand
  pfx=$(npm prefix -g 2>/dev/null || true)
  if [ -n "$pfx" ]; then
    cand="$(to_posix "$pfx")/1time"
    if [ -x "$cand" ]; then ONETIME="$cand"; return 0; fi
  fi
  return 1
}
need_1time(){ find_1time || die "未找到 1time CLI。请先执行: npm install -g @1time/cli （需 Node >=20）"; }

cmd_doctor(){
  echo "node   : $(node -v 2>/dev/null || echo '缺失（需 >=20）')"
  if find_1time; then
    echo "1time  : 可用 ($ONETIME)"
    echo "--- 1time 版本/用法 ---"
    "$ONETIME" --help 2>&1 | sed -n '1,4p'
  else
    echo "1time  : 缺失 -> npm install -g @1time/cli (Node >=20)"
    return 4
  fi
}

cmd_send(){
  local file="" text="" have_text=0 expires="1d" views="1" pass="" host="" json=0 maxmb="$DEFAULT_MAX_MB"
  while [ $# -gt 0 ]; do case "$1" in
    --file)               file="$2"; shift 2;;
    --text)               text="$2"; have_text=1; shift 2;;
    --expires)            expires="$2"; shift 2;;
    --views)              views="$2"; shift 2;;
    --passphrase|--pass)  pass="$2"; shift 2;;
    --host)               host="$2"; shift 2;;
    --max-mb)             maxmb="$2"; shift 2;;
    --json)               json=1; shift;;
    -h|--help)            usage; exit 0;;
    *) die "未知参数: $1";;
  esac; done
  need_1time

  set -- --expires-in "$expires" --views "$views"
  if [ -n "$host" ]; then set -- --host "$host" "$@"; fi

  local out="" errf="/tmp/.otf_err_$$" kind="" display="" bytes="" rc=0 err=""
  if [ -n "$file" ] && [ "$have_text" = 0 ]; then
    local posix win size maxbytes sizemb
    posix="$(to_posix "$file")"; win="$(to_win "$file")"
    [ -f "$posix" ] || die "文件不存在: $file"
    size=$(wc -c < "$posix" | tr -d ' ')
    maxbytes=$(( maxmb * 1024 * 1024 ))
    if [ "$size" -gt "$maxbytes" ]; then
      sizemb=$(( size / 1024 / 1024 ))
      die "文件约 $sizemb MiB 超过上限 $maxmb MiB，请分卷或改用其他方案"
    fi
    kind="file"; bytes="$size"; display="$file"
    if [ -n "$pass" ]; then
      out=$(env "1TIME_PASSPHRASE=$pass" "$ONETIME" send-file "$@" "$win" 2>"$errf"); rc=$?
    else
      out=$("$ONETIME" send-file "$@" "$win" 2>"$errf"); rc=$?
    fi
    if [ "$rc" -ne 0 ]; then cat "$errf" >&2; rm -f "$errf"; EXIT_CODE=3; die "上传失败"; fi
    err=$(cat "$errf" 2>/dev/null); rm -f "$errf"
  elif [ "$have_text" = 1 ]; then
    local chars
    chars=$(printf '%s' "$text" | wc -c | tr -d ' ')
    kind="text"; display="机密文本($chars字符)"; bytes=0
    out=$(printf '%s' "$text" | "$ONETIME" send "$@" 2>"$errf"); rc=$?
    if [ "$rc" -ne 0 ]; then cat "$errf" >&2; rm -f "$errf"; EXIT_CODE=3; die "上传失败"; fi
    err=$(cat "$errf" 2>/dev/null); rm -f "$errf"
  else
    die "需要 --file <路径> 或 --text <内容>"
  fi

  local url
  url=$(printf '%s' "$out" | tr -d '\r' | awk 'NF{print $NF}' | tail -n1)
  case "$url" in http://*|https://*) : ;; *) die "未能解析出链接，原始输出: $out" ;; esac

  if [ "$json" = 1 ]; then
    local passflag=0; [ -n "$pass" ] && passflag=1
    OTF_URL="$url" OTF_KIND="$kind" OTF_PATH="$display" OTF_BYTES="$bytes" OTF_EXP="$expires" OTF_VIEWS="$views" OTF_PASS="$passflag" \
    node -e 'const e=process.env;process.stdout.write(JSON.stringify({ok:true,url:e.OTF_URL,kind:e.OTF_KIND,path:e.OTF_PATH,bytes:Number(e.OTF_BYTES)||0,expires:e.OTF_EXP,views:Number(e.OTF_VIEWS),passphrase:e.OTF_PASS==="1"})+"\n")'
  else
    local p="无"; [ -n "$pass" ] && p="有"
    echo "OK 一次性链接已生成（阅后即焚）"
    echo "链接: $url"
    echo "类型: $kind  $display"
    echo "有效期: $expires   可用次数: $views   口令: $p"
    echo "!! 链接 # 之后即解密钥匙，链接本身=钥匙；到期或次数用尽即自动作废，请只发给目标接收人。"
    [ -n "$err" ] && echo "回执: $err"
  fi
}

cmd_read(){
  local link="" outpath="" pass="" host="" json=0
  while [ $# -gt 0 ]; do case "$1" in
    --out)                outpath="$2"; shift 2;;
    --passphrase|--pass)  pass="$2"; shift 2;;
    --host)               host="$2"; shift 2;;
    --json)               json=1; shift;;
    -h|--help)            usage; exit 0;;
    http://*|https://*)   link="$1"; shift;;
    *) die "未知参数: $1";;
  esac; done
  need_1time
  [ -n "$link" ] || die "缺少一次性链接"

  set --
  if [ -n "$host" ]; then set -- --host "$host"; fi

  local errf="/tmp/.otf_err_$$" out="" err="" rc=0 istext=0
  case "$link" in *"/v/"*) istext=1;; esac

  if [ "$istext" = 1 ]; then
    out=$("$ONETIME" read "$@" "$link" 2>"$errf"); rc=$?
    if [ "$rc" -ne 0 ]; then cat "$errf" >&2; rm -f "$errf"; EXIT_CODE=3; die "读取失败"; fi
    err=$(cat "$errf" 2>/dev/null); rm -f "$errf"
    if [ "$json" = 1 ]; then
      OTF_TEXT="$out" RECEIPT="$err" node -e 'const e=process.env;process.stdout.write(JSON.stringify({ok:true,kind:"text",text:e.OTF_TEXT,receipt:e.RECEIPT})+"\n")'
    else
      printf '%s\n' "$out"
      [ -n "$err" ] && echo "$err" >&2
    fi
  else
    if [ -n "$outpath" ]; then
      mkdir -p "$(dirname "$(to_posix "$outpath")")" 2>/dev/null || true
      set -- "$@" --out "$(to_win "$outpath")"
    fi
    if [ -n "$pass" ]; then
      out=$(env "1TIME_PASSPHRASE=$pass" "$ONETIME" read-file "$@" "$link" 2>"$errf"); rc=$?
    else
      out=$("$ONETIME" read-file "$@" "$link" 2>"$errf"); rc=$?
    fi
    if [ "$rc" -ne 0 ]; then cat "$errf" >&2; rm -f "$errf"; EXIT_CODE=3; die "读取失败"; fi
    err=$(cat "$errf" 2>/dev/null); rm -f "$errf"
    if [ "$json" = 1 ]; then
      OTF_OUT="$outpath" RECEIPT="$err" node -e 'const e=process.env;process.stdout.write(JSON.stringify({ok:true,kind:"file",out:e.OTF_OUT,receipt:e.RECEIPT})+"\n")'
    else
      echo "OK 已解密下载"
      [ -n "$outpath" ] && echo "保存到: $outpath"
      [ -n "$out" ] && echo "$out"
      [ -n "$err" ] && echo "$err" >&2
    fi
  fi
}

if [ $# -gt 0 ]; then sub="$1"; shift; else sub=""; fi
case "$sub" in
  send)   cmd_send "$@";;
  read)   cmd_read "$@";;
  doctor) cmd_doctor;;
  -h|--help|help|"") usage;;
  *) usage; exit 2;;
esac
