<#
#̷𝓍   𝓐𝓡𝓢 𝓢𝓒𝓡𝓘𝓟𝓣𝓤𝓜 
#̷𝓍 
#̷𝓍   <guillaumeplante.qc@gmail.com>
#̷𝓍   https://arsscriptum.github.io/  
#>

[CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [String]$DestinationPath,
        [Parameter(Mandatory=$true, Position=1)]
        [String]$ProjectName,
        [Parameter(Mandatory=$false)]
        [String]$BinaryName,
        [Parameter(Mandatory=$false)]
        [switch]$Overwrite
    )  



try{


    # Script Variables
    $Script:ProjectRoot = (Resolve-Path "$PSScriptRoot\..").Path
    $Script:TemplatePath = $Script:ProjectRoot
    $Script:DependenciesPath = (Resolve-Path "$PSScriptRoot\dependencies").Path
    $Script:Importer         = (Resolve-Path "$PSScriptRoot\cmdlets\Import-Dependencies.ps1").Path
    $Script:BuildCfgFile = Join-Path $Script:TemplatePath "buildcfg.ini"
    $Script:ProjectFile = Join-Path $Script:TemplatePath "vs\__PROJECT_NAME__.vcxproj"
    $Script:FiltersFile = Join-Path $Script:TemplatePath "vs\__PROJECT_NAME__.vcxproj.filters"
    $Script:ConfigsFile = Join-Path $Script:TemplatePath "vs\cfg\winapp.props"
    $Script:DejaInsFile = Join-Path $Script:TemplatePath "vs\cfg\dejainsight.props"

    $Script:NewBuildCfgFile = Join-Path $Path "buildcfg.ini"
    $Script:NewProjectFile = Join-Path $Path "vs\$($ProjectName).vcxproj"
    $Script:NewFiltersFile = Join-Path $Path "vs\$($ProjectName).vcxproj.filters"
    $Script:NewConfigsFile = Join-Path $Path "vs\cfg\winapp.props"
    $Script:NewDejaInsFile = Join-Path $Path "vs\cfg\dejainsight.props"

    $Script:ProjectFiles = @($Script:BuildCfgFile,$Script:ProjectFile, $Script:FiltersFile, $Script:ConfigsFile, $Script:DejaInsFile)
    $Script:NewProjectFiles = @($Script:NewBuildCfgFile,$Script:NewProjectFile, $Script:NewFiltersFile, $Script:NewConfigsFile, $Script:NewDejaInsFile )

    Write-Host "=======================================================" -f DarkYellow
    Write-Host "`"$Script:Importer`" -Path `"$Script:DependenciesPath`"" -f Red
    . "$Script:Importer" -Path "$Script:DependenciesPath"


    Write-Log "Script:TemplatePath $Script:TemplatePath"
    
    $Guid = (New-Guid).Guid
    $Guid = "{$Guid}"

Write-Log "DestinationPath $DestinationPath"
    # Apply default values if required

    if($False -eq $PSBoundParameters.ContainsKey('BinaryName')){
        $BinaryName = $ProjectName
        Write-Output "BinaryName: Using default value `"$ProjectName`""
    }

    $Script:Verbose = $False
    if($PSBoundParameters.ContainsKey('Verbose')){
        $Script:Verbose = $True
    }elseif($Verbose -eq $Null){
        $Script:Verbose = $False
    }

    $ErrorOccured = $False
    $TestMode = $False
    if($PSBoundParameters.ContainsKey('WhatIf')){
        Write-Output "TESTMODE ENABLED"
        $TestMode = $true
    }

    if(Test-Path -Path $DestinationPath -PathType Container){
        if($Overwrite){
            Remove-Item "$DestinationPath" -Force -Recurse -ErrorAction Ignore | Out-Null  
        }
    }else{
        $Null = New-Item -Path $DestinationPath -ItemType Directory -Force -ErrorAction Ignore
        $Null = Remove-Item -Path $DestinationPath -Force -Recurse -ErrorAction Ignore
    }
    $s = Get-Date -uFormat %d
    $LogFile = "$ENV:Temp\log.$s.log"
    
    Invoke-Robocopy -Source "$Script:TemplatePath" -Destination "$DestinationPath" -SyncType 'MIRROR' -Exclude @('.git', '.vs') -Log "$LogFile" 

    $Logs = Get-Content $LogFile
    ForEach($l in $Logs){
        Write-Host "$l" -DarkCyan
    }


    For($x = 0 ; $x -lt $NewProjectFiles.Count ; $x++){
        $newfile = $NewProjectFiles[$x]
        if(Test-Path -Path $newfile -PathType Leaf){
            if($Overwrite){
                Remove-Item "$NewProjectFiles[$y]" -Force -ErrorAction Ignore | Out-Null ; Write-Output "DELETED `"$NewProjectFiles[$y]`"" -d;
                continue;
            }
            Write-Output "Overwrite `"$newfile`" (y/n/a) " -n
            $a = Read-Host '?'
            while(($a -ne 'y') -And ($a -ne 'n') -And ($a -ne 'a')){
                Write-Output "Please enter `"y`" , `"n`" or `"a`""
                Write-Output "Overwrite `"$newfile`" (y/n/a) " -n
                $a = Read-Host '?'
            }
            if($a -eq 'a'){  
                For($y = 0 ; $y -lt $NewProjectFiles.Count ; $y++){
                    Remove-Item "$NewProjectFiles[$y]" -Force -ErrorAction Ignore | Out-Null ; Write-Output "DELETED `"$NewProjectFiles[$y]`"" -d;
                }
                break;
            }
            elseif($a -ne 'y'){ throw "File $newfile already exists!" ; }else{ Remove-Item $newfile -Force -ErrorAction Ignore | Out-Null ; Write-Output "DELETED `"$newfile`"" -d;}
        }
    }
    For($x = 0 ; $x -lt $ProjectFiles.Count ; $x++){
        $file = $ProjectFiles[$x]
        $newfile = $NewProjectFiles[$x]
        Write-Output "Processing '$file'" -d
        $Null = Remove-Item -Path $newfile -Force -ErrorAction Ignore
        $Null = New-Item -Path $newfile -ItemType File -Force -ErrorAction Ignore
        $exist = Test-Path -Path $file -PathType Leaf
        if($Verbose){
            LogResult "CHECKING FILE `"$file`"" -Ok:$exist
        }

        
        if($exist -eq $False){    
            throw "Missing $file"
        }
        

        Write-Output "Get-Content -Path $file -Raw" -d
        $FileContent = Get-Content -Path $file -Raw
        if($FileContent -eq $null){ throw "INVALID File $file" }

        Write-Output "`$FileContent.IndexOf('__PROJECT_NAME__')" -d
        $i = $FileContent.IndexOf('__PROJECT_NAME__')
        if($i -ge 0){
            Write-Output "Replacing '__PROJECT_NAME__' to '$ProjectName'" -d
            $FileContent = $FileContent -Replace '__PROJECT_NAME__', $ProjectName    
        }
        $i = $FileContent.IndexOf('__PROJECT_GUID__')
        if($i -ge 0){
            Write-Output "Replacing '__PROJECT_GUID__' to '$Guid'" -d
            $FileContent = $FileContent -Replace '__PROJECT_GUID__', $Guid
        }
        $i = $FileContent.IndexOf('__PROJECT_GUID__')
        if($i -ge 0){
            Write-Output "Replacing '__BINARY_NAME__' to '$BinaryName'" -d
            $FileContent = $FileContent -Replace '__BINARY_NAME__', $BinaryName
        }


        
        Write-Output "Saving '$newfile'"
        Set-Content -Path $newfile -Value $FileContent
    }
    
}catch{
    $ErrorOccured = $True
    Show-ExceptionDetails $_ -ShowStack
}finally{
    if($ErrorOccured -eq $False){
        Write-Host "`n[SUCCESS] " -ForegroundColor DarkGreen -n
        if($TestMode){
            Write-Host "test success! You can rerun in normal mode" -ForegroundColor Gray
        }else{
            Write-Host "Project generated in $Path" -ForegroundColor Gray    
            $exp = (Get-Command 'explorer.exe').Source
            &"$exp" "$Path"
        }
    }else{
        Write-Host "`n[FAILED] " -ForegroundColor DarkRed -n
        Write-Host "Script failure" -ForegroundColor Gray
    }
}





        
        
    