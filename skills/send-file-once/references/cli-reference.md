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
| --out | read-file | 当前目录原文件名 | 保存路径 |

## 关键行为
- send / send-file 的**链接只打到 stdout**；read / read-file 的「剩余次数 / 已销毁」回执打到 stderr，所以 stdout 始终可管道。
- read-file 不给 --out 时，存到**当前目录、用原文件名**（本技能建议总是显式 --out，便于定位）。
- 文本链接形如 `https://1time.io/v/#...`；文件链接形如 `https://1time.io/f/#...`（本技能按 /f/ 与 /v/ 区分）。
- 口令也可用环境变量 `1TIME_PASSPHRASE` 传入（本技能即用此法，避免口令进入 argv）。

## 本技能封装（scripts/otf.sh）相对原始 CLI 的增益
- 发送前校验文件存在与大小上限（默认 250MiB，`--max-mb` 可调），超限直接报错不发。
- 规范输出：人类可读块，或 `--json` 单行 JSON（ok / url / kind / path / bytes / expires / views / passphrase）。
- 口令经 `env 1TIME_PASSPHRASE` 交给 1time，不进 argv。
- `read --out` 自动创建父目录。
- `doctor` 自检依赖。

## 退出码（otf.sh）
0 成功 | 2 用法/校验错误（缺文件、超限、参数错）| 3 上传或下载失败 | 4 依赖缺失（缺 1time）

## 自建实例
```
bash scripts/otf.sh send --file ./x --host https://你的域名
bash scripts/otf.sh send --file ./x --host http://127.0.0.1:8080
```
自建仓库：github shingrus/1time.io（Go + Redis + 静态前端，docker compose）。
