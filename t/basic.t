use Test::More 'no_plan';

use strict;
use warnings;

BEGIN { use_ok('Image::PNG::Simple') };

my $ips = Image::PNG::Simple->new;
$ips->read_bmp('t/dog.bmp');
$ips->write_bmp('t/dog_copy.bmp');
$ips->write_png('t/dog_copy.png');
