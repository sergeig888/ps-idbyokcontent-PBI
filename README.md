# ps-idbyokcontent-PBI

## Sample PowerShell script to help enumerate specific types of Power BI artifacts

This sample code can help Power BI tenant admins identify most of the content hosted on dedicated capacities that is not covered by BYOK encryption or moved to remote capacity data center storage. It uses [Power BI Admin API](https://docs.microsoft.com/en-us/rest/api/power-bi/admin) and [Power BI PowerShell modules](https://docs.microsoft.com/en-us/powershell/power-bi/overview?view=powerbi-ps). These modules need  to be installed prior to executing this script. See dedicated to [BYOK](https://docs.microsoft.com/en-us/power-bi/service-encryption-byok#data-source-and-storage-considerations) and [Mult-Geo](https://docs.microsoft.com/en-us/power-bi/service-admin-premium-multi-geo#enable-and-configure) docs (e.g., Considerations and Limitations section) for details on the types of content that needs to be identified and monitored.  This is work in progress and this release is initial beta version of the script.  

## How to use this sample

Requirements:
* Install [Power BI PowerShell modules](https://docs.microsoft.com/en-us/powershell/power-bi/overview?view=powerbi-ps)
* User of the PS script has to provide Power BI tenant Admin credentials when prompted to login. Tenant Admin access scope is required. Users without tenant Admin privileges will not be able to successfully execute this script.

**UPDATE**[12/2/22]: added "Scan for non-BYOK compliant content.ps1" file that contains updated guidance for not covedred by BYOK content detection and tenant scan automation based on most recent API additons.
