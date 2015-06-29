RIA Warning Disabler
====================

Add a range of website to the java exception list in order to disable the warnings displayed before a java applet starts

## SYNOPSIS
Since Java 1.8 we can't lower java security. Only options are "High" & "Very High". Status "Lower" is not present anymore.
Therefore 
 - we get a warning each time we browse a non signed java applet (RIA) on the internet.
 - on non signed RIA we must add the url to the java security exception list.
This script removes all warnings once and for all.


## Requirement
You need Java Development Kit 1.7 or +. I recommend JDK 1.8
(see section Deploy only to disable ria warnings on computer that have only JRE and no JDK)
Download the JDK here: http://www.oracle.com/technetwork/java/javase/downloads/index.html


## SYNTAX
    .\ria_warning_disabler.ps1 [-jdk <Path to jdk>]

	
## DESCRIPTION
This script uses Oracle's java security Deployment Rule Set documented here: http://docs.oracle.com/javase/7/docs/technotes/guides/jweb/security/deployment_rules.html
idea on how to write this script comes from http://ephingadmin.com/administering-java/

Default website added to the exception list is:
  - http://*.oracle.com/
  
You can test that the script worked with:
 http://docs.oracle.com/javase/tutorial/deployment/doingMoreWithRIA/examples/dist/applet_JNLP_API/AppletPage.html

To modify this list, edit the file ruleset.xml
There are examples of ruleset files at the bottom of http://docs.oracle.com/javase/7/docs/technotes/guides/jweb/security/deployment_rules.html

