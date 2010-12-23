#!/use/bin/perl
use warnings;
use strict;
use lib 'lib';
use Test::More;
use Test::Exception;
use WebService::VaultPress::Partner::Request::History;

# Expected Defauls.
ok my $Obj = WebService::VaultPress::Partner::Request::History->new(),
    "Can make new object.";

is $Obj->limit, 100, "Limit method default is expected.";
is $Obj->offset, 0, "Offset method default is expect.";
is $Obj->api, "https://partner-api.vaultpress.com/gtm/1.0/usage",
    "API method default is expected.";

# No modifications of accessors.
dies_ok sub { $Obj->limit(100) }, "No Post Constructure Modifications";
dies_ok sub { $Obj->offset(100) }, "No Post Constructure Modifications";
dies_ok sub { $Obj->api(100) }, "No Post Constructure Modifications";

# Create With My Own Values

ok $Obj = WebService::VaultPress::Partner::Request::History->new(
    limit => 500,
    offset => 100,
    api => "Hello World",
), "Can make new object with set values.";

is $Obj->limit, 500, "Limit method is expected.";
is $Obj->offset, 100, "Offset method is expected.";
is $Obj->api, "Hello World", "Api method is expected.";

isnt $Obj->limit, 100, "Limit method is consistent.";
isnt $Obj->offset, 500, "Offset method is consistent.";
isnt $Obj->api, "Goodbye World.", "Api method is consistent.";

# Cannot Break Limits.
dies_ok sub { WebService::VaultPress::Partner::Request::History->new(
    limit => -100,
) }, "Unsane Limit Dies.";

dies_ok sub { WebService::VaultPress::Partner::Request::History->new(
    limit => "Hello World",
) }, "Unsane Limit Dies.";

dies_ok sub { WebService::VaultPress::Partner::Request::History->new(
    limit => 1000,
) }, "Unsane Limit Dies.";

dies_ok sub { WebService::VaultPress::Partner::Request::History->new(
    offset => -100,
) }, "Unsane offset Dies.";

dies_ok sub { WebService::VaultPress::Partner::Request::History->new(
    offset => "hello world",
) }, "Unsane offset Dies.";

done_testing;
