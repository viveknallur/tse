#!/usr/local/bin/perl -w
# AUML (v0.1) Winikoff April 2003
# v0.2, 1 September 2003 (added guards, sub-protocols, goto/label)
# v0.2.1, 2 September 2003 (added skip and action)
# v0.2.2, 2 August 2004 (added goal keyword, cf. action)
# v0.2.3, 11 November 2004 (added endstage, setstage, and mmessage for Chris' paper)
# 7 Dec 2004: added goalf for thicker goals and dotdotdot for "..."
# 20 May 2005: added stop agentshort
#   also backupn to control how much backup
#
# Additional (undocumented) commands:
# skip - additional space (reverse of backup)
# action agent text - like a guard, but places over named agent
# The folowing adjust parameters on a per-diagram level (3/9/03)
# They ADD to the named parameter
# agwidth+ number - width of agent box at the top of lifeline
# tagwidth+ number - width of the tag of boxes
# inittagwidth+ number - width of the tag of the top level box
# interboxgap+ number - gap between boxes
# agsep+ number - seperation between agent boxes (top of lifeline)
# offset+ number
#
# Added backupaction (backups up guardheight, rather than messageheight)
#
# Added optional second argument

# configuration stuff
$initvpos=5;			# initial vertical position
$agwidth=80; 			# width of box with agent name
$agsep=40;   			# separation between boxes
$agboxheight=20;		# Height of the agent box
$messageheight=20;		# vertical skip between messages
$agboxskip=$agboxheight+5+$messageheight;	# Vertical space after agent/role name boxes
$boxskip=15;			# Vertical space after closing box (if protocol continues)
$nextskip=20;			# Vertical space after a dashed next line in a box
$tagwidth=65;			# Width of the tag on boxes
$inittagwidth=80;		# Width of the tag for the initial protocol box
$tagheight=20;			# Height of the tag on boxes
$boxtop=$tagheight+5;		# Vertical space after opening of box
$inittagheight=20;		# Height of the tag for the initial protocol box
$initboxtop=$inittagheight+5; 	# vertical space after opening of initial protocol box
$tagsnip=7;			# The amount "snipped" off the tag of boxes (width=height)
$interboxgap=5;			# Space between nested boxes
$wishexec="/usr/local/bin/wish"; # Location of the wish executable
$nextlinewidth=2;		# Width of the "next" dashed line
$boxlinewidth=2;		# Width of the boxes
$textup=10;			# How far up text is moved so as not to be on top of lines
$textmup=8;			# Same, but for messages use a different (lower) shift
$guardheight=$messageheight+10;	# height of guards (and actions)
$subheight=30;			# height of sub-protocol box (NEW)
$contheight = 25;		# height of continuation (goto/label) (NEW)
$triangleoffset = 10; 		# shift triangle towards center in goto/label (NEW)
$stages = "no";			# use grey background for actions if yes
# new
$goalwidth = 160; #width of goal box
$stopheight =  15;
$stopwidth =  2;
# end config

# should be computed ideally ...
$offset=65;		# space at left (for boxes)
#$offset = $interboxgap * numboxes

$line = 0; # input line number
# used to create space between agents/roles and the first message
# init = 1 - processing agent roles
# init = 2 - processing closing boxes
$init = 1; 
$dash = "";

# Count of delayed procedures
$delayed = 0;

# used for mmessage to store coord of last goal
$lastgoaly = 0;

if (!defined($ARGV[0])) {
	print STDERR "Usage: auml.pl filename [arg]\n";
	print STDERR "If a second argument is given then wish and gv will be run.\n";
	print STDERR "The second argument can be anything, e.g. auml.pl filename x.\n\n";
	exit 1;
}

open INPUT,"$ARGV[0]";
open OUT,">$ARGV[0].tk";

print OUT "#!$wishexec\nset epsfile \"$ARGV[0].eps\"\n\n";
print OUT <<'END';

