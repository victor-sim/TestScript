    [CmdletBinding(PositionalBinding = $false)]
    param 
    (
        [Parameter(mandatory=$false)]
        [switch] $Upload,

        [Parameter(mandatory=$false)]
        [string] $PipelineCounter = $env:GO_PIPELINE_COUNTER,

        [Parameter(mandatory=$false)]
        [string] $PipelineName = $env:GO_PIPELINE_NAME,

        [Parameter(mandatory=$false)]
        [string] $AccessKey = $env:ACCESS_KEY,

        [Parameter(mandatory=$false)]
        [string] $SecretKey = $env:SECRET_KEY,

        [Parameter(mandatory=$false)]
        [string] $Region = 'us-east-1'
    )
BEGIN
{
    Set-DefaultAWSRegion -Region $Region | Out-Null
    Set-AWSCredential -AccessKey $AccessKey -SecretKey $SecretKey | Out-Null   
    [string] $bucket = 'mobicontrol-uat-installers'
}
PROCESS
{
    $s3Key = "test_$($PipelineName)_$($PipelineCounter)"
    $currentPath = Resolve-Path '.\'
    $workDir = Join-Path $currentPath $s3Key

    [int] $total = 0

    [datetime] $start = [datetime]::MinValue

    if($Upload)
    {
        $source = Join-Path $workDir 'test'
        $files = Get-ChildItem -Path $source
        $total = ($files | Measure-Object -property length -sum).sum

        $objects = Get-S3Object -BucketName $bucket -KeyPrefix $s3Key

        if ($objects -ne $null -and $objects.Count -gt 0)
        {
            foreach ($obj in $objects)
            {
                Remove-S3Object -BucketName $bucket -Key $obj.Key  -Force | Out-Null
            } 
        }

        Write-Host "Start to uploading $($files.Count) files ($total bytes)."
        $start = [datetime]::Now
        Write-S3Object -BucketName $bucket -Folder $source -KeyPrefix $s3Key -Recurse -Force | Out-Null
    }
    else
    {
        if (Test-Path -Path $workDir)
        {
            Remove-Item -Path $workDir -Force -Recurse
        }

        $s3Key = 'test/'
        $objects = Get-S3Object -BucketName $bucket -KeyPrefix $s3Key
        $total = ($objects | Measure-Object -property Size -sum).sum

        Write-Host "Start to download $($objects.Count) files ($($total) bytes)."
        $start = [datetime]::Now

        foreach ($obj in $objects)
        {
            Copy-S3Object -BucketName $bucket -Key $obj.Key  -Force -LocalFolder $workDir | Out-Null
        }
        Write-Host "Download completed"
    }
    [datetime] $end = [datetime]::Now

    [timespan] $timeDiff = $end - $start
    $bytePerSecond = $($total) / $timeDiff.TotalSeconds


    Write-Host ""
    Write-Host "Started at $start,  Ended at $end, Took $($timeDiff.TotalSeconds) seconds"
    Write-Host "Byte per second: $bytePerSecond."
}
