function Read-KeyWithEscape {
    param (
        [string]$Prompt
    )

    while ($true) {
        Write-Host $Prompt -NoNewline
        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        if ($key.VirtualKeyCode -eq 27) {   # Escape key
            $confirmEscape = Read-Host "`nEscape pressed. Are you sure you want to exit? (Y/N)"
            if ($confirmEscape -in @("Y", "y")) {
                Write-Host "Exiting script." -ForegroundColor Red
                exit
            } else {
                Write-Host "Continuing..." -ForegroundColor Yellow
                continue
            }
        }

        return $key.Character
    }
}
