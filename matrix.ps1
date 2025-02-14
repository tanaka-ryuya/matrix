# 監視するファイルのパス
$logFile = "C:\Users\tanaka-r\workspace\Jump\2025 214.RSD"

# サーバーのポート
$port = 12345
$listener = $null
$client = $null
$stream = $null
$writer = $null

# 停止フラグ（使用していないが、将来的な拡張用）
$stopEvent = [System.Threading.ManualResetEvent]::new($false)

# Ctrl+C 監視用のバックグラウンドジョブ
$stopJob = Start-Job -ScriptBlock {
    $Host.UI.RawUI.FlushInputBuffer()  # 余計な入力を削除
    while ($true) {
        Start-Sleep -Milliseconds 100
        if ($Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.VirtualKeyCode -eq 0x43 -and $key.ControlKeyState -match "Control") {
                Write-Host "`nCtrl+C detected. Shutting down..."
                Exit 1
            }
        }
    }
}

try {
    # TCPリスナーを開始（ポートが使用中ならエラー）
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
    $listener.Start()
    Write-Host "TCP Server started on port $port"

    # クライアントの接続待ち
    $client = $listener.AcceptTcpClient()
    Write-Host "Client connected"

    # ネットワークストリームを取得
    $stream = $client.GetStream()
    $writer = [System.IO.StreamWriter]::new($stream)
    $writer.AutoFlush = $true  # 自動フラッシュ

    # ファイルの内容をリアルタイムで監視（起動後に追加された行のみ送信）
    Get-Content -Path $logFile -Wait -Tail 0 | ForEach-Object {
        if ($stopJob.State -eq "Completed") { break }  # Ctrl+C を検知したらループを抜ける
        $writer.WriteLine($_)
    }
} catch [System.Net.Sockets.SocketException] {
    Write-Host "Error: Port $port is already in use. Please use a different port."
} catch {
    Write-Host "Unexpected error: $_"
} finally {
    # クリーンアップ処理
    Write-Host "Closing connections..."
    if ($writer) { $writer.Close() }
    if ($stream) { $stream.Close() }
    if ($client) { $client.Close() }
    if ($listener) { $listener.Stop() }
    Write-Host "Server shut down."
    Stop-Job $stopJob -Force
    Remove-Job $stopJob
}

