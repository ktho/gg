<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

<!-- filename: terminal.php --> 
<!-- Demonstrates a very simple command shell for entering queries -->

<script type="text/javascript">
window.onload=function() {
    document.getElementsByName('output')[0].scrollTop=document.getElementsByName('output')[0].scrollHeight;
    };
</script>

<head>
<meta content="text/html; charset=utf-8" http-equiv="Content-Type" />
<title>Simple Command Shell</title>
</head>

<body>
<h3>Simple Command Shell <font size="-1">  [<a href="index.html">front door</a></font>] </h3>
<p>
Useful for learning, implementation &amp; debugging
</p>

<form action="terminal.php" method="post" name="terminal">
<?php
include 'cmd_dispatch.php';

echo "<textarea readonly name=\"output\" style=\"width: 702px; height: 238px; font-family:'Courier New'; font-size:small; background-color: #808080; color: #FFFF00\">";

if (array_key_exists('output',$_POST)) {
	echo $_POST['output'];
}

$script = "";
$lines = array();

if (array_key_exists('script', $_POST)) {
	$script = $_POST['script']; 
	$lines = explode("\n",$script); 
	
	/*  Show the input lines */
	// $k = 0;
	// foreach ($lines as $cmd_line) {
	//	echo $k++ . ") " . $cmd_line . "\n"; 
	// }
	
	foreach ($lines as $cmd) {
			if (trim($cmd) != "") {
				$status = dispatchCommand (parseCommandLine($cmd)); 
				if ($status == cCmdStatus_ERROR) {
					break; 
				}
			}
	}
	echoResult(); 
	echoStatusMessage($status); 
}

	
	echo "</textarea>"; 
	echo "<p>Commands: help | examples | hello | cmd | pingdb | sum | set | unset | print \n"; 
	echo "<input name=\"clear\" type=\"button\" value=\"Clear\" onclick=\"document.terminal.output.value=''\" /><p>";

	echo "<textarea name=\"script\" style=\"width: 702px; height: 50px; font-family:'Courier New'; font-size:small\">\n"; 

		foreach ($lines as $cmd) {
			echo $cmd . "\n"; 
	}

	echo "</textarea>"; 


?>

&nbsp;
&nbsp;
<br>
<input name="enter" type="submit" value="Run..." />
<input name="clear" type="button" value="Clear" onclick="document.terminal.script.value=''" />




</body>


</html>
