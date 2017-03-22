#! /usr/bin/env perl
use strict;
use warnings;
use Data::Dumper;
use File::Path       qw( make_path );
use File::Copy  qw( copy move);
use File::Find::Rule qw( );
use Cwd qw(getcwd);
use File::Basename;
use File::Copy ();
use File::Remove ();
use File::Basename;
use File::Find;
use File::Spec;
use Getopt::Long   qw( GetOptions );
use Cwd;
##TO CHECK THE USAGE AT COMMAND LINE ARGUMENTS##
sub usage {
   if (@_) {
      my ($msg) = @_;
      chomp($msg);
      print(STDERR "$msg\n");
   }
   my $prog = basename($0);
   print(STDERR "$prog --help for usage\n");
   exit(1);
}

sub help {
   my $prog = basename($0);
   print(STDERR "$prog [options] -output output_dir\n");
   print(STDERR "$prog --help\n");
   exit(0);
}
##GETTING INPUT/OUTPUT FILE FROM COMMAND LINE ARGUMENTS##
GetOptions(
    'help|h|?' => \&help,
    'prjroot=s' => \my $input_dir,
    'outdir=s' => \my $output_dir,
    'mapfile=s' => \my $mapfile,
)
    or usage();

    
##CREATING THE DIRECTORIES FROM COMMAND LINE ARGUMENTS##
mkdir $output_dir ;


use File::Spec::Functions qw(rel2abs);
use File::Basename qw(dirname);
while(<>) {
#print $input_dir;
    if(/^REVISION_LOCATION:(.*)/) {
    
        system( my $otherscript, "--prjroot=".rel2abs($1, dirname($ARGV)), "--outdir=$output_dir", "--mapfile=$mapfile");
    }
}


##COPYING THE CONFIG FILES FROM SOURCE TO DESTINATION### 
my %created;
for my $in (
   File::Find::Rule
   ->maxdepth(5)
   ->file()
   ->prune()
   ->name(qr/^[^.].*\.config$/)
   ->in($input_dir)
) {
    my $match_file = substr($in, length($input_dir) + 1); 
    my ($match_dir) = $match_file =~ m{^(.*)/} ? $1 : '.';
    my $out_dir = $output_dir . '/' . $match_dir;
    my $out     = $output_dir . '/' . $match_file;
    make_path($out_dir) if !$created{$out_dir}++;
    copy($in, $out);
}

##TO RENAME DIRECTORIES AND RENAME THE CONTENTS OF THE .CONFIG FILES AS PER MATCHING WITH MAPFILE.TXT CONTENTS##
my $name_map = read_map( $mapfile );
my ($regex) = map {qr /\b(?:$_)\b/ } join '|', map {quotemeta} keys %$name_map;
my $top_dir = $output_dir;
rename_dirs( $top_dir, $name_map, $regex );
sub rename_dirs {
    my ( $top_dir, $name_map, $regex ) = @_;
    opendir (my $dh, $top_dir) or die "Can't open $top_dir: $!";
    my $save_dir = getcwd();
    chdir $top_dir;
    while (my $name = readdir $dh) {
        next if ($name eq '.') or ($name eq '..'); 
        if ( ( -d $name ) && ( exists $name_map->{$name} ) ) {
            my $new_name = $name_map->{$name};
            rename_file_or_dir( $name, $new_name );
            $name = $new_name;            
        }       
        elsif ( -f $name ) {
            when_config_file_rename_and_modify_it( $name, $name_map, $regex );
        }
        else
        {
         #print "  --> is not a directory", "\n";
         }

        if ( -d $name) { 
            
            rename_dirs( $name, $name_map, $regex );
            
            } 
    }
    chdir $save_dir;
}
sub when_config_file_rename_and_modify_it {
    my ( $name, $name_map, $regex ) = @_;
    if (( my $base_name = $name) =~ s/\.config$// ) {
        if ( $name_map->{$base_name} ) {
            my $new_name = $name_map->{$base_name} . '.config';
            rename_file_or_dir( $name, $new_name );
            $name = $new_name;
        }
        change_file( $name, $name_map, $regex );
    }
}
sub change_file {
    my ( $fn, $map, $regex ) = @_;
    open ( my $fh, '<', $fn ) or die "Could not open file '$fn': $!";
    my $str = do { local $/; <$fh> };
    close $fh;
    my $num_replacements = $str =~ s/($regex)/$map->{$1}/ge;
    if ( $num_replacements ) {
        write_new_file( $fn, \$str );
    }
}
sub write_new_file {
    my ( $fn, $str ) = @_;
    open ( my $fh, '>', $fn ) or die "Could not open file '$fn': $!";
    print $fh $$str;
    close $fh;
}
sub rename_file_or_dir {

    my ( $name, $new_name ) = @_;
    File::Copy::move( $name, $new_name )
        or die "Could not rename '$name' as '$new_name': $!";
}
sub read_map {
    my ( $fn ) = @_;
    my %name_map;
    open( my $fh, '<', $fn ) or die "Could not open file '$fn': $!";
    while( my $line = <$fh> ) {
        chomp $line;
        my @fields = split /:/, $line;
       # print @fields;
        if ( @fields == 3 ) {
            $name_map{$fields[2]} = $fields[1];
        }
    }
    close $fh;
    return \%name_map;
}

