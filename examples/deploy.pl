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
    cpanm_modules         => [qw/JSON::XS Carton/],
    cpanm_options         => '--verbose --notest',
};

task perl => {
    version => sub {
        my ( $host, @args ) = @_;
        my $deploy_to     = get('deploy_to');
        my $perlbrew_root = get('perlbrew_root');
        my $perlbrew      = get('perlbrew');

        no strict 'refs';
        remote {
            perlbrew_run {
                run 'perl --version';
            } $perlbrew_root, $perlbrew;
        } $host;
    },
};

task hello_world => sub {
    run 'echo', 'hello world';
};
