# install.ps1 - 把 skills/send-file-once 安装到用户全局技能目录 ~/.dsh/skills/send-file-once
# 用法：在仓库根执行  pwsh -File .\install.ps1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $here 'skills\send-file-once'
$dest = Join-Path $env:USERPROFILE '.dsh\skills\send-file-once'
if (-not (Test-Path (Join-Path $src 'SKILL.md'))) { throw "找不到 $src\SKILL.md，请在仓库根运行本脚本" }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force
Write-Host "已安装到: $dest"
Write-Host "包含文件:"
Get-ChildItem -Recurse -File $dest | ForEach-Object { Write-Host ("  " + $_.FullName.Substring($dest.Length + 1)) }
