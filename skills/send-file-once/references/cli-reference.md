# 1time CLI 参考（v0）

> 何时读：需要确认具体 flag、默认值，或排查报错时。grep 关键词：expires-in views passphrase host read-file。

## 安装与前置
- 需 Node ≥ 20。安装：`npm install -g @1time/cli`
- 可执行名 `1time`（本技能 scripts/otf.sh 已封装，正常无需直接调用原始命令）。

## 原始命令总览
```
1time send       [--host <h>] [--expires-in <Nd|Nh>] [--views <N>] [secret]
1time read       [--host <h>] <link>
1time send-file  [--host <h>] [--expires-in <Nd|Nh>] [--views <N>] [--passphrase <p>] <path>
1time read-file  [--host <h>] [--passphrase <p>] [--out <path>] <link>
```

## 参数（默认 / 范围）
| 参数 | 适用 | 默认 | 范围与说明 |
|---|---|---|---|
| --expires-in | send, send-file | 1d | 1h–30d；h/d 单位，可组合如 2d23h |
| --views | send, send-file | 1 | 1–10；文件=可下载次数，文本=可查看次数 |
| --passphrase | send-file, read-file | 无 | 仅文件支持；文本接口无口令 |
| --host | 全部 | 1time.io | 自建实例 origin；http 仅允许回环 127.0.0.1 |
| --out | read-file | 当前目录原文件名 | 保存路径；目标已存在会被 1time 拒绝 |

## 关键行为
- send / send-file 的**链接只打到 stdout**；read / read-file 的「剩余次数 / 已销毁」回执打到 stderr，所以 stdout 始终可管道。otf.sh 两个子命令的回执同样一律走 stderr。
- read-file 不给 --out 时，存到**当前目录、用原文件名**，重名自动加 ` (1)`（本技能建议总是显式 --out，便于定位）。
- 文本链接形如 `https://1time.io/v/#...`；文件链接形如 `https://1time.io/f/#...`（本技能按 /f/ 与 /v/ 区分）。文本链接只回 stdout，`--out` / `--passphrase` 对它无效（会被忽略并在 stderr 提示）。
- 口令也可用环境变量 `1TIME_PASSPHRASE` 传入；本技能即用此法，使 1time 的 argv 里没有口令（`--passphrase` 会触发 1time 的 argv 泄露告警）。

## 本技能封装（scripts/otf.sh）相对原始 CLI 的增益
- 发送前校验文件存在与大小上限（默认 250MiB，`--max-mb` 可在 1–10240 间调），超限直接报错不发。
- 规范输出：人类可读块，或 `--json` 单行 JSON——send 出 ok / url / kind / path / bytes / expires / views / passphrase / receipt，read 出 ok / kind / text|out / receipt。read 的 `out` 恒为实际落盘路径：给了 `--out` 就是它，没给则取 1time 回报的路径。
- 口令经 `env "1TIME_PASSPHRASE=…"` 交给 1time：1time 的 argv 不含口令。`1TIME_PASSPHRASE` 以数字开头，bash 无法用 `VAR=… cmd` 前缀赋值，故只能借 `env`（口令在该进程 argv 里只存续到 exec 1time 为止）。
- `read --out` 自动创建父目录；读取失败会把这一次新建的目录回滚掉，不留空目录。
- `doctor` 自检依赖。

## 退出码（otf.sh）
0 成功 | 2 用法/校验错误（无子命令、缺文件、超限、`--max-mb`/`--views`/`--expires` 越界或形态错、`--text` 配口令、缺链接）| 3 上传或下载失败（含 1time 端拒绝：口令错、链接过期、`--out` 目标已存在，会带回它的原文；也含 1time 报成功却解析不出链接）| 4 依赖缺失（缺 1time）

## 自建实例
```
bash scripts/otf.sh send --file ./x --host https://你的域名
bash scripts/otf.sh send --file ./x --host http://127.0.0.1:8080
```
自建仓库：github shingrus/1time.io（Go + Redis + 静态前端，docker compose）。
