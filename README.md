# dsh-send-file-once

> 一次性文件快传技能：把文件或一段敏感文本，变成一条**阅后即焚**的端到端加密下载链接。DSH 可用，封装 [1time](https://1time.io) CLI。

上传后得到一个链接，通过链接即可下载；支持**限次数（下载 N 次即失效）**与**限时间（1h–30d 到期失效）**，可选口令，零知识加密（服务器只见密文）。

## 特性
- 一条命令生成一次性链接，`#` 之后即解密钥匙。
- 阅后即焚：`--views` 1–10 次、`--expires` 1h–30d。
- 端到端加密 + 可选口令（口令与链接分通道）。
- 单文件默认 ≤ 250 MiB（`--max-mb` 可调；1time 客户端会整文件读进内存再按 4MiB 分片上传）；文本经脚本内部 stdin 交给 1time（调用侧 argv 仍可见，勿留日志）。
- 无状态、可自建（1time 开源）。

## 前置
- Node.js ≥ 20
- 1time CLI：`npm install -g @1time/cli`

## 安装到本机 DSH
```
pwsh -File .\install.ps1
```
等价于把 `skills/send-file-once/` 整目录拷到 `~/.dsh/skills/send-file-once`，DSH 启动后自动识别为技能。

## 作为 DSH 技能使用
装好后无需记命令，直接自然语言即可，例如：

> 把这个文件发给他，限下载一次，明天前取。

技能会自动按最严默认（1 天 / 1 次）生成链接并交付。

## 命令行用法（scripts/otf.sh）
```
# 发文件：3 天后失效、可下 2 次、加口令
bash scripts/otf.sh send --file <路径> --expires 3d --views 2 --passphrase <口令>

# 发一段机密文本
bash scripts/otf.sh send --text '<密钥或恢复码>'

# 对方取件
bash scripts/otf.sh read 'https://1time.io/f/#...' --out <保存路径>

# 自检依赖
bash scripts/otf.sh doctor
```

### 参数
| 参数 | 适用 | 默认 | 说明 |
|---|---|---|---|
| --expires | send | 1d | 1h–30d，可写 2d / 23h / 2d23h |
| --views | send | 1 | 1–10 次（文件=下载次数，文本=查看次数） |
| --passphrase | send --file / read | 无 | 仅文件支持；口令另走通道 |
| --out | read | 当前目录原文件名 | 保存路径；已存在则拒绝，未给时重名自动加 (1) |
| --host | 全部 | 1time.io | 自建实例，http 仅回环 |
| --max-mb | send --file | 250 | 单文件软上限 MiB，超出拒绝 |
| --json | send / read | 关 | 输出单行 JSON |

### 退出码
`0` 成功 · `2` 用法/校验错误 · `3` 上传/下载失败 · `4` 依赖缺失（未装 1time）

## 安全
- 链接的 `#` 之后就是解密钥匙，**链接本身即秘密**，只发给目标本人。
- 端到端加密：内容在本地加密后才上传，服务器只见密文与令牌哈希。
- `--text` / `--passphrase` 的取值在调用侧仍是 argv（对话记录、shell 历史、进程列表可见）：脚本只护住最后一跳，极敏内容先加密成文件再发。
- 口令与链接必须走**两条不同通道**，否则等于未加密。
- 不要把链接贴进公开群、工单、日志或截图。

## 目录结构
```
.
├─ .gitattributes                  # 统一按 LF 存取（脚本与清单哈希都依赖行尾）
├─ install.ps1                     # 安装到 ~/.dsh/skills
├─ skills/send-file-once/
│  ├─ SKILL.md                     # 技能主文件（触发 + 工作流 + 红线）
│  ├─ MANIFEST.json                # 文件清单与校验
│  ├─ scripts/otf.sh               # 封装脚本（send/read/doctor）
│  ├─ references/                  # CLI 参考 + 运维手册
│  └─ examples/send-example.md
└─ README.md
```

## 致谢
- 加密与一次性链接由 [1time](https://1time.io) 提供（开源自建：github shingrus/1time.io）。
