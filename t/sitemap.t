use lib './lib';
use strict;
use warnings;

use File::Temp qw/ tempdir /;
use Test::More;
use Try::Tiny;
use XML::Simple;

BEGIN { use_ok('MetaCPAN::Sitemap'); }
{
    require_ok('MetaCPAN::Sitemap');

    # A very simple check that calling the process routine with no arguments
    # causes a croak result.

    try {
        my $sitemap = MetaCPAN::Sitemap::process();
        BAIL_OUT('Did not fail with no arguments.');
    }
    catch {
        ok( 1, "Called with no arguments, caught error: $_" );
    };

    # Test each of the three things that the production script is going to do,
    # but limit the searches to a single chunk of 250 results to speed things
    # along.

    my @tests = (

        {
            inputs => {
                object_type    => 'author',
                field_name     => 'pauseid',
                xml_file       => '',
                cpan_directory => 'author',
            },
            pattern => qr{https:.+/author/[a-z0-9A-Z-]+},
        },

        {
            inputs => {
                object_type    => 'release',
                field_name     => 'distribution',
                xml_file       => '',
                cpan_directory => 'release',
                filter         => { status => 'latest' },
            },
            pattern => qr{https?:.+/release/[a-z0-9A-Z-]+},
        }
    );

    my $search_size = 250;
    my $temp_dir = tempdir( CLEANUP => 1 );

    foreach my $test (@tests) {

       
        # Generate the XML file into a file in a temporary directory, then
        # check that the file exists, is valid XML, and has the right number
        # of URLs.

        my $args = $test->{'inputs'};
        $args->{'size'}     = $search_size;
        $args->{'xml_file'} = File::Spec->catfile( $temp_dir,
            "$test->{'inputs'}{'object_type'}.xml.gz" );
        my $sitemap = MetaCPAN::Sitemap->new($args);
        $sitemap->process();

        ok( -e $args->{'xml_file'},
            "XML output file for $args->{'object_type'} exists" );

        open( my $xmlFH, '<:gzip', $args->{'xml_file'} )
            or BAIL_OUT("Unable to open $args->{'xml_file'}: $!");

        my $xml = XMLin($xmlFH);
        ok( defined $xml, "XML for $args->{'object_type'} checks out" );

        ok( @{ $xml->{'url'} }, "We have some URLs to look at" );
        is(
            $sitemap->{'size'},
            scalar @{ $xml->{'url'} },
            "Number of URLs is correct"
        );

        # Check that each of the urls has the right pattern.

        foreach my $url ( @{ $xml->{'url'} } ) {
            like( $url, $test->{'pattern'}, "URL matches" );
        }
    }

    done_testing;
}
