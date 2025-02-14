# Ctrl+C の検知用グローバル変数とイベントハンドラー
$global:ShutdownRequested = $false
$handler = {
    $global:ShutdownRequested = $true
    Write-Host "`nCtrl+C detected. Shutting down..."
}
[Console]::CancelKeyPress += $handler

# 監視するファイルのパス
$logFile = "C:\Users\tanaka-r\workspace\Jump\2025 214.RSD"

# サーバーのポート
$port = 12345

# TCPリスナーの作成と開始
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)
$listener.Start()
Write-Host "TCP Server started on port $port"

# メインループ：クライアント接続を待ち受ける
while (-not $global:ShutdownRequested) {
    Write-Host "Waiting for client connection..."
    try {
        $client = $listener.AcceptTcpClient()
        Write-Host "Client connected"
    } catch {
        if ($global:ShutdownRequested) { break }
        Write-Host "Error accepting client: $_"
        continue
    }
    
    try {
        $stream = $client.GetStream()
        $writer = [System.IO.StreamWriter]::new($stream)
        $writer.AutoFlush = $true

        # ファイルの新規行をクライアントに送信（起動後に追加された行のみ）
        Get-Content -Path $logFile -Wait -Tail 0 | ForEach-Object {
            if ($global:ShutdownRequested) { break }
            try {
                $writer.WriteLine($_)
            } catch {
                Write-Host "Error writing to client, assuming client disconnected."
                break
            }
        }
    } catch {
        Write-Host "Unexpected error with client connection: $_"
    } finally {
        if ($writer) { $writer.Close() }
        if ($stream) { $stream.Close() }
        if ($client) { $client.Close() }
        Write-Host "Connection closed. Waiting for next client..."
    }
}

$listener.Stop()
Write-Host "Server shut down."

