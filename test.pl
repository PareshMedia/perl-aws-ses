use strict;

use lib "lib";
use three4clavin::aws::ses;

main();

sub main {
    my $awsSes = new three4clavin::aws::ses(
        AWS_CREDENTIAL_FILE => "aws.creds"
    );
    
    #### Warning - sender must be "verified" by AWS utils outside of this
    #### script, or you'll get nothing but errors back
    my $awsSender   = 'foo@bar.com';
    my $awsReceiver = 'bar@foo.com';
    
    my $emailParts = $awsSes->createNewParts();
    my $filePart   = $awsSes->addFilePart("email.png", "my-image.png", "image/png", $emailParts);
    my $textPart   = $awsSes->addTextPart("Hello World.", "us-ascii", $emailParts);
    my $email      = $awsSes->createEmail($emailParts, $awsSender, $awsReceiver, 'AWS SES Test');
    
    $awsSes->sendEmail($email, $awsSender, $awsReceiver);
    
    print "Email sent.\n";
}
