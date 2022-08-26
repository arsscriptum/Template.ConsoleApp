<#
#̷𝓍   𝓐𝓡𝓢 𝓢𝓒𝓡𝓘𝓟𝓣𝓤𝓜 
#̷𝓍 
#̷𝓍   <guillaumeplante.qc@gmail.com>
#̷𝓍   https://arsscriptum.github.io/  
#>

[CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [String]$Path,
        [Parameter(Mandatory=$false)]
        [Switch]$Quiet
    )  


$Script:PrivateScripts = @( Get-ChildItem -Path $Path -Filter '*.ps1' -File ).Fullname
$Script:PrivatesCount = $Script:PrivateScripts.Count

$Script:ImportErrors = 0
$Script:CurrentIndex = 0
#Dot source the files
Foreach ($FilePath in $Script:PrivateScripts) {
    Try {
        $Script:CurrentIndex++
        . "$FilePath"
        Write-Verbose "✅ $FilePath [$Script:CurrentIndex/$Script:PrivatesCount]"
    }  
    Catch {
        $Script:ImportErrors++
        Write-Host "❗❗❗ $FilePath [$Script:CurrentIndex/$Script:PrivatesCount]" -f DarkYellow -n
        Write-Host " ERRORS [$Script:ImportErrors/$Script:PrivatesCount]" -f DarkRed
        
    }
}

if($Global:ImportErrors -gt 0){
    Write-Host -n "❗❗❗ "
    Write-Host "$Script:ImportErrors errors on $Script:CurrentIndex scripts loaded." -f DarkYellow
}


 
