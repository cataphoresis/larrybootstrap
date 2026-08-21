param(
    [Parameter(Mandatory)][string]$PackageId,
    [Parameter(Mandatory)][string]$ResultPath,
    [Parameter(Mandatory)][string]$LogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = [Security.Principal.WindowsPrincipal]::new($Identity)
$Elevated = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
$ContextLines = @(
    "[CONTEXT] User=$($Identity.Name)"
    "[CONTEXT] Elevated=$Elevated"
)

if ($Elevated) {
    [IO.File]::WriteAllLines(
        $LogPath,
        $ContextLines + "Refusing to run WinGet with an elevated token.",
        [Text.UTF8Encoding]::new($false)
    )
    [IO.File]::WriteAllText(
        $ResultPath, "740", [Text.UTF8Encoding]::new($false)
    )
    exit 740
}

$WinGet = (Get-Command winget.exe -ErrorAction Stop).Source
$Arguments = @(
    "install", "--id", $PackageId, "--exact", "--scope", "user",
    "--accept-package-agreements", "--accept-source-agreements",
    "--disable-interactivity"
)
$StartInfo = [Diagnostics.ProcessStartInfo]::new()
$StartInfo.FileName = $WinGet
$StartInfo.UseShellExecute = $false
$StartInfo.CreateNoWindow = $true
$StartInfo.RedirectStandardOutput = $true
$StartInfo.RedirectStandardError = $true
foreach ($Argument in $Arguments) {
    [void]$StartInfo.ArgumentList.Add($Argument)
}

$Process = [Diagnostics.Process]::new()
$Process.StartInfo = $StartInfo
$ExitCode = 1

try {
    [void]$Process.Start()
    $OutputTask = $Process.StandardOutput.ReadToEndAsync()
    $ErrorTask = $Process.StandardError.ReadToEndAsync()
    $Process.WaitForExit()
    $Output = $OutputTask.GetAwaiter().GetResult()
    $ErrorOutput = $ErrorTask.GetAwaiter().GetResult()
    [IO.File]::WriteAllText(
        $LogPath,
        ($ContextLines -join [Environment]::NewLine) +
            [Environment]::NewLine + $Output + $ErrorOutput,
        [Text.UTF8Encoding]::new($false)
    )
    $ExitCode = $Process.ExitCode
}
catch {
    [IO.File]::WriteAllText(
        $LogPath,
        ($ContextLines -join [Environment]::NewLine) +
            [Environment]::NewLine + $_.Exception.Message,
        [Text.UTF8Encoding]::new($false)
    )
}
finally {
    $Process.Dispose()
    [IO.File]::WriteAllText(
        $ResultPath, $ExitCode.ToString(), [Text.UTF8Encoding]::new($false)
    )
}

exit $ExitCode
