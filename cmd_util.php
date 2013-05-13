<?php
/*
 * filename: cmd_util.php 
 */


/*
 * This function dispatches a command and its parameters to the corresponding function 
 */
function dispatchUtilCmd($cmd, $cmd_list) 
{
	$cmd = $cmd_list[0]; 
	
	if ($cmd == "help") {
		$status = help($cmd_list);
	}
	elseif ($cmd == "hello") {
		$status = hello($cmd_list);
	}
	elseif ($cmd == "examples") {
		$status = examples_cmd($cmd_list);
	}
	elseif ($cmd == "cmd") {
		$status = cmd($cmd_list); 
	}
	elseif ($cmd == "pingdb") {
		$status = pingdb($cmd_list); 
	}
	elseif ($cmd == "sum") {
		$status = sum_cmd($cmd_list);
	}
	elseif ($cmd == "set") {
		$status = set_cmd($cmd_list);
	}
	elseif ($cmd == "unset") {
		$status = unset_cmd($cmd_list);
	}
	elseif ($cmd == "print") {
		$status = print_cmd($cmd_list);
	}
	else {
		$status = cCmdStatus_NOT_FOUND; 
	}
	return $status;
}

/*
 * hello -- Prints a message to the terminal 
 */
function hello($cmd_list) {
	global $gResult;
 	$gResult = "Hello to you too!"; 	
	return cCmdStatus_OK; 
}

/* 
 * 	cmd - prints the parameters of a command (good for debugging) 
 *				cmd --switch -p1 hello -p2 "hello world" {a b c d} cheers 
 *
 * 				> Array
 *				(
 *   					[0] => cmd
 *   					[1] => --switch
 *  					[2] => -p1
 * 						[3] => hello
 *  					[4] => -p2
 *  					[5] => hello world
 *  					[6] => a b c d
 *  					[7] => cheers
 *				)
 */
function cmd($cmd_list) {
	global $gResult;
	$gResult = print_r($cmd_list,true); 
	return cCmdStatus_OK; 
}

/* 
 *	pingdb - pings the database and prints a status message
 */
function pingdb($cmd_list) {
	global $gResult;
	$gResult = returnDbStatus();  
	return cCmdStatus_OK; 
}

/* 
 * sum - adds a list of numbers together 
 * 			sum 1 2 3 4 5 
 */
function sum_cmd($cmd_list) {
	global $gResult;
	
	$k=1; 
	$t=0; 
	while ($k < count($cmd_list)) {
		$t += $cmd_list[$k]; 
		$k++; 
	}
	$gResult = $t; 
	
	return cCmdStatus_OK; 
}

/* 
 * set - assigns a value to a variable which can then be referenced with $
 * 			set t 10 
 *			set z "hello world"
 *			set x $t
 *			print t x z 
 */
 function set_cmd($cmd_list) {
	global $gResult;
	global $gVariables;
	
	$gResult = ""; 
		
	//print_r($gVariables);
	$var = $cmd_list[1]; 
	$val = $cmd_list[2];
	
	$gVariables[$var] = $val;  

	//print_r($gVariables);
	//print_r($cmd_list); 
	return cCmdStatus_OK; 
}

/* 
 * unset - removes a variable for the system 
 * 			set t 10 
 *			unset t 
 */
function unset_cmd($cmd_list) {
	global $gResult;
	global $gVariables;
	$gVariables[$cmd_list[1]] = NULL; 
	print_r($cmd_list); 
	return cCmdStatus_OK; 
}

/* 
 *  print - Prints out a list of variables 
 * 			set t 10 
 * 			set z 2
 * 			print t z 
 */
function print_cmd($cmd_list) {
	global $gResult;
	global $gVariables;
	
	
	$k=1; 
	$t=""; 
	while ($k < count($cmd_list)) {
		$var = $cmd_list[$k]; 
		$val = "NotSet"; 
		if (isset($gVariables[$var]) == true)  {
			$val = $gVariables[$var]; 
		}
		$t .= $val . " "; 
		$k++; 
	}
	$gResult = $t; 
	return cCmdStatus_OK; 
}

/*
 * Returns a summary of call commands that have been implemented
 */
function getAllCmds() 
{
	$s  = ""; 
 	$s .= "help <command>";
 	$s .= " | examples";
 	$s .= " | hello";
 	$s .= " | cmd <a1> <a2> ... ";
 	$s .= " | pingdb ";
 	$s .= " | sum <a1> <a2> ... ";
 	$s .= " | set <variable> <value> ";
 	$s .= " | unset <variable> ";
 	$s .= " | print <a1> <a2> ...";
 	return $s;
 }

/*
 * Prints a message to the terminal 
 */
function help($cmd_list) {
	global $gResult;
	if (count($cmd_list) == 1) {
		$gResult = getAllCmds(); 
		return cCmdStatus_OK; 
	}
	elseif (count($cmd_list) > 1) {
		$cmd = $cmd_list[1];
		if ($cmd == "pingdb") {
			$gResult = "pingdb -details about pingdb"; 
		}
		elseif ($cmd == "hello") {
			$gResult = "hello -prints a message"; 
		}
		elseif ($cmd == "cmd") {
			$gResult = "cmd <a1> <a2> ... -prints out the arguments for a command \n"; 
			$gResult .= "  try: cmd --switch -p1 hello -p2 \"hello world\" {a b c d} cheers"; 
		}
		elseif ($cmd == "sum") {
			$gResult = "sum <a1> <a2> ... -sums the arguments \n"; 
			$gResult .= "  try: sum 1 2 3 4 5"; 
		}
		elseif ($cmd == "set") {
			$gResult = "set <variable> <value> -assign a value to a variable \n"; 
			$gResult .= '  try: set t 10' . "\n" . '       set z $t' . "\n       print t z";
		}
		elseif ($cmd == "unset") {
			$gResult = "unset <variable> -remove a variable assignment\n"; 
			$gResult .= '  try: set t 10' . "\n" . '       unset t' . "\n       print t";
		}
		elseif ($cmd == "print") {
			$gResult = "print <a1> <a2> ... - print out each variable"; 
		}
		elseif ($cmd == "help") {
			$gResult = "help <command> - prints out a short help message"; 
		}
		elseif ($cmd == "examples") {
			$gResult = "examples - prints out some examples"; 
		}

	}
	return cCmdStatus_OK; 
}

function examples_cmd($cmd_list)
{
	global $gResult;
 	$gResult 	 = 		"Examples: \n"; 
 	$gResult 	.= 		"  #1\n"; 	
 	$gResult 	.=		"      set t 1\n"; 
 	$gResult 	.=		"      set z 6\n"; 
 	$gResult	.=		'      sum $t $z' . "\n"; 
 	 
 	$gResult 	.= 		"  #2\n"; 	
 	$gResult 	.=		"      set t 1\n"; 
 	$gResult 	.=		"      set z 6\n"; 
 	$gResult	.=		'      set x [sum $t $z]' . "\n"; 
 	$gResult	.=		'      print x' . "\n"; 

 	$gResult 	.= 		"  #3\n"; 	
 	$gResult 	.=		"      sum [sum 1 2] [sum 10 20] \n"; 
 
 	$gResult    .= 		"  #4\n"; 	
 	$gResult 	.=		"      cmd --switch -p1 hello -p2 \"hello world\" {a b c d} cheers \n"; 

	return cCmdStatus_OK; 
}


?>