<#
.SYNOPSIS
	Since Java 1.8 we can't lower java security. Only options are "High" & "Very High". Status "Lower" is not present anymore.
	Therefore 
	 - we get a warning each time we browse a non signed java applet (RIA) on the internet.
	 - on non signed RIA we must add the url to the java security exception list.
	This script removes all warnings once and for all.
.DESCRIPTION
	This script uses Oracle's java security Deployment Rule Set documented here: http://docs.oracle.com/javase/7/docs/technotes/guides/jweb/security/deployment_rules.html
	idea on how to write this script comes from http://ephingadmin.com/administering-java/

	Default website added to the exception list is:
	  - http://*.oracle.com/
	  
	You can test that the script worked with:
	 http://docs.oracle.com/javase/tutorial/deployment/doingMoreWithRIA/examples/dist/applet_JNLP_API/AppletPage.html

	To modify this list, edit the file ruleset.xml
	There are examples of ruleset files at the bottom of http://docs.oracle.com/javase/7/docs/technotes/guides/jweb/security/deployment_rules.html
    
.NOTES
	Author: Zougi
#>

Param (
	[Parameter(Mandatory=$false)] [string]$jdk
)

#this script needs administrator privileges because of certutil, and copy of file in windows folder
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You do not have enough rights! Please re-run this script as an Administrator!"
    Break
}

#check if JRE is present
[Double]$javaCurrentVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\JavaSoft\Java Development Kit" -erroraction 'silentlycontinue').CurrentVersion -as [Double]
if ($javaCurrentVersion -ge 1.7)
{
    $jdkPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\JavaSoft\Java Development Kit\$javaCurrentVersion" -erroraction 'silentlycontinue').JavaHome
}
else
{
	$javaCurrentVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Wow6432Node\JavaSoft\Java Development Kit" -erroraction 'silentlycontinue').CurrentVersion -as [Double]
	if ($javaCurrentVersion -ge 1.7)
	{
		$jdkPath = (Get-ItemProperty -Path "HKLM:\SOFTWARE\JavaSoft\Java Development Kit\$javaCurrentVersion" -erroraction 'silentlycontinue').JavaHome
	}
}
if (!$jdkPath -and (($env:JAVA_HOME -like "*jdk1.7*") -or ($env:JAVA_HOME -like "*jdk1.8*")))
{
    $jdkPath = $env:JAVA_HOME
}
#override found path with supplied one
if ($jdk)
{
	$jdkPath = $jdk
}
if (!$jdkPath)
{
    Write-Warning "Can't find JDK version 1.7 or superior.`nIf it's not installed download it at http://www.oracle.com/technetwork/java/javase/downloads/index.html`nIf it is already installed, re-run the script with argument -jdk <path-of-jdk>"
    Break
}

$jarExe = Join-Path $jdkPath "bin\jar.exe"
$keytoolExe = Join-Path $jdkPath "bin\keytool.exe"
$jarsignerExe = Join-Path $jdkPath "bin\jarsigner.exe"
$certutilExe = "C:\Windows\System32\certutil.exe"

$rulesetPath = (Resolve-Path "ruleset.xml").path
$currPath = Split-Path $rulesetPath
$keystoreJKS = Join-Path $currPath "keystore.jks"
$certPath = Join-Path $currPath "Cert.cer"

#ruleset must be in the same folder of jar.exe. Specifying a path doesn't work
Copy-Item $rulesetPath -Destination (Split-Path $jarExe) -force
&$jarExe -cvf DeploymentRuleSet.jar "ruleset.xml"

#create a certificate to selfsign our deployment rules. will be valid for a year
&$keytoolExe -genkey -noprompt -keyalg RSA -alias selfsigned -dname "CN=wdf.sap.corp, OU=ID, O=SAP, L=Fondue, S=Savoyarde, C=FR" `
    -keystore $keystoreJKS -storepass password -keypass password -validity 360 -keysize 2048
&$keytoolExe -exportcert -noprompt -keystore $keystoreJKS -alias selfsigned -file $certPath -storepass password
#add certificate to windows
&$certutilExe -addstore -f "TrustedPublisher" $certPath

$jreX64 = Get-ChildItem "C:\Program Files\Java\"
$jreX86 = Get-ChildItem "C:\Program Files (x86)\Java\"
$jreList = $jreX64 +$jreX86
#for each jre and jdk, install  the certificate to the keystore of the jre/jdk.
foreach ($jre in $jreList)
{
    $cacertsPath = Join-Path $jre.FullName “lib\security\cacerts”
    if (Test-Path $cacertsPath)
    {
        #NOTE: default storepass is changeit
        &$keytoolExe -delete -alias selfsigned -keystore $cacertsPath -storepass changeit -noprompt
        &$keytoolExe -importcert -keystore $cacertsPath -storepass changeit -file $certPath -alias selfsigned -noprompt
    }
    #&$keytoolExe -importkeystore -deststorepass password -destkeystore $keystoreJKS -srcKeystore $certPath -srcstoretype pkcs12 -srcstorepass password
}

#sign the deployment rule jar
&$jarsignerExe -verbose -keystore keystore.jks -signedjar DeploymentRuleSet.jar DeploymentRuleSet.jar selfsigned -storepass password

$javaDeployementPath = "C:\Windows\Sun\Java\Deployment"
#create deployment configuration path if it doesn't exists
if (!(Test-Path $javaDeployementPath))
{
    New-Item -path $javaDeployementPath -type directory
}
#move signed deployment rule jar to needed folder
mi DeploymentRuleSet.jar $javaDeployementPath -Force

#remove generated files
ri $keystoreJKS
#ri $certPath #dont remove certificate because it could be used for deployer_only

Write-Warning "If you enconter any problem loading the RIA, remove the file $javaDeployementPath\DeploymentRuleSet.jar"
Write-Host "DONE`n" -foreground "green"