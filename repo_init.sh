#!/usr/bin/expect -f

# jbernal
# 2017.10.13

namespace eval cfg {
	variable version 1.0

	variable sections [list DEFAULT]

	variable cursection DEFAULT
	variable DEFAULT;   # DEFAULT section
}

proc cfg::sections {} {
	return $cfg::sections
}

proc cfg::variables {{section DEFAULT}} {
	return [array names ::cfg::$section]
}

proc cfg::add_section {str} {
	variable sections
	variable cursection

	set cursection [string trim $str \[\]]
	if {[lsearch -exact $sections $cursection] == -1} {
		lappend sections $cursection
		variable ::cfg::${cursection}
	}
}

proc cfg::setvar {varname value {section DEFAULT}} {
	variable sections
	if {[lsearch -exact $sections $section] == -1} {
		cfg::add_section $section
	}
	set ::cfg::${section}($varname) $value
}

proc cfg::getvar {varname {section DEFAULT}} {
	variable sections
	if {[lsearch -exact $sections $section] == -1} {
		error "No such section: $section"
	}
	return [set ::cfg::${section}($varname)]
}


proc cfg::parse_file {filename} {
	variable sections
	variable cursection
	set line_no 1
	set fd [open $filename r]
	while {![eof $fd]} {
		set line [string trim [gets $fd] " "]
		if {$line == ""} continue
			switch -regexp -- $line {
				^#.* { }
				^\\[.*\\]$ {
					cfg::add_section $line
				}
				.*=.* {
					set pair [split $line =]
					set name [string trim [lindex $pair 0] " "]
					set value [string trim [lindex $pair 1] " "]
					cfg::setvar $name $value $cursection
				} 
				default {
					error "Error parsing $filename (line: $line_no): $line"
				}
			}
			incr line_no
		}
		close $fd
	}

	set config_path "/home/jbernal/Documentos/Tcl/Skynet_git/"

	cfg::parse_file $config_path[concat repo.cfg]

	set server 				$cfg::SERVER(server_ip)
	set path_main  			$cfg::SERVER(path_main)
	set user_server			$cfg::SERVER(user)
	set repositorio 		$cfg::GITHUB(repositorio)
	set user_github			$cfg::GITHUB(user)
	set pass_github			$cfg::GITHUB(pass)
	set pem_file 			$cfg::LOCAL(pem_file)
	set systemTime 			[clock seconds]
	set iso_date 			[clock format $systemTime -format {%Y%m%d%H%M%S}]

	set folder_deploy		[lindex $argv 0]
	set branch_github		[lindex $argv 1]

	set path_proyect 		$path_main[concat $folder_deploy]
	set path_proyect_new	$path_main$folder_deploy[concat _$iso_date]

	set timeout -1

	if { $branch_github == "" } {
		puts "DEBE ESPECIFICAR BRANCH GITHUB\n";
		exit 1
	}

	if { $folder_deploy == "" } {
		puts "DEBE ESPECIFICAR CARPETA PARA DEPLOY\n";
		exit 1
	}

	spawn ssh -i $pem_file $user_server@$server
	expect "$ "

	send "sudo su\r"
	expect "# "

	send "mv $path_proyect $path_proyect_new\r"
	expect "# "

	send "mkdir $path_proyect\r"
	expect "# "

	send "chown ubuntu:ubuntu $path_proyect -R\r"
	expect "# "

	send "su ubuntu\r"
	expect "$ "

	send "cd $path_proyect\r"
	expect "$ "

	send "git clone $repositorio $path_proyect\r"
	expect "*sername* "

	send "$user_github\r"
	expect "*assw*"

	send "$pass_github\r"
	expect {
		"*Checking connectivity... done*" {
			puts "poyecto ok"
		}
	}

	send "git config credential.helper store\r"
	expect "$ "

	send "git checkout --track origin/$branch_github\r"
	expect "$ "

	send "git checkout $branch_github\r"
	expect "$ "

	send "git pull origin $branch_github\r"
	expect "$ "

	send "sudo chmod 777 storage/ -R\r"
	expect "$ "

	send "cp ../mastergeo/.env .\r"
	expect "$ "

	send "composer install\r"
	expect {
		"*ompiling common classes*" {
			puts "OK CTM!"
		}
	}