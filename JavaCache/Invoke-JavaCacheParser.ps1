<#
.SYNOPSIS
	Invoke-JavaCacheParser.ps1 parses the forensic artifacts from .idx files (Java Cache).
	
.PARAMETER LocalHost (Default choice if no parameters are specified)
	Use this parameter to run against the current computer, look in default locations, and parse all .idx files found.

.PARAMETER FullName (Alias FilePath)
	Use this parameter if you want to parse a specific .idx file or files.

.EXAMPLE
	Invoke-JavaCacheParser.ps1

.EXAMPLE
	Invoke-JavaCacheParser.ps1 -FilePath "C:\IDXFilesToParse"

.EXAMPLE
	Get-ChildItem -Path "C:\IDXFilesToParse" -Recurse -Filter *.idx | Select-Object -Property FullName | Invoke-JavaCacheParser.ps1

.NOTES
    Author: David Howell
    Last Modified: 03/18/2015
	Thanks to: Woanware for their amazing documentation:  https://github.com/woanware/javaidx
#>
[CmdletBinding(DefaultParameterSetName='LocalHost')]
Param(
	[Parameter(Mandatory=$True,ParameterSetName='File',ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
	[ValidateNotNullOrEmpty()]
	[Alias('FilePath')]
		[String[]]$FullName
)

Begin {
	# Initialize ASCII Encoding to convert Byte Array data to ASCII
	$ASCIIEncoding = New-Object System.Text.ASCIIEncoding
	
	# Initialize an Array to store our IDX File Information
	$IDXMetadata=@()
	
	function Analyze-IDXFile {
		[CmdletBinding()]Param(
			[Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$FilePath
		)
		
		# Initialize a Blank Object with properties for us to fill in
		$TempObject = "" | Select-Object -Property FileName, Length, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc, JavaCacheVersion, ContentLength, Section2Version, Section2URL, Section2NamespaceID, Section2CodebaseIP
		
		# Get basic NTFS information about the File
		$FileInfo = Get-ChildItem -Path $FilePath | Select-Object -Property FullName, Length, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc
		
		# Read the IDX file into a Byte Array
		[Byte[]]$FileBytes = [System.IO.File]::ReadAllBytes($FileInfo.FullName)
		
		# Write File Metadata to the Custom Object
		$TempObject.FileName = $FileInfo.FullName
		$TempObject.Length = $FileInfo.Length
		$TempObject.CreationTimeUtc = $FileInfo.CreationTimeUtc
		$TempObject.LastAccessTimeUtc = $FileInfo.LastAccessTimeUtc
		$TempObject.LastWriteTimeUtc = $FileInfo.LastWriteTimeUtc
		
		# Section 1 (First 128 Byets) is metadata/header info
		# Get Java Cache Version
		$TempObject.JavaCacheVersion = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[2..5]) -replace "-",""),16)
		
		# Get Content Length
		if ($TempObject.JavaCacheVersion -gt 605) {
			$TempObject.ContentLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[7..10]) -replace "-",""),16)
		} else {
			$TempObject.ContentLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[9..12]) -replace "-",""),16)
		}
		
		# Begin Parsing "Section 2" a.k.a. "Download History"
		if ($TempObject.JavaCacheVersion -eq 602) {
			# Variable to Track Current Offset after Section 1
			[int]$Offset = 37
			
			# Get Section 2 - Version Length
			$S2VersionLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[128..129]) -replace "-",""),16)
			# Get Section 2 - Version String (From our offset for the length of the Version)
			$TempObject.Section2Version = $ASCIIEncoding.GetString($FileBytes[$Offset..($Offset+$S2VersionLength-1)])
			# Advance our Offset by the Version Length
			$Offset = $Offset + $S2VersionLength
			
			# Get Section 2 - URL String Length
			$S2URLLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[$Offset..($Offset+1)]) -replace "-",""),16)
			$Offset = $Offset + 2
			# Get Section 2 - URL String
			if ($S2URLLength -gt 0) {
				$TempObject.Section2URL = $ASCIIEncoding.GetString($FileBytes[$Offset..($Offset+$S2URLLength-1)])
				$Offset = $Offset + $S2URLLength
			}
			
			# Get Section 2 - Namespace ID Length
			$S2NamespaceLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[$Offset..($Offset+1)]) -replace "-",""),16)
			$Offset = $Offset + 2
			# Get Section 2 - Namespace ID String
			if ($S2NamespaceLength -gt 0) { 
				$TempObject.Section2NamespaceID = $ASCIIEncoding.GetString($FileBytes[$Offset..($Offset+$S2NamespaceLength-1)])
				$Offset = $Offset + $S2NamespaceLength
			}
			
			# Loop through HTTP Header Values
			$HTTPHeadercount = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[$Offset..($Offset+3)]) -replace "-",""),16)
			$Offset = $Offset + 4
			for ($i=0; $i -lt $HTTPHeadercount; $i++) {
				# Get HTTP Header Name Length
				$HTTPHeaderLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[$Offset..($Offset+1)]) -replace "-",""),16)
				$Offset = $Offset + 2
				# Get HTTP Header Name
				$HTTPHeaderName = $ASCIIEncoding.GetString($FileBytes[$Offset..($Offset+$HTTPHeaderLength-1)])
				$Offset = $Offset + $HTTPHeaderLength
				# Get HTTP Value Length
				$HTTPValueLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[$Offset..($Offset+1)]) -replace "-",""),16)
				$Offset = $Offset + 2
				# Get HTTP Value
				$HTTPValue = $ASCIIEncoding.GetString($FileBytes[$Offset..($Offset+$HTTPValueLength-1)])
				$Offset = $Offset + $HTTPValueLength
				$TempObject | Add-Member -MemberType NoteProperty -Name $HTTPHeaderName -Value $HTTPValue
			}
		} else {
			# Variable to Track Current Offset after Section 1
			[int]$Offset = 130
			
			# Get Section 2 - Version Length
			$S2VersionLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[128..129]) -replace "-",""),16)
			# Get Section 2 - Version String (From our offset for the length of the Version)
			$TempObject.Section2Version = $ASCIIEncoding.GetString($FileBytes[$Offset..($Offset+$S2VersionLength-1)])
			# Advance our Offset by the Version Length
			$Offset = $Offset + $S2VersionLength
			
			# Get Section 2 - URL String Length
			$S2URLLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[$Offset..($Offset+1)]) -replace "-",""),16)
			$Offset = $Offset + 2
			# Get Section 2 - URL String
			if ($S2URLLength -gt 0) {
				$TempObject.Section2URL = $ASCIIEncoding.GetString($FileBytes[$Offset..($Offset+$S2URLLength-1)])
				$Offset = $Offset + $S2URLLength
			}
			
			# Get Section 2 - Namespace ID Length
			$S2NamespaceLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[$Offset..($Offset+1)]) -replace "-",""),16)
			$Offset = $Offset + 2
			# Get Section 2 - Namespace ID String
			if ($S2NamespaceLength -gt 0) { 
				$TempObject.Section2NamespaceID = $ASCIIEncoding.GetString($FileBytes[$Offset..($Offset+$S2NamespaceLength-1)])
				$Offset = $Offset + $S2NamespaceLength
			}
			
			# Get Section 2 - Codebase IP Length
			$S2CodebaseIPLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[$Offset..($Offset+1)]) -replace "-",""),16)
			$Offset = $Offset + 2
			if ($S2CodebaseIPLength -gt 0) {
				$TempObject.Section2CodebaseIP = $ASCIIEncoding.GetString($FileBytes[$Offset..($Offset+$S2CodebaseIPLength-1)])
				$Offset = $Offset + $S2CodebaseIPLength
			}
			
			# Loop through HTTP Header Values
			$HTTPHeadercount = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[$Offset..($Offset+3)]) -replace "-",""),16)
			$Offset = $Offset + 4
			for ($i=0; $i -lt $HTTPHeadercount; $i++) {
				# Get HTTP Header Name Length
				$HTTPHeaderLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[$Offset..($Offset+1)]) -replace "-",""),16)
				$Offset = $Offset + 2
				# Get HTTP Header Name
				$HTTPHeaderName = $ASCIIEncoding.GetString($FileBytes[$Offset..($Offset+$HTTPHeaderLength-1)])
				$Offset = $Offset + $HTTPHeaderLength
				# Get HTTP Value Length
				$HTTPValueLength = [System.Convert]::ToInt32(([System.BitConverter]::ToString($FileBytes[$Offset..($Offset+1)]) -replace "-",""),16)
				$Offset = $Offset + 2
				# Get HTTP Value
				$HTTPValue = $ASCIIEncoding.GetString($FileBytes[$Offset..($Offset+$HTTPValueLength-1)])
				$Offset = $Offset + $HTTPValueLength
				$TempObject | Add-Member -MemberType NoteProperty -Name $HTTPHeaderName -Value $HTTPValue
			}
		}
	
		return $TempObject
	}

} Process {
	switch($PSCmdlet.ParameterSetName) {
		"File" {
			ForEach ($File in $FullName) {
				$IDXMetadata += Analyze-IDXFile -FilePath $File
			}
		}
		
		Default {			
			#Get User Profiles on the System
			$UserProfiles = Get-WMIObject -Class Win32_UserProfile | Select-Object -ExpandProperty LocalPath | Where-Object { $_ -like "C:\Users\*" -or $_ -like "C:\Windows\system32\config\systemprofile"}
			
			# Check the Java Cache for Each Profile
			ForEach ($UserProfile in $UserProfiles) {
				$IDXFiles=$null
				
				# Look for .idx files, and process each one
				$IDXFiles = Get-ChildItem -Path "$UserProfile\AppData\LocalLow\Sun\Java\Deployment\cache\" -Filter *.idx -ErrorAction SilentlyContinue | Select-Object -Property FullName, Length, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc
				
				ForEach ($IDXFiles in $IDXFiles) {
					$IDXMetadata += Analyze-IDXFile -FilePath $IDXFile.FullName
				}
			}
		}
	}
} End {
	$IDXMetadata | Format-Table -AutoSize
}