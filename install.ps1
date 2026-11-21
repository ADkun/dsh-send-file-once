# install.ps1 - 把 skills/send-file-once 安装到用户全局技能目录 ~/.dsh/skills/send-file-once
# 用法：在仓库根执行  pwsh -File .\install.ps1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$src  = Join-Path $here 'skills\send-file-once'
$dest = Join-Path $env:USERPROFILE '.dsh\skills\send-file-once'
if (-not (Test-Path (Join-Path $src 'SKILL.md'))) { throw "找不到 $src\SKILL.md，请在仓库根运行本脚本" }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force

# 拷完按 MANIFEST 逐文件核对 sha256：安装副本必须与仓库逐字节一致
$manifestPath = Join-Path $src 'MANIFEST.json'
if (Test-Path $manifestPath) {
  $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
  $bad = @()
  foreach ($p in $manifest.files.PSObject.Properties) {
    $dst = Join-Path $dest $p.Name
    if (-not (Test-Path -LiteralPath $dst)) { $bad += ($p.Name + ' 缺失'); continue }
    $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $dst).Hash.ToLower()
    if ($h -ne $p.Value.sha256) { $bad += ($p.Name + ' 哈希不符') }
  }
  if ($bad.Count -gt 0) { throw ('安装校验失败: ' + ($bad -join '；')) }
  $props = @($manifest.files.PSObject.Properties)
  Write-Host ('MANIFEST 校验通过：v' + $manifest.version + '，' + $props.Count + ' 个文件逐字节一致')
  $known = @($props.Name) + @('MANIFEST.json')
  Get-ChildItem -Recurse -File $dest | ForEach-Object {
    $rel = $_.FullName.Substring($dest.Length + 1).Replace('\','/')
    if ($known -notcontains $rel) { Write-Host ('  注意：目标目录有清单外文件 ' + $rel) }
  }
}
Write-Host "已安装到: $dest"
Write-Host "包含文件:"
Get-ChildItem -Recurse -File $dest | ForEach-Object { Write-Host ("  " + $_.FullName.Substring($dest.Length + 1)) }
