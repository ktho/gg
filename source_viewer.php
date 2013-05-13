<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

<!-- filename: source_viewer.php --> 
<!-- Used to print source files in a browsers -->


<head>
<meta content="text/html; charset=utf-8" http-equiv="Content-Type" />
<title>Untitled 1</title>
</head>

<body>


<?php

if (array_key_exists('fn',$_GET)) {
	$fn =  $_GET['fn'];
	echo "<h3>Code for $fn</h3>\n";
	$code = htmlspecialchars(file_get_contents($fn));
	echo "<pre style=\"font-size:small; border: 1px solid silver; background: #f4f4f4;padding: 0.5em;\">$code</pre>";
}
else {
	echo "Usage: php_source_viewer.php?fn=__filename__\n<br>";
	echo "Replace __filename__with the name of the file to be displayed\n";
	echo "\n";
}
?>

</body>
</html>