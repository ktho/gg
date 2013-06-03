<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">

<head>
<meta content="text/html; charset=utf-8" http-equiv="Content-Type" />
<title>Create Gossip</title>
</head>

<body>
<h3>Create <font size="-1">  [<a href="index.html">front door</a></font>] </h3>

<form action="gossip.php" method="post" name="gossip">
<h2>Enter information regarding gossip</h2>
<ul>
<form name="gossip" action="gossip.php" method="POST" >
<p>Workflow Name:<input type="text" name="workflow" /></p>
<p>Workflow Node:<input type="text" name="node" /></p>
<p>Reporter Username:<input type="text" name="username" /></p>
<p>Celebrity Nickname:<input type="text" name="nickname" /></p>
<p>Title:<p><input type="text" size="128" name="title" /></p></p>
<p>Body:<p><textarea rows="10" cols="128" name="body">Enter message body.</textarea></p></p>
<p><input type="submit" /></p>
</form>
</ul> 
</body>
</html>

<?php
include 'cmd_dispatch.php';

if ($_SERVER[REQUEST_METHOD] == "POST") {
$sql = sprintf("select ggdb.create_gossip ('%s', '%s', '%s', '%s', '%s', '%s');", $_POST[workflow], $_POST[node], $_POST[username], $_POST[nickname], $_POST[title], $_POST[body]);
$result = runScalarDbQuery($sql);
echo "HOPE THIS WORKS";
$nl = "\n"; 
$gResult = $nl . print_r($cmd_list,true);
return cCmdStatus_OK; 
}
echo $sql;	

?>
