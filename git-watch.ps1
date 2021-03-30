$duration_in_seconds = 2
$autosave_message = "autosave"
$target_branch = "deployed"

If (-Not (Get-Command git -errorAction SilentlyContinue)) {
  Write-Output "Error: git is not installed"
  Exit 1
}

if ($args.Count -eq 0) {
  $target_dir = $PSScriptRoot
} else {
  $target_dir = $args[0]
}

if (-Not (Test-Path $target_dir)) {
  Write-Output "Error: Invalid directory '$target_dir'"
  Exit 1
}

function getCurrentDate() {
  $currentDate = Get-Date
  return "{0:yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'}" -f $currentDate
}

try {
  Push-Location $target_dir

  if (-Not (Test-Path ".git")) {
    Write-Output "Error: Invalid git respository '$target_dir'"
    Exit 1
  }

  if ($duration_in_seconds -lt 0) {
    Write-Output "Error: Invalid duration '$duration_in_seconds', value must be >= 0";
    Exit 2
  }

  $base_commit = git rev-parse HEAD 2>$null
  if ($LASTEXITCODE -eq 128) {
    Write-Output "Warning: Creating initial commit for new git repository"
    git commit --allow-empty -m "initial commit"
    $base_commit = git rev-parse HEAD 2>$null
  }

  $base_commit = $base_commit.Substring(0,7)
  $current_date = getCurrentDate

  $script_name = $MyInvocation.MyCommand.Name
  $repository = git rev-parse --show-toplevel
  Write-Output "$script_name
--------------------------------------------------
      Started: $current_date
     Duration: Every $duration_in_seconds second(s)
   Repository: $repository ($base_commit)
--------------------------------------------------"

  while ($true) {
    $files_changed = (git status -s)

    if (-Not [String]::IsNullOrEmpty($files_changed)) {
      $current_branch = git rev-parse --abbrev-ref HEAD
      git add -AN
      git commit -am $autosave_message --quiet 2>$null
      git push origin $target_branch
      git log --format="%C(auto)[$current_branch %h] %s" -n 1 --stat
      Write-Output ""
    }

    Start-Sleep -Seconds $duration_in_seconds
  }
} finally {
  git log "$base_commit...HEAD" --format="%C(auto) %h %s (%cd)" --date=relative
  Pop-Location
}
