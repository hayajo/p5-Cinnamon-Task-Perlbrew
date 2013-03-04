package Cinnamon::Task::Perlbrew;

use warnings;
use strict;
use Carp;

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
    my $dsl      = "${caller}::run";
    my $orig_dsl = *{$dsl}{CODE};

    local *{$dsl} = sub (@) {
        my @cmd = @_;
        my $pre_cmd = <<"EOS";
export PERLBREW_ROOT=$perlbrew_root
export PERLBREW_HOME=$perlbrew_root
source $perlbrew_rc
perlbrew use $perlbrew
EOS
        my $opts;
        $opts = shift @cmd if ref $cmd[0] eq 'HASH';

        if ($opts) {
            unshift @cmd, $opts, $pre_cmd;
        }
        else {
            unshift @cmd, $pre_cmd;
        }

        $orig_dsl->(@cmd);
    };

    $code->();
}

task perlbrew => {
    setup => sub {
        my ( $host, @args ) = @_;
        my $perlbrew_root   = shell_quote( get 'perlbrew_root' );
        my $perlbrew_bin    = perlbrew_bin $perlbrew_root;

        remote {
            run <<"EOS";
export PERLBREW_ROOT=$perlbrew_root
if [ ! -e $perlbrew_bin ]; then
    curl -kL http://install.perlbrew.pl > perlbrew-install
    /bin/sh perlbrew-install
    $perlbrew_bin -f install-cpanm
else
fi
    $perlbrew_bin self-upgrade
    $perlbrew_bin -f install-patchperl
    $perlbrew_bin -f install-cpanm
EOS
        } $host;
    },
    perl => {
        install => sub {
            my ( $host, @args ) = @_;
            my $perlbrew_root = shell_quote( get 'perlbrew_root' );
            my $version       = shell_quote( get 'perlbrew_perl_version' );
            my $install_opts  = get 'perlbrew_perl_install_options';
            my $perlbrew_bin  = perlbrew_bin $perlbrew_root;

            remote {
                run "export PERLBREW_ROOT=$perlbrew_root && $perlbrew_bin install --verbose $version $install_opts";
            } $host;
        },
        uninstall => sub {
            my ( $host, @args ) = @_;
            my $perlbrew_root = shell_quote( get 'perlbrew_root' );
            my $version       = shell_quote( get 'perlbrew_perl_version' );
            my $perlbrew_bin  = perlbrew_bin $perlbrew_root;

            remote {
                run "export PERLBREW_ROOT=$perlbrew_root && $perlbrew_bin uninstall $version";
            } $host;
        },
    },
    lib => {
        create => sub {
            my ( $host, @args ) = @_;
            my $perlbrew_root = shell_quote( get 'perlbrew_root' );
            my $perlbrew      = shell_quote( get 'perlbrew' );
            my $perlbrew_bin  = perlbrew_bin $perlbrew_root;

            remote {
                run <<"EOS"
export PERLBREW_ROOT=$perlbrew_root
export PERLBREW_HOME=$perlbrew_root
$perlbrew_bin lib create $perlbrew
EOS
            } $host;
        },
        delete => sub {
            my ( $host, @args ) = @_;
            my $perlbrew_root = shell_quote( get 'perlbrew_root' );
            my $perlbrew      = shell_quote( get 'perlbrew' );
            my $perlbrew_bin  = perlbrew_bin $perlbrew_root;

            remote {
                run <<"EOS"
export PERLBREW_ROOT=$perlbrew_root
export PERLBREW_HOME=$perlbrew_root
$perlbrew_bin lib delete $perlbrew
EOS
            } $host;
        },
    },
    cpanm => sub {
        my ( $host, @args ) = @_;
        my $perlbrew_root   = shell_quote( get 'perlbrew_root' );
        my $perlbrew        = shell_quote( get 'perlbrew' );
        my $modules         = get 'cpanm_modules' || [];
        my $opts            = get 'cpanm_options';
        my $perlbrew_bin    = perlbrew_bin $perlbrew_root;
        my $perlbrew_rc     = perlbrew_rc $perlbrew_root;

        remote {
            my $_modules = join( ' ', @$modules );
            # perlbrew_run $perlbrew_root, $perlbrew, "cpanm $opts $_modules";
        } $host;
    },
};

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
  
  my $perlbrew_root = '/tmp/cinnamon_perlbrew';
  
  # global options
  set perlbrew_root => $perlbrew_root;
  set user          => getpwuid($>);
  
  role development => [qw/localhost/], {
      perlbrew_perl_version => 'perl-5.17.9',
      perlbrew              => 'perl-5.17.9@hoge',
      cpanm_modules         => [qw/JSON::XS Plack/],
      cpanm_options         => '--verbose --notest',
  };
  
  task perl => {
      version => sub {
          my ( $host, @args ) = @_;
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

Cinnamon::Task::Perlbrew is


=head1 TASKS

=head2 C<perlbrew:setup>

=head2 C<perlbrew:perl:install>

=head2 C<perlbrew:perl:uninstall>

=head2 C<perlbrew:lib:create>

=head2 C<perlbrew:lib:delete>

=head2 C<perlbrew:cpanm>


=head1 DSL

=head2 prelbrew_run ( I<$sub: CODE> I<$perlbrew_root: String> I<$perlbrew: String> ): Any

This is supported only under remote.

  # Executed on remote host
  remote {
    perlbrew_run {
        run 'perl --version';
    } $perlbrew_root, $perlbrew;
  } $host;


=head1 AUTHOR

hayajo  C<< <hayajo@cpan.org> >>


=head1 SEE ALSO

L<Cinnamon>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2013, hayajo C<< <hayajo@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=cut
