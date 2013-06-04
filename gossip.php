<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
	<meta content="text/html; charset=utf-8" http-equiv="Content-Type" />
	<style type="text/css">
		.error {
		color: red;
		}
	</style>
	<?php
		// define variables and initialize with empty values
		$userErr = $nickErr = $titErr = $bodyErr = "";
		$username = $nickname = $title = $body = "";
		$reset = true;
		if ($_SERVER[REQUEST_METHOD] == "POST") {
		    if (empty($_POST["username"]))  {
		        $userErr = "Missing";
		        $reset = false;
		    } else {
		        $username = $_POST["username"];
		    }
		    
		    if (empty($_POST["title"])) {
		        $titErr = "Missing";
		        $reset = false;
		    }  else {
		        $title = $_POST["title"];
		    }
		    
		    if (empty($_POST["body"])) {
		        $bodyErr = "Missing";
		        $reset = false;
		    }  else {
		        $body = $_POST["body"];
		    }
		    
		    if($reset){
		    	$username = $nickname = $title = $body = "";
		    }
		}
	?>
	
	<title>Create Gossip</title>
</head>

<body>
	<h3>Create <font size="-1">  [<a href="index.html">front door</a></font>] </h3>
	<h2>Enter information regarding gossip</h2>
	<form name="gossip" action="gossip.php" method="POST" >
		<p>Reporter Username:</p>
		<input type="text" name="username" value="<?php echo htmlspecialchars($username);?>"/>
		<span class="error"><?php echo $userErr;?></span>
		
		<p>Celebrity Nickname:</p>
		<select name="nickname">
			<option value="Kim Kardashian">Kim Kardashian</option>
			<option value="Cee Lo">Cee Lo</option>
			<option value="Brad Pitt">Brad Pitt</option>
			<option value="Peter Griffen">Peter Griffen</option>
			<option value="Macklemore">Macklemore</option>
			<option value="Fresh Prince">Fresh Prince</option>
			<option value="LiLo">LiLo</option>
			<option value="The Masheen">The Masheen</option>
		</select>
		
		<p>Title:</p>
		<input type="text" size="128" name="title" value="<?php echo htmlspecialchars($title);?>"/>
		<span class="error"><?php echo $titErr;?></span>
		
		<p>Body:</p>
		<textarea rows="10" cols="98" name="body"><?php echo htmlspecialchars($body);?></textarea>
		<span class="error"><?php echo $bodyErr;?></span>
		<br/>
		<input type="submit" value="POST"/>
	</form>
	<?php
		
		include 'cmd_dispatch.php';
		
		if ($_SERVER[REQUEST_METHOD] == "POST" && $reset) {
			$sqlInsert = "SELECT ggdb.create_gossip ('def', 'str', '" . $_POST[username] . "', '" . $_POST[nickname] . "', '" . $_POST[title] . "', '" . $_POST[body] . "');";
			$sqlShow = "SELECT * FROM ggdb.version WHERE creation_time > '2013-06-03 13:16:07.60319' ORDER BY creation_time DESC LIMIT 10;";
	?>
	<h3>Recent Gossip</h3>
	<?php	
			runScalarDBQuery($sqlInsert);
			runAndPrint($sqlShow);
			$reset = false;
		}	
	?>
</body>
</html>
