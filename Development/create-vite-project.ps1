# -------------------------------
# Step 1: Setup known variables and functions
# -------------------------------
# Absolute path to Helpers folder
$helpersFolder = Join-Path $PSScriptRoot "../Helpers"

$helperPath = Join-Path $helpersFolder "Read-KeyWithEscape.ps1"
$extensionsFile = Join-Path $helpersFolder "vs-code-extensions.txt"
$demoFilesFile = Join-Path $helpersFolder "vite-reactjs-demo-files.txt"
$templatesRoot = Join-Path $PSScriptRoot "DefaultStructure"

# Get the current user's Documents folder dynamically
$userDocuments = [Environment]::GetFolderPath("MyDocuments")

Write-Host $helpersFolder
Write-Host $helperPath
Write-Host $extensionsFile
Write-Host $demoFilesFile

# -------------------------------
# Check existence and warn
# -------------------------------
if (-not (Test-Path $helpersFolder)) {
    Write-Host "❌ Helpers folder not found: $helpersFolder" -ForegroundColor Red
} else {
    Write-Host "✅ Helpers folder found: $helpersFolder"
}

if (-not (Test-Path $helperPath)) {
    Write-Host "❌ Escape helper script not found: $helperPath" -ForegroundColor Red
} else {
    Write-Host "✅ Escape helper script found: $helperPath"
}

if (-not (Test-Path $extensionsFile)) {
    Write-Host "⚠ VS Code extensions file not found: $extensionsFile" -ForegroundColor Yellow
} else {
    Write-Host "✅ VS Code extensions file found: $extensionsFile"
}

if (-not (Test-Path $demoFilesFile)) {
    Write-Host "⚠ Demo files list not found: $demoFilesFile" -ForegroundColor Yellow
} else {
    Write-Host "✅ Demo files list found: $demoFilesFile"
}

# -------------------------------
# Load Escape helper
# -------------------------------
if (Test-Path $helperPath) {
    . $helperPath
} else {
    Write-Host "❌ Escape helper script not found at $helperPath. Exiting." -ForegroundColor Red
    exit
}

# Make sure template folder exists
if (-not (Test-Path $templatesRoot)) {
    Write-Host "❌ DefaultStructure folder not found at $templatesRoot. Exiting." -ForegroundColor Red
    exit
}


# -------------------------------
# Function to choose folder
# -------------------------------
function Choose-Folder {
    param (
        [string[]]$options,
        [string]$promptMessage
    )

    Write-Host $promptMessage
    for ($i = 0; $i -lt $options.Count; $i++) {
        Write-Host "$($i+1). $($options[$i])"
    }
    Write-Host "0. Enter custom path"

    while ($true) {
        $choice = Read-Host "Enter number of your choice (Escape to quit)"

        if ($choice -eq "0") {
            $customPath = Read-Host "Enter custom path (Escape to quit)"
            if ([string]::IsNullOrWhiteSpace($customPath)) {
                Write-Host "Invalid path. Try again." -ForegroundColor Yellow
                continue
            }
            return $customPath
        }
        elseif ([int]::TryParse($choice, [ref]$null) -and $choice -ge 1 -and $choice -le $options.Count) {
            return $options[$choice - 1]
        } else {
            Write-Host "Invalid choice. Try again." -ForegroundColor Yellow
        }
    }
}

# -------------------------------
# Step 2: Select parent directory
# -------------------------------
$parentDirs = @(
    "C:\projects",
    "C:\scripts",
    $userDocuments
)

$selectedParent = Choose-Folder -options $parentDirs -promptMessage "Select a parent directory:"

# Resolve full path
$selectedParent = [System.IO.Path]::GetFullPath($selectedParent)

# Create parent if it doesn't exist
if (-not (Test-Path $selectedParent)) {
    try {
        New-Item -ItemType Directory -Path $selectedParent -Force | Out-Null
        Write-Host "Created directory: $selectedParent" -ForegroundColor Green
    } catch {
        Write-Host "Cannot create directory: $selectedParent. Exiting." -ForegroundColor Red
        exit
    }
}

# -------------------------------
# Step 3: Select or create subfolder
# -------------------------------
$subDirs = Get-ChildItem -Path $selectedParent -Directory | ForEach-Object { $_.Name }

$selectedSub = Choose-Folder -options $subDirs -promptMessage "Select a subfolder or enter a custom folder path:"

# Resolve final path
$finalPath = Join-Path $selectedParent $selectedSub

# Create subfolder if it doesn't exist
if (-not (Test-Path $finalPath)) {
    try {
        New-Item -ItemType Directory -Path $finalPath -Force | Out-Null
        Write-Host "Created folder: $finalPath" -ForegroundColor Green
    } catch {
        Write-Host "Cannot create folder: $finalPath. Exiting." -ForegroundColor Red
        exit
    }
}

