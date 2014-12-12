param(
    [string]$OutputDir,
    [string]$RootDir
    )
$OutputDir = if( [String]::IsNullOrWhiteSpace($OutputDir) ) { '..\vcproj' } else { $OutputDir }
$RootDir = if( [String]::IsNullOrWhiteSpace($RootDir) ) { '..' } else { $RootDir }

function Read-Makefile($Path)
{
    $lines = (Get-Content -Path $Path) -as [string[]]
    $hash = @{}
    foreach($line in $lines)
    {
        if( $line -match '\s*([A-Za-z_][0-9A-Za-z_]*)\s*=\s*(.*)' )
        {
            $hash[$matches[1]] = $matches[2]
        }
    }
    return $hash
}

function New-Guid()
{
    return [Guid]::NewGuid().ToString()
}

$makefilePath = "$RootDir\Makefile"
$makefileVars = Read-Makefile -Path $makefilePath

$msbuildNs = 'http://schemas.microsoft.com/developer/msbuild/2003'

$templateDir = '.'
$projectTemplatePath = "$templateDir\template.vcxproj"
$projectDoc = [xml](Get-Content -Path $projectTemplatePath)
$projectNav = $projectDoc.CreateNavigator()
$projectNavNamespace = New-Object System.Xml.XmlNamespaceManager @($projectNav.NameTable)
$projectNavNamespace.AddNamespace('msb', $msbuildNs)

# $propTemplatePath = 'vcproj_template\template.props'
# $propDoc = [xml](Get-Context -Path $propTemplatePath)
# $propNav = $propDoc.CreateNavigator()
# $propNavNamespace = New-Object System.Xml.XmlNamespaceManager @($propNav.NameTable)
# $propNavNamespace.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')


# $filterTemplatePath = 'vcproj_template\template.vcxproj.filter'
# $filterDoc = [xml](Get-Context -Path $filterTemplatePath)

$includePath = $makefileVars['INCLUDE_PATHS'].Replace(' -I.', ';..').Replace('/', '\').Replace('-I.', '..')
$projectName = $makefileVars['PROJECT']
$outputFile = "$projectName.hex"

$searchPathNodes = $projectNav.Select('/msb:Project/msb:PropertyGroup/msb:NMakeIncludeSearchPath', $projectNavNamespace)
foreach($node in $searchPathNodes)
{
    [void]$node.SetValue($includePath)
}

$projectNav.Select('/msb:Project/msb:PropertyGroup/msb:NMakeOutput', $projectNavNamespace) | Foreach-Object { $_.SetValue("`$(ProjectDir)..\$outputFile") }
$projectNav.Select('/msb:Project/msb:PropertyGroup/msb:OutDir', $projectNavNamespace) | Foreach-Object { $_.SetValue("`$(ProjectDir)..") }
$includeGroup = $projectDoc.CreateElement('ItemGroup', $msbuildNs); [void]$projectDoc.Project.AppendChild($includeGroup)
$compileGroup = $projectDoc.CreateElement('ItemGroup', $msbuildNs); [void]$projectDoc.Project.AppendChild($compileGroup)

Get-ChildItem -Path $RootDir | Where-Object { $_.Name -match '\.c(pp)?$' } | Foreach-Object { 
    $filename = $_.Name
    $newItem = $projectDoc.CreateElement('ClCompile', $msbuildNs)
    [void]$newItem.SetAttribute('Include', "..\$filename")
    [void]$compileGroup.AppendChild($newItem)
}

Get-ChildItem -Path $RootDir | Where-Object { $_.Name -match '\.h$' } | Foreach-Object { 
    $filename = $_.Name
    $newItem = $projectDoc.CreateElement('ClInclude', $msbuildNs)
    [void]$newItem.SetAttribute('Include', "..\$filename")
    [void]$compileGroup.AppendChild($newItem)
}

$projectNav.Select('/msb:Project/msb:PropertyGroup[@Label = "Globals"]/msb:ProjectGuid', $projectNavNamespace) | Foreach-Object { $_.SetValue((New-Guid)) }

New-Item -ItemType Container -Path (Split-Path -Parent $OutputDir) -Name (Split-Path -Leaf $OutputDir) -Force | Out-Null
[void]$projectDoc.Save("$OutputDir\$projectName.vcxproj")

Copy-Item -Path "$templateDir\mbed.props" -Destination "$OutputDir\mbed.props"
Copy-Item -Path "$templateDir\make.cmd" -Destination "$RootDir"
