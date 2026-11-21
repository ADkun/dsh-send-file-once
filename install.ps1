# install.ps1 - 把 skills/send-file-once 安装到用户全局技能目录 ~/.dsh/skills/send-file-once
# 用法：在仓库根执行  pwsh -File .\install.ps1
# 做法：先拷到 <目标>.new，按 MANIFEST 逐文件核对 sha256，全部一致才替换正式目录（失败则目标目录保持原样）。
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $here 'skills\send-file-once'
$dest = Join-Path $env:USERPROFILE '.dsh\skills\send-file-once'
if (-not (Test-Path (Join-Path $src 'SKILL.md'))) { throw "找不到 $src\SKILL.md，请在仓库根运行本脚本" }

# 没有清单就没有校验，宁可装不上
$manifestPath = Join-Path $src 'MANIFEST.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw "源目录缺少 MANIFEST.json，无法校验，拒绝安装" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$props = @($manifest.files.PSObject.Properties)
if ($props.Count -lt 1) { throw "MANIFEST.json 未声明任何文件（files 为空或键名写错），拒绝安装" }

$staging = "$dest.new"
if (Test-Path -LiteralPath $staging) { Remove-Item -Recurse -Force -LiteralPath $staging }
New-Item -ItemType Directory -Force -Path $staging | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $staging -Recurse -Force

$bad = @()
foreach ($p in $props) {
  $st = Join-Path $staging $p.Name
  if (-not (Test-Path -LiteralPath $st)) { $bad += ($p.Name + ' 缺失'); continue }
  $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $st).Hash.ToLower()
  if ($h -ne $p.Value.sha256) { $bad += ($p.Name + ' 哈希不符') }
}
if ($bad.Count -gt 0) {
  Remove-Item -Recurse -Force -LiteralPath $staging
  throw ('安装校验失败: ' + ($bad -join '；') + '（源目录与 MANIFEST 不一致，目标目录未被改动）')
}

# 校验通过：整目录替换，顺带清掉旧版本残留文件
$backup = "$dest.bak"
if (Test-Path -LiteralPath $backup) { Remove-Item -Recurse -Force -LiteralPath $backup }
if (Test-Path -LiteralPath $dest) { Move-Item -LiteralPath $dest -Destination $backup }
Move-Item -LiteralPath $staging -Destination $dest
if (Test-Path -LiteralPath $backup) { Remove-Item -Recurse -Force -LiteralPath $backup }

Write-Host ('MANIFEST 校验通过：v' + $manifest.version + '，' + $props.Count + ' 个文件逐字节一致')
$known = @($props.Name) + @('MANIFEST.json')
Get-ChildItem -Recurse -File $dest | ForEach-Object {
  $rel = $_.FullName.Substring($dest.Length + 1).Replace('\','/')
  if ($known -notcontains $rel) { Write-Host ('  注意：源目录有清单外文件 ' + $rel + '（已一并安装，未受校验）') }
}
Write-Host "已安装到: $dest"
Write-Host "包含文件:"
Get-ChildItem -Recurse -File $dest | ForEach-Object { Write-Host ("  " + $_.FullName.Substring($dest.Length + 1)) }
