<#
#̷𝓍   𝓐𝓡𝓢 𝓢𝓒𝓡𝓘𝓟𝓣𝓤𝓜 
#̷𝓍 
#̷𝓍   <guillaumeplante.qc@gmail.com>
#̷𝓍   https://arsscriptum.github.io/  
#>
function New-ProjectFromTemplate{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [String]$DestinationPath,
        [Parameter(Mandatory=$true, Position=1)]
        [String]$ProjectName,
        [Parameter(Mandatory=$false)]
        [String]$BinaryName,
        [Parameter(Mandatory=$false)]
        [switch]$Overwrite,
        [Parameter(Mandatory=$false)]
        [switch]$UseHttpLib,
        [Parameter(Mandatory=$false)]
        [switch]$UseJsonLib
    )  


    try{


        # Script Variables
        $Script:ProjectRoot = (Resolve-Path "$PSScriptRoot\..").Path
        $Script:TemplatePath = $Script:ProjectRoot
        $Script:DependenciesPath = (Resolve-Path "$PSScriptRoot\dependencies").Path
        $Script:Importer         = (Resolve-Path "$PSScriptRoot\cmdlets\Import-Dependencies.ps1").Path

        
        . "$Script:Importer" -Path "$Script:DependenciesPath"

        $Guid = (New-Guid).Guid
        $Guid = "{$Guid}"

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
        

        $ExcludeDir = @('.git', '.vs')

        if($UseJsonLib.IsPresent -eq $False){
            $ExcludeDir += "jsmn"
        }
        if($UseHttpLib.IsPresent -eq $False){
            $ExcludeDir += "cpp-httplib"
            $ExcludeDir += "openssl"
        }
       

        Invoke-Robocopy -Source "$Script:TemplatePath" -Destination "$DestinationPath" -SyncType 'MIRROR' -ExcludeDir $ExcludeDir -ExcludeFiles @('__PROJECT_NAME__.vcxproj', '__PROJECT_NAME__.vcxproj.filters') -Log "$LogFile" 

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

            $UseHttpLibValue = "0"
            if($UseHttpLib){
                $UseHttpLibValue = "1"
            }
            $UseJsonLibValue = "0"
            if($UseJsonLib){
                $UseJsonLibValue = "1"
            }
            $i = $FileContent.IndexOf('__USE_HTTPLIB__')
            if($i -ge 0){
                Write-Verbose "Replacing '__USE_HTTPLIB__' to '"
                $FileContent = $FileContent -Replace '__USE_HTTPLIB__', $UseHttpLibValue
            }
            $i = $FileContent.IndexOf('__USE_JSONLIB__')
            if($i -ge 0){
                Write-Verbose "Replacing '__USE_JSONLIB__' to '"
                $FileContent = $FileContent -Replace '__USE_JSONLIB__', $UseJsonLibValue
            }
            Write-Output "Generating '$newfile'"
            Set-Content -Path $newfile -Value $FileContent
        }

        
        
    }catch{
        $ErrorOccured = $True
        Show-ExceptionDetails $_ -ShowStack
    }finally{
        if($ErrorOccured -eq $False){
            Write-Host "===================================" -ForegroundColor Gray
            Write-Host "New-ProjectFromTemplate [SUCCESS]" -ForegroundColor DarkGreen
            Write-Host "===================================`n`n" -ForegroundColor Gray
            $exp = (Get-Command 'explorer.exe').Source
            &"$exp" "$DestinationPath"

            pushd "$DestinationPath"
            . "./Build.bat"
            popd
            
        }else{
            Write-Host "`n[FAILED] " -ForegroundColor DarkRed -n
            Write-Host "Script failure" -ForegroundColor Gray
        }
    }
}



        
        
    