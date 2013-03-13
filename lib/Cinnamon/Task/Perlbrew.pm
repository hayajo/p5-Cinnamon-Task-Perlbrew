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

sub _perlbrew_bin      { catfile( $_[0], qw/bin perlbrew/ ) }
sub _perlbrew_rc       { catfile( $_[0], qw/etc bashrc/ ) }
sub _perlbrew_perl_dir { catdir( $_[0], 'perls', $_[1] ) }

sub perlbrew_run (&$$) {
    my $code          = shift;
    my $perlbrew_root = shift;
    my $perlbrew      = shell_quote shift;

    my $perlbrew_bin = shell_quote( _perlbrew_bin $perlbrew_root );
    my $perlbrew_rc  = shell_quote( _perlbrew_rc $perlbrew_root );

    $perlbrew_root   = shell_quote( $perlbrew_root );

    no strict 'refs';
    no warnings 'redefine';

    my $caller   = caller;
    my $run      = "${caller}::run";
    my $orig_run = *{$run}{CODE} or Carp::croak "$run is not implemented";

    local *{$run} = sub (@) {
        Carp::croak "perlbrew_run have to use with remote"
            unless ( ref $_ eq 'Cinnamon::Remote' );

        my @cmd = @_;

        my $cmd_str = <<"EOS";
export PERLBREW_ROOT=$perlbrew_root && \\
export PERLBREW_HOME=$perlbrew_root && \\
source $perlbrew_rc && \\
perlbrew use $perlbrew && \\
EOS

        if ( ref $cmd[0] eq 'HASH' ) {
            splice( @cmd, 1, 0, $cmd_str );
        }
        else {
            unshift( @cmd, $cmd_str );
        }

        $orig_run->(@cmd);
    };

    $code->();
}

