
function New-RandomFilename{
<#
    .SYNOPSIS
            Create a RandomFilename 
    .DESCRIPTION
            Create a RandomFilename 
#>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Path = "$ENV:Temp",
        [Parameter(Mandatory=$false)]
        [string]$Extension = 'tmp',
        [Parameter(Mandatory=$false)]
        [int]$MaxLen = 6,
        [Parameter(Mandatory=$false)]
        [switch]$CreateFile,
        [Parameter(Mandatory=$false)]
        [switch]$CreateDirectory
    )    
    try{
        if($MaxLen -lt 4){throw "MaxLen must be between 4 and 36"}
        if($MaxLen -gt 36){throw "MaxLen must be between 4 and 36"}
        [string]$filepath = $Null
        [string]$rname = (New-Guid).Guid
        Write-Verbose "Generated Guid $rname"
        [int]$rval = Get-Random -Minimum 0 -Maximum 9
        Write-Verbose "Generated rval $rval"
        [string]$rname = $rname.replace('-',"$rval")
        Write-Verbose "replace rval $rname"
        [string]$rname = $rname.SubString(0,$MaxLen) + '.' + $Extension
        Write-Verbose "Generated file name $rname"
        if($CreateDirectory -eq $true){
            [string]$rdirname = (New-Guid).Guid
            $newdir = Join-Path "$Path" $rdirname
            Write-Verbose "CreateDirectory option: creating dir: $newdir"
            $Null = New-Item -Path $newdir -ItemType "Directory" -Force -ErrorAction Ignore
            $filepath = Join-Path "$newdir" "$rname"
        }
        $filepath = Join-Path "$Path" $rname
        Write-Verbose "Generated filename: $filepath"

        if($CreateFile -eq $true){
            Write-Verbose "CreateFile option: creating file: $filepath"
            $Null = New-Item -Path $filepath -ItemType "File" -Force -ErrorAction Ignore 
        }
        return $filepath
        
    }catch{
        Write-Error $_
    }
}


