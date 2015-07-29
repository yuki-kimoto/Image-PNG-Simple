use Test::More 'no_plan';

use strict;
use warnings;
use File::Temp;
use FindBin;

BEGIN { use_ok('Image::PNG::Simple') };

# Create png file and bitmap file
{
  my $ips = Image::PNG::Simple->new;
  
  # Read bitmap file
  $ips->read_bmp('t/images/dog.bmp');
  
  # Write png and bitmap file
  my $tmp_dir = File::Temp->newdir;
  my $dir_name = $tmp_dir->dirname;
  my $dog_copy_bmp_file = "$dir_name/dog_copy.bmp";
  my $dog_copy_png_file = "$dir_name/dog_copy.png";
  $ips->write_bmp($dog_copy_bmp_file);
  $ips->write_png($dog_copy_png_file);
  
  my $dog_copy_bmp;
  {
    open my $fh, '<', $dog_copy_bmp_file
      or die "Can't open file $dog_copy_bmp_file";
    binmode($fh);
    read($fh, $dog_copy_bmp, -s $dog_copy_bmp_file); 
  }

  my $dog_copy_bmp_expected_file = "$FindBin::Bin/images/dog_copy.bmp";
  my $dog_copy_bmp_expected;
  {
    open my $fh, '<', $dog_copy_bmp_expected_file
      or die "Can't open file $dog_copy_bmp_expected_file";
    binmode($fh);
    read($fh, $dog_copy_bmp_expected, -s $dog_copy_bmp_file); 
  }
  
  is($dog_copy_bmp, $dog_copy_bmp_expected);

  my $dog_copy_png;
  {
    open my $fh, '<', $dog_copy_png_file
      or die "Can't open file $dog_copy_png_file";
    binmode($fh);
    read($fh, $dog_copy_png, -s $dog_copy_png_file); 
  }
  
  my $dog_copy_png_expected_file = "$FindBin::Bin/images/dog_copy.png";
  my $dog_copy_png_expected;
  {
    open my $fh, '<', $dog_copy_png_expected_file
      or die "Can't open file $dog_copy_png_expected_file";
    binmode($fh);
    read($fh, $dog_copy_png_expected, -s $dog_copy_png_expected_file); 
  }
  is($dog_copy_png, $dog_copy_png_expected);

  1;
}
