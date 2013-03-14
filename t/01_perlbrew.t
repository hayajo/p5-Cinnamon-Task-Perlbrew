use strict;
use warnings;

use Test::More tests => 8;
use Test::Exception::LessClever;

use Cinnamon::DSL;
use Cinnamon::Task::Perlbrew;
use String::ShellQuote;
use Cwd;
use File::Spec::Functions;

my $host          = 'localhost';
my $perlbrew_root = getcwd;
my $perlbrew      = "perl-5.16.2";

{
    package TESTIN;
    sub TIEHANDLE {
        my $class = shift;
        my @in_lines = map { "$_\n" } @_;
        bless \@in_lines, $class;
    }
    sub READLINE { shift @{ $_[0] } }
}

{
    no strict 'refs';
    no warnings 'redefine';
    *Cinnamon::Remote::execute = sub {
        my ( $self, @cmd ) = @_;
        my $opt = shift @cmd;
        +{ stdout => join( ' ', @cmd ) };
    };
}

subtest 'perlbrew_run' => sub {
    my @run_cmd = qw/perl --version/;

    dies_ok { perlberw_run { run @run_cmd } $perlbrew_root, $perlbrew } "die on local";

    remote {
        my $pass = "mypassword";
        tie local *STDIN, 'TESTIN', $pass;

        my ($stdout_run) = perlbrew_run { run @run_cmd } $perlbrew_root, $perlbrew;
        my ($stdout_sudo) = perlbrew_run { sudo @run_cmd } $perlbrew_root, $perlbrew;
        my @stdout = ($stdout_run, $stdout_sudo);

        my $perlbrew_rc = catfile($perlbrew_root, qw/etc bashrc/);
        for (@stdout) {
            is $_, join( ' ', <<"CMD", @run_cmd );
export PERLBREW_ROOT=$perlbrew_root && \\
export PERLBREW_HOME=$perlbrew_root && \\
source $perlbrew_rc && \\
perlbrew use $perlbrew && \\
CMD
        }
    } $host;
};


subtest 'perlbrew:setup' => sub {
    set perlbrew_root => $perlbrew_root;

    my $task = Cinnamon::Config::get_task('perlbrew:setup');
    my ($stdout) = $task->($host);

    my $perlbrew_bin = catfile($perlbrew_root, qw/bin perlbrew/);
    is $stdout, <<"CMD";
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
CMD
};

subtest 'perlbrew:perl:install' => sub {
    set perlbrew_root                 => $perlbrew_root;
    set perlbrew_perl_version         => $perlbrew;
    set perlbrew_perl_install_options => [qw/--force -j 5/];

    my $task = Cinnamon::Config::get_task('perlbrew:perl:install');
    my ($stdout) = $task->($host);

    my $perlbrew_bin = catfile($perlbrew_root, qw/bin perlbrew/);
    is $stdout, <<"CMD"
export PERLBREW_ROOT=$perlbrew_root && \\
$perlbrew_bin install --verbose --force -j 5 $perlbrew
CMD
};

subtest 'perlbrew:perl:uninstall' => sub {
    set perlbrew_root         => $perlbrew_root;
    set perlbrew_perl_version => $perlbrew;

    my $task = Cinnamon::Config::get_task('perlbrew:perl:uninstall');
    my ($stdout) = $task->($host);

    my $perlbrew_bin = catfile($perlbrew_root, qw/bin perlbrew/);
    is $stdout, <<"CMD"
export PERLBREW_ROOT=$perlbrew_root && \\
$perlbrew_bin uninstall $perlbrew
CMD
};

subtest 'perlbrew:perl:upgrade' => sub {
    set perlbrew_root => $perlbrew_root;
    set perlbrew      => $perlbrew;

    my $task = Cinnamon::Config::get_task('perlbrew:perl:upgrade');
    my ($stdout) = $task->($host);

    my $perlbrew_bin = catfile($perlbrew_root, qw/bin perlbrew/);
    my $perlbrew_rc = catfile($perlbrew_root, qw/etc bashrc/);
    my $upgrade_perl = "perlbrew upgrade-perl\n";
    is $stdout, join(' ', <<"CMD", $upgrade_perl);
export PERLBREW_ROOT=$perlbrew_root && \\
export PERLBREW_HOME=$perlbrew_root && \\
source $perlbrew_rc && \\
perlbrew use $perlbrew && \\
CMD
};

subtest 'perlbrew:lib:create' => sub {
    set perlbrew_root => $perlbrew_root;
    set perlbrew      => $perlbrew;

    my $task = Cinnamon::Config::get_task('perlbrew:lib:create');
    my ($stdout) = $task->($host);

    my $perlbrew_bin = catfile($perlbrew_root, qw/bin perlbrew/);
    is $stdout, <<"CMD";
export PERLBREW_ROOT=$perlbrew_root && \\
export PERLBREW_HOME=$perlbrew_root && \\
$perlbrew_bin lib create $perlbrew
CMD
};

subtest 'perlbrew:lib:delete' => sub {
    set perlbrew_root => $perlbrew_root;
    set perlbrew      => $perlbrew;

    my $task = Cinnamon::Config::get_task('perlbrew:lib:delete');
    my ($stdout) = $task->($host);

    my $perlbrew_bin = catfile($perlbrew_root, qw/bin perlbrew/);
    is $stdout, <<"CMD";
export PERLBREW_ROOT=$perlbrew_root && \\
export PERLBREW_HOME=$perlbrew_root && \\
$perlbrew_bin lib delete $perlbrew
CMD
};

subtest 'perlbrew:lib:cpanm' => sub {
    set perlbrew_root => $perlbrew_root;
    set perlbrew      => $perlbrew;
    set cpanm_modules => [qw/Carton Plack/];
    set cpanm_options => [qw/-L extlib --verbose --no-interactive/];

    my $task = Cinnamon::Config::get_task('perlbrew:cpanm');
    my ($stdout) = $task->($host);

    my $cpanm = "cpanm -L extlib --verbose --no-interactive Carton Plack\n";
    my $perlbrew_bin = catfile($perlbrew_root, qw/bin perlbrew/);
    my $perlbrew_rc = catfile($perlbrew_root, qw/etc bashrc/);
    is $stdout, join( ' ', <<"CMD", $cpanm );
export PERLBREW_ROOT=$perlbrew_root && \\
export PERLBREW_HOME=$perlbrew_root && \\
source $perlbrew_rc && \\
perlbrew use $perlbrew && \\
CMD
};
