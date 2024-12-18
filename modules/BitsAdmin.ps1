bitsadmin /list /allusers /verbose

Write-Output "Check for any malicious BitsAdmin downloads`n"

Write-Output "Run ``bitsadmin /cancel `"<jobid>`"`` to cancel one specific job, run ``bitsadmin /reset /allusers`` to cancel all jobs"