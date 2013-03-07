package Cinnamon::Task::Perlbrew;

use warnings;
use strict;
use Carp ();

our $VERSION = '0.01';

# Module implementation here
use parent qw(Exporter);
use Cinnamon::DSL;
use File::Spec::Functions qw/catfile catdir/;
use String::ShellQuote;

our @EXPORT = qw(
    perlbrew_run
);

sub perlbrew_bin      { catfile( $_[0], qw/bin perlbrew/ ) }
sub perlbrew_rc       { catfile( $_[0], qw/etc bashrc/ ) }
sub perlbrew_perl_dir { catdir( $_[0], 'perls', $_[1] ) }

sub perlbrew_run (&$$) {
    my $code          = shift;
    my $perlbrew_root = shell_quote shift;
    my $perlbrew      = shell_quote shift;

    my $perlbrew_bin = perlbrew_bin $perlbrew_root;
    my $perlbrew_rc  = perlbrew_rc $perlbrew_root;

    no strict 'refs';
    no warnings 'redefine';

    my $caller   = caller;
    my $run      = "${caller}::run";
    my $orig_run = *{$run}{CODE} or Carp::croak "$run is not implemented";

    local *{$run} = sub (@) {
        Carp::croak "perlbrew_run have to use with remote"
            unless ( ref $_ eq 'Cinnamon::Remote' );

        my @cmd = @_;
        my $pre_cmd = <<"EOS";
export PERLBREW_ROOT=$perlbrew_root; \\
export PERLBREW_HOME=$perlbrew_root; \\
source $perlbrew_rc && \\
perlbrew use $perlbrew && \\
EOS

        my $opt  = ( ref $cmd[0] eq 'HASH' ) ? shift @cmd : undef;
        my @args = ( $pre_cmd . join( ' ', @cmd ) );
        unshift @args, $opt if ($opt);

        $orig_run->(@args);
    };

    $code->();
}

task perlbrew => {
    setup => sub {
        my ( $host, @args ) = @_;
        my $perlbrew_root   = shell_quote( get 'perlbrew_root' );
        my $perlbrew_sudo   = get 'perlbrew_sudo';
        my $perlbrew_bin    = perlbrew_bin $perlbrew_root;

        remote {
            my $cmd = <<"EOS";
export PERLBREW_ROOT=$perlbrew_root
if [ ! -e $perlbrew_bin ]; then \\
  curl -kL http://install.perlbrew.pl > perlbrew-install; \\
  /bin/sh perlbrew-install; \\
  $perlbrew_bin -f install-cpanm; \\
else \\
  $perlbrew_bin self-upgrade; \\
  $perlbrew_bin -f install-patchperl; \\
  $perlbrew_bin -f install-cpanm; \\
fi
EOS
            chomp $cmd;
            _run( $cmd, $perlbrew_sudo );
        } $host;
    },
    perl => {
        install => sub {
            my ( $host, @args ) = @_;
            my $perlbrew_root = shell_quote( get 'perlbrew_root' );
            my $version       = shell_quote( get 'perlbrew_perl_version' );
            my $install_opts  = get 'perlbrew_perl_install_options';
            my $perlbrew_sudo = get 'perlbrew_sudo';
            my $perlbrew_bin  = perlbrew_bin $perlbrew_root;

            remote {
                _run( "export PERLBREW_ROOT=$perlbrew_root; $perlbrew_bin install --verbose $version $install_opts", $perlbrew_sudo );
            } $host;
        },
        uninstall => sub {
            my ( $host, @args ) = @_;
            my $perlbrew_root = shell_quote( get 'perlbrew_root' );
            my $version       = shell_quote( get 'perlbrew_perl_version' );
            my $perlbrew_sudo = get 'perlbrew_sudo';
            my $perlbrew_bin  = perlbrew_bin $perlbrew_root;

            remote {
                _run( "export PERLBREW_ROOT=$perlbrew_root; $perlbrew_bin uninstall $version", $perlbrew_sudo );
            } $host;
        },
    },
    lib => {
        create => sub {
            my ( $host, @args ) = @_;
            my $perlbrew_root = shell_quote( get 'perlbrew_root' );
            my $perlbrew      = shell_quote( get 'perlbrew' );
            my $perlbrew_sudo = get 'perlbrew_sudo';
            my $perlbrew_bin  = perlbrew_bin $perlbrew_root;

            remote {
                my $cmd = <<"EOS";
export PERLBREW_ROOT=$perlbrew_root; \\
export PERLBREW_HOME=$perlbrew_root; \\
$perlbrew_bin lib create $perlbrew
EOS
                chomp $cmd;
                _run( $cmd, $perlbrew_sudo );
            } $host;
        },
        delete => sub {
            my ( $host, @args ) = @_;
            my $perlbrew_root = shell_quote( get 'perlbrew_root' );
            my $perlbrew      = shell_quote( get 'perlbrew' );
            my $perlbrew_sudo = get 'perlbrew_sudo';
            my $perlbrew_bin  = perlbrew_bin $perlbrew_root;

            remote {
                my $cmd = <<"EOS";
export PERLBREW_ROOT=$perlbrew_root; \\
export PERLBREW_HOME=$perlbrew_root; \\
$perlbrew_bin lib delete $perlbrew
EOS
                chomp $cmd;
                _run( $cmd, $perlbrew_sudo );
            } $host;
        },
    },
    cpanm => sub {
        my ( $host, @args ) = @_;
        my $perlbrew_root   = shell_quote( get 'perlbrew_root' );
        my $perlbrew        = shell_quote( get 'perlbrew' );
        my $modules         = get 'cpanm_modules' || [];
        my $opts            = get 'cpanm_options';
        my $perlbrew_sudo   = get 'perlbrew_sudo';
        my $perlbrew_bin    = perlbrew_bin $perlbrew_root;
        my $perlbrew_rc     = perlbrew_rc $perlbrew_root;

        remote {
            perlbrew_run {
                my $_modules = join( ' ', @$modules );
                _run( "cpanm $opts $_modules", $perlbrew_sudo );
            } $perlbrew_root, $perlbrew;
        } $host;
    },
};