# code from http://wiki.tcl.tk/1416
proc roundRect { w x0 y0 x3 y3 radius args } {
    set r [winfo pixels $w $radius]
    set d [expr { 2 * $r }]

    # Make sure that the radius of the curve is less than 3/8
    # size of the box!

    set maxr 0.75

    if { $d > $maxr * ( $x3 - $x0 ) } {
        set d [expr { $maxr * ( $x3 - $x0 ) }]
    }
    if { $d > $maxr * ( $y3 - $y0 ) } {
        set d [expr { $maxr * ( $y3 - $y0 ) }]
    }

    set x1 [expr { $x0 + $d }]
    set x2 [expr { $x3 - $d }]
    set y1 [expr { $y0 + $d }]
    set y2 [expr { $y3 - $d }]

    set cmd [list $w create polygon]
    lappend cmd $x0 $y0
    lappend cmd $x1 $y0
    lappend cmd $x2 $y0
    lappend cmd $x3 $y0
    lappend cmd $x3 $y1
    lappend cmd $x3 $y2
    lappend cmd $x3 $y3
    lappend cmd $x2 $y3
    lappend cmd $x1 $y3
    lappend cmd $x0 $y3
    lappend cmd $x0 $y2
    lappend cmd $x0 $y1
    lappend cmd -smooth 1
    return [eval $cmd $args]
 }
canvas .c
frame .f
button .f.quit -text "Quit" -command finishup
pack .f -side top
pack .f.quit -fill x -side left
pack .c -side bottom -fill both -expand 1
focus .c
proc finishup {} {
        global epsfile
        set bb [.c bbox all]
        if {[llength $bb] == 0} return
        set x1 [lindex $bb 0]
        set y1 [lindex $bb 1]
        set w [expr [lindex $bb 2]-$x1]
        set h [expr [lindex $bb 3]-$y1]
        .c postscript -file $epsfile  -x $x1 -y $y1 -height $h -width $w
	exit
}
END

%agents = ();  # number of agent (first, second)
%agentsy = (); # y position of roles
@boxes = ();   # stack of boxes - each box stores "type,y"
$agentnum=0;   # next available agent number
$vpos = $initvpos;    # vertical position

