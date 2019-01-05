<#
.Synopsis
    Function to assist in lazily searching throught a list of object by a vague keyword or list of partial keywords
.EXAMPLE
    $KeySharePointServicesFilter = @{
        ObjectToFilter = Get-Service
        ParamToSearch = "DisplayName"
        FilterKeywords = "SharePoint","SQL","Nintex"
    }

    $KeySharePointServices = Filter-ObjectByKeywords @KeySharePointServicesFilter
.EXAMPLE
    $Services = Get-Service
    Filter-ObjectByKeywords -ObjectToFilter $Services -ParamToSearch "DisplayName" -FilterKeywords "SharePoint","SQL","Xbox","Hyper-V"
.EXAMPLE
    $Services = Get-Service
    $FilterWords = "SharePoint","SQL","Xbox","Hyper-V"
    $ParamToSearch = "DisplayName"

    Filter-ObjectByKeywords -ObjectToFilter $Services -ParamToSearch $ParamToSearch -FilterKeywords $FilterWords
.INPUTS
    ObjectToFilter is where you pass in the array of objects you want to filter.
    ObjectToFilter constraints and alias:
    [Parameter(Mandatory=$true)]
    [Alias("Object", "Array", "Arr", "o", "a")]
    [ValidateNotNullOrEmpty()]
    $ObjectToFilter


    ParamToSearch is where you list the parameter you would like to search through, typically "DisplayName", "Name", "Status", "Process". To find out what parameter you want to search through, just print the first object in your array to the screen: <$your_object>[0] | format-list
    ParamToSearch constraints and alias:
    [Parameter(Mandatory=$true)]
    [Alias("Field", "Param", "p")]
    [ValidateNotNullOrEmpty()]
    $ParamToSearch 
    

    FilterKeywords is the list of strings you want to filter your objects by. This can be either one item or more.
    FilterKeywords constraints and alias:
    [Parameter(Mandatory=$true,
                ValueFromRemainingArguments=$true)]
    [Alias("Keywords", "Filter", "f")]
    [ValidateNotNullOrEmpty()]
    [String[]]$FilterKeywords
    
.OUTPUTS
   Outputs the filtered array of objects.
.NOTES
   - Enable lazy search, where it will just default to searching all columns if no object parameter is specified to check in
   - At somepoint enable pipeline input for the array you're searching through - might simplify the Process section
#>
function Filter-ObjectArrayByKeywords
{
    [Alias("VagueArrayFilter", "vaf")]
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory=$true,
                   ValueFromRemainingArguments=$true)]
        [Alias("Keywords", "Filter", "f")]
        [ValidateNotNullOrEmpty()]
        [String[]]$FilterKeywords,
        
        [Parameter(Mandatory=$true)]
        [Alias("Object", "Array", "Arr", "o", "a")]
        [ValidateNotNullOrEmpty()]
        $ObjectToFilter,

        [Parameter(Mandatory=$true)]
        [Alias("Field", "Param", "p")]
        [ValidateNotNullOrEmpty()]
        $ParamToSearch 
    )

    Begin
    {
        $ServiceSelectionParams = @{
            Name = "FilteredItems"
            Expression = { $FieldItemsToSearch -match $_ }
        }

        $FieldItemsToSearch = $ObjectToFilter | Select-Object -ExpandProperty $ParamToSearch
    }

    Process
    {
        $Found = $FilterList | Select-Object $ServiceSelectionParams `
                             | Select-Object -ExpandProperty FilteredItems

        return $ObjectToFilter | ? $ParamToSearch -in $Found
    }
}

