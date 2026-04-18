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
# Function to select folder
# -------------------------------
function Select-Folder {
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
        $choice = Read-KeyWithEscape "Enter number of your choice (Escape to quit): "

        if ($choice -eq "0") {
            $customPath = Read-KeyWithEscape "Enter custom path (Escape to quit): "
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

$selectedParent = Select-Folder -options $parentDirs -promptMessage "Select a parent directory:"

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
# Step 3: Select or create subfolder / project folder
# -------------------------------
while ($true) {
    $subDirs = Get-ChildItem -Path $selectedParent -Directory | ForEach-Object { $_.Name }

    Write-Host "Select a subfolder or enter a new folder name (this will also be the project name):"
    for ($i = 0; $i -lt $subDirs.Count; $i++) {
        Write-Host "$($i+1). $($subDirs[$i])"
    }
    Write-Host "0. Enter new folder name"

    $choice = Read-KeyWithEscape "Enter number of your choice (Escape to quit): "

    if ($choice -eq "0") {
        $selectedSub = Read-KeyWithEscape "Enter new folder name (no spaces, Escape to quit): "

        if ([string]::IsNullOrWhiteSpace($selectedSub)) {
            Write-Host "Folder name cannot be empty." -ForegroundColor Yellow
            continue
        }
        if ($selectedSub -match "\s") {
            Write-Host "Folder name cannot contain spaces." -ForegroundColor Yellow
            continue
        }
    }
    elseif ([int]::TryParse($choice, [ref]$null) -and $choice -ge 1 -and $choice -le $subDirs.Count) {
        $selectedSub = $subDirs[$choice - 1]
    } else {
        Write-Host "Invalid choice. Try again." -ForegroundColor Yellow
        continue
    }

    # Resolve final path
    $finalPath = Join-Path $selectedParent $selectedSub

    # Check if folder already exists
    if (Test-Path $finalPath) {
        Write-Host "Folder already exists: $finalPath. Please select a different name." -ForegroundColor Yellow
        continue
    }

    # Create folder
    try {
        New-Item -ItemType Directory -Path $finalPath -Force | Out-Null
        Write-Host "Created project folder: $finalPath" -ForegroundColor Green
        break
    } catch {
        Write-Host "Cannot create folder: $finalPath. Try a different name." -ForegroundColor Red
    }
}

# Use folder name as project name
$projectName = Split-Path $finalPath -Leaf
Write-Host "Project Name set to: $projectName" -ForegroundColor Cyan


# -------------------------------
# Step 4: Final confirmation
# -------------------------------
Write-Host "`nYou have selected:" -ForegroundColor Cyan
Write-Host "Parent: $selectedParent"
Write-Host "Folder: $finalPath"

$confirm = Read-KeyWithEscape "Press Y to commit selection and create Vite project, any other key to exit: "

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

# Initialize project inside the folder
npx create-vite@latest . --template react-ts --no-interactive

# -------------------------------
# Step 6: Install additional packages
# -------------------------------
$packageJsonPath = Join-Path $finalPath "package.json"
$packageJson = $null

if (Test-Path $packageJsonPath) {
    $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
}

function Get-PackageName {
    param (
        [string]$packageSpec
    )

    if ($packageSpec -match '^(?<name>@[^/]+/[^@]+|[^@]+)@') {
        return $Matches.name
    }

    return $packageSpec
}

$additionalDependencies = @(
    "axios@latest",
    "@emotion/react@latest",
    "@emotion/styled@latest",
    "@hookform/resolvers@latest",
    "@mui/icons-material@latest",
    "@mui/material@latest",
    "@mui/x-date-pickers@latest",
    "@tanstack/react-query@latest",
    "i18next@latest",
    "luxon@latest",
    "react-hook-form@latest",
    "react-i18next@latest",
    "react-router-dom@latest",
    "zod@latest"
)

$additionalDevDependencies = @(
    "@testing-library/jest-dom@latest",
    "@testing-library/react@latest",
    "@testing-library/user-event@latest",
    "@types/luxon@latest",
    "@vitest/coverage-v8@latest",
    "jsdom@latest",
    "vite-tsconfig-paths@latest",
    "vitest@latest"
)

$targetDependencyPackages = @{}
$targetDevDependencyPackages = @{}

if ($null -ne $packageJson) {
    foreach ($property in $packageJson.dependencies.PSObject.Properties) {
        $targetDependencyPackages[$property.Name] = $true
    }

    foreach ($property in $packageJson.devDependencies.PSObject.Properties) {
        $targetDevDependencyPackages[$property.Name] = $true
    }
}

foreach ($packageSpec in $additionalDependencies) {
    $targetDependencyPackages[(Get-PackageName $packageSpec)] = $true
}

foreach ($packageSpec in $additionalDevDependencies) {
    $targetDevDependencyPackages[(Get-PackageName $packageSpec)] = $true
}

$targetDependencies = $targetDependencyPackages.Keys | Sort-Object
$targetDevDependencies = $targetDevDependencyPackages.Keys | Sort-Object

Write-Host "`nInstalling project packages with exact versions..." -ForegroundColor Cyan

if ($targetDependencies.Count -gt 0) {
    npm install --save-exact $targetDependencies
}

if ($targetDevDependencies.Count -gt 0) {
    npm install -D --save-exact $targetDevDependencies
}

$codeCliPath = Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd"

if (-not (Test-Path $codeCliPath)) {
    $codeCliCommand = Get-Command code.cmd -ErrorAction SilentlyContinue
    if ($null -ne $codeCliCommand) {
        $codeCliPath = $codeCliCommand.Source
    }
}

# Load VS Code extensions for React and TypeScript
if (Test-Path $extensionsFile) {
    $extensions = Get-Content $extensionsFile | Where-Object {
        ($_ -ne "") -and (-not $_.TrimStart().StartsWith("#"))
    }
} else {
    Write-Host "VS Code extensions file not found at $extensionsFile. Skipping extension installation." -ForegroundColor Yellow
    $extensions = @()
}

# Install extensions if missing
Write-Host "`nInstalling VS Code extensions..." -ForegroundColor Cyan

if (-not (Test-Path $codeCliPath)) {
    Write-Host "VS Code CLI not found. Skipping extension installation." -ForegroundColor Yellow
} else {
    $installedExtensions = & $codeCliPath --list-extensions

    foreach ($ext in $extensions) {
        if (-not ($installedExtensions | Select-String "^$ext$")) {
            & $codeCliPath --install-extension $ext
            Write-Host "Installed $ext"
            $installedExtensions += $ext
        } else {
            Write-Host "$ext is already installed"
        }
    }
}

Write-Host "✅ VS Code extension setup complete!"

# -------------------------------
# Step 7: Remove the demo files
# -------------------------------
if (Test-Path $demoFilesFile) {
    $demoItems = Get-Content $demoFilesFile | Where-Object {
        ($_ -ne "") -and (-not $_.TrimStart().StartsWith("#"))
    }
} else {
    Write-Host "Demo files list not found at $demoFilesFile. Skipping removal." -ForegroundColor Yellow
    $demoItems = @()
}

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
# Step 8: Populate project from templates
# -------------------------------
Write-Host "`nCreating minimal project structure..." -ForegroundColor Cyan

$templateFiles = Get-ChildItem -Path $templatesRoot -Recurse -File -Filter "*.txt"

foreach ($template in $templateFiles) {
    $relativePath = $template.FullName.Substring($templatesRoot.Length + 1)
    $relativePathWithoutTxt = $relativePath -replace "\.txt$",""
    $destinationPath = Join-Path $finalPath $relativePathWithoutTxt

    $destinationDir = Split-Path $destinationPath -Parent
    if (-not (Test-Path $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    Copy-Item -Path $template.FullName -Destination $destinationPath -Force
    Write-Host "✅ Created $destinationPath"
}

# -------------------------------
# Step 9: Update index.html title
# -------------------------------
$indexHtmlPath = Join-Path $finalPath "index.html"

if (-not (Test-Path $indexHtmlPath)) {
    $indexHtmlPath = Join-Path $finalPath "public\index.html"
}

if (Test-Path $indexHtmlPath) {
    $htmlContent = Get-Content $indexHtmlPath -Raw

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
