package Image::PNG::Simple;

use 5.00807;
use strict;
use warnings;

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Image::PNG::Simple', $VERSION);

1;

__END__

=head1 NAME

Image::PNG::Simple - Convert bitmap file to png file without C library dependency.

=head1 SYNOPSIS

  use Image::PNG::Simple;
  
  # Create Image::PNG::Simple object
  my $ips = Image::PNG::Simple->new;
  
  # Read bitmap file
  $ips->read_bmp('dog.bmp');
  
  # Write png file
  $ips->write_png('dog.png');

=head1 DESCRIPTION

Convert bitmap file to png file without C library dependency.

=head1 METHODS

=head2 new

  my $ips = Image::PNG::Simple->new;

Create new Image::PNG::Simple object.

=head2 read_bmp

  $ips->read_bmp('dog.bmp');

Read bitmap file.

=head2 write_bmp

  $ips->write_bmp('dog_copy.bmp');

Write bitmap file.

=head2 write_png

  $ips->write_png('dog.png');

Write png file.

=head1 SEE ALSO

L<Image::PNG>, L<Imager::File::PNG>, L<Image::PNG::Libpng>

=head1 AUTHOR

Yuki Kimoto E<lt>kimoto.yuki@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by Yuki Kimoto

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.16.3 or,
at your option, any later version of Perl 5 you may have available.

=cut
