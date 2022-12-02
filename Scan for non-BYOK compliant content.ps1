# Written by Sergei Gundorov; v1 development started on 12/02/22
#
# Intent: supplement temporary gap in Power BI BYOK certain content type protection 
#         by providing inventory of known artifacts not protected by BYOK encryption.
#         Also applies to some Power BI multi-geo capacities hosted content    
#
# BYOK: see https://docs.microsoft.com/en-us/power-bi/service-encryption-byok#data-source-and-storage-considerations for details and updates for unencrypted content types
# Multi-geo: see https://learn.microsoft.com/en-us/power-bi/admin/service-admin-premium-multi-geo#considerations-and-limitations
#
# NOTE: Dataflows can be either disabled on the tenant or use external storage with its own encryption


 
# HELPER FUNCTIONS:

# Helper function to get all dataset content provider types currently present on the tenant
# PbixInImportMode is covered by BYOK by defintion
# RetailSales is a sample dataset  
(Invoke-PowerBIRestMethod -Url 'admin/groups?$expand=datasets&$top=5000' -Method Get `
 | ConvertFrom-Json).value | Select -ExpandProperty datasets `
 | where {($_.contentProviderType -ne 'PbixInImportMode') -and ($_.contentProviderType -ne 'RetailSales') } `
 | Select contentProviderType -Unique


############################################################################################
#
#   Sample API based flow to reactively detect unprotected by BYOK content uploads
#
############################################################################################

#After the initial tenant clean up it is pososble to focus only on the new content additions
#leveraging Get Modified Workspaces API and checking them for non-covered by BYOK content 

#Get the list of all modified workspaces in a particular time interval:
$day=Get-date

#Time interval to check; logic needs to be finetuned for specific tenant needs
#a once per 30min check for get modified workspaces is minimal reasonable interval
#reason: Get Modified Workspaces API is based on activity log events which have 30 min SLA
#this example will check current day activity
$day=$day.AddDays(0)

$base=$day.ToString("yyyy-MM-dd")
#Optional line; e.g., use this during debugging only to validate that base date is correct
write-host $base

$modifiedWorkspaces=Invoke-PowerBIRestMethod -Url ('admin/workspaces/modified?modifiedSince='+$base +'T00:00:00.0000000Z') -Method Get
$workspaceList=($modifiedWorkspaces | Convertfrom-json).Id

#Check whether anyone uploaded or created content not covered by BYOK in any recently modified workspaces
#this check servers only as a trigger to check the tenant for the presence of non-compliant content
#NOTE: you can only check 200 unique workspaces in any 60 min time period (limit is expplicitly documented and can change in the future w/o notice)
$workspacesToCheck=$workspaceList | ForEach-Object {Get-PowerBIWorkspaceEncryptionStatus -Id $_} | where {$_.EncryptionStatus -eq 'NotSupported'}

#if there is new unencrypted content detected in any modified workspaces
#then triggering tenant check using dedicated to artifact type API 
#IMPORTANT: if the number of modified workspaces exceed the 200 per 60 min limit the code blocks below can be run
#at a periodic interval as well and skip modified workspace check which makes tenant monitoring more efficient
#the commandlets below are also useful for taking initial non-cmpliant with BYOK content inventory
if($workspacesToCheck.count -ne 0)
{    
    #Getting full list of workbooks on the tenant
    $workbooksDetails=Get-PowerBIWorkspace -Scope Organization -All -Include Workbooks -Filter 'workbooks/any()' | Select -Property @{n="WorkspaceId"; e={$_.id}} -ExpandProperty Workbooks
        
    #NOTE: filter in this code block targets streaming datasets
    #it can be adjusted for broader range of dataset types depending on
    #particular tenant activity analysis (i.e., what content types results in encryption status of a workspace check to return 'NotSupported')
    #see Helper Functions section above for guidance on how to get all content types present on the tenant
    $datasetDetials=(Invoke-PowerBIRestMethod -Url 'admin/groups?$expand=datasets&$top=5000' -Method Get `
        | ConvertFrom-Json).value | Select -Property @{n="WorkspaceId"; e={$_.id}} -ExpandProperty datasets `
        | where { `
        ($_.contentProviderType -eq 'RealTimeInPushMode') -or ` 
        ($_.contentProviderType -eq 'RealTime') -or `
        ($_.contentProviderType -eq 'RealTimeInPubNubMode') -or `
        ($_.contentProviderType -eq 'RealTimeInStreamingMode')} `
        | Select WorkspaceId, id, name, contentProviderType, createdDate, configuredBy

    if($workbooksDetails.count -ne 0)
    {
        Write-Host "New Workbooks details:"
        Write-Host ($workbooksDetails | Format-List | Out-string)      
    }

    if($datasetDetials.count -ne 0)
    {
        Write-Host "New streaming datasets details:"
        write-Host ($datasetDetials | Out-string)
    }
}