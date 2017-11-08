# Fail on error
$ErrorActionPreference = "Stop"

# Customize this variable
${localappdata_company_directory} = "Omnis Software"
# End customization

function usage {
    Write-Host "Usage: omniscli.ps1 [path to omnis exe] [command] [arg1] [...] [argN]"
    Exit 1
}

# Check usage
if (${args}.Length -lt 2) {
    usage
}

# Check path to Omnis and get the command
${path_to_omnis}, ${command}, ${omniscli_args} = ${args}
if (-not (Test-Path ${path_to_omnis})) {
    Write-Host "${path_to_omnis} is not a valid path"
    usage
}

# Build omniscli arguments, quoted
${quoted_args} = "'" + ${omniscli_args} -join "' '" + "'"
$env:OMNISCLI_ARGUMENTS = ${command} + ' ' + ${quoted_args}

# Get paths
${omnis_directory} = Split-Path -parent ${path_to_omnis}
${omnis_directory_name} = (Get-Item ${omnis_directory}).Name
${path_to_run} = "${env:LOCALAPPDATA}\${localappdata_company_directory}\${omnis_directory_name}\run"

${path_to_stdout} = "${path_to_run}\stdout.txt"
${path_to_stderr} = "${path_to_run}\stderr.txt"
${path_to_exitstatus} = "${path_to_run}\exitstatus.txt"

function clean_run_directory {
    if (Test-Path ${path_to_stdout}) { Remove-Item ${path_to_stdout} -Force }
    if (Test-Path ${path_to_stderr}) { Remove-Item ${path_to_stderr} -Force}
    if (Test-Path ${path_to_exitstatus}) { Remove-Item ${path_to_exitstatus} -Force }
}

# Clean run directory
clean_run_directory

# Initialize run directory
if (-not (Test-Path ${path_to_run})) {
    New-Item -ItemType Directory -Path ${path_to_run} | Out-Null
}

New-Item -ItemType File ${path_to_stdout} | Out-Null
New-Item -ItemType File ${path_to_stderr} | Out-Null

# Tail stdout and stderr

# Launch Omnis
${omnis_process_info} = New-Object System.Diagnostics.ProcessStartInfo
${omnis_process_info}.FileName = ${path_to_omnis}
${omnis_process} = New-Object System.Diagnostics.Process
${omnis_process}.StartInfo = ${omnis_process_info}
${omnis_process}.Start() | Out-Null

# Open stdout
${stdout_file_stream} = New-Object System.IO.FileStream(${path_to_stdout}, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
${stdout_reader} = New-Object System.IO.StreamReader(${stdout_file_stream})
${stdout_writer} = New-Object System.IO.StreamWriter([System.Console]::OpenStandardOutput())

# Open stderr
${stderr_file_stream} = New-Object System.IO.FileStream(${path_to_stderr}, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
${stderr_reader} = New-Object System.IO.StreamReader(${stderr_file_stream})
${stderr_writer} = New-Object System.IO.StreamWriter([System.Console]::OpenStandardError())

function flushStream ([System.IO.StreamReader]${file_stream}, [System.IO.StreamWriter]${output}) {
    while (-not ${file_stream}.EndOfStream) {
        ${output}.Write([char]${file_stream}.Read())
    }
}

function flushConsole {
    flushStream -file_stream ${stdout_reader} -output ${stdout_writer}
    flushStream -file_stream ${stderr_reader} -output ${stderr_writer}
}

# Wait for Omnis to finish and output tail results
while (-not ${omnis_process}.HasExited) {
    flushConsole
    Start-Sleep -m 100
}

# Close stdout and stderr
flushConsole

${stdout_reader}.Close()
${stdout_file_stream}.Close()
${stdout_writer}.Close()

${stderr_reader}.Close()
${stderr_file_stream}.Close()
${stderr_writer}.Close()

# Get the exit status
if (-not (Test-Path ${path_to_exitstatus})) {
    Write-Error "Exit Status file not found at ${path_to_exitstatus}"
    ${exit_status} = 1
} else {
    ${exit_status} = Get-Content ${path_to_exitstatus}
}

# Clean up
clean_run_directory

# Return final exit status
Exit ${exit_status}