function Create-MP4 {
    param(
        [Parameter()]
        [string]$Title,

        [Parameter()]
        [string]$diskReaderDrive = "E:\",
        
        [Parameter()]
        [string]$MakeMKVcon = "C:\Program Files (x86)\MakeMKV\makemkvcon64.exe",
        
        [Parameter()]
        [string]$HandBrakeCLI = "C:\Program Files\HandBrakeCLI\HandBrakeCLI.exe",

        [Parameter()]
        [string]$ProcessingPath = "C:\temp\mkv\",
        
        [Parameter()]
        [string]$OutputDirectory = "J:\media\movies",

        [Parameter()]
        [string]$ArchivePath = "C:\temp\mkv\archive\"
    )
    $sw = New-Object System.Diagnostics.Stopwatch
    $sw.Start()
    Write-Host "Start DVD->MP4 file creation."

    $mkvStaging     = $ProcessingPath
    $nasDestination = $OutputDirectory
    $noTitle = [string]::IsNullOrWhiteSpace($Title)
    $driveEject = New-Object -ComObject Shell.Application
    $cleanTitle = if ($noTitle) { (New-Guid).Guid.Split('-')[0] } else {$Title -replace '[^A-z]*' }
    $mkvDir = Join-Path $mkvStaging $cleanTitle
    if (!(Test-Path $mkvDir)) { 
        Write-Host "Creating staging directory $mkvDir"
        mkdir $mkvDir | Out-Null
    }
    if ($noTitle) {
        try {
            $discName = $driveEject.NameSpace(17).ParseName($diskReaderDrive).Name
            $Title = $discName.Substring($discName.IndexOf(")")+2)
        } catch { $Title = $cleanTitle }
    }
    Write-Host "Using title: $Title"

    # Use MakeMKV to create MKV from disk
    Write-Host "Starting MKV file creation..."
    ## Find title to rip by pulling disc info
    Write-Host "Finding target file contents..."
    $discInfoPath = Join-Path $mkvDir "discinfo.txt"
    & $MakeMKVcon -r info disc:0 | Out-File $discInfoPath
    $discInfo = gc -Raw $discInfoPath
    $titleMatch = 'TINFO:(\d*),11,.*\"([^\"]*)\"'
    $titleId = ($discInfo.Split([Environment]::NewLine) |
        ? { $_ -match $titleMatch } |
        % { [Regex]::Match($_, $titleMatch) } |
        select @{n="TitleID";e={[int]$_.Groups[1].ToString()}}, @{n="Size";e={[int64]$_.Groups[2].ToString()}} |
        sort Size -desc |
        select -First 1).TitleID
    if ($noTitle) {
        $discNameMatch = 'CINFO:2,0,\"([^\"]*)\"'
        if ($discInfo -match $discNameMatch) {
            $Title = [Regex]::Match($discInfo, $discNameMatch).Groups[1].ToString()
            Write-Host "Title updated to: $Title"
        }
    }

    ## Write title to MKV file
    Write-Host "Writing title $titleId contents to file..."
    & $MakeMKVcon -r mkv disc:0 $titleId $mkvDir | Out-Null
    $mkvFilePath = (Resolve-Path "$mkvDir\*.mkv").Path
    if ([string]::IsNullOrWhiteSpace($mkvFilePath) -and $titleId -ne 0) {
        & $MakeMKVcon -r mkv disc:0 0 $mkvDir | Out-Null
        $mkvFilePath = (Resolve-Path "$mkvDir\*.mkv").Path
    }
    Write-Host "MKV file created: $mkvFilePath"

    # Eject disk once completed
    Write-Host "Ejecting drive $diskReaderDrive..."
    $driveEject.NameSpace(17).ParseName($diskReaderDrive).InvokeVerb("Eject")

    # Send notification that new disc can be started
    try {
        $email = "myemail@gmail.com"
        $smsEmail = "mycellnumber@provider.domain.com"
        $appPassword = "my_app_password"
        Write-Host "Sending notification..."
        $smtpServer = "smtp.gmail.com"
        $smtpFrom = $email
        $smtpTo = $smsEmail
        $message = New-Object System.Net.Mail.MailMessage $smtpFrom, $smtpTo
        $message.Body = "$Title completed"
        $smtp = New-Object System.Net.Mail.SmtpClient($smtpServer)
        $smtp.EnableSsl = $true
        $smtp.Port = 587
        $smtp.Credentials = New-Object System.Net.NetworkCredential($email, $appPassword)
        $smtp.Send($message)
        Write-Host "Notification sent."
    } catch { Write-Host "Failed to send notification." }

    # Use HandBrake to convert to MP4 from MKV
    $outputFileName = $Title -replace '[^\w\d\s]*'
    $outputFileName += ".mp4"
    $outputFilePath = Join-Path $nasDestination $outputFileName

    Write-Host "Starting conversion of $mkvFilePath to $outputFilePath"
    Start-Process -FilePath $HandBrakeCLI -ArgumentList $('-i "'+$mkvFilePath+'"'), $('-o "'+$outputFilePath+'"') -WindowStyle Hidden -Wait -RedirectStandardError "$mkvDir\\error.log" -RedirectStandardOutput "$mkvDir\\output.log"
    Write-Host "Conversion complete."

    # Remove staging folder in MKV directory
    try { 
        Write-Host "Creating archive..."
        if (!(Test-Path $ArchivePath)) {
            Write-Host "Creating archive directory $ArchivePath"
            mkdir $ArchivePath | Out-Null
        }
        $archiveFilePath = Join-Path $ArchivePath $($outputFileName + ".zip")
        dir $mkvDir -Exclude *.mkv | 
            Compress-Archive -DestinationPath $archiveFilePath
        Write-Host "Archive created: $archiveFilePath"
    } catch { Write-Host "Failed to create archive." }
    
    Write-Host "Removing MKV staging directory $mkvDir"
    rm -Force -Recurse $mkvDir

    $sw.Stop()
    $elapsed = $sw.Elapsed.ToString('g')
    Write-Host "End DVD->MP4 file creation. Time Elapsed: $elapsed"
}