while (<INPUT>) {
	$line++;
	chomp;
	($a,$b,$c,@d) = split " ";
	$d = join " ", @d;
	next if !defined($a);
	if ($a eq "agent" || $a eq "role" || $a eq "invis") {
		$c = $c . " " . $d if defined($d);
		print OUT "# agent $b ($c)\n";
		$agents{$b} = $agentnum;
		$agentsy{$b} = -1;
		$pos = ($agwidth/2) + ($agentnum*($agwidth+$agsep)) + $offset;
		$apos = $pos - ($agwidth/2);
		if ($a eq "agent" || $a eq "role") {
			$agentsy{$b} = $vpos;
			$x2 = $apos + $agwidth;
			$y2 = $vpos+$agboxheight-$textup;
			$y3 = $vpos+$agboxheight;
			print OUT ".c create rectangle $apos $vpos $x2 $y3\n";
			$c =~ s/\[/\\\[/g;
			$c =~ s/\]/\\\]/g;
			$c =~ s/\$/\\\$/g;
			print OUT ".c create text $pos $y2 -text \"$c\"\n";
		}
		$agentnum++;
		$init=1;
	} elsif ($a eq "backupn") {
		$vpos = $vpos-$b;
	} elsif ($a eq "backup") {
		$vpos = $vpos-$messageheight;
	} elsif ($a eq "backupaction") {
		$vpos = $vpos-$guardheight;
	} elsif ($a eq "skip") {
		$vpos = $vpos+$messageheight;
	} elsif (($a eq "message") || ($a eq "mmessage")) {
		$vpos = $vpos + $agboxskip if $init==1; # move down if first message
		$vpos = $vpos + $boxskip if $init==2; # move down if message after alt
		$init = 0 if $init>0;
		print OUT "# $a $b $c $d\n";
		$num_from = $agents{$b};
		$num_to  = $agents{$c};
		if (($a eq "mmessage") && ($lastgoaly == 0)) {
			print STDERR "mmessage: no previous goal - line $line\n";
		}
		if ($num_to == $num_from) {
			print STDERR "Can't send a message to self - line $line\n";
		} else {
				$mm_offset = 8;
				$mm_offset = -8 if ($num_from > $num_to);
				$mm_offset = 0 if ($a eq "message"); 
				$pos_from = ($agwidth/2) + ($num_from*($agwidth+$agsep)) +$offset+$mm_offset;
				$pos_to = ($agwidth/2) + ($num_to*($agwidth+$agsep)) +$offset;
				$pos_text = ($pos_to+$pos_from)/2;
				print OUT ".c create line $pos_from $vpos $pos_to $vpos -arrow last\n";
				print OUT ".c create line $pos_from $lastgoaly $pos_from $vpos\n" 
					if ($a eq "mmessage");
				$vpos2 = $vpos-$textmup;
				# quote characters that are interpreted by Tcl/Tk
				$d =~ s/\[/\\\[/g;
				$d =~ s/\]/\\\]/g;
				$d =~ s/\$/\\\$/g;
				print OUT ".c create text $pos_text $vpos2 -text \"$d\"\n";
				$vpos = $vpos+$messageheight;
		}
	} elsif ($a eq "stop") {
		$vpos = $vpos + $agboxskip if $init==1; # move down if first message
		$vpos = $vpos + $boxskip if $init==2; # move down if message after alt
		$init = 0 if $init>0;
		print OUT "# $a $b\n";
		$num_from = $agents{$b};
		$x1 = ($agwidth/2) + ($num_from*($agwidth+$agsep)) +$offset - ($stopheight/2); 
		$x2 = $x1 + $stopheight;
		$y1 = $vpos - ($stopheight/2);
		$y2 = $vpos + ($stopheight/2);
		print OUT ".c create  line $x1 $y1 $x2 $y2 -width $stopwidth\n";
		print OUT ".c create  line $x1 $y2 $x2 $y1 -width $stopwidth\n";
		$vpos = $vpos + $stopheight
    	} elsif ($a eq "start") {
		$c = $c . " " . $d if defined($d) && defined($c);
		$b = $b . " " . $c if defined($c);
		push @boxes, "$b,$vpos";
		$vpos += $initboxtop;
		$dash = "-dash -"; # Make lifelines dashed, not solid
	} elsif (($a eq "goal") || ($a eq "goalf")) { # NEW Guards
		$vpos = $vpos + $agboxskip if $init==1; # move down if first message
		$vpos = $vpos + $boxskip if $init==2; # move down if message after alt
		$c = $c . " " . $d if defined($d) && defined($c);
		$init = 0 if $init>0;
		$c =~ s/\[/\\\[/g;
		$c =~ s/\]/\\\]/g;
		$c =~ s/\$/\\\$/g;
		$guardpos = ($agwidth/2) + ($agents{$b}*($agwidth+$agsep)) + $offset;
		$x1 = $guardpos-($goalwidth/2); $x2 = $guardpos+($goalwidth/2);
		$vpos2 = $vpos+($guardheight/2)-$textup;
		$y1 = $vpos2-8; $y2 = $vpos2+($textup/2);
		$delayed++;
		print OUT "proc delay$delayed {} {\n";
		if ($a eq "goal") {
			print OUT "  .c create rectangle $x1 $y1 $x2 $y2 -fill white \n";
		} else {
			$rad = 4;
			$thick = 3;
			$x1 = $x1 - $thick;
			$x2 = $x2 + $thick;
			$y1 = $y1 - $thick;
			$y2 = $y2 + $thick;
			print OUT " roundRect .c $x1 $y1 $x2 $y2 $rad -outline black -fill white -width $thick\n";
		}
		print OUT "  .c create text $guardpos $vpos2 -text \"$c\"\n";
		print OUT "}\n";
		$lastgoaly = $y2;
		$vpos += $guardheight;
	} elsif ($a eq "dotdotdot") {
		$vpos = $vpos + $agboxskip if $init==1; # move down if first message
		$vpos = $vpos + $boxskip if $init==2; # move down if message after alt
		$init = 0 if $init>0;
		# $guardpos = ($agwidth/2) + ($agents{$b}*($agwidth+$agsep)) + $offset;
		# $xend = ($agwidth/2)+(($agentnum-1)*($agwidth+$agsep))+$offset;
		# $xstart = ($agwidth/2)+$offset;
		$x = (((($agwidth/2)+(($agentnum-1)*($agwidth+$agsep))+$offset)
			+ (($agwidth/2)+$offset))/2) -12;
		$y1 = $vpos-2;
		$y2 = $vpos+2;
		print OUT "#dot dot dot\n";
		$x1 = $x-2;
		$x2 = $x+2;
		print OUT ".c create oval $x1 $y1 $x2 $y2 -fill black\n";
		$x = $x+12;
		$x1 = $x-2;
		$x2 = $x+2;
		print OUT ".c create oval $x1 $y1 $x2 $y2 -fill black\n";
		$x = $x+12;
		$x1 = $x-2;
		$x2 = $x+2;
		print OUT ".c create oval $x1 $y1 $x2 $y2 -fill black\n";
		#print OUT ".c create line $x1 $vpos $x2 $vpos -width 3 -dash .\n";
		$vpos = $vpos + 8;
	} elsif ($a eq "action" || $a eq "percept" || $a eq "comment") { # NEW Guards
		$vpos = $vpos + $agboxskip if $init==1; # move down if first message
		$vpos = $vpos + $boxskip if $init==2; # move down if message after alt
		$c = $c . " " . $d if defined($d) && defined($c);
		$init = 0 if $init>0;
		$c =~ s/\[/\\\[/g;
		$c =~ s/\]/\\\]/g;
		$c =~ s/\$/\\\$/g;
		$guardpos = ($agwidth/2) + ($agents{$b}*($agwidth+$agsep)) + $offset;
		$guardpos = $guardpos - (($agwidth+$agsep)/2) if ($a eq "comment");
		$x1 = $guardpos-2; $x2 = $guardpos+2;
		$vpos2 = $vpos+($guardheight/2)-$textup;
		$y1 = $vpos2-5; $y2 = $vpos2+5;
		$delayed++;
		print OUT "proc delay$delayed {} {\n";
		if ($stages eq "yes") {
			print OUT "  .c create rectangle $x1 $y1 $x2 $y2 -outline {} -fill grey \n";
		} else {
			print OUT "  .c create rectangle $x1 $y1 $x2 $y2 -outline {} -fill white \n";
		}
		print OUT "  .c create text $guardpos $vpos2 -text \"$c\"\n";
		print OUT "}\n";
		$vpos += $guardheight;
	} elsif ($a eq "guard") { # NEW Guards
		$vpos = $vpos + $agboxskip if $init==1; # move down if first message
		$vpos = $vpos + $boxskip if $init==2; # move down if message after alt
		$init = 0 if $init>0;
		$c = $c . " " . $d if defined($d) && defined($c);
		$b = $b . " " . $c if defined($c);
		$b =~ s/\[/\\\[/g;
		$b =~ s/\]/\\\]/g;
		$b =~ s/\$/\\\$/g;
		$guardpos = ($agwidth/2) + $offset;
		$x1 = $guardpos-2; $x2 = $guardpos+2;
		$vpos2 = $vpos +($guardheight/2)-$textup;
		$y1 = $vpos2-5; $y2 = $vpos2+5;
		$delayed++;
		print OUT "proc delay$delayed {} {\n";
		print OUT "  .c create rectangle $x1 $y1 $x2 $y2 -outline {} -fill white \n";
		print OUT "  .c create text $guardpos $vpos2 -text \"$b\"\n";
		print OUT "}\n";
		$vpos += $guardheight;
	} elsif ($a eq "goto" || $a eq "label") { # NEW goto and label
		# Put this into a procedure and call later because need 
		# to delay this until after life lines are drawn.
		$c = $c . " " . $d if defined($d) && defined($c);
		$b = $b . " " . $c if defined($c);
		$vpos = $vpos + $agboxskip if $init==1; # move down if first message
		$vpos = $vpos + $boxskip if $init==2; # move down if message after alt
		# $vpos += $boxtop;
		#$x1 = $interboxgap*(1+($#boxes+1)); 
		#$x2 = $agentnum*($agwidth+$agsep)+$offset-($interboxgap*(1+$#boxes));
		#$x1 += $contindent; $x2 -= ($contindent+$offset);
		$y1 = $vpos;
		# Position around first and last agent lifelines
		$x1 = ($agwidth/2) + (0*($agwidth+$agsep)) +$offset; 
		$x2 = ($agwidth/2) + (($agentnum-1)*($agwidth+$agsep)) +$offset; 
		$x1 -= $contheight+5;
		$x2 += $contheight+5;
		$delayed++;
		print OUT "proc delay$delayed {} {\n";
		$x3 = $x1+$contheight;
		$y3 = $y1+$contheight;
		$x4 = $x2-$contheight;
		$x15 = $x1+($contheight/2);
		$x45 = $x2-($contheight/2);
		print OUT "  .c create rectangle $x15 $y1 $x45 $y3 -outline {} -fill white\n";
		print OUT "  .c create arc $x1 $y1 $x3 $y3 -start 90 -extent 180 -style arc\n";
		print OUT "  .c create arc $x4 $y1 $x2 $y3 -start 270 -extent 180 -style arc\n";
		print OUT "  .c create line $x15 $y1 $x45 $y1\n";
		print OUT "  .c create line $x15 $y3 $x45 $y3\n";
		$x12 = ($x1+$x2)/2;
		$y15 = $y1+($contheight/2);
		print OUT "  .c create text $x12 $y15 -text \"$b\"\n";
		$y4 = $y1+2;
		$y5 = $y1+$contheight-2;
		$x15 = $x15 + $triangleoffset;
		$x3 = $x3 + $triangleoffset;
		$x4 = $x4 - $triangleoffset;
		$x45 = $x45 - $triangleoffset;
		if ($a eq "goto") {
			print OUT "  .c create polygon $x4 $y4 $x45 $y15 $x4 $y5 -fill black\n";
		} else {
			print OUT "  .c create polygon $x15 $y4 $x3 $y15 $x15 $y5 -fill black\n";
		}
		$vpos += $interboxgap+$contheight;
		$init =2;
		print OUT "}\n";
	} elsif ($a eq "sub") { # NEW Sub-Protocol
		# Put this into a procedure and call later because need 
		# to delay this until after life lines are drawn.
		$c = $c . " " . $d if defined($d) && defined($c);
		$b = $b . " " . $c if defined($c);
		$vpos = $vpos + $agboxskip if $init==1; # move down if first message
		$vpos = $vpos + $boxskip if $init==2; # move down if message after alt
		# $vpos += $boxtop;
		$x1 = $interboxgap*(1+($#boxes+1)); 
		$x2 = $agentnum*($agwidth+$agsep)+$offset-($interboxgap*(1+$#boxes));
		$vpos2 = $vpos + $subheight;
		$delayed++;
		print OUT "proc delay$delayed {} {\n";
		print OUT "  .c create rectangle $x1 $vpos $x2 $vpos2 -width $boxlinewidth -fill white\n"; 
		$x3 = $x1+ $tagwidth;
		$x4 = $x1+$tagwidth-$tagsnip;
		$y2 = $vpos+$tagheight-$tagsnip;
		$y3 = $vpos+$tagheight;
		$xtext = ($x1+$x3)/2;
		$ytext = $y3-$textup;
		print OUT "  .c create polygon $x1 $vpos $x3 $vpos $x3 $y2 $x4 $y3 $x1 $y3 -fill {} -outline black -width $boxlinewidth\n";
		print OUT "  .c create text $xtext $ytext -text \"ref\"\n";
		# Center argument in box
		$xtext = ($x1+$x2)/2;
		$ytext = ($vpos+$vpos2)/2; 
		print OUT "  .c create text $xtext $ytext -font {Helvetica 14} -text \"$b\"\n"; 
		$vpos=$vpos2;
		$vpos += $interboxgap;
		$init =2;
		print OUT "}\n";
	} elsif ($a eq "box") {
		$c = $c . " " . $d if defined($d) && defined($c);
		$b = $b . " " . $c if defined($c);
		$vpos = $vpos + $agboxskip if $init==1; # move down if first message
		$vpos = $vpos + $boxskip if $init==2; # move down if message after alt
		$init = 0 if $init>0;
		push @boxes, "$b,$vpos";
		$vpos += $boxtop;
	} elsif ($a eq "next") {
		$x1 = $interboxgap*(1+$#boxes); 
		$x2 = $agentnum*($agwidth+$agsep)+$offset-($interboxgap*$#boxes);
		print OUT ".c create line $x1 $vpos $x2 $vpos -width $nextlinewidth -dash -\n";
		$vpos += $nextskip;
	} elsif (($a eq "end") || ($a eq "finish") || ($a eq "endstage")) {
		$c = $c . " " . $d if defined($d) && defined($c);
		$b = $b . " " . $c if defined($c);
		$x1 = $interboxgap*(1+$#boxes); 
		$x2 = $agentnum*($agwidth+$agsep)+$offset-($interboxgap*$#boxes);
		$l = pop @boxes;
		($type,$y) = split ",", $l;
		if (defined($b) && !($type eq $b) && !($a eq "finish")) {
			print STDERR "Error: $b doesn't match up on line $line - type=$type!\n";
		}
		if ($a eq "endstage") {
			print OUT "set tmp [.c create rectangle $x1 $y $x2 $vpos -fill grey -outline {}]\n";
			print OUT ".c lower \$tmp\n";
		} else {
			print OUT ".c create rectangle $x1 $y $x2 $vpos -width $boxlinewidth\n";
		}
		$extrax = 0;
		$extrax = $inittagwidth-$tagwidth if $a eq "finish";
		$extray = 0;
		$extray = $inittagheight-$tagheight if $a eq "finish";
		$x3 = $x1+ $tagwidth +$extrax;
		$x4 = $x1+$tagwidth +$extrax-$tagsnip;
		$y2 = $y+$tagheight+$extray-$tagsnip;
		$y3 = $y+$tagheight+$extray;
		$xtext = ($x1+$x3)/2;
		$ytext = $y3-$textup;
		print OUT ".c create polygon $x1 $y $x3 $y $x3 $y2 $x4 $y3 $x1 $y3 -fill {} -outline black -width $boxlinewidth\n"
			unless ($a eq "endstage");
		print OUT ".c create text $xtext $ytext -text \"$type\"\n";
		$vpos += $interboxgap if !($a eq "finish");
		$init =2;
# ** split R SR
# ** join R SR
# ** change R SR NR
# ** endrole R

	} elsif ($a eq "goalwidth") {
		$goalwidth = $b;
	} elsif ($a eq "agsep+") {
		$agsep += $b;
	} elsif ($a eq "agwidth+") {
		$agwidth += $b;
	} elsif ($a eq "offset+") {
		$offset += $b;
	} elsif ($a eq "tagwidth+") {
		$tagwidth += $b;
	} elsif ($a eq "inittagwidth+") {
		$inittagwidth += $b;
	} elsif ($a eq "interboxgap+") {
		$interboxgap += $b;
	} elsif (($a eq "#") || ($a eq "--")) {
		# comment, ignore
	} elsif (($a eq "setstages") || ($a eq "setstage")) {
		$stages = "yes";
	} else {
		print STDERR "Ignored input on line $line\n";
	}
}
close INPUT;

print OUT "\n# Create life lines\n";
foreach $k (keys %agents) {
	$pos_from = ($agwidth/2) + ($agents{$k}*($agwidth+$agsep)) +$offset;
	$y = $agentsy{$k}+$agboxheight; 
	print OUT ".c create line $pos_from $y $pos_from $vpos $dash\n" 
		unless $agentsy{$k}==-1;
}
for ($i=1;$i<=$delayed;$i++) {
	print OUT "delay$i\n";
}
print OUT <<'END';
# uncomment for automatic printout and quit
finishup
END

close OUT;

if (defined($ARGV[1])) {
	print "Executing: $wishexec $ARGV[0].tk\n";
	system "$wishexec $ARGV[0].tk";
	if ($ARGV[1] ne "w") {
		print "Executing: gv $ARGV[0].eps\n";
		system "gv $ARGV[0].eps";
	}
}

