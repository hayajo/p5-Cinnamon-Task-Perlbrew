use strict;
use warnings FATAL => 'all';
use Module::Build;

my $builder = Module::Build->new(
    module_name          => 'Cinnamon::Task::Perlbrew',
    license              => 'perl',
    dist_author          => 'hayajo <hayajo@cpan.org>',
    dist_version_from    => 'lib/Cinnamon/Task/Perlbrew.pm',
    build_requires       => {
        'Test::More'     => '0.98',
        'Test::Requires' => '0.06',
    },
    configure_requires => { 'Module::Build' => '0.38' },
    requires           => {
        'perl'            => '5.008001',
        # 'REQUIRED::MODULE' => '0',
    },
    script_files   => [],
    create_readme  => 1,
    create_license => ( eval "require Software::License" ) ? 1 : 0,
    # test_files => ( -d '.git' || $ENV{RELEASE_TESTING} ) ? 't/ xt/' : 't/',
    test_files => 't/',
    recursive_test_files => 1,
    add_to_cleanup => ['Cinnamon-Task-Perlbrew-*'],
);

$builder->create_build_script();
