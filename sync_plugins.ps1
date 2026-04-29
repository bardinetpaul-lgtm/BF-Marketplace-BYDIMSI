param (
    [string]$Message = "Update plugins structure and marketplace manifest"
)

Write-Host "--- Syncing Plugins to GitHub ---" -ForegroundColor Cyan

# Check for changes
$status = git status --porcelain
if (-not $status) {
    Write-Host "No changes to sync." -ForegroundColor Yellow
    exit
}

# Add and commit
Write-Host "Adding changes..."
git add .
Write-Host "Committing changes..."
git commit -m $Message

# Push
Write-Host "Pushing to GitHub..."
git push origin main

Write-Host "Done!" -ForegroundColor Green
