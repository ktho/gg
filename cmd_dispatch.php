<?php
/*
 * filename: cmd_dispatch.php 
 */
 
include_once 'cmd_VARS.php';
include 'db_util.php';
include 'cmd_util.php';
include 'cmd_moduleworkflow.php';
include 'cmd_moduledocument.php';
include 'cmd_moduletagging.php';
include 'cmd_moduleutility.php';

/*
 * This function seeks to find a function that matches the command
 */
function dispatchCommand($cmd_list) 
{
	// The first element is the command name 
	$cmd = $cmd_list[0]; 
	
	// Try to match the command against the utility commands
	$status = dispatchUtilCmd($cmd, $cmd_list); 
	if ($status != cCmdStatus_NOT_FOUND) {
		return $status; 
	}
	
		// Try to match the command against the utility commands
	$status = dispatchWorkflowCmd($cmd, $cmd_list); 
	if ($status != cCmdStatus_NOT_FOUND) {
		return $status; 
	}

	$status = dispatchNodeCmd($cmd, $cmd_list); 
	if ($status != cCmdStatus_NOT_FOUND) {
		return $status; 
	}

	$status = dispatchLinkCmd($cmd, $cmd_list); 
	if ($status != cCmdStatus_NOT_FOUND) {
		return $status; 
	}

	// You could sent the command to other dispatchers if desired ... 
	// $status = dispatchXxxxCmd($cmd, $cmd_list); 

	// Not match was found 
	return cCmdStatus_NOT_FOUND;
}

/* 
 * This function maps the status of a result into short human readable string
 */
function statusMessage($status) {
	switch ($status) {
    	case cCmdStatus_ERROR:
        	return "Error"; 
    	case cCmdStatus_OK:
    		return "OK"; 
    	case cCmdStatus_NOT_FOUND:
    		return "Command not found";
    	default:
    		return "Unknown status"; 
    }
}

/*
 * Used to print the status message of the last command 
 */
function echoStatusMessage($status) 
{
	global $gLastCommand; 
	global $gLastErrorMessage; 
	
	echo $gLastCommand . "\n";
	if ($status == cCmdStatus_ERROR) {
		echo $gLastErrorMessage . "\n";
	}
	echo statusMessage($status) . "\n\n";
}

/*
 * Used to print the result of the last command 
 */
function echoResult()
{
	global $gResult; 
	echo "> " . $gResult . "\n";
}

/* 
 *  This function breaks up command lines into tokens and string chunks, 
 *  creating an array of strings. Example: 
 * 		statement -t1 fred -t2 "mary" - t3 "green monster" 
 *  becomes: 
 *		Array
 *		(
 *		    [0] => statement
 *		    [1] => -t1
 *		    [2] => fred
 *		    [3] => -t2
 *		    [4] => mary
 *		    [5] => -t3 
 *		    [6] => green monster
 *		)
 */
function parseCommandLine($cmd_in)
{
	global $gLastCommand; 
	global $gResult; 
	global $gVariables;
	
	$cmd = trim($cmd_in) . " ";
	$cmd_list = array(); 
	$len = strlen($cmd); 
	$j = 0;
	$k = 0; 
	
	//echo "<pre>cmd: " . $cmd . "\n";

	while ($k < $len) {
		$c = $cmd[$k];
		
		if ($c == " ") {
			//echo "char: " . $c . "(" . $k . ")\n";
		
			$tok = substr($cmd,$j, $k-$j); 
		
			/*
			 * Found a string; therefore, find an end quote and make a chunk
			 */
			if (strlen($tok) > 0 && $tok[0] == "\"") {
				$t = strpos($cmd,"\"",$j+1);
				if ($t !== false) {
					$tok = substr($cmd,$j+1, $t-$j-1);
					$k = $t+1; 
					$j = $t+1; 
				}
				else {
					$tok = substr($cmd, $j+1, $len-2);
					$k = $len;
					$j = $len; 
				}
			}
			/*
			 * Found a $, indicating a variable; therefore, make a substitution 
			 */
			else if (strlen($tok) > 0 && $tok[0] == "$") {
				$t = strpos($cmd, " ",$j+1);
				$start = $j;
				if ($t !== false) {
					$tok = substr($cmd,$j+1, $t-$j-1);
					$k = $t+1; 
					$j = $t+1; 
				}
				else {
					$tok = substr($cmd, $j+1, $len-2);
					$k = $len;
					$j = $len; 
				}
				//echo 'found |' . $tok . "|\n";
				$temp_tok = "NotSet"; 
				if (isset($gVariables[$tok]) && $gVariables[$tok] != NULL) {
					$temp_tok =  $gVariables[$tok];
				}
				
				//echo 'insert this ' . $gVariables[$tok];
					
				$tok = $temp_tok; 
				$part1 = substr($cmd,0,$start) . " " . $tok . " "; 
				$part2 = substr($cmd,$k,$len); 
				$cmd = $part1 . $part2; 
				$start = strlen($part1); 
				$len = strlen($cmd); 
				$k = $j =  $start; 
		}
		/* 
		 * Found a '[' (evaluation bracket); therefore, try to evaluate an expression
		 */
		elseif (strlen($tok) > 0 && $tok[0] == "[") {
				$t = strpos($cmd, "]", $j+1); 
				$start = $j; 
				if ($t !== false) {
					$tok = substr($cmd,$j+1, $t-$j-1);
					$k = $t+1; 
					$j = $t+1; 
				}
				else {
					$tok = substr($cmd, $j+1, $len-2);
					$k = $len;
					$j = $len; 
				}
			//echo "found cmd to evaluate: |" . $tok . "|\n"; 
			
			// Evaluate the token and then put the result into the string
			$s = dispatchCommand(parseCommandLine($tok)); 
			$tok = $gResult;
			$part1 = substr($cmd,0,$start) . " " . $tok . " "; 
			$part2 = substr($cmd,$k,$len); 
			$cmd = $part1 . $part2; 
			$start = strlen($part1); 
			$len = strlen($cmd); 
			$k = $j =  $start; 
		}
		/*
		 * Found a '{' (opening of a list); therefore, find the end of the list
		 */
		elseif (strlen($tok) > 0 && $tok[0] == "{") {
				$t = strpos($cmd, "}", $j+1); 
				if ($t !== false) {
					$tok = substr($cmd,$j+1, $t-$j-1);
					$k = $t+1; 
					$j = $t+1; 
				}
				else {
					$tok = substr($cmd, $j+1, $len-2);
					$k = $len;
					$j = $len; 
				}
			} 
			/* 
			 * Found an ordinary token
			 */
			else {
				//echo "token: |" . $tok . "|\n";  
				$j = $k; 
			}
		
			// Add the token or string chunk to the array 
			array_push($cmd_list,$tok); 
		
			// Eat white space
			while ($k < $len && $cmd[$k] == " ") { $k++; $j++;}
		}
		$k++;
		
		//echo "Echo: " . $cmd . "\n";
	}
	
	$gLastCommand = $cmd_in; 
	return $cmd_list;
}
?>