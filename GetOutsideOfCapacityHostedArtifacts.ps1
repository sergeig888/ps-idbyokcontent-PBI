# Written by Sergei Gundorov; v1 development started on 10/17/19
#
# Intent: supplement temporary gap in Power BI BYOK certain content type protection 
#         by providing inventory of known artifacts not protected by BYOK encryption.
#         Also applies to Power BI multi-geo capacities hosted content    
#
# BYOK: see https://docs.microsoft.com/en-us/power-bi/service-encryption-byok#data-source-and-storage-considerations for details and updates for unencrypted content types
# Multi-geo: see https://docs.microsoft.com/en-us/power-bi/service-admin-premium-multi-geo#enable-and-configure
#
# Make sure Dataflows workload is not enabled on capacity
# TODO: any other exceptions that we need to capature?
#
# NOTE: 10/16/19 - periodic scan of the audit log may be a better option
# NOTE: 10/17/19 - Audit log tracks Excel file upload either 'connect' or'import' as "CreateDataset" activity, i.e., Audit log can't help trap Excel file uploads
 
# Helper functions:
#
# TODO: add error handling

function Get-ReportMetaData($reportId)
{       
    foreach ($workspace in $capacityWorkspaces)
    {
        foreach($report in $workspace.reports)
        {        
            if($report.Id.ToLower() -eq $reportId)
            {
                return $workspace
            }
        }   
    }    
}
 

function Get-DatasetMetaData($datasetId)
{       
    foreach ($workspace in $capacityWorkspaces)
    {
        foreach($dataset in $workspace.datasets)
        {        
            if($dataset.Id.ToLower() -eq $datasetId)
            {
                return $workspace                
            }
        }   
    }    
}


function Get-StreamingDatasets()
   {        
        foreach ($workspace in $capacityWorkspaces)
        {
            foreach($dataset in $workspace.datasets)
            {        
                if($dataset.AddRowsApiEnabled  -eq "True")
                {                    
                    Write-Host $dataset.Name
                    Write-Host ("`t workspace id:`t" + $workspace.Id.ToLower())
                    Write-Host ("`t workspace:`t`t" + $workspace.name)
                    Write-Host ("`t dataset id:`t" + $dataset.Id)                               
                    Write-Host ("`t owner:`t`t`t" + $dataset.configuredBy.ToLower())
                }
            }   
        }        
   }


#end of Helper functions

#TODO: add proper/appropriate for the environment login; should use Connect-PowerBIServiceAccount to cover Windows Server use case
Connect-PowerBIServiceAccount

#TODO: figure out if shredded out data model is safe, i.e., where is it hosted?

#TODO: need to extend to go beyond 5000 single pass max
#Get all *.xls* files
Write-Host "Getting collection of all Excel file Imports " (get-date).ToString('T')
$xlFiles=(Invoke-PowerBIRestMethod -Url 'admin/imports?$top=5000&$skip=0&$expand=reports,datasets' -Method GET | ConvertFrom-Json).value | where {$_.name -like '*.xls*'}

#TODO: create a loop for processing of each capacity
#TODO: use the line below to obtain the list of encrypted capacities in prod version of the script
#Get-PowerBICapacity -Scope Organization | where {$_.EncryptionKeyId.Length -ne 0}

#$encryptedCapacities = Get-PowerBICapacity -Scope Organization | where {$_.EncryptionKeyId.Length -eq 0}

#Get all workspaces - necessary step to map dataset to workspace to get workspace properties
Write-Host "Getting collection of all workspaces for dataset mapping " (get-date).ToString('T')

#NOTE: capacity segregation (i.e., BYOK and/or MG) and 5000 object limit need to be addressed in prod targetted scripts
#NOTE: workspaces not assigned to capacity are filtered out
$capacityWorkspaces=(Invoke-PowerBIRestMethod -Url 'admin/groups?$top=5000&$skip=0&$expand=datasets,reports,users,capacity' -Method GET | ConvertFrom-Json).value | where {$_.capacity.id.length -ne 0}
#TODO: need to display capacity details if iterating by capacity

Write-Host "`n*** MS EXCEL WORKBOOKS UPLOADED TO THE TENANT ***`n"

# I only need to cycle through datasets based on uploaded Excel file
# file using both connect and upload - both show up as datasets; not sure how rare "no dataset" case originated, possibly orphaned content case
foreach ($xlFile in $xlFiles) 
{    
    Write-Host $xlFile.name
    Write-Host ("`t type:`t`t`t" + $xlFile.connectionType)  
    Write-Host ("`t created:`t`t" + $xlFile.createdDateTime)
    Write-Host ("`t import id:`t`t" + $xlFile.id)
    
   if ($xlFile.datasets.Count -ne 0)
   {  
        #Write-Host $xlFile.datasets[0].id
        #TODO: instead of iterating, add API call to get dataset and "configuredby" property
        #TODO: need to specify file source if avaialble; use file name and then tabs for properties
        $output = Get-DatasetMetaData $xlFile.datasets[0].id
        Write-Host ("`t dataset id:`t" + $xlFile.datasets[0].id.ToLower())
        try
        {        
            Write-Host ("`t workspace id:`t" + $output.Id.ToLower())            
            Write-Host ("`t workspace:`t`t" + $output.name)
            Write-Host ("`t owner:`t`t`t" + $output.datasets[0].configuredBy.ToLower())
        }
        catch
        {
            Write-Host ("`t workspace id:`terror retreiving information")            
            Write-Host ("`t workspace:`t`terror retreiving information")
            Write-Host ("`t owner:`t`t`terror retreiving information")            
        } 
   }
   else
   {
        Write-Host "`t dataset id:`tnot available"
        Write-Host "`t workspace id:`tnot available"        
   }

   <#
   #handling 'connect'
   if ($xlFile.connectionType -eq "connect")
   {
        #Write-Host $xlFile.reports[0].name        
        Write-Host $xlFile.name $xlFile.reports[0].webUrl
   }
   elseif($xlFile.connectionType -eq "import")
   {
        #Write-Host $xlFile.datasets[0].id
        $output = Get-DatasetMetaData $xlFile.datasets[0].id
        Write-Host $output.Id $xlFile.name
   }
   #>
}

Write-Host "`n*** STREAMING DATASETS CREATED ON TENANT ***`n"

Get-StreamingDatasets