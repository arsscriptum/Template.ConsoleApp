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
    
    Invoke-Robocopy -Source "$Script:TemplatePath" -Destination "$DestinationPath" -SyncType 'MIRROR' -ExcludeDir @('.git', '.vs') -ExcludeFiles @('__PROJECT_NAME__.vcxproj', '__PROJECT_NAME__.vcxproj.filters') -Log "$LogFile" 

    $Script:BuildCfgFile = Join-Path $Script:TemplatePath "buildcfg.ini"
    $Script:ProjectFile = Join-Path $Script:TemplatePath "vs\__PROJECT_NAME__.vcxproj"
    $Script:FiltersFile = Join-Path $Script:TemplatePath "vs\__PROJECT_NAME__.vcxproj.filters"
    $Script:ConfigsFile = Join-Path $Script:TemplatePath "vs\cfg\winapp.props"
    $Script:DejaInsFile = Join-Path $Script:TemplatePath "vs\cfg\dejainsight.props"
    $Script:MainFile = Join-Path $TemplatePath "src\main.cpp"

    $Script:NewBuildCfgFile = Join-Path $DestinationPath "buildcfg.ini"
    $Script:NewProjectFile = Join-Path $DestinationPath "vs\$($ProjectName).vcxproj"
    $Script:NewFiltersFile = Join-Path $DestinationPath "vs\$($ProjectName).vcxproj.filters"
    $Script:NewConfigsFile = Join-Path $DestinationPath "vs\cfg\winapp.props"
    $Script:NewDejaInsFile = Join-Path $DestinationPath "vs\cfg\dejainsight.props"
    $Script:NewMainFile = Join-Path $DestinationPath "src\main.cpp"
    $Script:ProjectFiles =    @($Script:BuildCfgFile,   $Script:ProjectFile,    $Script:FiltersFile,    $Script:ConfigsFile,        $Script:DejaInsFile,    $Script:MainFile)
    $Script:NewProjectFiles = @($Script:NewBuildCfgFile,$Script:NewProjectFile, $Script:NewFiltersFile, $Script:NewConfigsFile ,    $Script:NewDejaInsFile, $Script:NewMainFile)

    For($x = 0 ; $x -lt $ProjectFiles.Count ; $x++){
        $file = $ProjectFiles[$x]
        $newfile = $NewProjectFiles[$x]
        
        $Null = Remove-Item -Path $newfile -Force -ErrorAction Ignore
        $Null = New-Item -Path $newfile -ItemType File -Force -ErrorAction Ignore
        $exist = Test-Path -Path $file -PathType Leaf
      
        if($exist -eq $False){    
            throw "Missing $file"
        }
        

        Write-Verbose "Get-Content -Path `"$file`" -Raw"
        $FileContent = Get-Content -Path "$file" -Raw
        if($FileContent -eq $null){ throw "INVALID File $file" }

        Write-Verbose "`$FileContent.IndexOf('__PROJECT_NAME__')"
        $i = $FileContent.IndexOf('__PROJECT_NAME__')
        if($i -ge 0){
            Write-Verbose "Replacing '__PROJECT_NAME__' to '$ProjectName'"
            $FileContent = $FileContent -Replace '__PROJECT_NAME__', $ProjectName    
        }
        $i = $FileContent.IndexOf('__PROJECT_GUID__')
        if($i -ge 0){
            Write-Verbose "Replacing '__PROJECT_GUID__' to '$Guid'"
            $FileContent = $FileContent -Replace '__PROJECT_GUID__', $Guid
        }
        $i = $FileContent.IndexOf('__BINARY_NAME__')
        if($i -ge 0){
            Write-Verbose "Replacing '__BINARY_NAME__' to '$BinaryName'"
            $FileContent = $FileContent -Replace '__BINARY_NAME__', $BinaryName
        }

        Write-Host "Generating '$newfile'" -f DarkYellow
        Set-Content -Path $newfile -Value $FileContent
    }



    <#
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

    #>
    
}catch{
    $ErrorOccured = $True
    Show-ExceptionDetails $_ -ShowStack
}finally{
    if($ErrorOccured -eq $False){
        Write-Host "`n[SUCCESS] " -ForegroundColor DarkGreen -n
        
        $exp = (Get-Command 'explorer.exe').Source
        &"$exp" "$DestinationPath"

        pushd "$DestinationPath"
        . "./Build.bat"
        
    }else{
        Write-Host "`n[FAILED] " -ForegroundColor DarkRed -n
        Write-Host "Script failure" -ForegroundColor Gray
    }
}





        
        
    