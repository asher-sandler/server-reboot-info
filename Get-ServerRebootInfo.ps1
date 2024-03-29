#$dateBegin = get-date 17/11/12
#$dateEnd = get-date 18/11/12

$date=(get-date).Adddays(-1)
$xmlfilename= "c:\AdminDir\Scripts\log.xml"
Function ReadXML($filename)
{
   $outobj = @() 
   if (Test-Path $filename)
   {
	$xmlcontent = [XML](Get-Content $filename)
        
        
        foreach($item in $xmlcontent.events.event)
	{
                $oitem = "" | Select Timeof, Host ,Status, Message
                if (![string]::IsNullOrEmpty($item.Time))
                {
                        $day   = $item.Time.Substring(0,2)
                        $month = $item.Time.Substring(3,2)	
                        $yr    = $item.Time.Substring(6,4)

                        $time  = $item.Time.Substring(10)
                        $hour  = $time.split(":")[0]
                        $min   = $time.split(":")[1]
                        $sec   = $time.split(":")[2]
                        
			$oitem.Timeof = Get-Date -Day $day -Month $month -Year $yr -Hour $hour -Minute $min -Second $sec
		}
		else
		{
                        $oitem.Timeof = Get-Date "01.01.2000 00:00:00"
		}
                $oitem.Host = $item.name
                $oitem.status = $item.error  
                $oitem.Message = $item.mess
                
		$outobj += $oitem
	} 
      }
      return $outobj
}


Function Get-servers()
{
    Write-Host Retrive Server list...

    # import-module activedirectory # - ipmo ac* 
    $NameComputers = New-Object System.Collections.ArrayList
    $getADComputers = get-QADComputer  "S29*" 

    Write-Host Done.

    foreach($getADComputer in $getADComputers){ $NameComputers+=$getADComputer.Name }

    Return $NameComputers
}
Start-Transcript GetServerRebotInfo.log

Add-PSSnapin Quest.ActiveRoles.ADManagement
cls
$ComputersName = Get-servers

$xmlobj = ReadXML $xmlfilename


$outobj = @() 

foreach($ComputerName in $ComputersName)
{
    Write-Host $("connect to "+$ComputerName+ "....")
    $query = "select * from win32_pingstatus where address = '" +$ComputerName + "'"
    $isping = get-wmiobject -query $query 
    if ($isping.statuscode -eq 0) 
    {
        Write-Host Connected. Retrive Event log.
        try{
           $getReboots=get-eventlog -logname System  -computerName $ComputerName |
           where {$_.Eventid -eq 6008} 
           if ($getReboots.Count -gt 0)
           { 
             $oitem = "" | Select Timeof, Host ,Status, Message
   	     $oitem.Timeof = $getReboots
        
  	      foreach ($getReboot in $getReboots)
              { 
                $PreviousError = $outobj | Where{($_.Host -eq $ComputerName) -and ($_.Timeof.ToLongDateString() -eq $getReboot.TimeGenerated.ToLongDateString())}
                if ([string]::IsNullOrEmpty($PreviousError))
		{
			$oitem = "" | Select Timeof, Host ,Status, Message
                 
                	$oitem.Timeof = $getReboot.TimeGenerated
	                $oitem.Host = $ComputerName
                        $DaysPassed = ((Get-Date)  - $oitem.Timeof).Days
                        $DaysPassed
			$($DaysPassed -le 4)
                        if ($DaysPassed -le 4)  # 4 days
                        {
				$oitem.Status = 2
			}
			else
			{
				$oitem.Status = 1
			}        	        
                	$oitem.Message = $getReboot.Message
                }
		break
                
              }
	      $outobj += $oitem
              # $outobj 
	   }
        }
        catch
        {
             Write-host $("It's impossible to open System Event log on " +  $ComputerName+".")
        }
              
    }
    
}

$log = "<?xml version =`"1.0`"?>`n <?xml-stylesheet type=`"text/xsl`" href=`"log.xsl`"?>`n<events>`n"

$outobj = $outobj | sort -Property Timeof -desc
foreach($el in $outobj )
{
        # write-host Numerate el
        
	$day    = $el.Timeof.Day.ToString("D2")
        $month  = $el.Timeof.Month.ToString("D2")
        $year   = $el.Timeof.Year.ToString("D4") 

        $hour   = $el.Timeof.Hour.ToString("D2")
        $Minute = $el.Timeof.Minute.ToString("D2")
        $Second = $el.Timeof.Second.ToString("D2")

        $timeStr = [string]::Format("{0}.{1}.{2} {3}:{4}:{5}",$day,$month,$year,$hour,$Minute,$Second)

        $str     = [string]::Format("`t<event>`n`t`t<time>{0}</time>`n`t`t<mess>{1}</mess>`n`t`t<name>{2}</name>`n`t`t<error>{3}</error>`n`t</event>`n",$timeStr,$el.Message,$el.Host,$el.Status)
        # write-host $str

	$log += $str
}
$log += "</events>"

out-file $xmlfilename -inputobject $log -Encoding Ascii


    $SmtpClient = new-object system.net.mail.smtpClient
	$MailMessage = New-Object system.net.mail.mailmessage
	$Mailmessage.IsBodyHtml = 1 
	$SmtpClient.Host = "srv-ex1-klg.kaluga.cbr.ru"
	$mailmessage.from = "powershell@kaluga.cbr.ru"
	$mailmessage.To.add("29InderevaEA@cbr.ru")
	$mailmessage.Subject = "Отчет по работе серверов"
	$mailmessage.Body = "http://portal.kaluga.cbr.ru/deprts/ui/ois/VariousStat/RebootStat.aspx"
	#$mailmessage.Headers.Add("message-id", "<3BD50098E401463AA228377848493927-1>")
	$smtpclient.Send($mailmessage)
Write-Host Program END
Stop-Transcript