sub _run {
    my ( $cmd, $sudo ) = @_;
    ($sudo) ? sudo $cmd : run $cmd;
}

1; # Magic true value required at end of module
__END__

=head1 NAME

Cinnamon::Task::Perlbrew - [One line description of module's purpose here]


=head1 VERSION

This document describes Cinnamon::Task::Perlbrew version 0.01


=head1 SYNOPSIS

  use strict;
  use warnings;
  
  use Cinnamon::DSL;
  use Cinnamon::Task::Perlbrew;
  
  set user          => getpwuid($>);
  set perlbrew_root => '/tmp/cinnamon_perlbrew';
  
  role development => [qw/localhost/], {
      perlbrew_perl_version => 'perl-5.16.2',
      perlbrew              => 'perl-5.16.2@development',
      cpanm_modules         => [qw/JSON::XS Plack/],
      cpanm_options         => '--verbose --notest',
  };
  
  task perl => {
      version => sub {
          my ( $host, @args ) = @_;
          my $perlbrew_root   = get('perlbrew_root');
          my $perlbrew        = get('perlbrew');
          remote {
              perlbrew_run {
                run 'perl', '--version';
              } $perlbrew_root, $perlbrew;
          } $host;
      },
  };
  
  task server => {
      ...
  }


=head1 DESCRIPTION

Cinnamon::Task::Perlbrew is perlbrew tasks and dsl for L<Cinnamon>.

This is B<alpha> version.

=head1 TASKS

=over 4

=item C<perlbrew:setup>

=item C<perlbrew:perl:install>

=item C<perlbrew:perl:uninstall>

=item C<perlbrew:lib:create>

=item C<perlbrew:lib:delete>

=item C<perlbrew:cpanm>

=back


=head1 DSL

=over 4

=item prelbrew_run ( I<$sub: CODE> I<$perlbrew_root: String> I<$perlbrew: String> ): Any

This is supported only under C<remote>.

C<sudo> is not supported.

  # Executed on remote host
  remote {
    perlbrew_run {
        run 'perl --version';
    } $perlbrew_root, $perlbrew;
  } $host;

=back


=head1 AUTHOR

hayajo  C<< <hayajo@cpan.org> >>


=head1 SEE ALSO

L<Cinnamon>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2013, hayajo C<< <hayajo@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=cut
