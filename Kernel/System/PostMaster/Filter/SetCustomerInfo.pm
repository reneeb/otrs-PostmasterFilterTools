# --
# Copyright (C) 2017 Perl-Services.de, http://perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::SetCustomerInfo;

use strict;

use Kernel::System::ObjectManager;
use Kernel::System::EmailParser;

our @ObjectDependencies = qw(
    Kernel::System::CustomerUser
    Kernel::System::Log
);

sub new {
    my $Type  = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;
    
    my $LogObject          = $Kernel::OM->Get('Kernel::System::Log');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');

    my $ParserObject;
    {
        local $Kernel::OM = Kernel::System::ObjectManager->new();

        $ParserObject = Kernel::System::EmailParser->new(
            Mode         => 'Standalone',
            Debug        => 0,
        );
    }

    for my $Needed (qw(JobConfig GetParam)) {
        if ( !$Param{$Needed} ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # get plain email address
    my $From = $Param{GetParam}->{From};

    return 1 if !$From;

    my $PlainFrom = $ParserObject->GetEmailAddress(
        Email => $From,
    );

    return 1 if !$PlainFrom;

    # check if customer user for the mail address already exists
    my %List = $CustomerUserObject->CustomerSearch(
        PostMasterSearch => $PlainFrom,
        Limit            => 2,
    );

    return 1 if !%List;
    return 1 if 1 < scalar keys %List;

    my ($UserID) = keys %List;

    my %CustomerUser = $CustomerUserObject->CustomerUserDataGet(
        User => $UserID,
    );

    return 1 if !%CustomerUser;

    KEY:
    for my $Key ( keys %CustomerUser ) {
        next KEY if ref $CustomerUser{$Key};

        $Param{GetParam}->{'X-OTRS-CustomerUser-' . $Key} = $CustomerUser{$Key};
    }

    return 1;
}

1;

