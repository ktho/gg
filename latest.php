<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

<head>
<meta content="text/html; charset=utf-8" http-equiv="Content-Type" />
<title>Latest Gossip</title>
</head>

<body>
<h3>Latest Gossip About Cory <font size="-1">  [<a href="index.html">front door</a></font>] </h3>

</body>
</html>

<?php
include 'cmd_dispatch.php';

$sql = sprintf("select * from ggdb.version v order by v.creation_time limit 10");
echo $sql;
$result = runScalarDbQuery($sql);
echo $result;


?>