function Invoke-Robocopy {
    <#
    .SYNOPSIS
        Copy a directory to a destination directory using ROBOCOPY.
    .DESCRIPTION
        Backup a directory will copy all te files from the source directory but will not remove missing files
        on a second iteration, like a MIRROR/SYNC would   
    .DESCRIPTION
        Invoke ROBOCOPY to copy files, a wrapper.
    .PARAMETER Source
        Source Directory (drive:\path or \\server\share\path).
    .PARAMETER Destination
        Destination Dir  (drive:\path or \\server\share\path).
    .PARAMETER SyncType 
        One of the following operating procedures:
        'MIR'    ==> MIRror a directory tree (equivalent to /E plus /PURGE), delete dest files/dirs that no longer exist in source.
        'COPY'   ==> It will leave everything in destination, but will add new files fro source, usefull to merge 2 folders
        'NOCOPY' ==> delete dest files/dirs that no longer exist in source. do not copy new, keep same.
        Default  ==> MIRROR
    .PARAMETER Log
        Log File name
    .PARAMETER BackupMode
        copy files in restartable mode.; if access denied use Backup mode.
        Requires Admin privileges to add user rights.        
    .PARAMETER Test
        Simulation: dont copy (like what if, but will call Start-Process)        
    .EXAMPLE 
       Sync-Directories $dst $src -SyncType 'NOCOPY'
       Sync-Directories $src $dst -SyncType 'MIRROR' -Verbose
       Sync-Directories $src $dst -Test
#>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateScript({
            if(-Not ($_ | Test-Path) ){
                throw "File or folder does not exist"
            }
            if(-Not ($_ | Test-Path -PathType Container) ){
                throw "The Path argument must be a Directory. Files paths are not allowed."
            }
            return $true 
        })]
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('s', 'src')]
        [String]$Source,
        [Parameter(Mandatory=$true,Position=1)]
        [Alias('d', 'dst')]
        [String]$Destination,
        [Parameter(Mandatory=$false)]
        [String[]]$ExcludeDir,
        [Parameter(Mandatory=$false)]
        [String[]]$ExcludeFiles,
        [Parameter(Mandatory=$false)]
        [Alias('t', 'type')]
        [ValidateSet('MIRROR', 'COPY', 'NOCOPY')]
        [string]$SyncType,        
        [Parameter(Mandatory=$false)]
        [Alias('l')]
        [String]$Log=""
    )

    try{

        # throw errors on undefined variables
        Set-StrictMode -Version 1

        $FNameOut = New-RandomFilename -Extension 'log' -CreateDirectory
        $FNameErr = New-RandomFilename -Extension 'log' -CreateDirectory

        # make sure the given parameters are valid paths

        if (Test-Path $Destination) {
            throw "Destination Path $Destination Non-Existent"
        } 
        New-Item -Path $Destination -ItemType Directory -Force -ErrorAction Ignore | Out-null   
        $Source  = Resolve-Path $Source
        $Destination = Resolve-Path $Destination
        $ROBOCOPY = (Get-Command 'robocopy.exe').Source

        if($Log -ne ""){
            New-Item -Path $Log -ItemType File -Force -ErrorAction ignore | Out-Null
        }

        if (-Not (Test-Path -Type Container $Source))  { throw "not a container: $Source"  }
        if (-Not (Test-Path -Type Container $Destination)) { throw "not a container: $Destination" }
        if (-Not (Test-Path -Type Leaf $ROBOCOPY)) { throw "cannot find ROBOCOPY: $ROBOCOPY" }

        
        Write-Verbose "start sync $Source ==> $Destination`n`tMULTI-THERADED (8 threads)`n`t1 FAILURE ALLOWED`n`tCREATE DIRECTORY STRUCTURE`n"
        $ArgumentList = "$Source $Destination /MT:8 /R:1 /W:1 /BYTES /FP /X"

        if ($PSBoundParameters.ContainsKey('Verbose')) {
            
            Write-Verbose "Verbose OUTPUT"       
            $ArgumentList += " /V"
        }

        if ($PSBoundParameters.ContainsKey('WhatIf')) {
           
            Write-Verbose "WhatIf : Simulation; List only - don't copy, timestamp or delete any files." -f Yellow            
            $ArgumentList += " /L"
        }
        if ($PSBoundParameters.ContainsKey('ExcludeDir')) {
           
           
            Write-Verbose " /XD " 
            $ArgumentList += " /XD "
            ForEach($d in $ExcludeDir){
                $ArgumentList += "`"$d`" "
                Write-Verbose "`"$d`" "
            }          
            
        }

        if ($PSBoundParameters.ContainsKey('ExcludeFiles')) {
           
      
            Write-Verbose " /XF "
            $ArgumentList += " /XF "
            ForEach($d in $ExcludeFiles){
                $ArgumentList += "`"$d`" "
                Write-Verbose "`"$d`" "
            }          
            
        }


        if ($PSBoundParameters.ContainsKey('SyncType')) {
            if($SyncType -eq 'MIRROR'){
                $ArgumentList += " /MIR"
                
                Write-Verbose "`n`tMIRRORING : FILES WILL BE REMOVED OR ADDED TO BE N SYNC"
            }elseif($SyncType -eq 'COPY'){

                $ArgumentList += " /COPY:DAT /E"
                
                Write-Verbose "`n`tCOPY ALL file info. copy subdirectories, including Empty ones."
            }elseif($SyncType -eq 'NOCOPY'){
                $ArgumentList += " /PURGE /NOCOPY "
                
                Write-Verbose "`n`tNOCOPY"
            }else{
                throw "INVALID COPY TYPE"
            }
           
        }else{
            $ArgumentList += " /MIR "      
        }

        # Instantiate and start a new stopwatch
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

  
        if($Log -ne ""){
            $ArgumentList += " /LOG:$Log"
        }


        $ProcessArguments = @{
            FilePath = $ROBOCOPY
            ArgumentList = $ArgumentList 
            Wait = $true 
            NoNewWindow = $true
            PassThru = $true
            RedirectStandardError  = $FNameErr
            RedirectStandardOutput = $FNameOut
        }
        Write-Verbose "Start-Process $ProcessArguments"

        $awnser = 'y'#Read-Host "Press `'y`' to go"
        $process = Start-Process @ProcessArguments
      
        $handle = $process.Handle # cache proc.Handle
        $null=$process.WaitForExit();

        # This will print out False/True depending on if the process has ended yet or not
        # Needs to be called for the command below to work correctly
        $null=$process.HasExited
        $ProcessExitCode = $process.ExitCode

        [int]$elapsedSeconds = $stopwatch.Elapsed.Seconds
        $stopwatch.Stop()
        $stdErr = ''
        $stdOut = ''
        if(Test-Path $FNameOut){
            $stdOut = Get-Content -Path $FNameOut -Raw
            
            if ([string]::IsNullOrEmpty($stdOut) -eq $false) {
                $stdOut = $stdOut.Trim()
            }
        }
        if(Test-Path $FNameErr){
            $stdErr = Get-Content -Path $FNameErr -Raw
            if ([string]::IsNullOrEmpty($stdErr) -eq $false) {
                $stdErr = $stdErr.Trim()
            }
        }
        Write-Verbose "COMPLETED IN $elapsedSeconds seconds"
    
        $returnCodeMessage = @{
            0x00 = "[INFO]: No errors occurred, and no copying was done. The source and destination directory trees are completely synchronized."
            0x01 = "[INFO]: One or more files were copied successfully (that is, new files have arrived)."
            0x02 = "[INFO]: Some Extra files or directories were detected. Examine the output log for details."
            0x04 = "[WARN]: Some Mismatched files or directories were detected. Examine the output log. Some housekeeping may be needed."
            0x08 = "[ERROR]: Some files or directories could not be copied (copy errors occurred and the retry limit was exceeded). Check these errors further."
            0x10 = "[ERROR]: Usage error or an error due to insufficient access privileges on the source or destination directories."
        }

        if( $returnCodeMessage.ContainsKey( $ProcessExitCode ) ) {
            $Message = $returnCodeMessage[$ProcessExitCode]
            Write-Host "[ROBOCOPY] " -f Blue -NoNewLine
            Write-Host "$Message" -f Gray

        }
        else {
            for( $flag = 1; $flag -le 0x10; $flag *= 2 ) {
                if( $ProcessExitCode -band $flag ) {
                    $returnCodeMessage[$flag]
                    $Message = $returnCodeMessage[$flag]
                    Write-Host "[ROBOCOPY] " -f Blue -NoNewLine
                    Write-Host "$Message" -f Gray
                }
            }
        }



    }catch {
        Show-ExceptionDetails($_) -ShowStack
    }
}