# -------------------------------
# Step 4: Final confirmation
# -------------------------------
Write-Host "`nYou have selected:" -ForegroundColor Cyan
Write-Host "Parent: $selectedParent"
Write-Host "Folder: $finalPath"

$confirm = Read-Host "Press Y to commit selection and create Vite project, any other key to exit"

if ($confirm -notin @("Y","y")) {
    Write-Host "Exiting without creating project." -ForegroundColor Red
    exit
}

# -------------------------------
# Step 5: Create Vite + React + TypeScript project
# -------------------------------
Write-Host "Creating Vite + React + TypeScript project in $finalPath..." -ForegroundColor Cyan

# Move to final path
Set-Location $finalPath

# Initialize project
npm create vite@latest . -- --template react-ts

# Install dependencies
npm install

# Load VS Code extensions for React and TypeScript
if (Test-Path $extensionsFile) {
    # Read lines that are not blank and do not start with '#'
    $extensions = Get-Content $extensionsFile | Where-Object {
        ($_ -ne "") -and (-not $_.TrimStart().StartsWith("#"))
    }
} else {
    Write-Host "VS Code extensions file not found at $extensionsFile. Skipping extension installation." -ForegroundColor Yellow
    $extensions = @()
}

# Install extensions if the are missing
Write-Host "`nInstalling VS Code extensions..." -ForegroundColor Cyan

foreach ($ext in $extensions) {
    if (-not (code --list-extensions | Select-String "^$ext$")) {
        code --install-extension $ext
        Write-Host "Installed $ext"
    } else {
        Write-Host "$ext is already installed"
    }
}

Write-Host "✅ VS Code extension setup complete!"

# -------------------------------
# Step 6: Remove the demo files
# -------------------------------
# Remove initial demo files from vite and react js templates
if (Test-Path $demoFilesFile) {
    $demoItems = Get-Content $demoFilesFile | Where-Object {
        ($_ -ne "") -and (-not $_.TrimStart().StartsWith("#"))
    }
} else {
    Write-Host "Demo files list not found at $demoFilesFile. Skipping removal." -ForegroundColor Yellow
    $demoItems = @()
}

# Remove demo files/folders
Write-Host "`nRemoving default demo files/folders..." -ForegroundColor Cyan

foreach ($item in $demoItems) {
    $fullPath = Join-Path $finalPath $item
    if (Test-Path $fullPath) {
        Remove-Item $fullPath -Recurse -Force
        Write-Host "Removed $fullPath"
    } else {
        Write-Host "Skipping $fullPath (not found)"
    }
}

# -------------------------------
# Step 7: Populate project from templates
# -------------------------------
Write-Host "`nCreating minimal project structure..." -ForegroundColor Cyan

# Recursively get all .txt template files
$templateFiles = Get-ChildItem -Path $templatesRoot -Recurse -File -Filter "*.txt"

foreach ($template in $templateFiles) {
    # Relative path of the template file from the DefaultStructure folder
    $relativePath = $template.FullName.Substring($templatesRoot.Length + 1)

    # Remove the .txt suffix to get the final path in project
    $relativePathWithoutTxt = $relativePath -replace "\.txt$",""

    # Full path in the project
    $destinationPath = Join-Path $finalPath $relativePathWithoutTxt

    # Ensure the folder exists
    $destinationDir = Split-Path $destinationPath -Parent
    if (-not (Test-Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    # Copy content from template to project file
    Copy-Item -Path $template.FullName -Destination $destinationPath -Force

    Write-Host "✅ Created $destinationPath"
}


# -------------------------------
# Step 8: Update index.html title
# -------------------------------
$indexHtmlPath = Join-Path $finalPath "index.html"

# Vite default index.html is usually in the project root
if (-not (Test-Path $indexHtmlPath)) {
    # If not found, check public/index.html (Vite sometimes uses public/)
    $indexHtmlPath = Join-Path $finalPath "public\index.html"
}

if (Test-Path $indexHtmlPath) {
    # Read current content
    $htmlContent = Get-Content $indexHtmlPath -Raw

    # Replace <title>...</title> with GymFury
    if ($htmlContent -match "<title>.*?</title>") {
        $htmlContent = [regex]::Replace($htmlContent, "<title>.*?</title>", "<title>GymFury</title>")
        Set-Content -Path $indexHtmlPath -Value $htmlContent -Force
        Write-Host "Updated <title> in $indexHtmlPath to 'GymFury'"
    } else {
        Write-Host "No <title> tag found in $indexHtmlPath. You may need to edit manually." -ForegroundColor Yellow
    }
} else {
    Write-Host "index.html not found. Cannot update <title>." -ForegroundColor Yellow
}


Write-Host "`n🎉 Minimal GymFury project setup complete!" -ForegroundColor Green
Write-Host "➡ Location: $finalPath"
Write-Host "➡ Run with: npm run dev"

