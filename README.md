# PS-WindowsForensics
PowerShell scripts for parsing forensic artifacts in the Windows operating system, and the documentation I've created along the way.  

Information regarding data structures have been pulled from a number of sources including the ForensicsWiki, Harlan Carvey's RegRipper code, and various whitepapers and forensic professionals.  I have done my best to cite all of my sources in each of the scripts, and in this readme.  I apologize for any I've forgotten.

# Goals
1 Provide scripts that can be run on Windows systems without requiring any additional software download/installation
2 Provide scripts that can be run against live Windows systems
3 Provide scripts that can be run against most Windows systems
  * PowerShell Version 3 if possible
  * Lowest version of .NET possible, but most everything I find has at least 4
4 Provide scripts that can easily be run, or modified to run, in a PowerShell session.

# Thanks
Thanks to Harlan Carvey and his RegRipper tool for providing a lot of help working through the data structures (and for providing a great tool): https://github.com/keydet89/RegRipp2.8