function Get-FolderSize {
    # This returns a list of all files/folders within the $path (default is current folder) and adds the total size up into human readable format.
    param(
        [parameter(ValueFromPipeline)][string]$path = ".\",
        [switch]$descending,
        [ValidateSet("Auto", "KB", "MB", "GB", "TB")][string]$sizeFormat = "Auto"
    )    
    
    $sortOptions = @{
        Property   = "Size"
        Descending = $descending
    }
    
    $results = Get-ChildItem $path | Select-Object Name, @{N = "Type"; E = { if ($_.PSIsContainer) { "Folder" }else { "File" } } }, @{N = "Size"; E = { if ($_.PSIsContainer) { ((Get-ChildItem $_ -Recurse | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum) }else { (($_ | Measure-Object -Property Length -Sum -ErrorAction Stop).Sum) } } }
    $totalSize = ($results | Measure-Object -Sum Size).Sum
    Write-Output ($results | Sort-Object @sortOptions | Select-Object -ExcludeProperty Size *, @{N = "Size"; E = { ConvertBytes $_.Size $sizeFormat } } | Out-String).Trim()
    Write-Output "`nTotal Size: $(ConvertBytes $totalSize $sizeFormat)"
}


function Compare-Directories {

    <#
      .SYNOPSIS
     
      .DESCRIPTION
     
      .EXAMPLE

    #>  

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [ValidateScript({
            if(-Not ($_ | Test-Path) ){
                throw "File or folder does not exist"
            }
            if(-Not ($_ | Test-Path -PathType Container) ){
                throw "The Path argument must be a Directory. Files paths are not allowed."
            }
            return $true 
        })]
        [Parameter(Mandatory=$true,Position=0)]
        [String]$Left,
        [ValidateScript({
            if(-Not ($_ | Test-Path) ){
                throw "File or folder does not exist"
            }
            if(-Not ($_ | Test-Path -PathType Container) ){
                throw "The Path argument must be a Directory. Files paths are not allowed."
            }
            return $true 
        })]
        [Parameter(Mandatory=$true,Position=1)]
        [String]$Right
        
    )

    # throw errors on undefined variables
    Set-StrictMode -Version 1

    # stop immediately on error
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

    # init counters
    $Items = $MissingRight = $MissingLeft = $Contentdiff = 0

    # make sure the given parameters are valid paths
    $left  = Resolve-Path $left
    $right = Resolve-Path $right

    # make sure the given parameters are directories
    if (-Not (Test-Path -Type Container $left))  { throw "not a container: $left"  }
    if (-Not (Test-Path -Type Container $right)) { throw "not a container: $right" }

    # Starting from $left as relative root, walk the tree and compare to $right.
    Push-Location $left

    try {
        Get-ChildItem -Recurse | Resolve-Path -Relative | ForEach-Object {
            $rel = $_
            
            $Items++
            
            # make sure counterpart exists on the other side
            if (-not (Test-Path $right\$rel)) {
                Write-Host "  -->  " -f DarkGreen -NoNewLine
                Write-Host "missing from right: $rel" -f White
                $MissingRight++
                return
                }
        
            # compare contents for files (directories just have to exist)
            if (Test-Path -Type Leaf $rel) {
                if ( Compare-Object (Get-Content $left\$rel) (Get-Content $right\$rel) ) {
                    Write-Host "  <" -f Magenta -NoNewLine
                    Write-Host "!" -f DarkRed -NoNewLine
                    Write-Host ">  " -f Magenta -NoNewLine
                    Write-Host "content differs   : $rel" -f White
                    $ContentDiff++
                    }
                }
            }
        }catch {
        Show-ExceptionDetails($_)
    }
    finally {
        Pop-Location
        }

    # Check items in $right for counterparts in $left.
    # Something missing from $left of course won't be found when walking $left.
    # Don't need to check content again here.

    Push-Location $right

    try {
        Get-ChildItem -Recurse | Resolve-Path -Relative | ForEach-Object {
            $rel = $_
            
            if (-not (Test-Path $left\$rel)) {
                Write-Host "  <--  " -f DarkMagenta -NoNewLine
                Write-Host "missing from left : $rel" -f White
                $MissingLeft++
                return
                }
            }
        }catch {
        Show-ExceptionDetails($_)
    }
    finally {
        Pop-Location
        }

    Write-Verbose "$Items items, $ContentDiff differed, $MissingLeft missing from left, $MissingRight from right"
}

