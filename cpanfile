requires 'Moo' => 2.00;
requires 'namespace::autoclean' => 0.16;

requires 'CPAN::Recent::Uploads';
requires 'Data::Printer';
requires 'DateTime';
requires 'Type::Tiny';
requires 'URI';
requires 'YAML::XS';

on 'test' => sub {
    requires 'Test::More' => '0.88';

    requires 'Test::Fatal';
    requires 'Test::Warnings';
};
