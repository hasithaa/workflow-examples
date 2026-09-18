# A building permit application submitted by an applicant.
#
# + applicationId - Unique identifier of the application
# + applicant - Name of the person or firm applying
# + address - Address of the proposed works
# + permitClass - Permit class, which decides the conditions that attach
# + description - What the applicant proposes to build
public type PermitApplication record {|
    string applicationId;
    string applicant;
    string address;
    string permitClass;
    string description;
|};

# The letter the agent drafts. Declared as the agent's `resultType`, so the draft
# arrives as a record rather than prose the workflow would have to parse.
#
# + subject - Subject line of the letter
# + body - Body of the letter, addressed to the applicant
# + conditions - Conditions that attach to this permit class
public type LetterDraft record {|
    string subject;
    string body;
    string[] conditions = [];
|};

# What an officer records after assessing the plans. The sign-off task shows it,
# and the officer who submits it is excluded from signing.
#
# + compliant - Whether the plans meet the building code
# + findings - What the officer found
public type AssessmentResult record {|
    boolean compliant;
    string findings = "";
|};

# The drafted letter as the signing officer sees it. Declared as the sign-off
# task's `taskInputType`, so the form shows the draft as read-only context.
#
# + applicationId - The application being decided
# + applicant - Who applied
# + address - Address of the proposed works
# + subject - Subject line of the drafted letter
# + body - Body of the drafted letter
# + conditions - Conditions the agent proposes to attach
# + findings - What the assessing officer found
public type LetterForSigning record {|
    string applicationId;
    string applicant;
    string address;
    string subject;
    string body;
    string[] conditions;
    string findings;
|};

# The signing officer's decision. Amendments are optional: a signer who is content
# with the draft submits none, and the letter goes out as drafted.
#
# + approved - Whether the permit is granted
# + reason - Reason shown to the applicant when it is refused
# + amendedConditions - Conditions replacing the drafted ones, when the signer changes them
public type SigningDecision record {|
    boolean approved;
    string reason = "";
    string[] amendedConditions?;
|};

# Who signed the letter, taken from the sign-off task's completion rather than
# from anything the letter's author could set.
#
# + name - The user who completed the sign-off
# + signedAt - When they completed it
# + asAdministrator - Whether an administrator signed instead of the named audience
public type Signature record {|
    string name;
    string signedAt;
    boolean asAdministrator;
|};

# The issued letter, as sent to the applicant.
#
# + applicationId - The application this letter decides
# + reference - Reference printed on the letter
# + subject - Subject line
# + body - Body of the letter
# + conditions - Conditions attached to the permit
# + signature - Who signed it and when
public type PermitLetter record {|
    string applicationId;
    string reference;
    string subject;
    string body;
    string[] conditions;
    Signature signature;
|};

# Final outcome of one application.
#
# + applicationId - The application identifier
# + status - GRANTED, REFUSED or NOT_COMPLIANT
# + letter - The issued letter, when one was sent
# + deliveryEscalated - Whether a person had to decide on a failing delivery
public type PermitOutcome record {|
    string applicationId;
    string status;
    PermitLetter letter?;
    boolean deliveryEscalated = false;
|};
