# 1. Configurações Iniciais e Permissões
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -ErrorAction SilentlyContinue

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ScriptDir

$destPath = "C:\Program Files\Hytale"
$zipName = "Hytale.zip"
$tempExtractPath = "$env:TEMP\HytaleTemp"

Add-Type -AssemblyName System.Windows.Forms

# 2. Localizar e Desbloquear o ZIP
$zipPath = Join-Path -Path $ScriptDir -ChildPath $zipName
if (-not (Test-Path $zipPath)) {
    $FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $FileBrowser.Filter = "Arquivos Zip (*.zip)|*.zip"
    if ($FileBrowser.ShowDialog() -eq "OK") { $zipPath = $FileBrowser.FileName } else { exit }
}
Unblock-File -Path $zipPath -ErrorAction SilentlyContinue

# 3. Ler versão dentro do ZIP (Busca Inteligente)
$shell = New-Object -ComObject Shell.Application
$zipFile = $shell.NameSpace($zipPath)
Start-Sleep -Milliseconds 500

# Procura por qualquer item que comece com "version" e tenha números (ignora a extensão .txt se estiver oculta)
$zipVersionItem = $zipFile.Items() | Where-Object { $_.Name -match "^version\s*[\d\.]+" } | Select-Object -First 1

if (-not $zipVersionItem) {
    $listaDeArquivos = ($zipFile.Items() | ForEach-Object { $_.Name }) -join ", "
    [System.Windows.Forms.MessageBox]::Show("Erro: Arquivo version nao encontrado!`n`nArquivos lidos: $listaDeArquivos", "Erro de Identificacao")
    exit
}

# Extrai apenas os números da versão
$newVersionStr = ($zipVersionItem.Name -replace "(?i)^version\s*", "" -replace "(?i)\.txt$", "").Trim()
# Garante a conversão para número independente da região (Ponto vs Vírgula)
$newVersion = [double]::Parse($newVersionStr, [System.Globalization.CultureInfo]::InvariantCulture)

# 4. Verificar versão instalada
if (-not (Test-Path $destPath)) { New-Item -ItemType Directory -Path $destPath -Force | Out-Null }
$installedFiles = Get-ChildItem -Path $destPath -Filter "version *.txt"
$oldVersion = 0.0
if ($installedFiles) {
    $oldVersion = ($installedFiles | ForEach-Object { 
        $v = ($_.Name -replace "version ", "" -replace ".txt", "").Trim()
        [double]::Parse($v, [System.Globalization.CultureInfo]::InvariantCulture)
    } | Measure-Object -Maximum).Maximum
}

# 5. Processo de Instalação
if ($oldVersion -lt $newVersion) {
    Write-Host "Atualizando: $oldVersion -> $newVersion" -ForegroundColor Yellow
    Add-MpPreference -ExclusionPath $destPath -ErrorAction SilentlyContinue

    try {
        if (Test-Path $tempExtractPath) { Remove-Item $tempExtractPath -Recurse -Force }
        Get-ChildItem -Path $destPath -Filter "version *.txt" | Remove-Item -Force

        Write-Host "Extraindo arquivos..." -ForegroundColor Gray
        Expand-Archive -Path $zipPath -DestinationPath $tempExtractPath -Force

        Write-Host "Movendo arquivos (Robocopy)..." -ForegroundColor Cyan
        robocopy $tempExtractPath $destPath /E /IS /IT /NC /NFL /NDL /NJH /NJS /R:0 /W:0 | Out-Null

        Remove-Item $tempExtractPath -Recurse -Force
        [System.Windows.Forms.MessageBox]::Show("Jogo atualizado com sucesso!`nVersao: $newVersion", "Hytale Installer")
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Erro na instalacao: $_", "Erro")
    }
} else {
    [System.Windows.Forms.MessageBox]::Show("O jogo ja esta na versao mais recente ($oldVersion).", "Hytale Installer")
}

# 6. Atalhos e Nick
$WshShell = New-Object -ComObject WScript.Shell
$DesktopPath = [System.Environment]::GetFolderPath("Desktop")

$LnkLauncher = $WshShell.CreateShortcut("$DesktopPath\Hytale Launcher.lnk")
$LnkLauncher.TargetPath = "$destPath\HytaleLauncher.exe"; $LnkLauncher.WorkingDirectory = $destPath; $LnkLauncher.Save()

$LnkNick = $WshShell.CreateShortcut("$DesktopPath\Mudar Nick Hytale.lnk")
$LnkNick.TargetPath = "$destPath\mudar_nick.exe"; $LnkNick.WorkingDirectory = $destPath; $LnkNick.Save()

if ([System.Windows.Forms.MessageBox]::Show("Deseja trocar de nick agora?", "Hytale", "YesNo", "Question") -eq "Yes") {
    Start-Process -FilePath "$destPath\mudar_nick.exe" -WorkingDirectory $destPath
}