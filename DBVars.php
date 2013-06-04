<?php
/* filename: DBVars.php 
 *
 * This file holds information for creating a DB connection string. Edit this 
 * file and careful check that the connection string is correct. 
 *
 * Include this file in other PHH scripts so that you always have the connection
 * string avaiable. 
 */

/* 
 * The host name for the database. Typically one of: 
 *     (1) dante.u.washington.edu for students     (vergil) 
 *     (2) homer.u.washington.edu for faculty/staff or shared accounts  (ovid)
 */
$gDB_host	= "vergil.u.washington.edu";
/*
 * The name of the database
 */
$gDB_name	= 'postgres';
/*
 * The port on which the database is listening  
 */
$gDB_port		= '13131';
/*
 * The NetID user name 
 */
$gDB_user	= 'cte';

$gDB_password = 'acad13bsbl';
/*
 *  This is the connection string for connecting to the database -- 
 *  Note: In this case we do not use a password.
 */
$gDB_conn_string = 	'host=' . 		$gDB_host . 
					' dbname=' . 	$gDB_name . 
					' port=' .		$gDB_port .
					' user=' . 		$gDB_user . 
					' password=' .  $gDB_password;
					
/*  Example 
$gDB_host		= 'vergil.u.washington.edu';
$gDB_name		= 'postgres';
$gDB_port		= '4567';
$gDB_user		= 'xxx';
$gDB_password	= 'xxx';
$gDB_conn_string = 	'host=' . 		$gDB_host . 
					' dbname=' . 	$gDB_name . 
					' port=' .		$gDB_port .
					' user=' . 		$gDB_user . 
					' password=' .	$gDB_password;
*/
?>