task perlbrew => {
    setup => sub {
        my ( $host, @args ) = @_;
        my $perlbrew_root   = get('perlbrew_root') or Carp::croak "perlbrew_root is required";
        my $perlbrew_sudo   = get('perlbrew_sudo') || 0;

        my $perlbrew_bin = _perlbrew_bin $perlbrew_root;
        $perlbrew_root   = shell_quote($perlbrew_root);

        remote {
            _run( <<"EOS", $perlbrew_sudo );
export PERLBREW_ROOT=$perlbrew_root && \\
if [ ! -e $perlbrew_bin ]; then \\
  curl -kL http://install.perlbrew.pl > perlbrew-install && \\
  /bin/sh perlbrew-install && \\
  $perlbrew_bin -f install-cpanm; \\
else \\
  $perlbrew_bin self-upgrade && \\
  $perlbrew_bin -f install-patchperl && \\
  $perlbrew_bin -f install-cpanm; \\
fi
EOS
        } $host;
    },
    perl => {
        install => sub {
            my ( $host, @args ) = @_;
            my $perlbrew_root = get('perlbrew_root') or Carp::croak "perlbrew_root is required";
            my $version       = get('perlbrew_perl_version') or Carp::croak "perlbrew_perl_version is required";
            my $install_opts  = get('perlbrew_perl_install_options') || [];
            my $perlbrew_sudo = get('perlbrew_sudo') || 0;

            my $perlbrew_bin = shell_quote( _perlbrew_bin $perlbrew_root );
            $perlbrew_root   = shell_quote($perlbrew_root);
            $version         = shell_quote($version);

            my $cmd_str = <<"EOS";
export PERLBREW_ROOT=$perlbrew_root && \\
$perlbrew_bin install --verbose
EOS
            chomp $cmd_str;
            for (@$install_opts) {
                $cmd_str .= ' ' . shell_quote($_);
            }
            $cmd_str .= " $version\n";

            remote {
                _run( $cmd_str, $perlbrew_sudo );
            } $host;
        },
        uninstall => sub {
            my ( $host, @args ) = @_;
            my $perlbrew_root = get('perlbrew_root') or Carp::croak "perlbrew_root is required";
            my $version       = get('perlbrew_perl_version') or Carp::croak "perlbrew_perl_version is required";
            my $perlbrew_sudo = get('perlbrew_sudo') || 0;

            my $perlbrew_bin = shell_quote( _perlbrew_bin $perlbrew_root );
            $perlbrew_root   = shell_quote($perlbrew_root);
            $version         = shell_quote($version);

            remote {
                _run( <<"EOS", $perlbrew_sudo );
export PERLBREW_ROOT=$perlbrew_root && \\
$perlbrew_bin uninstall $version
EOS
            } $host;
        },
    },
    lib => {
        create => sub {
            my ( $host, @args ) = @_;
            my $perlbrew_root = get('perlbrew_root') or Carp::croak "perlbrew_root is required";
            my $perlbrew      = get('perlbrew') or Carp::croak "perlbrew is required";
            my $perlbrew_sudo = get('perlbrew_sudo') || 0;

            my $perlbrew_bin = shell_quote( _perlbrew_bin $perlbrew_root );
            $perlbrew_root   = shell_quote($perlbrew_root);
            $perlbrew        = shell_quote($perlbrew);

            remote {
                _run( <<"EOS", $perlbrew_sudo );
export PERLBREW_ROOT=$perlbrew_root && \\
export PERLBREW_HOME=$perlbrew_root && \\
$perlbrew_bin lib create $perlbrew
EOS
            } $host;
        },
        delete => sub {
            my ( $host, @args ) = @_;
            my $perlbrew_root = get('perlbrew_root') or Carp::croak "perlbrew_root is required";
            my $perlbrew      = get('perlbrew') or Carp::croak "perlbrew is required";
            my $perlbrew_sudo = get('perlbrew_sudo') || 0;

            my $perlbrew_bin = shell_quote( _perlbrew_bin $perlbrew_root );
            $perlbrew_root   = shell_quote($perlbrew_root);
            $perlbrew        = shell_quote($perlbrew);

            remote {
                _run( <<"EOS", $perlbrew_sudo );
export PERLBREW_ROOT=$perlbrew_root && \\
export PERLBREW_HOME=$perlbrew_root && \\
$perlbrew_bin lib delete $perlbrew
EOS
            } $host;
        },
    },
    cpanm => sub {
        my ( $host, @args ) = @_;
        my $perlbrew_root   = get('perlbrew_root') or Carp::croak "perlbrew_root is required";
        my $perlbrew        = get('perlbrew') or Carp::croak "perlbrew is required";
        my $modules         = get('cpanm_modules') || [];
        my $cpanm_opts      = get('cpanm_options') || [];
        my $perlbrew_sudo   = get('perlbrew_sudo') || 0;

        my $perlbrew_bin = shell_quote( _perlbrew_bin $perlbrew_root );
        my $perlbrew_rc  = shell_quote( _perlbrew_rc $perlbrew_root );
        $perlbrew_root   = shell_quote($perlbrew_root);
        $perlbrew        = shell_quote($perlbrew);

        my $cmd_str = "cpanm";
        for ( @$cpanm_opts, @$modules ) {
            $cmd_str .= ' ' . shell_quote($_);
        }
        $cmd_str .= "\n";

        remote {
            perlbrew_run {
                _run( $cmd_str, $perlbrew_sudo );
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

=over 2

=item I<perlbrew_root :Srting:Required>

PERLBREW_ROOT path.

=back

=item C<perlbrew:perl:install>

=over 2

=item I<perlbrew_root :String:Required>

PERLBREW_ROOT path.

=item I<perlbrew_perl_version :String:Required>

version of perl.

e.g.

  perl-5.16.2

=item I<perlbrew_perl_install_options :Arrayref>

options for "perlbrew install".

=back

=item C<perlbrew:perl:uninstall>

=over 2

=item I<perlbrew_root :String:Required>

PERLBREW_ROOT path.

=item I<perlbrew_perl_version :String:Required>

version of perl.

e.g.

  perl-5.16.2

=back

=item C<perlbrew:lib:create>

=over 2

=item I<perlbrew_root :String:Required>

PERLBREW_ROOT path.

=item I<perlbrew :String:Required>

lib-name for "perlbrew lib"

e.g.

  perl-5.16.2@nobita, shizuka

=back

=item C<perlbrew:lib:delete>

=over 2

=item I<perlbrew_root :String:Required>

PERLBREW_ROOT path.

=item I<perlbrew :String:Required>

lib-name for "perlbrew lib"

e.g.

  perl-5.16.2@nobita, shizuka

=back

=item C<perlbrew:cpanm>

=over 2

=item I<perlbrew_root :String:Required>

PERLBREW_ROOT path.

=item I<perlbrew :String:Required>

version or lib-name for "perlbrew"

e.g.

  perl-5.16.2, perl-5.16.2@nobita, shizuka

=item I<cpanm_modules :ArrayRef>

install modules.

=item I<cpanm_options :ArrayRef>

options for "cpanm".

=back

=back


=head1 DSL

=over 4

=item perlbrew_run ( I<$sub: CODE> I<$perlbrew_root: String> I<$perlbrew: String> ): Any

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
