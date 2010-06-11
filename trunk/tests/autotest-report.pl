#!/usr/bin/perl

# pretty-printing
sub prettysuffix
{
	my $suffix = shift;

	return " C++0x" if ($suffix eq '_0x');
	return " x64" if ($suffix eq '_x64');
	return " PPC" if ($suffix eq '_ppc');

	return "";
}

sub prettytoolset
{
	my $toolset = shift;

	return "Borland C++ 5.82" if ($toolset eq 'bcc');
	return "Metrowerks CodeWarrior 8" if ($toolset eq 'cw');
	return "Digital Mars C++ 8.51" if ($toolset eq 'dmc');
	return "Sun C++ 5.10" . prettysuffix($1) if ($toolset =~ /^suncc(.*)$/);

	return "Intel C++ Compiler $1.0" . prettysuffix($2) if ($toolset =~ /^ic(\d+)(.*)$/);
	return "MinGW (GCC $1.$2)" . prettysuffix($3) if ($toolset =~ /^mingw(\d)(\d)(.*)$/);
	return "Microsoft Visual C++ 7.1" if ($toolset eq 'msvc71');
	return "Microsoft Visual C++ $1.0" . prettysuffix($2) if ($toolset =~ /^msvc(\d+)(.*)$/);
	return "GNU C++ Compiler $1" . prettysuffix($2) if ($toolset =~ /^gcc([\d.]*)(.*)$/);

	$toolset;
}

sub prettyplatform
{
	my $platform = shift;

	return "solaris" if ($platform =~ /solaris/);

	return "macos" if ($platform =~ /darwin/);

	return "linux64" if ($platform =~ /64-linux/);
	return "linux32" if ($platform =~ /86-linux/);

	return "fbsd64" if ($platform =~ /64-freebsd/);
	return "fbsd32" if ($platform =~ /86-freebsd/);

	return "win64" if ($platform =~ /MSWin32-x64/);
	return "win32" if ($platform =~ /MSWin32/);

	$platform;
}

# parse build log
%results = ();
%toolsets = ();
%defines = ();
%configurations = ();

sub insertindex
{
	my ($hash, $key) = @_;

	$$hash{$key} = scalar(keys %$hash) unless defined $$hash{$key};
}

while (<>)
{
	### autotest i386-freebsd-64int gcc release [wchar] result 0 97.78 98.85
	if (/^### autotest (\S+) (\S+) (\S+) \[(.*?)\] (.*)/)
	{
		my ($platform, $toolset, $configuration, $defineset, $info) = ($1, $2, $3, $4, $5);

		my $fulltool = &prettyplatform($platform) . ' ' . &prettytoolset($toolset);
		my $fullconf = "$configuration $defineset";

		if ($info =~ /^prepare/)
		{
			$results{$fulltool}{$fullconf}{result} = 1;
		}
		elsif ($info =~ /^success/)
		{
			$results{$fulltool}{$fullconf}{result} = 0;
		}
		elsif ($info =~ /^coverage (\S+) (\S+)/)
		{
			$results{$fulltool}{$fullconf}{"coverage_$1"} = $2;
		}
		else
		{
			print STDERR "Unrecognized autotest infoline $_";
		}

		&insertindex(\%toolsets, $fulltool);

		$defines{$_} = 1 foreach (split /,/, $defineset);
		&insertindex(\%configurations, $fullconf);
	}
	elsif (/^### autotest revision (\d+)/)
	{
		if (defined $revision && $revision != $1)
		{
			print STDERR "Autotest build report contains several revisions: $revision, $1\n";
		}
		else
		{
			$revision = $1;
		}
	}
}

# make arrays of toolsets and configurations
@toolsetarray = ();
@configurationarray = ();

$toolsetarray[$toolsets{$_}] = $_ foreach (keys %toolsets);
$configurationarray[$configurations{$_}] = $_ foreach (keys %configurations);

# print header
$stylesheet = <<END;
table.autotest { border: 1px solid black; border-left: none; border-top: none; }
table.autotest td { border: 1px solid black; border-right: none; border-bottom: none; }
END

print <<END;
<html><head><title>pugixml autotest report</title><style type="text/css"><!-- $stylesheet --></style></head><body>
<h3>pugixml autotest report</h3>
<table border=1 cellspacing=0 cellpadding=4 class="autotest">
END

# print configuration header (release/debug)
print "<tr><td align='right' colspan=2>configuration</td>";
print "<td>".(split /\s+/)[0]."</td>" foreach (@configurationarray);
print "</tr>\n";

# print defines header (one row for each define)
foreach $define (sort {$a cmp $b} keys %defines)
{
	print "<tr><td align='right' colspan=2><small>$define</small></td>";

	foreach (@configurationarray)
	{
		my $present = ($_ =~ /\b$define\b/);
		my $color = $present ? "#cccccc" : "#ffffff";
		print "<td bgcolor='$color' align='center'>" . ($present ? "+" : "&nbsp;") . "</td>";
	}
	print "</tr>\n";
}

# print data (one row for each toolset)
foreach $tool (@toolsetarray)
{
	my ($platform, $toolset) = split(/\s+/, $tool, 2);
	print "<tr><td style='border-right: none' align='center'><small>$platform</small></td><td style='border-left: none'>$toolset</td>";

	foreach (@configurationarray)
	{
		my $info = $results{$tool}{$_};

		if (!defined $$info{result})
		{
			print "<td bgcolor='#cccccc'>&nbsp;</td>";
		}
		elsif ($$info{result} == 0)
		{
			my ($coverage_pugixml, $coverage_pugixpath) = ($$info{coverage_pugixml}, $$info{coverage_pugixpath});

			print "<td bgcolor='#00ff00' align='center'>pass";
				
			if ($coverage_pugixml > 0 || $coverage_pugixpath > 0)
			{
				print "<br><font size='-2'>" . ($coverage_pugixml + 0) . "%<br>" . ($coverage_pugixpath + 0) . "%</font>";
			}

			print "</td>";
		}
		else
		{
			print "<td bgcolor='#ff0000' align='center'>fail</td>"
		}
	}

	print "</tr>\n";
}

# print footer
$date = localtime;

print <<END;
</table><br>
Generated on $date from Subversion r$revision
</body></html>
END
