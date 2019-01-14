$values = 5,6,8,2,6

function Math-PartialApplication
{
    Param(
        $Numbers,
        $Function
    )

    if($Numbers.Count -eq 1)
    {
        return [int](& $Function $Numbers)
    }
    else
    {
        return $Numbers | %{ & $Function $_ }
    }
    
}

function AddNumber($a)
{
    return { Param($b) return $a + $b }.GetNewClosure()
}

$Add4 = AddNumber 4

Math-PartialApplication -Numbers $values -Function $Add4
