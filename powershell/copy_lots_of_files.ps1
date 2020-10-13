###
# @source: https://community.spiceworks.com/topic/1691932-fastest-way-to-copy-millions-of-little-files-fastcopy
#
# This script runs robocopy jobs in parallel by increasing the number of outstanding i/o's to the copy process. Even though you can
# change the number of threads using the "/mt:#" parameter, your backups will run faster by adding two or more jobs to your
# original set. 
#
# To do this, you need to subdivide the work into directories. That is, each job will recurse the directory until completed.
# The ideal case is to have 100's of directories as the root of the backup. Simply change $src to get
# the list of folders to backup and the list is used to feed $ScriptBlock.
# 
# For maximum SMB throughput, do not exceed 8 concurrent Robocopy jobs with 20 threads. Any more will degrade
# the performance by causing disk thrashing looking up directory entries. Lower the number of threads to 8 if one
# or more of your volumes are encrypted.
#
# Parameters:
# $src a directory which has lots of subdirectories that can be processed in parallel 
# $dest where you want to backup your files to
# $max_jobs Change this to the number of parallel jobs to run ( <= 8 )
# $log Change this to the directory where you want to store the output of each robocopy job.
#
####
#
# Set $log to a local folder to store logfiles
#
$max_jobs = 8
$tstart = get-date
$log = "c:\temp\Logs\"

$src = Read-Host -Prompt 'Source path'
if(! ($src.EndsWith("\") )){$src=$src + "\"}
$dest = Read-Host -Prompt 'Destination path'
if(! ($dest.EndsWith("\") )){$dest=$dest + "\"}

if((Test-Path -Path $src )) {
	if(!(Test-Path -Path $log)) {New-Item -ItemType directory -Path $log}
	if((Test-Path -Path $dest)) {
		robocopy $src $dest
		$files = ls $src
		
		$files | %{
			$ScriptBlock = {
			param($name, $src, $dest, $log)
			$log += "\$name-$(get-date -f yyyy-MM-dd-mm-ss).log"
			robocopy $src$name $dest$name /E /nfl /np /mt:16 /ndl > $log
			Write-Host $src$name " completed"
			 }
			$j = Get-Job -State "Running"
			while ($j.count -ge $max_jobs) 
			{
			 Start-Sleep -Milliseconds 500
			 $j = Get-Job -State "Running"
			}
			 Get-job -State "Completed" | Receive-job
			 Remove-job -State "Completed"
			Start-Job $ScriptBlock -ArgumentList $_,$src,$dest,$log
		}

		While (Get-Job -State "Running") { Start-Sleep 2 }
		Remove-Job -State "Completed" 
		  Get-Job | Write-host

		$tend = get-date
		Cls
		Echo 'Completed copy'
		Echo 'From: $src'
		Echo 'To: $Dest'
		new-timespan -start $tstart -end $tend
		
	} else {echo 'invalid Destination'}
} else {echo 'invalid Source'}