##RENAME THE FILES WITH ITS DIRECTORIES NAME FROM THE FOLDERS NAME##
    my $input_file_dir = $output_dir;
    sub process_file 
    {
      my $dir_name = (File::Spec -> splitdir ($File::Find::dir))[-1];
      my $file_name = basename $_;
      my $extension = ($file_name =~ m/([^.]+)$/)[0];        
      if ( -f $_ ) 
      {
        rename $_, "$dir_name.$extension";
      }
    }
    finddepth { 'wanted' => \&process_file, 'no_chdir' => 0 }, $input_file_dir;   
    
##PROCESSING AND REMOVING THE UNWANTED DIRECTORIES##
sub ProcessDirectory{
    my ($workdir) = shift;
    my $mask = $workdir . '/*';
    my @dirs = grep { -d } glob $mask;
    foreach my $d (@dirs)
    {
        ProcessDirectory($d);
        my $dirname = basename($d);
        if ($dirname =~ /^temp*/)
        {
          my $filemask = $d . '/*';
          unlink glob $filemask;
          rmdir $d;          
        }
    }
}
ProcessDirectory($output_dir);

##REMOVE TASK.CONFIG FROM ALL DIRECTORIES##
sub DelTaskFiles{
    my ($workdir) = shift;
    my $mask = $workdir . '/*';
    my @files1 = glob $mask;
    foreach my $f (@files1)
    {
        if(-d $f)
        {
        DelTaskFiles($f);
        }
        else
        {
        my $filename1 = basename($f);     
            if ($filename1 =~ /^task*/)
            {
                unlink $f;
            }      
       }
   }
}
DelTaskFiles($output_dir);

###RENAMING THE FILES
sub runDir($$);
sub runDir($$) {
    my $prefix = shift @_;

    my $dir = shift @_;
    opendir(DIR, $dir) or die $!;
    my @entries = readdir(DIR);
    #print "****@entries***";
    close(DIR);
    foreach my $file (@entries) {
        next if ($file =~ /^\.+$/);
        if ( -d $dir . '/' . $file) {
            runDir($prefix . $file .'_', $dir . '/' . $file);
        } elsif ( ( -f $dir . '/' . $file ) && ( $file =~ /\.config$/ ) && ($file !~ /^$prefix/)) {
            my $suffix = $file;
            $suffix=~s{\A[^.]*}{}xms;
            rename $dir . '/' . $file, $dir . '/' . $prefix . $suffix ;
        }
    }
}
runDir('',$output_dir);
##########MAXIMUM FILE FILTER
my $location = $output_dir;
open LOGFILE, $location;
my $first_line = 1;
my $max_id;
while (<LOGFILE>) {
    if (/rev_(\d)+/) {
        if ($first_line) {
            $first_line = 0;
            $max_id = $1;
        } else {
            $max_id = $1 if ($1 > $max_id);
        }
    }
}
close LOGFILE;
##HTML CONVERSION##
my @files = File::Find::Rule->file
                            ->name('*.config')
                            ->prune
                            ->in($output_dir);                                                      
foreach my $file (@files) 
{
    my ($name, $root, $ext) = $file =~ m|(.*)/(.*)\.(.*)|;   
    my $outfile = "$name/$root.html";
    open my $fh_out, '>', $outfile or die "Can't open $outfile: $!","\n";
    my $head = "
<!doctype html>
<html lang=\"en\"> 
<head> <meta charset=\"utf-8\"> <title>DCMS_CHECKLIST</title><tr><td></td></tr> </head> 
<body>
<table>
<th>SL.NO</th><th>CHECKLIST ITEM</th><th>VALUE</th><th>COMMENTS</th><th>CONFIRMATION</th>
<style>
.bold {
  font-weight: bold;
}
.bold td
{
border: 0px;
}
table, th, td {
    border: 1px solid black;
}
</style>";
    print $fh_out $head ;   # write the header
    open my $fh, '<', $file or die "Can't open $file: $!";
    while (my $line=<$fh>) {
    chomp $line;
    for($line)
    {    
    s/\&//g;
    s/[\\\_\@\_]//g;
    s/COMMENT//g;
    }
    my @data = split /:/, $line;
    my $class = $data[0] ? 'normal' : 'bold';  
    print $fh_out qq[<tr class="$class">];
    my $href="http://www.ipdccad.analog.com/cadapps/dev/adikb/dcms";
  #  my $href="https://confluence.analog.com/display/ADIKDB/$root";
    my $check=0;
    my $dolink=$data[0] !~ m/[\=\%]/;
    for my $word(@data){ 
    $check++;
    print $fh_out '<td>';
    if($check==1 && $dolink ) {
         print $fh_out '<a href="'.$href.'" >'.$word.'</a>';   
         }
      else { print $fh_out $word;} 
      print $fh_out '</td>';
      }
      }      
}
#TO Keep .html files in separate folder##
chdir $output_dir;
mkdir 'html',0755;
`find . -name '*.html' | cpio -pdm  html`;


