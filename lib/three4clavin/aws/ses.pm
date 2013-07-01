package three4clavin::aws::ses;

use strict;

#### Cheesy wrapper around the AWS SES perl example code
#### Everyone seems to use the SES example code as gospel - it does a fair job
#### of showing a command line example, but a terrible job of demonstrating
#### an API integration.
#### This lib attempts to bridge that gap, but be warned there's some highly
#### un-tested/un-checked string manipulation.  It "works", but use at your
#### own risk...

#### At the end of the day, this still shells out to the AWS SES sample
#### library which makes too many assumptions about the caller (assumed to be
#### a command line program with flags and switches).  So you'll see some
#### wierdness in here trying to set up the same parameters/options

# Don't have IO::All?  Try:
#     yum install perl-CPAN
#     perl -MCPAN -e shell
#     cpan> install IO::All
use IO::All;

# http://aws.amazon.com/code/8945574369528337
# AWS "official" utils
#     Assumes LWP.  Don't have?  Try:
#         perl -MCPAN -e shell
#         cpan> install LWP
#         cpan> install LWP::Protocol::https
use SES;

use MIME::Base64;
use Encode;
use POSIX;

my $DEFAULT_AWS_CREDENTIAL_FILE = "aws.creds";

sub new {
    my ($class, %args) = @_;
    
    my $self = {
        AWS_CREDENTIAL_FILE => $args{AWS_CREDENTIAL_FILE}
    };
    
    if(! _checkArgs($self)){
        return undef;
    }
    
    bless $self, $class;
    return $self;
}

sub createNewParts {
    my ($self) = @_;
    my @parts = ();
    return \@parts;
}

sub addFilePart {
    my ($self, $file, $filename, $contentType, $parts) = @_;
    
    #if(! defined($charset)){
    #    $charset = "us-ascii";
    #}
    
    # Should probably toss in some undef checks here...
    my $filesize         = -s $file;
    my $modificationTime = (stat $file)[9];
    my $fileDate         = $self->_genDatestamp($modificationTime);
    my $nowDate          = $self->_genDatestamp(time());
    
    my $part = "".
        "Content-Type: ".$contentType."; ".
        "name=\"".$filename."\"\n".
        "Content-Description: ".$filename."\n".
        "Content-Disposition: attachment; ".
        "filename=\"".$filename."\"; ".
        "size=".$filesize.";\n".
        "    creation-date=\"".$fileDate."\";\n".
        "    modification-date=\"".$nowDate."\"\n".
        "Content-Transfer-Encoding: base64".
        "\n\n".
    "";
    $part .= encode_base64(io($file)->all);
    
    if(defined($parts)){
        push(@$parts, $part);
    }
    
    return $part;
}

sub addTextPart {
    my ($self, $text, $charset, $parts) = @_;
    
    if(! defined($charset)){
        $charset = "us-ascii";
    }
    
    my $part = "".
        "Content-Type: text/plain; charset=\"".$charset."\"\n".
        "Content-Transfer-Encoding: quoted-printable".
        "\n\n".
        $text.
    "";
    
    if(defined($parts)){
        push(@$parts, $part);
    }
    
    return $part;
}

sub createEmail {
    my ($self, $parts, $from, $to, $subject) = @_;
    
    # Should we use a better UUID?
    my $boundary = "_____________".(time())."_____";
    my $email = "".
        "From: ".$from."\n".
        "To: ".$to."\n".
        "Subject: ".$subject."\n".
        "Content-Type: multipart/mixed;\n".
        "    boundary=\"".$boundary."\"\n".
        "MIME-Version: 1.0\n".
        "\n".
    "";
    
    if(defined($parts)){
        foreach my $part (@$parts){
            $email .= "--".$boundary."\n";
            $email .= $part."\n";
        }
        $email .= "\n"."--".$boundary."\n";
    }
    
    return $email;
}

sub sendEmail {
    my ($self, $email, $awsSender, $awsReceiver) = @_;
    
    _info("Sending email from $awsSender to $awsReceiver.");
    
    my $params = {
        'Source'                => $awsSender,
        'Destinations.member.1' => $awsReceiver,
        # 'RawMessage.Data'       => encode_base64(encode("utf8", $email->as_string)),
        'RawMessage.Data'       => encode_base64(encode("utf8", $email)),
        'Action'                => 'SendRawEmail'
    };
    
    my $opts   = {
        k => $self->{AWS_CREDENTIAL_FILE},
        # verbose => 'verbose'
    };
    
    my ($responseCode, $responseContent, $responseFlag) =
        SES::call_ses($params, $opts);
    
    if($responseCode ne 200){
        _err("Email errored:    '".$email."'.");
        _err("Response code:    '".$responseCode."'.");
        _err("Response flag:    '".$responseFlag."'.");
        _err("Response content: '".$responseContent."'.");
    }
}

# ---------------- Internal Only Stuff -------------------

sub _genDatestamp {
    my ($self, $time) = @_;
    
    if(! defined($time)){
        $time = time();
    }
    
    my @months = ("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug",
                  "Sep", "Oct", "Nov", "Dec");
    my @wdays  = ("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat");
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = 
        localtime($time);
    $year += 1900;
    my $monName  = $months[$mon];
    my $wdayName = $wdays[$wday];
    
    if($sec < 10){ $sec = "0".$sec; }
    if($min < 10){ $min = "0".$min; }
    if($hour < 10){ $hour = "0".$hour; }
    if($mday < 10){ $mday = "0".$mday; }
    
    my $tz = strftime("%Z", localtime($time));
    my $date = $wdayName.", ".$mday." ".$monName." ".$year." ".$hour.":".
        $min.":".$sec." ".$tz;
    
    return $date;
}

sub _checkArgs {
    my ($self) = @_;
    
    if((! defined($self->{AWS_CREDENTIAL_FILE})) ||
       ("" eq $self->{AWS_CREDENTIAL_FILE})){
        _err("AWS_CREDENTIAL_FILE not provided to aws::ses.");
        _err("Using default '".$DEFAULT_AWS_CREDENTIAL_FILE."'.");
        $self->{AWS_CREDENTIAL_FILE} = $DEFAULT_AWS_CREDENTIAL_FILE;
        return 1;
    }
    
    return 1;
}

sub _err {
    my ($message) = @_;
    print STDERR "[ERR] ".$message."\n";
}

sub _info {
    my ($message) = @_;
    print "[INF] ".$message."\n";
}

# ------------------- Perl Begin/End Voodoo --------------------
BEGIN {
}

END {
}


1;
