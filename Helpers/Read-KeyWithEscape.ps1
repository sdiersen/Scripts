function Read-KeyWithEscape {
    param (
        [string]$Prompt
    )

    Write-Host $Prompt -NoNewline

    $inputBuffer = ""

    while ($true) {
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        # Escape key
        if ($key.VirtualKeyCode -eq 27) {
            $confirm = Read-Host "`nEscape pressed. Exit script? (Y/N)"
            if ($confirm -in @("Y","y")) {
                Write-Host "Exiting script." -ForegroundColor Red
                exit
            }
            Write-Host $Prompt -NoNewline
            Write-Host $inputBuffer -NoNewline
            continue
        }

        # Enter -> return full string
        if ($key.VirtualKeyCode -eq 13) {
            Write-Host ""
            return $inputBuffer
        }

        # Backspace
        if ($key.VirtualKeyCode -eq 8) {
            if ($inputBuffer.Length -gt 0) {
                $inputBuffer = $inputBuffer.Substring(0, $inputBuffer.Length - 1)
                $host.UI.RawUI.CursorPosition = @{
                    X = $host.UI.RawUI.CursorPosition.X - 1
                    Y = $host.UI.RawUI.CursorPosition.Y
                }
                Write-Host " " -NoNewline
                $host.UI.RawUI.CursorPosition = @{
                    X = $host.UI.RawUI.CursorPosition.X - 1
                    Y = $host.UI.RawUI.CursorPosition.Y
                }
            }
            continue
        }

        # Normal characters
        if ($key.Character) {
            $inputBuffer += $key.Character
            Write-Host $key.Character -NoNewline
        }
    }
}
